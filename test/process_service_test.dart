import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ollivo/services/ai_service.dart';
import 'package:ollivo/services/process_service.dart';

void main() {
  group('ProcessService & Daemon Recovery Tests (MOD-002)', () {
    test('1. Does not spawn new process if Ollama is already online and healthy', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"version": "0.40.2"}', 200);
      });

      final aiService = AIService(client: mockClient);
      bool processStarterCalled = false;

      final processService = ProcessService(
        aiService: aiService,
        processStarter: (exec, args, {mode = ProcessStartMode.normal}) async {
          processStarterCalled = true;
          throw Exception('Should not be called');
        },
      );

      final result = await processService.launchDaemon();
      expect(result.success, isTrue);
      expect(result.status, DaemonStatus.online);
      expect(result.message, contains('already active'));
      expect(processStarterCalled, isFalse);
    });

    test('2. Returns missingExecutable when ollama binary cannot be found', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Connection refused');
      });

      final aiService = AIService(client: mockClient);

      final processService = ProcessService(
        aiService: aiService,
        pathChecker: (path) => false, // Simulate missing binary
      );

      final result = await processService.launchDaemon();
      expect(result.success, isFalse);
      expect(result.status, DaemonStatus.missingExecutable);
      expect(result.message, contains('not found'));
    });

    test('3. Successfully spawns daemon and verifies endpoint when binary exists', () async {
      int checkCount = 0;
      final mockClient = MockClient((request) async {
        checkCount++;
        // First check (before spawn) returns 500/offline
        // Subsequent checks return 200/online
        if (checkCount == 1) {
          throw http.ClientException('Connection refused');
        }
        return http.Response('{"version": "0.40.2"}', 200);
      });

      final aiService = AIService(client: mockClient);
      String? spawnedExec;
      List<String>? spawnedArgs;

      final processService = ProcessService(
        aiService: aiService,
        pathChecker: (path) => path == '/opt/homebrew/bin/ollama',
        processStarter: (exec, args, {mode = ProcessStartMode.normal}) async {
          spawnedExec = exec;
          spawnedArgs = args;
          // Return a mock process that succeeds
          return Process.start('echo', ['started']);
        },
      );

      final result = await processService.launchDaemon();
      expect(result.success, isTrue);
      expect(result.status, DaemonStatus.online);
      expect(spawnedExec, '/opt/homebrew/bin/ollama');
      expect(spawnedArgs, ['serve']);
      expect(result.message, contains('successfully started'));
    });

    test('4. Handles ProcessException permission denied gracefully with terminal fallback', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Connection refused');
      });

      final aiService = AIService(client: mockClient);

      final processService = ProcessService(
        aiService: aiService,
        pathChecker: (path) => true,
        processStarter: (exec, args, {mode = ProcessStartMode.normal}) async {
          throw const ProcessException('ollama', ['serve'], 'Operation not permitted', 1);
        },
      );

      final result = await processService.launchDaemon();
      expect(result.success, isFalse);
      expect(result.status, DaemonStatus.permissionDenied);
      expect(result.message, contains('ollama serve'));
    });

    test('5. stopDaemon handles already stopped state cleanly', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Connection refused');
      });

      final aiService = AIService(client: mockClient);
      final processService = ProcessService(aiService: aiService);

      final result = await processService.stopDaemon();
      expect(result.success, isTrue);
      expect(result.status, DaemonStatus.offline);
      expect(result.message, contains('already stopped'));
    });

    test('6. stopDaemon terminates running daemon and verifies shutdown', () async {
      int checkCount = 0;
      final mockClient = MockClient((request) async {
        checkCount++;
        // First check: online. Subsequent checks: offline
        if (checkCount <= 1) {
          return http.Response('{"version": "0.40.2"}', 200);
        }
        throw http.ClientException('Connection refused');
      });

      final aiService = AIService(client: mockClient);
      bool pkillCalled = false;

      final processService = ProcessService(
        aiService: aiService,
        processRunner: (exec, args) async {
          pkillCalled = true;
          return ProcessResult(1234, 0, '', '');
        },
      );

      final result = await processService.stopDaemon();
      expect(result.success, isTrue);
      expect(result.status, DaemonStatus.offline);
      expect(pkillCalled, isTrue);
      expect(result.message, contains('successfully stopped'));
    });

    test('7. checkConnection accurately returns latency, version, and status', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"version": "0.40.2"}', 200);
      });

      final aiService = AIService(client: mockClient);
      final processService = ProcessService(
        aiService: aiService,
        pathChecker: (path) => path == '/opt/homebrew/bin/ollama',
      );

      final result = await processService.checkConnection();
      expect(result.isOnline, isTrue);
      expect(result.status, DaemonStatus.online);
      expect(result.version, '0.40.2');
      expect(result.latencyMs, isNonNegative);
      expect(result.executablePath, '/opt/homebrew/bin/ollama');
      expect(result.message, contains('Connected to Ollama v0.40.2'));
    });
  });
}
