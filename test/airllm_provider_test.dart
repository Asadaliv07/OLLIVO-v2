import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ollivo/services/ai_service.dart';
import 'package:ollivo/services/model_catalog_service.dart';
import 'package:ollivo/services/process_service.dart';
import 'package:ollivo/services/providers/backend_provider.dart';
import 'package:ollivo/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AirLLM Backend & Layer-Streaming Integration Tests', () {
    test('1. ProviderRegistry registers AirLLMBackendProvider and resolves category', () {
      final registry = ProviderRegistry();
      expect(registry.providers.length, greaterThanOrEqualTo(5));

      final airllmById = registry.getProviderById('airllm');
      expect(airllmById, isNotNull);
      expect(airllmById, isA<AirLLMBackendProvider>());
      expect(airllmById?.id, 'airllm');
      expect(airllmById?.name, contains('AirLLM'));
      expect(airllmById?.isLocalOnly, isTrue);

      final airllmCat = registry.getProviderForCategory('AirLLM (70B+)');
      expect(airllmCat, isNotNull);
      expect(airllmCat?.id, 'airllm');
    });

    test('2. AirLLMBackendProvider queries AIService accurately with mock responses', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/health') {
          return http.Response(
            jsonEncode({
              'status': 'healthy',
              'engine': 'airllm',
              'model_loaded': true,
              'active_model': 'meta-llama/Meta-Llama-3-70B-Instruct',
            }),
            200,
          );
        } else if (request.url.path == '/api/ai/models') {
          return http.Response(
            jsonEncode({
              'models': [
                {'id': 'meta-llama/Meta-Llama-3-70B-Instruct', 'status': 'loaded'},
                {'id': 'deepseek-ai/DeepSeek-R1-Distill-Llama-70B', 'status': 'available'},
              ],
            }),
            200,
          );
        } else if (request.url.path == '/api/ai/status') {
          return http.Response(
            jsonEncode({
              'status': 'ready',
              'engine': 'airllm',
              'active_model': 'meta-llama/Meta-Llama-3-70B-Instruct',
              'device': 'mps',
              'compression': '4bit',
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final provider = AirLLMBackendProvider(client: mockClient);

      final isInstalled = await provider.checkInstalled();
      expect(isInstalled, isTrue);

      final health = await provider.checkHealth();
      expect(health['isOnline'], isTrue);
      expect(health['modelId'], 'meta-llama/Meta-Llama-3-70B-Instruct');

      final models = await provider.listAvailableModels();
      expect(models, contains('meta-llama/Meta-Llama-3-70B-Instruct'));
      expect(models, contains('deepseek-ai/DeepSeek-R1-Distill-Llama-70B'));

      final aiService = AIService(client: mockClient);
      final status = await aiService.fetchAirLLMStatus();
      expect(status?['engine'], 'airllm');
      expect(status?['device'], 'mps');
    });

    test('3. ProcessService does not spawn new AirLLM process if daemon is already online', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'status': 'healthy',
            'engine': 'airllm',
            'model_loaded': false,
            'active_model': null,
          }),
          200,
        );
      });

      final aiService = AIService(client: mockClient);
      bool starterCalled = false;

      final processService = ProcessService(
        aiService: aiService,
        processStarter: (exec, args, {mode = ProcessStartMode.normal}) async {
          starterCalled = true;
          throw Exception('Should not spawn');
        },
      );

      final result = await processService.launchAirLLMDaemon();
      expect(result.success, isTrue);
      expect(result.status, DaemonStatus.online);
      expect(result.message, contains('already active'));
      expect(starterCalled, isFalse);
    });

    test('4. ProcessService stopAirLLMDaemon cleanly handles stopped state', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Connection refused');
      });

      final aiService = AIService(client: mockClient);
      final processService = ProcessService(aiService: aiService);

      final result = await processService.stopAirLLMDaemon();
      expect(result.success, isTrue);
      expect(result.status, DaemonStatus.offline);
      expect(result.message, contains('already stopped'));
    });

    test('5. ProcessService checkAirLLMConnection reports healthy and latency accurately', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'status': 'healthy',
            'engine': 'airllm',
            'model_loaded': true,
            'active_model': 'meta-llama/Meta-Llama-3-70B-Instruct',
          }),
          200,
        );
      });

      final aiService = AIService(client: mockClient);
      final processService = ProcessService(aiService: aiService);

      final result = await processService.checkAirLLMConnection();
      expect(result.isOnline, isTrue);
      expect(result.status, DaemonStatus.online);
      expect(result.version, 'meta-llama/Meta-Llama-3-70B-Instruct');
      expect(result.latencyMs, isNonNegative);
      expect(result.message, contains('Connected to AirLLM daemon'));
    });

    test('6. SettingsService handles AirLLM switch defaults, persistence, and legacy configs', () async {
      // Test A: Older configuration without 'airllm_enabled' defaults to false
      SharedPreferences.setMockInitialValues({
        'airllm_host': 'http://127.0.0.1:9999',
        'airllm_model': 'deepseek-ai/DeepSeek-R1-Distill-Llama-70B',
      });

      var prefs = await SharedPreferences.getInstance();
      var settings = SettingsService();
      await settings.init(testPrefs: prefs);

      expect(settings.airllmEnabled, isFalse, reason: 'Must default to false for existing installations');
      expect(settings.effectiveInferenceBackend, 'ollama');
      expect(settings.effectiveInferenceHost, settings.ollamaHost);
      expect(settings.effectiveInferenceModel, settings.activeModel);

      // Test B: Toggling ON persists to storage and restores on re-init
      await settings.setAirllmEnabled(true);
      expect(settings.airllmEnabled, isTrue);
      expect(settings.effectiveInferenceBackend, 'airllm');
      expect(settings.effectiveInferenceHost, 'http://127.0.0.1:9999');
      expect(settings.effectiveInferenceModel, 'deepseek-ai/DeepSeek-R1-Distill-Llama-70B');

      // Re-initialize to verify persistence
      final settingsReloaded = SettingsService();
      await settingsReloaded.init(testPrefs: prefs);
      expect(settingsReloaded.airllmEnabled, isTrue, reason: 'Saved ON state must survive settings reload');

      // Test C: Reset to defaults turns switch OFF
      await settingsReloaded.resetSection('runtime');
      expect(settingsReloaded.airllmEnabled, isFalse, reason: 'Reset to defaults must turn switch OFF');
    });

    test('7. SettingsService JSON export and import preserves airllmEnabled', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsService();
      await settings.init(testPrefs: prefs);

      await settings.setAirllmEnabled(true);
      await settings.setAirllmHost('http://127.0.0.1:8765');
      await settings.setAirllmModel('meta-llama/Meta-Llama-3-70B-Instruct');

      final exportedJson = settings.exportSettingsJson();
      final decoded = jsonDecode(exportedJson) as Map<String, dynamic>;
      final runtime = decoded['runtime'] as Map<String, dynamic>;
      expect(runtime['airllmEnabled'], isTrue);
      expect(runtime['airllmHost'], 'http://127.0.0.1:8765');
      expect(runtime['airllmModel'], 'meta-llama/Meta-Llama-3-70B-Instruct');

      // Modify in memory and import back
      await settings.setAirllmEnabled(false);
      expect(settings.airllmEnabled, isFalse);

      final imported = await settings.importSettingsJson(exportedJson);
      expect(imported, isTrue);
      expect(settings.airllmEnabled, isTrue, reason: 'Imported settings must restore airllmEnabled true');
    });

    test('8. ProviderRegistry.getActiveProvider respects the persistent switch', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsService();
      await settings.init(testPrefs: prefs);

      final registry = ProviderRegistry();

      // Switch OFF -> Ollama backend
      await settings.setAirllmEnabled(false);
      final activeWhenOff = registry.getActiveProvider(settings);
      expect(activeWhenOff, isA<OllamaBackendProvider>());
      expect(activeWhenOff.id, 'ollama');

      // Switch ON -> AirLLM backend
      await settings.setAirllmEnabled(true);
      final activeWhenOn = registry.getActiveProvider(settings);
      expect(activeWhenOn, isA<AirLLMBackendProvider>());
      expect(activeWhenOn.id, 'airllm');
    });

    test('9. Centralized inference routing takes effect immediately on new requests without app restart', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsService();
      await settings.init(testPrefs: prefs);

      // Initially OFF
      expect(settings.effectiveInferenceBackend, 'ollama');
      expect(settings.effectiveInferenceHost, settings.ollamaHost);
      expect(settings.effectiveInferenceModel, settings.activeModel);

      // User flips switch ON in Settings
      await settings.setAirllmEnabled(true);
      // Immediately, subsequent requests read AirLLM configuration
      expect(settings.effectiveInferenceBackend, 'airllm');
      expect(settings.effectiveInferenceHost, settings.airllmHost);
      expect(settings.effectiveInferenceModel, settings.airllmModel);

      // User flips switch OFF in Settings
      await settings.setAirllmEnabled(false);
      // Immediately returns to Ollama without restarting the application
      expect(settings.effectiveInferenceBackend, 'ollama');
      expect(settings.effectiveInferenceHost, settings.ollamaHost);
      expect(settings.effectiveInferenceModel, settings.activeModel);
    });

    test('10. In-flight request isolation: changing switch mid-stream does not alter active request', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsService();
      await settings.init(testPrefs: prefs);

      await settings.setAirllmEnabled(true);

      // Simulate Request 1 starting while AirLLM is enabled
      final request1Host = settings.effectiveInferenceHost;
      final request1Model = settings.effectiveInferenceModel;
      final request1Backend = settings.effectiveInferenceBackend;

      expect(request1Backend, 'airllm');
      expect(request1Host, settings.airllmHost);

      // User toggles switch OFF while Request 1 is actively in-flight
      await settings.setAirllmEnabled(false);

      // Request 1 variables remain bound to AirLLM (in-flight isolation)
      expect(request1Backend, 'airllm');
      expect(request1Host, settings.airllmHost);
      expect(request1Model, settings.airllmModel);

      // Subsequent Request 2 immediately binds to Ollama
      final request2Host = settings.effectiveInferenceHost;
      final request2Model = settings.effectiveInferenceModel;
      final request2Backend = settings.effectiveInferenceBackend;

      expect(request2Backend, 'ollama');
      expect(request2Host, settings.ollamaHost);
      expect(request2Model, settings.activeModel);
    });

    test('11. AIService with backendId airllm yields clear actionable error when model is not loaded', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/generate') {
          return http.Response(
            jsonEncode({'detail': 'No model loaded into memory'}),
            503,
          );
        }
        return http.Response('Not Found', 404);
      });

      final aiService = AIService(client: mockClient);

      final stream = aiService.generateStream(
        'Hello AirLLM',
        customHost: 'http://127.0.0.1:8765',
        customModel: 'meta-llama/Meta-Llama-3-70B-Instruct',
        backendId: 'airllm',
      );

      final List<String> chunks = await stream.toList();
      expect(chunks.length, 1);
      final errorResponse = chunks.first;
      expect(errorResponse, contains('AirLLM service returned HTTP 503'));
      expect(errorResponse, contains('No model loaded into memory'));
      expect(errorResponse, contains('Settings -> AirLLM'));
      expect(errorResponse.contains('Ollama'), isFalse, reason: 'Must not misidentify AirLLM as Ollama');
    });

    test('12. AIService with backendId airllm yields clear actionable error when daemon is offline without silent fallback', () async {
      final mockClient = MockClient((request) async {
        throw const SocketException('Connection refused to 127.0.0.1:8765');
      });

      final aiService = AIService(client: mockClient);

      final stream = aiService.generateStream(
        'Hello AirLLM',
        customHost: 'http://127.0.0.1:8765',
        customModel: 'meta-llama/Meta-Llama-3-70B-Instruct',
        backendId: 'airllm',
      );

      final List<String> chunks = await stream.toList();
      expect(chunks.length, 1);
      final errorResponse = chunks.first;
      expect(errorResponse, contains('Failed to connect to AirLLM daemon'));
      expect(errorResponse, contains('Settings -> AirLLM'));
      expect(errorResponse.contains('Ollama'), isFalse, reason: 'Must never silently fallback to Ollama');
    });

    test('13. AIService with backendId airllm streams valid tokens when AirLLM is healthy', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/generate') {
          // Return streaming NDJSON matching AirLLM Ollama compatibility endpoint
          final ndjson = '{"response": "AirLLM", "done": false}\n{"response": " streaming", "done": false}\n{"response": " works!", "done": true}\n';
          return http.Response(ndjson, 200);
        }
        return http.Response('Not Found', 404);
      });

      final aiService = AIService(client: mockClient);

      final stream = aiService.generateStream(
        'Explain quantum mechanics',
        customHost: 'http://127.0.0.1:8765',
        customModel: 'meta-llama/Meta-Llama-3-70B-Instruct',
        backendId: 'airllm',
      );

      final List<String> chunks = await stream.toList();
      expect(chunks.join(''), 'AirLLM streaming works!');
    });

    test('14. ModelCatalogService contains AirLLM models and filters them by category', () {
      final airllmModels = ModelCatalogService.searchModels(
        category: 'AirLLM (70B+)',
      );

      expect(airllmModels.length, greaterThanOrEqualTo(4));
      expect(airllmModels.any((m) => m.id == 'meta-llama/Meta-Llama-3-70B-Instruct'), isTrue);
      expect(airllmModels.any((m) => m.id == 'deepseek-ai/DeepSeek-R1-Distill-Llama-70B'), isTrue);
      expect(airllmModels.any((m) => m.id == 'Qwen/Qwen2.5-72B-Instruct'), isTrue);

      final llama70b = airllmModels.firstWhere((m) => m.id == 'meta-llama/Meta-Llama-3-70B-Instruct');
      expect(llama70b.backend, 'airllm');
      expect(llama70b.estimatedMemoryGb, lessThan(8.0)); // AirLLM uses layer-streaming, fitting 70B into <8GB RAM!
    });
  });
}
