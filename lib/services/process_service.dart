import 'dart:async';
import 'dart:io';
import 'ai_service.dart';

/// Status of the local Ollama daemon service
enum DaemonStatus {
  online,
  offline,
  launching,
  stopping,
  missingExecutable,
  permissionDenied,
  portConflict,
  failed,
}

/// Result returned from daemon launch attempt
class DaemonLaunchResult {
  final bool success;
  final DaemonStatus status;
  final String message;
  final String? executablePath;

  const DaemonLaunchResult({
    required this.success,
    required this.status,
    required this.message,
    this.executablePath,
  });
}

/// Result returned from daemon stop attempt
class DaemonStopResult {
  final bool success;
  final DaemonStatus status;
  final String message;

  const DaemonStopResult({
    required this.success,
    required this.status,
    required this.message,
  });
}

/// Result returned from daemon connection check
class DaemonStatusResult {
  final bool isOnline;
  final DaemonStatus status;
  final String? version;
  final int latencyMs;
  final String host;
  final String? executablePath;
  final String message;

  const DaemonStatusResult({
    required this.isOnline,
    required this.status,
    this.version,
    required this.latencyMs,
    required this.host,
    this.executablePath,
    required this.message,
  });
}

/// Typedef for custom process runner to allow mockable testing
typedef ProcessStarter = Future<Process> Function(
  String executable,
  List<String> arguments, {
  ProcessStartMode mode,
});

typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

typedef PathChecker = bool Function(String path);

/// Dedicated Service to manage, detect, start, stop, restart, and recover the local Ollama daemon
class ProcessService {
  final AIService _aiService;
  final ProcessStarter? processStarter;
  final ProcessRunner? processRunner;
  final PathChecker? pathChecker;

  bool _isLaunching = false;
  bool _isStopping = false;
  Process? _activeProcess;

  bool _isLaunchingAirllm = false;
  bool _isStoppingAirllm = false;
  Process? _activeAirllmProcess;

  ProcessService({
    AIService? aiService,
    this.processStarter,
    this.processRunner,
    this.pathChecker,
  }) : _aiService = aiService ?? AIService();

  bool get isLaunching => _isLaunching;
  bool get isStopping => _isStopping;
  bool get isLaunchingAirllm => _isLaunchingAirllm;
  bool get isStoppingAirllm => _isStoppingAirllm;

  /// Candidate paths for the Ollama binary across operating systems
  static const List<String> standardMacOsPaths = [
    '/opt/homebrew/bin/ollama', // Apple Silicon Homebrew
    '/usr/local/bin/ollama', // Intel Mac Homebrew / Official installer
    '/usr/bin/ollama',
    '/Applications/Ollama.app/Contents/Resources/ollama', // macOS App bundle helper
  ];

  static const List<String> standardLinuxPaths = [
    '/usr/local/bin/ollama',
    '/usr/bin/ollama',
    '/bin/ollama',
    '/var/lib/flatpak/exports/bin/ollama',
  ];

  static const List<String> standardWindowsPaths = [
    r'C:\Program Files\Ollama\ollama.exe',
  ];

  /// Locate the Ollama CLI executable on the local system
  String? findOllamaExecutable() {
    final checker = pathChecker ?? ((path) => File(path).existsSync());

    // 1. Check OS-specific standard candidate paths
    List<String> candidates = standardMacOsPaths;
    if (Platform.isLinux) {
      candidates = standardLinuxPaths;
    } else if (Platform.isWindows) {
      candidates = standardWindowsPaths;
      final localAppData = Platform.environment['LOCALAPPDATA'];
      if (localAppData != null && localAppData.isNotEmpty) {
        final userCandidate = '$localAppData\\Programs\\Ollama\\ollama.exe';
        if (checker(userCandidate)) {
          return userCandidate;
        }
      }
    }

    for (final path in candidates) {
      if (checker(path)) {
        return path;
      }
    }

    // 2. Check system PATH environment variable
    final pathEnv = Platform.environment['PATH'];
    if (pathEnv != null) {
      final delimiter = Platform.isWindows ? ';' : ':';
      final binaryName = Platform.isWindows ? 'ollama.exe' : 'ollama';

      for (final dir in pathEnv.split(delimiter)) {
        if (dir.trim().isEmpty) continue;
        final separator = Platform.isWindows ? '\\' : '/';
        final candidate = '$dir$separator$binaryName';
        if (checker(candidate)) {
          return candidate;
        }
      }
    }

    return null;
  }

