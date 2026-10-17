import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ollivo/controllers/chat_controller.dart';
import 'package:ollivo/controllers/model_controller.dart';
import 'package:ollivo/main.dart';
import 'package:ollivo/services/ai_service.dart';
import 'package:ollivo/services/database_service.dart';
import 'package:ollivo/services/document_service.dart';
import 'package:ollivo/services/memory_service.dart';
import 'package:ollivo/services/settings_service.dart';
import 'package:ollivo/services/task_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database inMemoryDb;
  late DatabaseService dbService;
  late SettingsService settingsService;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settingsService = SettingsService();
    await settingsService.init(
      testPrefs: await SharedPreferences.getInstance(),
      testAppSupportPath: Directory.systemTemp.path,
    );

    dbService = DatabaseService();
    inMemoryDb = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE conversations (id TEXT PRIMARY KEY, title TEXT NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL);');
        await db.execute('CREATE TABLE messages (id TEXT PRIMARY KEY, conversation_id TEXT NOT NULL, role TEXT NOT NULL, content TEXT NOT NULL, is_memory_saved INTEGER DEFAULT 0, created_at INTEGER NOT NULL);');
        await db.execute('CREATE TABLE memories (id TEXT PRIMARY KEY, fact TEXT NOT NULL, category TEXT DEFAULT "general", created_at INTEGER NOT NULL);');
        await db.execute('CREATE TABLE documents (id TEXT PRIMARY KEY, filename TEXT NOT NULL, file_path TEXT NOT NULL, file_size INTEGER NOT NULL, chunk_count INTEGER NOT NULL, created_at INTEGER NOT NULL);');
        await db.execute('CREATE TABLE tasks (id TEXT PRIMARY KEY, title TEXT NOT NULL, description TEXT, status TEXT DEFAULT "todo", priority TEXT DEFAULT "medium", due_date INTEGER, created_at INTEGER NOT NULL);');
      },
    );
    await dbService.init(testDatabase: inMemoryDb);
  });

  tearDown(() async {
    await dbService.close();
  });

  testWidgets('Ollivo app initializes cleanly', (WidgetTester tester) async {
    final mockClient = MockClient((request) async {
      if (request.url.path.endsWith('/api/version')) {
        return http.Response('{"version": "0.40.2"}', 200);
      } else if (request.url.path.endsWith('/api/tags')) {
        return http.Response('{"models": [{"name": "qwen2.5-coder:1.5b", "size": 980000000}]}', 200);
      }
      return http.Response('{"response": "Test response"}', 200);
    });

    final aiService = AIService(client: mockClient);
    final memoryService = MemoryService(dbService: dbService);
    final documentService = DocumentService(dbService: dbService);
    final taskService = TaskService(dbService: dbService);

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
    await tester.runAsync(() async {
      await chatController.loadConversations();
      await modelController.refreshModels();
    });

    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(OllivoApp(
      settingsService: settingsService,
      dbService: dbService,
      aiService: aiService,
      memoryService: memoryService,
      documentService: documentService,
      taskService: taskService,
      chatController: chatController,
      modelController: modelController,
    ));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('AI Assistant Chat'), findsAtLeast(1));
    expect(find.text('Ollivo'), findsAtLeast(1));
  });
}
