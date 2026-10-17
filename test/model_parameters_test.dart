import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ollivo/services/ai_service.dart';
import 'package:ollivo/services/settings_service.dart';
import 'package:ollivo/controllers/chat_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 2 Model Parameters & Generation Telemetry Tests (CORE-004, CORE-006)', () {
    test('SettingsService persists and validates inference parameters (CORE-004)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsService();
      await settings.init(testPrefs: prefs);

      // Verify default values
      expect(settings.contextWindow, 4096);
      expect(settings.topP, 0.9);
      expect(settings.topK, 40);
      expect(settings.repeatPenalty, 1.1);
      expect(settings.systemPrompt, '');

      // Set custom values
      await settings.setContextWindow(8192);
      await settings.setTopP(0.85);
      await settings.setTopK(60);
      await settings.setRepeatPenalty(1.25);
      await settings.setSystemPrompt('You are a senior Flutter engineer.');

      expect(settings.contextWindow, 8192);
      expect(settings.topP, 0.85);
      expect(settings.topK, 60);
      expect(settings.repeatPenalty, 1.25);
      expect(settings.systemPrompt, 'You are a senior Flutter engineer.');

      // Verify SharedPreferences persistence
      expect(prefs.getInt('model_context_window'), 8192);
      expect(prefs.getDouble('model_top_p'), 0.85);
      expect(prefs.getInt('model_top_k'), 60);
      expect(prefs.getDouble('model_repeat_penalty'), 1.25);
      expect(prefs.getString('model_system_prompt'), 'You are a senior Flutter engineer.');

      // Verify reset to defaults
      await settings.resetAllSettings();
      expect(settings.contextWindow, 4096);
      expect(settings.topP, 0.9);
      expect(settings.topK, 40);
      expect(settings.repeatPenalty, 1.1);
      expect(settings.systemPrompt, '');
    });

    test('AIService encodes inference options and system prompt in request body (CORE-004)', () async {
      Map<String, dynamic>? capturedBody;

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/generate') {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          final lines = [
            jsonEncode({'response': 'Hello', 'done': false}),
            jsonEncode({'response': ' World', 'done': true}),
          ].join('\n');
          return http.Response(lines, 200);
        }
        return http.Response('Not Found', 404);
      });

      final aiService = AIService(client: mockClient);

      final tokens = await aiService.generateStream(
        'Write code',
        temperature: 0.6,
        contextWindow: 8192,
        topP: 0.95,
        topK: 50,
        repeatPenalty: 1.15,
        systemPrompt: 'Custom System Instructions',
        systemContext: 'Additional RAG context',
      ).toList();

      expect(tokens, ['Hello', ' World']);
      expect(capturedBody, isNotNull);
      expect(capturedBody!['model'], isNotNull);
      expect(capturedBody!['prompt'], 'Write code');
      expect(capturedBody!['system'], contains('Custom System Instructions'));
      expect(capturedBody!['system'], contains('Additional RAG context'));

      final options = capturedBody!['options'] as Map<String, dynamic>;
      expect(options['temperature'], 0.6);
      expect(options['num_ctx'], 8192);
      expect(options['top_p'], 0.95);
      expect(options['top_k'], 50);
      expect(options['repeat_penalty'], 1.15);
    });

    test('ChatController tracks tokens/sec and generation telemetry metrics (CORE-006)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsService();
      await settings.init(testPrefs: prefs);

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/generate') {
          final lines = [
            jsonEncode({'response': 'Stream', 'done': false}),
            jsonEncode({'response': ' token', 'done': false}),
            jsonEncode({'response': ' telemetry', 'done': true}),
          ].join('\n');
          return http.Response(lines, 200);
        }
        return http.Response('Not Found', 404);
      });

      final aiService = AIService(client: mockClient);
      final controller = ChatController(
        aiService: aiService,
        settingsService: settings,
      );

      await controller.sendUserPrompt('Calculate metrics');

      expect(controller.messages.length, greaterThanOrEqualTo(2));
      final lastMsg = controller.messages.last;
      expect(lastMsg['role'], 'assistant');
      expect(lastMsg['content'], 'Stream token telemetry');

      final metrics = lastMsg['metrics'] as Map<String, dynamic>?;
      expect(metrics, isNotNull);
      expect(metrics!['totalTokens'], 3);
      expect(metrics['tokensPerSecond'], isA<double>());
      expect(metrics['durationMs'], isA<int>());
      expect(metrics['firstTokenMs'], isA<int>());
      expect(metrics['isStreaming'], false);
    });
  });
}
