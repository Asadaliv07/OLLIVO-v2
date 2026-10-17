import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ollivo/components/quick_ask_dialog.dart';
import 'package:ollivo/services/ai_service.dart';
import 'package:ollivo/services/settings_service.dart';

void main() {
  late SettingsService settings;
  late AIService aiService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    settings = SettingsService();
    await settings.init(
      testPrefs: prefs,
      testAppSupportPath: Directory.systemTemp.path,
    );
    await settings.setActiveModel('qwen2.5-coder:1.5b');

    final mockClient = MockClient((request) async {
      return http.Response('{"response": "ok"}\n', 200);
    });
    aiService = AIService(client: mockClient);
  });

  testWidgets('MAC-001: QuickAskDialog widget renders active model tag and tips', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuickAskDialog(
            aiService: aiService,
            settingsService: settings,
            autofocus: false,
          ),
        ),
      ),
    );
    await tester.pump();

    // Verify dialog header and model badge
    expect(find.text('Quick Ask'), findsOneWidget);
    expect(find.text('qwen2.5-coder:1.5b'), findsOneWidget);
    expect(find.text('ESC'), findsOneWidget);

    // Verify TextField and tip presence
    expect(find.byType(TextField), findsOneWidget);
    expect(find.textContaining('Press ⌘K anywhere'), findsOneWidget);
    expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
  });
}
