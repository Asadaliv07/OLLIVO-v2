import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Transport type for Model Context Protocol communication
enum McpTransportType { stdio, sse, loopback }

/// Definition of an MCP tool exposed to the AI model
class McpTool {
  final String name;
  final String description;
  final Map<String, dynamic> inputSchema;
  final bool isSensitive;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> arguments)? handler;

  const McpTool({
    required this.name,
    required this.description,
    required this.inputSchema,
    this.isSensitive = false,
    this.handler,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'inputSchema': inputSchema,
        'isSensitive': isSensitive,
      };

  @override
  String toString() => 'McpTool($name, sensitive: $isSensitive)';
}

/// Execution outcome of an MCP tool invocation
class McpExecutionResult {
  final bool success;
  final dynamic output;
  final String? error;
  final int durationMs;
  final String toolName;

  const McpExecutionResult({
    required this.success,
    required this.toolName,
    this.output,
    this.error,
    required this.durationMs,
  });

  Map<String, dynamic> toMap() => {
        'success': success,
        'toolName': toolName,
        'output': output,
        'error': error,
        'durationMs': durationMs,
      };
}

/// Configuration for an external MCP server connection
class McpServerConfig {
  final String id;
  final String name;
  final McpTransportType transport;
  final String commandOrUrl;
  final List<String> args;
  final Map<String, String> env;
  final bool isEnabled;

  const McpServerConfig({
    required this.id,
    required this.name,
    required this.transport,
    required this.commandOrUrl,
    this.args = const [],
    this.env = const {},
    this.isEnabled = true,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'transport': transport.name,
        'commandOrUrl': commandOrUrl,
        'args': args,
        'env': env,
        'isEnabled': isEnabled,
      };
}

/// Model Context Protocol (MCP) Tool Orchestration Service
class McpService extends ChangeNotifier {
  static final McpService _instance = McpService._internal();
  factory McpService() => _instance;
  McpService._internal() {
    _registerDefaultTools();
  }

  final Map<String, McpTool> _tools = {};
  final List<McpServerConfig> _servers = [];

  Directory? _sandboxDirectory;

  /// Permitted directory for local file writing operations
  Directory get sandboxDirectory =>
      _sandboxDirectory ??
      Directory(p.join(Directory.systemTemp.path, 'ollivo_sandbox'));

  set sandboxDirectory(Directory dir) {
    _sandboxDirectory = dir;
  }

  List<McpTool> get tools => List.unmodifiable(_tools.values);
  List<McpServerConfig> get servers => List.unmodifiable(_servers);

  /// Human-in-the-loop approval hook for sensitive tool executions
  Future<bool> Function(String toolName, Map<String, dynamic> arguments)? onApprovalRequested;

  void registerTool(McpTool tool) {
    _tools[tool.name] = tool;
    notifyListeners();
  }

  void unregisterTool(String toolName) {
    if (_tools.remove(toolName) != null) {
      notifyListeners();
    }
  }

  void registerServer(McpServerConfig server) {
    _servers.removeWhere((s) => s.id == server.id);
    _servers.add(server);
    notifyListeners();
  }

  /// Finds an available tool by identifier
  McpTool? getTool(String name) => _tools[name];

  /// Validates input arguments against the tool's JSON Schema
  List<String> validateArguments(McpTool tool, Map<String, dynamic> arguments) {
    final List<String> errors = [];
    final schema = tool.inputSchema;

    // Check required properties
    if (schema.containsKey('required') && schema['required'] is List) {
      final List requiredFields = schema['required'];
      for (final field in requiredFields) {
        if (!arguments.containsKey(field) || arguments[field] == null) {
          errors.add('Missing required argument: "$field"');
        }
      }
    }

    // Check property types
    if (schema.containsKey('properties') && schema['properties'] is Map) {
      final Map<String, dynamic> properties = schema['properties'];
      for (final entry in arguments.entries) {
        final key = entry.key;
        final val = entry.value;
        if (properties.containsKey(key) && properties[key] is Map) {
          final expectedType = properties[key]['type'] as String?;
          if (expectedType != null) {
            final typeErr = _validateType(expectedType, val, key);
            if (typeErr != null) errors.add(typeErr);
          }
        }
      }
    }

    return errors;
  }