  /// Launch the Ollama daemon safely and verify endpoint connectivity
  Future<DaemonLaunchResult> launchDaemon({String? customHost}) async {
    final host = customHost ?? _aiService.ollamaHost;

    if (_isLaunching) {
      return const DaemonLaunchResult(
        success: false,
        status: DaemonStatus.launching,
        message: 'A launch attempt is already in progress. Please wait...',
      );
    }

    // Step 1: Detect if daemon is already running and healthy
    final isAlreadyOnline = await _aiService.checkHealth(customHost: host);
    if (isAlreadyOnline) {
      return DaemonLaunchResult(
        success: true,
        status: DaemonStatus.online,
        message: 'Ollama daemon is already active and healthy at $host.',
      );
    }

    // Step 2: Discover executable path
    final executable = findOllamaExecutable();
    if (executable == null) {
      return const DaemonLaunchResult(
        success: false,
        status: DaemonStatus.missingExecutable,
        message: 'Ollama executable was not found in standard paths (/opt/homebrew/bin, /usr/local/bin) or PATH. '
            'Install Ollama from https://ollama.com or run "brew install ollama".',
      );
    }

    _isLaunching = true;

    try {
      // Step 3: Spawn 'ollama serve' via argument-safe invocation without shell interpolation
      if (processStarter != null) {
        _activeProcess = await processStarter!(
          executable,
          ['serve'],
          mode: ProcessStartMode.detached,
        );
      } else {
        _activeProcess = await Process.start(
          executable,
          ['serve'],
          mode: ProcessStartMode.detached,
        );
      }

      // Step 4: Verify connectivity via polling with exponential backoff
      const delays = [
        Duration(milliseconds: 500),
        Duration(milliseconds: 1000),
        Duration(milliseconds: 1500),
        Duration(milliseconds: 2500),
      ];

      for (final delay in delays) {
        await Future.delayed(delay);
        final isOnline = await _aiService.checkHealth(customHost: host);
        if (isOnline) {
          _isLaunching = false;
          return DaemonLaunchResult(
            success: true,
            status: DaemonStatus.online,
            message: 'Ollama daemon successfully started and responding at $host.',
            executablePath: executable,
          );
        }
      }

      // Failed to reach service within timeout
      _isLaunching = false;
      return DaemonLaunchResult(
        success: false,
        status: DaemonStatus.failed,
        message: 'Ollama process was initiated at $executable, but the server did not respond at $host within 5 seconds. '
            'If another service is using port 11434, terminate it or check "ollama serve" in Terminal.',
        executablePath: executable,
      );
    } on ProcessException catch (e) {
      _isLaunching = false;
      return DaemonLaunchResult(
        success: false,
        status: DaemonStatus.permissionDenied,
        message: 'Failed to launch Ollama: ${e.message} (Error code: ${e.errorCode}). '
            'You can start it manually in Terminal using: ollama serve',
        executablePath: executable,
      );
    } catch (e) {
      _isLaunching = false;
      return DaemonLaunchResult(
        success: false,
        status: DaemonStatus.failed,
        message: 'Unexpected error starting Ollama: $e. Run "ollama serve" manually in Terminal.',
        executablePath: executable,
      );
    }
  }

  /// Stop the running Ollama daemon gracefully
  Future<DaemonStopResult> stopDaemon({String? customHost}) async {
    final host = customHost ?? _aiService.ollamaHost;

    if (_isStopping) {
      return const DaemonStopResult(
        success: false,
        status: DaemonStatus.stopping,
        message: 'A stop attempt is already in progress.',
      );
    }

    // Check if daemon is currently online
    final isOnline = await _aiService.checkHealth(customHost: host);
    if (!isOnline) {
      return const DaemonStopResult(
        success: true,
        status: DaemonStatus.offline,
        message: 'Ollama daemon is already stopped.',
      );
    }

    _isStopping = true;

    try {
      // 1. If we hold an active process handle, kill it
      if (_activeProcess != null) {
        try {
          _activeProcess!.kill(ProcessSignal.sigterm);
        } catch (_) {}
        _activeProcess = null;
      }

      // 2. Gracefully terminate any running ollama serve process using safe targeted command
      final runner = processRunner ?? Process.run;
      try {
        if (Platform.isWindows) {
          await runner('taskkill', ['/F', '/IM', 'ollama.exe']);
        } else {
          // On macOS and Linux, terminate ollama serve process cleanly
          await runner('pkill', ['-TERM', '-x', 'ollama']);
        }
      } catch (_) {
        // Fallback or ignore if pkill isn't present
      }

      // 3. Poll to verify daemon has stopped
      for (int i = 0; i < 6; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        final stillRunning = await _aiService.checkHealth(customHost: host);
        if (!stillRunning) {
          _isStopping = false;
          return const DaemonStopResult(
            success: true,
            status: DaemonStatus.offline,
            message: 'Ollama daemon successfully stopped.',
          );
        }
      }

      _isStopping = false;
      return const DaemonStopResult(
        success: false,
        status: DaemonStatus.failed,
        message: 'Ollama process could not be terminated within timeout.',
      );
    } catch (e) {
      _isStopping = false;
      return DaemonStopResult(
        success: false,
        status: DaemonStatus.failed,
        message: 'Error stopping Ollama daemon: $e',
      );
    }
  }

