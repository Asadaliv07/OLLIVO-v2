import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ollivo/controllers/model_controller.dart';
import 'package:ollivo/services/ai_service.dart';
import 'package:ollivo/services/model_catalog_service.dart';
import 'package:ollivo/services/providers/backend_provider.dart';
import 'package:ollivo/services/settings_service.dart';

void main() {
  group('Model Management & One-Click Ollama E2E Test Suite', () {
    late SettingsService settingsService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      settingsService = SettingsService();
      await settingsService.init(
        testPrefs: await SharedPreferences.getInstance(),
        testAppSupportPath: '/tmp/test_ollivo_support',
      );
    });

    test('1. Catalog contains >= 100 genuine verified models across all 9 categories', () {
      final allModels = ModelCatalogService.getAllModels();
      expect(allModels.length, greaterThanOrEqualTo(100));

      final categories = allModels.map((m) => m.category).toSet();
      expect(categories.contains('Lightweight'), isTrue);
      expect(categories.contains('Medium'), isTrue);
      expect(categories.contains('Coding'), isTrue);
      expect(categories.contains('Reasoning'), isTrue);
      expect(categories.contains('Vision'), isTrue);
      expect(categories.contains('Embeddings'), isTrue);
      expect(categories.contains('Image Generation'), isTrue);
      expect(categories.contains('Audio'), isTrue);
      expect(categories.contains('Video'), isTrue);

      // Verify essential lightweight models
      expect(allModels.any((m) => m.id == 'llama3.2:1b'), isTrue);
      expect(allModels.any((m) => m.id == 'qwen2.5:0.5b'), isTrue);
      expect(allModels.any((m) => m.id == 'smollm2:135m'), isTrue);

      // Verify coding models
      expect(allModels.any((m) => m.id == 'qwen2.5-coder:1.5b'), isTrue);
      expect(allModels.any((m) => m.id == 'deepseek-coder:6.7b'), isTrue);

      // Verify reasoning models
      expect(allModels.any((m) => m.id == 'deepseek-r1:1.5b'), isTrue);
      expect(allModels.any((m) => m.id == 'deepseek-r1:8b'), isTrue);

      // Verify vision models
      expect(allModels.any((m) => m.id == 'llama3.2-vision:11b'), isTrue);
      expect(allModels.any((m) => m.id == 'qwen2.5-vl:7b'), isTrue);

      // Verify embedding models
      expect(allModels.any((m) => m.id.contains('nomic-embed-text')), isTrue);
      expect(allModels.any((m) => m.id.contains('mxbai-embed-large')), isTrue);
    });

    test('2. Model search and multi-facet filtering work seamlessly', () {
      // Filter by category: Coding
      final codingModels = ModelCatalogService.searchModels(
        query: '',
        category: 'Coding',
        sizeFilter: 'All',
        statusFilter: 'All',
      );
      expect(codingModels.isNotEmpty, isTrue);
      expect(codingModels.every((m) => m.category == 'Coding'), isTrue);

      // Search query: 'qwen'
      final qwenModels = ModelCatalogService.searchModels(
        query: 'qwen',
        category: 'All',
        sizeFilter: 'All',
        statusFilter: 'All',
      );
      expect(qwenModels.isNotEmpty, isTrue);
      expect(qwenModels.any((m) => m.id.toLowerCase().contains('qwen')), isTrue);

      // Filter by size: Lightweight
      final lightweightModels = ModelCatalogService.searchModels(
        query: '',
        category: 'All',
        sizeFilter: 'Lightweight',
        statusFilter: 'All',
      );
      expect(lightweightModels.isNotEmpty, isTrue);
      expect(lightweightModels.every((m) => m.estimatedMemoryGb <= 3.0), isTrue);
    });

    test('3. ModelController daemon controls and health monitoring operate accurately', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/api/version')) {
          return http.Response('{"version":"0.5.1"}', 200);
        }
        if (request.url.path.endsWith('/api/tags')) {
          return http.Response('{"models":[{"name":"llama3.2:3b","size":2000000000}]}', 200);
        }
        if (request.url.path.endsWith('/api/ps')) {
          return http.Response('{"models":[{"name":"llama3.2:3b","size":2000000000,"size_vram":1900000000,"expires_at":"2026-10-11T20:00:00Z"}]}', 200);
        }
        if (request.url.path.endsWith('/api/generate')) {
          return http.Response('{"response":"","done":true}', 200);
        }
        return http.Response('{}', 200);
      });

      final aiService = AIService(
        ollamaHost: 'http://127.0.0.1:11434',
        modelName: 'llama3.2:3b',
        client: mockClient,
      );

      final controller = ModelController(
        aiService: aiService,
        settingsService: settingsService,
      );

      await controller.refreshModels();

      expect(controller.isOllamaOnline, isTrue);
      expect(controller.ollamaVersion, '0.5.1');
      expect(controller.daemonLatencyMs, greaterThanOrEqualTo(0));
      expect(controller.installedModels.length, 1);
      expect(controller.installedModels.first.name, 'llama3.2:3b');
      expect(controller.loadedModels.length, 1);
      expect(controller.loadedModels.first.name, 'llama3.2:3b');
      expect(controller.loadedModels.any((m) => m.name == 'llama3.2:3b'), isTrue);

      // Unload model from memory
      final unloadSuccess = await controller.unloadModel('llama3.2:3b');
      expect(unloadSuccess, isTrue);

      // Preload model into memory
      final preloadSuccess = await controller.preloadModel('llama3.2:3b');
      expect(preloadSuccess, isTrue);

      // Favorites toggle
      expect(controller.isFavorite('llama3.2:3b'), isFalse);
      await controller.toggleFavorite('llama3.2:3b');
      expect(controller.isFavorite('llama3.2:3b'), isTrue);
      await controller.toggleFavorite('llama3.2:3b');
      expect(controller.isFavorite('llama3.2:3b'), isFalse);
    });

    test('4. Streaming download progress and parsing events', () {
      final progress1 = OllamaPullProgress(
        status: 'pulling manifest',
        total: 1000000,
        completed: 500000,
      );
      expect(progress1.progressPercentage, 0.5);
      expect(progress1.isFinished, isFalse);
      expect(progress1.formattedProgress, contains('pulling manifest'));

      final progressSuccess = OllamaPullProgress(
        status: 'success',
        total: 1000000,
        completed: 1000000,
        isFinished: true,
      );
      expect(progressSuccess.isFinished, isTrue);
      expect(progressSuccess.progressPercentage, 1.0);
    });

    test('5. Multi-backend ProviderRegistry manages Ollama and external engines', () {
      final registry = ProviderRegistry();
      final providers = registry.providers;

      expect(providers.length, greaterThanOrEqualTo(4));
      expect(providers.any((p) => p.id == 'ollama'), isTrue);
      expect(providers.any((p) => p.id == 'comfyui'), isTrue);
      expect(providers.any((p) => p.id == 'whisper_piper'), isTrue);
      expect(providers.any((p) => p.id == 'video_engine'), isTrue);

      final ollamaProvider = registry.getProviderById('ollama');
      expect(ollamaProvider, isNotNull);
      expect(ollamaProvider!.supportedCategories.contains('Coding'), isTrue);
      expect(ollamaProvider.supportedCategories.contains('Vision'), isTrue);
      expect(ollamaProvider.supportedCategories.contains('Embeddings'), isTrue);

      final comfyProvider = registry.getProviderById('comfyui');
      expect(comfyProvider, isNotNull);
      expect(comfyProvider!.supportedCategories.contains('Image Generation'), isTrue);

      final audioProvider = registry.getProviderById('whisper_piper');
      expect(audioProvider, isNotNull);
      expect(audioProvider!.supportedCategories.contains('Audio'), isTrue);
    });
  });
}