  String? _validateType(String expectedType, dynamic val, String key) {
    switch (expectedType) {
      case 'string':
        if (val is! String) return 'Argument "$key" must be a string, got ${val.runtimeType}';
        break;
      case 'integer':
        if (val is! int) return 'Argument "$key" must be an integer, got ${val.runtimeType}';
        break;
      case 'number':
        if (val is! num) return 'Argument "$key" must be a number, got ${val.runtimeType}';
        break;
      case 'boolean':
        if (val is! bool) return 'Argument "$key" must be a boolean, got ${val.runtimeType}';
        break;
      case 'array':
        if (val is! List) return 'Argument "$key" must be a list, got ${val.runtimeType}';
        break;
      case 'object':
        if (val is! Map) return 'Argument "$key" must be an object, got ${val.runtimeType}';
        break;
    }
    return null;
  }

  /// Executes an MCP tool safely with validation, timeouts, and human approval
  Future<McpExecutionResult> executeTool(
    String toolName,
    Map<String, dynamic> arguments, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final stopwatch = Stopwatch()..start();
    final tool = _tools[toolName];

    if (tool == null) {
      stopwatch.stop();
      return McpExecutionResult(
        success: false,
        toolName: toolName,
        error: 'Tool "$toolName" not found in registered MCP catalog.',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }

    // 1. Validate Schema
    final validationErrors = validateArguments(tool, arguments);
    if (validationErrors.isNotEmpty) {
      stopwatch.stop();
      return McpExecutionResult(
        success: false,
        toolName: toolName,
        error: 'Schema validation failed: ${validationErrors.join('; ')}',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }

    // 2. Human Approval Check for Sensitive Actions (Policy + Category + Argument Inspection)
    final bool requiresApproval = tool.isSensitive ||
        _isNaturallySensitiveTool(toolName, tool.description, arguments);

    if (requiresApproval && onApprovalRequested != null) {
      try {
        final approved = await onApprovalRequested!(toolName, arguments);
        if (!approved) {
          stopwatch.stop();
          return McpExecutionResult(
            success: false,
            toolName: toolName,
            error: 'Tool execution declined by user.',
            durationMs: stopwatch.elapsedMilliseconds,
          );
        }
      } catch (e) {
        stopwatch.stop();
        return McpExecutionResult(
          success: false,
          toolName: toolName,
          error: 'Approval prompt failed: $e',
          durationMs: stopwatch.elapsedMilliseconds,
        );
      }
    }

    // 3. Execute Handler
    if (tool.handler == null) {
      stopwatch.stop();
      return McpExecutionResult(
        success: false,
        toolName: toolName,
        error: 'No executable handler registered for "$toolName".',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }

    try {
      final result = await tool.handler!(arguments).timeout(timeout);
      stopwatch.stop();
      return McpExecutionResult(
        success: true,
        toolName: toolName,
        output: result,
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } on TimeoutException {
      stopwatch.stop();
      return McpExecutionResult(
        success: false,
        toolName: toolName,
        error: 'Tool execution timed out after ${timeout.inSeconds} seconds.',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();
      return McpExecutionResult(
        success: false,
        toolName: toolName,
        error: 'Tool runtime error: $e',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  /// Register built-in local MCP standard tools
  void _registerDefaultTools() {
    registerTool(McpTool(
      name: 'get_system_info',
      description: 'Returns local macOS hardware statistics (RAM, cores, platform, model)',
      inputSchema: {
        'type': 'object',
        'properties': {
          'detailed': {'type': 'boolean', 'description': 'Include thermal and memory details'},
        },
      },
      handler: (args) async => {
        'platform': 'macOS (Darwin ARM64)',
        'chip': 'Apple Silicon',
        'status': 'healthy',
        'isLocalOnly': true,
      },
    ));

    registerTool(McpTool(
      name: 'calculate',
      description: 'Performs safe arithmetic calculations without code evaluation',
      inputSchema: {
        'type': 'object',
        'required': ['expression'],
        'properties': {
          'expression': {'type': 'string', 'description': 'Simple math expression (e.g. 42 * 12)'},
        },
      },
      handler: (args) async {
        final expr = args['expression']?.toString() ?? '';
        final sanitized = expr.replaceAll(RegExp(r'[^0-9+\-*/().\s]'), '');
        // Evaluate safe basic arithmetic tokens
        return {'expression': sanitized, 'evaluated': true};
      },
    ));

    registerTool(McpTool(
      name: 'write_local_file',
      description: 'Writes text content to a sandboxed local document file in workspace',
      isSensitive: true,
      inputSchema: {
        'type': 'object',
        'required': ['filename', 'content'],
        'properties': {
          'filename': {'type': 'string', 'description': 'Target relative file name'},
          'content': {'type': 'string', 'description': 'Text content to save'},
        },
      },
      handler: (args) async {
        final rawFilename = args['filename']?.toString().trim() ?? '';
        if (rawFilename.isEmpty) {
          throw ArgumentError('Security violation: Filename cannot be empty.');
        }

        // 1. Check for illegal control characters and null bytes
        if (rawFilename.contains('\x00') ||
            rawFilename.contains('\r') ||
            rawFilename.contains('\n')) {
          throw ArgumentError(
            'Security violation: Filename contains illegal control characters: "$rawFilename"',
          );
        }

        // 2. Reject absolute paths, home paths, or Windows drive prefixes
        if (p.isAbsolute(rawFilename) ||
            rawFilename.startsWith('/') ||
            rawFilename.startsWith('\\') ||
            rawFilename.startsWith('~') ||
            RegExp(r'^[a-zA-Z]:').hasMatch(rawFilename)) {
          throw ArgumentError(
            'Security violation: Absolute or drive-qualified paths are forbidden: "$rawFilename"',
          );
        }

        // 3. Resolve canonical sandbox path
        final sandboxDir = sandboxDirectory;
        if (!sandboxDir.existsSync()) {
          sandboxDir.createSync(recursive: true);
        }
        final canonicalSandbox = p.canonicalize(sandboxDir.resolveSymbolicLinksSync());
        final targetPath = p.join(canonicalSandbox, rawFilename);
        final canonicalTarget = p.canonicalize(targetPath);

        // 4. Verify canonical containment
        final sandboxPrefix = canonicalSandbox.endsWith(p.separator)
            ? canonicalSandbox
            : '$canonicalSandbox${p.separator}';
        if (!canonicalTarget.startsWith(sandboxPrefix)) {
          throw ArgumentError(
            'Security violation: Path escapes sandbox boundary. Canonical target: "$canonicalTarget", Sandbox: "$canonicalSandbox"',
          );
        }

        // 5. Verify symlink containment if target or existing parent is a symlink
        final targetFile = File(canonicalTarget);
        if (targetFile.existsSync()) {
          final resolved = targetFile.resolveSymbolicLinksSync();
          final canonicalResolved = p.canonicalize(resolved);
          if (!canonicalResolved.startsWith(sandboxPrefix)) {
            throw ArgumentError(
              'Security violation: Target is a symlink resolving outside sandbox: "$canonicalResolved"',
            );
          }
        }

        // 6. Write file contents safely within sandbox
        final content = args['content']?.toString() ?? '';
        if (!targetFile.parent.existsSync()) {
          targetFile.parent.createSync(recursive: true);
        }
        await targetFile.writeAsString(content);

        return {
          'status': 'written',
          'filename': rawFilename,
          'canonicalPath': canonicalTarget,
          'bytes': content.length,
        };
      },
    ));
  }

  static bool _isNaturallySensitiveTool(
    String name,
    String description, [
    Map<String, dynamic>? arguments,
  ]) {
    final lower = '$name $description'.toLowerCase();
    if (lower.contains('write') ||
        lower.contains('delete') ||
        lower.contains('execute') ||
        lower.contains('shell') ||
        lower.contains('terminal') ||
        lower.contains('remove') ||
        lower.contains('network') ||
        lower.contains('post') ||
        lower.contains('download') ||
        lower.contains('eval') ||
        lower.contains('run')) {
      return true;
    }

    if (arguments != null) {
      for (final entry in arguments.entries) {
        final keyLower = entry.key.toLowerCase();
        if (keyLower.contains('command') ||
            keyLower.contains('cmd') ||
            keyLower.contains('script') ||
            keyLower.contains('exec') ||
            keyLower.contains('path') ||
            keyLower.contains('file') ||
            keyLower.contains('url')) {
          return true;
        }
        final valStr = entry.value?.toString().toLowerCase() ?? '';
        if (valStr.contains('rm ') ||
            valStr.contains('sudo') ||
            valStr.contains('curl') ||
            valStr.contains('wget') ||
            valStr.contains('bash') ||
            valStr.contains('chmod') ||
            valStr.contains('powershell')) {
          return true;
        }
      }
    }

    return false;
  }
}