  /// Restart the Ollama daemon cleanly
  Future<DaemonLaunchResult> restartDaemon({String? customHost}) async {
    final host = customHost ?? _aiService.ollamaHost;

    // First stop
    await stopDaemon(customHost: host);
    // Allow brief pause for socket cleanup
    await Future.delayed(const Duration(milliseconds: 1000));
    // Then launch
    return launchDaemon(customHost: host);
  }

  /// Comprehensive connection check with detailed latency & version metrics
  Future<DaemonStatusResult> checkConnection({String? customHost}) async {
    final host = customHost ?? _aiService.ollamaHost;
    final details = await _aiService.checkHealthDetails(customHost: host);
    final isOnline = details['isOnline'] == true;
    final version = details['version'] as String?;
    final latency = details['latencyMs'] as int? ?? -1;
    final executable = findOllamaExecutable();

    return DaemonStatusResult(
      isOnline: isOnline,
      status: isOnline ? DaemonStatus.online : DaemonStatus.offline,
      version: version,
      latencyMs: latency,
      host: host,
      executablePath: executable,
      message: isOnline
          ? 'Connected to Ollama v${version ?? 'unknown'} at $host (${latency}ms latency).'
          : 'Disconnected from Ollama daemon at $host.',
    );
  }

  /// Locate the Python binary with AirLLM installed (AIR-PROC-001)
  String? findAirLLMPythonExecutable() {
    final checker = pathChecker ?? ((path) => File(path).existsSync());

    // 1. Check workspace dedicated virtual environment
    final currentDir = Directory.current.path;
    final venvPythonMac = '$currentDir/airllm_service/.venv/bin/python';
    if (checker(venvPythonMac)) return venvPythonMac;

    final venvPythonWin = '$currentDir\\airllm_service\\.venv\\Scripts\\python.exe';
    if (checker(venvPythonWin)) return venvPythonWin;

    // 2. Check standard system python candidates
    final candidates = [
      '/opt/homebrew/bin/python3.11',
      '/opt/homebrew/bin/python3',
      '/usr/local/bin/python3',
      '/usr/bin/python3',
    ];
    for (final c in candidates) {
      if (checker(c)) return c;
    }

    return null;
  }

  /// Launch the AirLLM local service daemon safely (AIR-PROC-002)
  Future<DaemonLaunchResult> launchAirLLMDaemon({
    String? customHost,
    String? customModel,
    String? compression,
    String? device,
  }) async {
    final host = customHost ?? 'http://127.0.0.1:8765';

    if (_isLaunchingAirllm) {
      return const DaemonLaunchResult(
        success: false,
        status: DaemonStatus.launching,
        message: 'An AirLLM launch attempt is already in progress. Please wait...',
      );
    }

    // Step 1: Detect if AirLLM daemon is already active
    final details = await _aiService.checkAirLLMHealthDetails(customHost: host);
    if (details['isOnline'] == true) {
      return DaemonLaunchResult(
        success: true,
        status: DaemonStatus.online,
        message: 'AirLLM daemon is already active and healthy at $host.',
      );
    }

    // Step 2: Discover executable path
    final executable = findAirLLMPythonExecutable();
    if (executable == null) {
      return const DaemonLaunchResult(
        success: false,
        status: DaemonStatus.missingExecutable,
        message: 'AirLLM Python environment was not found. '
            'Please ensure airllm_service/.venv is initialized via "uv venv airllm_service/.venv" '
            'or run "pip install airllm".',
      );
    }

    _isLaunchingAirllm = true;

    try {
      final args = ['-m', 'airllm_service.service'];
      if (customModel != null && customModel.isNotEmpty) {
        args.addAll(['--model', customModel]);
      }
      if (compression != null && compression.isNotEmpty) {
        args.addAll(['--compression', compression]);
      }
      if (device != null && device.isNotEmpty) {
        args.addAll(['--device', device]);
      }

      if (processStarter != null) {
        _activeAirllmProcess = await processStarter!(
          executable,
          args,
          mode: ProcessStartMode.detached,
        );
      } else {
        _activeAirllmProcess = await Process.start(
          executable,
          args,
          mode: ProcessStartMode.detached,
        );
      }

      // Step 4: Verify connectivity via polling
      const delays = [
        Duration(milliseconds: 500),
        Duration(milliseconds: 1000),
        Duration(milliseconds: 1500),
        Duration(milliseconds: 2500),
      ];

      for (final delay in delays) {
        await Future.delayed(delay);
        final statusCheck = await _aiService.checkAirLLMHealthDetails(customHost: host);
        if (statusCheck['isOnline'] == true) {
          _isLaunchingAirllm = false;
          return DaemonLaunchResult(
            success: true,
            status: DaemonStatus.online,
            message: 'AirLLM daemon successfully started and responding at $host.',
            executablePath: executable,
          );
        }
      }

      _isLaunchingAirllm = false;
      return DaemonLaunchResult(
        success: false,
        status: DaemonStatus.failed,
        message: 'AirLLM service was initiated at $executable, but did not respond at $host within timeout.',
        executablePath: executable,
      );
    } catch (e) {
      _isLaunchingAirllm = false;
      return DaemonLaunchResult(
        success: false,
        status: DaemonStatus.failed,
        message: 'Failed to launch AirLLM daemon: $e',
        executablePath: executable,
      );
    }
  }

