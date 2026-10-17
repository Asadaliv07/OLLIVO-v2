import 'package:flutter_test/flutter_test.dart';
import 'package:ollivo/services/mcp_service.dart';

void main() {
  group('McpService Unit and Tool Execution Tests', () {
    late McpService mcpService;

    setUp(() {
      mcpService = McpService();
      mcpService.onApprovalRequested = null;
    });

    test('Initializes with default builtin system tools', () {
      final tools = mcpService.tools;
      expect(tools.length, greaterThanOrEqualTo(3));
      expect(tools.any((t) => t.name == 'get_system_info'), isTrue);
      expect(tools.any((t) => t.name == 'calculate'), isTrue);
      expect(tools.any((t) => t.name == 'write_local_file'), isTrue);
    });

    test('get_system_info executes successfully without human approval', () async {
      final result = await mcpService.executeTool('get_system_info', {});
      expect(result.success, isTrue);
      expect(result.output, isNotNull);
      expect(result.output['platform'], contains('macOS'));
      expect(result.output['chip'], equals('Apple Silicon'));
      expect(result.output['isLocalOnly'], isTrue);
    });

    test('Validates required parameters and rejects invalid schema', () async {
      // calculate requires 'expression'
      final result = await mcpService.executeTool('calculate', {});
      expect(result.success, isFalse);
      expect(result.error, contains('Missing required argument: "expression"'));
    });

    test('Rejects unknown non-existent tools safely', () async {
      final result = await mcpService.executeTool('non_existent_tool_123', {});
      expect(result.success, isFalse);
      expect(result.error, contains('not found in registered MCP catalog'));
    });

    test('Requires approval when tool marked isSensitive and user approves', () async {
      mcpService.onApprovalRequested = (tool, args) async => true;

      final result = await mcpService.executeTool('write_local_file', {
        'filename': 'notes.txt',
        'content': 'Secret notes',
      });

      expect(result.success, isTrue);
      expect(result.output['status'], equals('written'));
      expect(result.output['filename'], equals('notes.txt'));
    });

    test('Blocks execution when tool is sensitive and user denies approval', () async {
      mcpService.onApprovalRequested = (tool, args) async => false;

      final result = await mcpService.executeTool('write_local_file', {
        'filename': 'confidential.txt',
        'content': 'Do not write',
      });

      expect(result.success, isFalse);
      expect(result.error, contains('declined by user'));
    });

    test('Registers custom tool dynamically and executes correctly', () async {
      mcpService.registerTool(McpTool(
        name: 'calculate_discount',
        description: 'Calculates price with percentage discount',
        inputSchema: {
          'type': 'object',
          'required': ['price', 'discount'],
          'properties': {
            'price': {'type': 'number'},
            'discount': {'type': 'number'},
          },
        },
        handler: (args) async {
          final price = (args['price'] as num).toDouble();
          final discount = (args['discount'] as num).toDouble();
          return {'finalPrice': price * (1.0 - discount)};
        },
      ));

      final result = await mcpService.executeTool('calculate_discount', {
        'price': 100.0,
        'discount': 0.15,
      });

      expect(result.success, isTrue);
      expect(result.output['finalPrice'], closeTo(85.0, 0.001));
    });
  });
}
