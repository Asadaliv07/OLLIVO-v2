import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ollivo/services/ai_service.dart';

void main() {
  group('Loaded Models & Memory Management (/api/ps) Tests', () {
    test('fetchLoadedModels parses /api/ps response accurately with VRAM metrics', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/ps') {
          return http.Response('''
          {
            "models": [
              {
                "name": "qwen2.5-coder:7b",
                "model": "qwen2.5-coder:7b",
                "size": 4682000000,
                "size_vram": 4682000000,
                "digest": "abc123digest",
                "expires_at": "2026-10-11T22:00:00Z",
                "details": {
                  "parent_model": "",
                  "format": "gguf",
                  "family": "qwen2",
                  "families": ["qwen2"],
                  "parameter_size": "7.6B",
                  "quantization_level": "Q4_K_M"
                }
              }
            ]
          }
          ''', 200);
        }
        return http.Response('Not Found', 404);
      });

      final aiService = AIService(client: mockClient);
      final loaded = await aiService.fetchLoadedModels();

      expect(loaded.length, 1);
      final model = loaded.first;
      expect(model.name, 'qwen2.5-coder:7b');
      expect(model.parameterSize, '7.6B');
      expect(model.quantizationLevel, 'Q4_K_M');
      expect(model.sizeVram, 4682000000);
      expect(model.formattedVram, contains('4.4 GB VRAM'));
      expect(model.formattedSize, contains('4.4 GB'));
    });

    test('preloadModel calls /api/generate with warm-up prompt', () async {
      String? requestBody;
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/generate') {
          requestBody = request.body;
          return http.Response('{"done": true}', 200);
        }
        return http.Response('Not Found', 404);
      });

      final aiService = AIService(client: mockClient);
      final success = await aiService.preloadModel('llama3.2:3b');

      expect(success, isTrue);
      expect(requestBody, contains('"model":"llama3.2:3b"'));
      expect(requestBody, contains('"prompt":""'));
    });

    test('unloadModel sends keep_alive: 0 to /api/generate to free memory', () async {
      String? requestBody;
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/generate') {
          requestBody = request.body;
          return http.Response('{"done": true}', 200);
        }
        return http.Response('Not Found', 404);
      });

      final aiService = AIService(client: mockClient);
      final success = await aiService.unloadModel('mistral:7b');

      expect(success, isTrue);
      expect(requestBody, contains('"model":"mistral:7b"'));
      expect(requestBody, contains('"keep_alive":0'));
    });
  });
}