  /// Stop the running AirLLM daemon gracefully
  Future<DaemonStopResult> stopAirLLMDaemon({String? customHost}) async {
    final host = customHost ?? 'http://127.0.0.1:8765';

    if (_isStoppingAirllm) {
      return const DaemonStopResult(
        success: false,
        status: DaemonStatus.stopping,
        message: 'An AirLLM stop attempt is already in progress.',
      );
    }

    final details = await _aiService.checkAirLLMHealthDetails(customHost: host);
    if (details['isOnline'] != true) {
      return const DaemonStopResult(
        success: true,
        status: DaemonStatus.offline,
        message: 'AirLLM daemon is already stopped.',
      );
    }

    _isStoppingAirllm = true;

    try {
      if (_activeAirllmProcess != null) {
        try {
          _activeAirllmProcess!.kill(ProcessSignal.sigterm);
        } catch (_) {}
        _activeAirllmProcess = null;
      }

      final runner = processRunner ?? Process.run;
      try {
        if (Platform.isWindows) {
          await runner('taskkill', ['/F', '/IM', 'python.exe', '/FI', 'WINDOWTITLE eq *airllm*']);
        } else {
          await runner('pkill', ['-TERM', '-f', 'airllm_service.service']);
        }
      } catch (_) {}

      for (int i = 0; i < 6; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        final stillRunning = await _aiService.checkAirLLMHealthDetails(customHost: host);
        if (stillRunning['isOnline'] != true) {
          _isStoppingAirllm = false;
          return const DaemonStopResult(
            success: true,
            status: DaemonStatus.offline,
            message: 'AirLLM daemon successfully stopped.',
          );
        }
      }

      _isStoppingAirllm = false;
      return const DaemonStopResult(
        success: false,
        status: DaemonStatus.failed,
        message: 'AirLLM process could not be terminated within timeout.',
      );
    } catch (e) {
      _isStoppingAirllm = false;
      return DaemonStopResult(
        success: false,
        status: DaemonStatus.failed,
        message: 'Error stopping AirLLM daemon: $e',
      );
    }
  }

  /// Restart the AirLLM daemon cleanly
  Future<DaemonLaunchResult> restartAirLLMDaemon({
    String? customHost,
    String? customModel,
    String? compression,
    String? device,
  }) async {
    final host = customHost ?? 'http://127.0.0.1:8765';
    await stopAirLLMDaemon(customHost: host);
    await Future.delayed(const Duration(milliseconds: 1000));
    return launchAirLLMDaemon(
      customHost: host,
      customModel: customModel,
      compression: compression,
      device: device,
    );
  }

  /// AirLLM connection check
  Future<DaemonStatusResult> checkAirLLMConnection({String? customHost}) async {
    final host = customHost ?? 'http://127.0.0.1:8765';
    final details = await _aiService.checkAirLLMHealthDetails(customHost: host);
    final isOnline = details['isOnline'] == true;
    final latency = details['latencyMs'] as int? ?? -1;
    final modelId = details['modelId'] as String?;
    final executable = findAirLLMPythonExecutable();

    return DaemonStatusResult(
      isOnline: isOnline,
      status: isOnline ? DaemonStatus.online : DaemonStatus.offline,
      version: modelId,
      latencyMs: latency,
      host: host,
      executablePath: executable,
      message: isOnline
          ? 'Connected to AirLLM daemon at $host (${latency}ms latency, Model: ${modelId ?? 'Unloaded'}).'
          : 'Disconnected from AirLLM daemon at $host.',
    );
  }
}
