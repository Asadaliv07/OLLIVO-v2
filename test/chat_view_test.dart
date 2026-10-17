import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ollivo/controllers/chat_controller.dart';
import 'package:ollivo/controllers/model_controller.dart';
import 'package:ollivo/services/ai_service.dart';
import 'package:ollivo/services/database_service.dart';
import 'package:ollivo/services/document_service.dart';
import 'package:ollivo/services/memory_service.dart';
import 'package:ollivo/services/settings_service.dart';
import 'package:ollivo/views/chat/chat_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SettingsService settingsService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settingsService = SettingsService();
    await settingsService.init(
      testPrefs: await SharedPreferences.getInstance(),
      testAppSupportPath: Directory.systemTemp.path,
    );
  });

  testWidgets('AI Chat view renders messages and starter prompts', (WidgetTester tester) async {
    final dbService = DatabaseService();

    final mockClient = MockClient((request) async {
      if (request.url.path.endsWith('/api/version')) {
        return http.Response('{"version": "0.40.2"}', 200);
      } else if (request.url.path.endsWith('/api/tags')) {
        return http.Response('{"models": [{"name": "qwen2.5-coder:1.5b", "size": 980000000}]}', 200);
      }
      return http.Response('{"response": "I have saved this decision into your local vector memory."}\n', 200);
    });

    final aiService = AIService(client: mockClient);
    final memoryService = MemoryService(dbService: dbService);
    final documentService = DocumentService(dbService: dbService);

    final chatController = ChatController(
      aiService: aiService,
      dbService: dbService,
      memoryService: memoryService,
      documentService: documentService,
      settingsService: settingsService,
    );
    final modelController = ModelController(
      aiService: aiService,
      settingsService: settingsService,
    );
    await chatController.loadConversations();

    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ChatView(
          chatController: chatController,
          modelController: modelController,
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    // Verify Active Conversation header
    expect(find.text('General Session'), findsOneWidget);

    // Verify initial assistant welcome message
    expect(find.textContaining('Welcome to'), findsOneWidget);

    // Verify starter prompt chips
    expect(find.text('Save Project Preference'), findsOneWidget);
  });

  testWidgets('ChatView displays Start Ollama button when offline (MOD-002)', (WidgetTester tester) async {
    final mockClient = MockClient((request) async {
      throw http.ClientException('Connection refused');
    });

    final aiService = AIService(client: mockClient);
    final memoryService = MemoryService(dbService: DatabaseService());
    final documentService = DocumentService(dbService: DatabaseService());

    final chatController = ChatController(
      aiService: aiService,
      dbService: DatabaseService(),
      memoryService: memoryService,
      documentService: documentService,
      settingsService: settingsService,
    );
    final modelController = ModelController(
      aiService: aiService,
      settingsService: settingsService,
    );

    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ChatView(
          chatController: chatController,
          modelController: modelController,
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    // Verify offline banner and Start Ollama recovery button
    expect(find.text('Local Ollama Service Offline'), findsOneWidget);
    expect(find.text('Start Ollama'), findsOneWidget);
  });

  testWidgets('ChatView displays generation telemetry badge on assistant responses (CORE-006)', (WidgetTester tester) async {
    final mockClient = MockClient((request) async {
      if (request.url.path.endsWith('/api/version')) {
        return http.Response('{"version": "0.40.2"}', 200);
      }
      final lines = [
        '{"response": "Here is "}\n',
        '{"response": "the response."}\n',
      ].join();
      return http.Response(lines, 200);
    });

    final aiService = AIService(client: mockClient);
    final chatController = ChatController(
      aiService: aiService,
      settingsService: settingsService,
    );
    final modelController = ModelController(
      aiService: aiService,
      settingsService: settingsService,
    );

    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ChatView(
          chatController: chatController,
          modelController: modelController,
        ),
      ),
    ));
    await tester.pump();

    // Send a user prompt
    await chatController.sendUserPrompt('Run test');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify telemetry badge is rendered
    expect(find.byIcon(Icons.speed_rounded), findsOneWidget);
    expect(find.textContaining('tok/s'), findsOneWidget);
    expect(find.textContaining('2 tokens'), findsOneWidget);
  });
}

