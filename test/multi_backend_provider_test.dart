import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ollivo/services/ai_service.dart';
import 'package:ollivo/services/providers/backend_provider.dart';

void main() {
  group('Multi-Backend Provider Architecture Tests', () {
    test('ProviderRegistry registers core providers and resolves categories', () {
      final registry = ProviderRegistry();
      expect(registry.providers.length, greaterThanOrEqualTo(4));

      final ollamaProv = registry.getProviderForCategory('Coding');
      expect(ollamaProv, isA<OllamaBackendProvider>());
      expect(ollamaProv?.id, 'ollama');

      final imageProv = registry.getProviderForCategory('Image Generation');
      expect(imageProv, isA<ImageGenBackendProvider>());
      expect(imageProv?.id, 'comfyui');

      final audioProv = registry.getProviderForCategory('Audio');
      expect(audioProv, isA<AudioBackendProvider>());
      expect(audioProv?.id, 'whisper_piper');

      final videoProv = registry.getProviderForCategory('Video');
      expect(videoProv, isA<VideoBackendProvider>());
      expect(videoProv?.id, 'video_engine');
    });

    test('OllamaBackendProvider queries AIService accurately', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/version') {
          return http.Response('{"version": "0.40.2"}', 200);
        } else if (request.url.path == '/api/tags') {
          return http.Response('{"models": [{"name": "qwen2.5-coder:1.5b", "size": 980000000}]}', 200);
        }
        return http.Response('Not Found', 404);
      });

      final aiService = AIService(client: mockClient);
      final provider = OllamaBackendProvider(aiService: aiService);

      final isInstalled = await provider.checkInstalled();
      expect(isInstalled, isTrue);

      final models = await provider.listAvailableModels();
      expect(models, contains('qwen2.5-coder:1.5b'));
    });
  });
}
