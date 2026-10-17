import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ollivo/controllers/model_controller.dart';
import 'package:ollivo/services/ai_service.dart';
import 'package:ollivo/services/database_service.dart';
import 'package:ollivo/services/document_service.dart';
import 'package:ollivo/services/settings_service.dart';
import 'package:ollivo/services/task_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('New Feature Services & Controllers Tests', () {
    late DatabaseService dbService;

    setUp(() async {
      dbService = DatabaseService();
      final inMemoryDb = await openDatabase(
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

    test('1. SettingsService persists preferences & custom folder paths', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService();
      await settings.init(testPrefs: await SharedPreferences.getInstance());

      expect(settings.themeMode, 'dark');
      expect(settings.ollamaHost, 'http://127.0.0.1:11434');

      await settings.setThemeMode('light');
      await settings.setOllamaHost('http://127.0.0.1:11434');
      await settings.setActiveModel('qwen2.5-coder:7b');

      expect(settings.themeMode, 'light');
      expect(settings.activeModel, 'qwen2.5-coder:7b');
    });

    test('2. TaskService performs database CRUD operations', () async {
      final taskService = TaskService(dbService: dbService);

      final task = TaskItem(
        id: 't-1',
        title: 'Review Ollivo macOS release build',
        priority: 'high',
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      await taskService.createTask(task);
      List<TaskItem> tasks = await taskService.getTasks();
      expect(tasks.length, 1);
      expect(tasks.first.title, 'Review Ollivo macOS release build');
      expect(tasks.first.isCompleted, false);

      await taskService.toggleTaskStatus('t-1', true);
      tasks = await taskService.getTasks();
      expect(tasks.first.isCompleted, true);

      await taskService.deleteTask('t-1');
      tasks = await taskService.getTasks();
      expect(tasks.isEmpty, true);
    });

    test('3. DocumentService parses file chunks and queries RAG keywords', () async {
      final docService = DocumentService(dbService: dbService);

      final tempDir = Directory.systemTemp.createTempSync('ollivo_doc_test');
      final sampleFile = File('${tempDir.path}/test_notes.md');
      await sampleFile.writeAsString('# Ollivo Architecture\n\nOllivo uses #121212 Onyx background and #6B9E78 Emerald accent.');

      final docItem = await docService.importAndIndexDocument(sampleFile.path, '${tempDir.path}/sandbox_docs');

      expect(docItem.filename, 'test_notes.md');
      expect(docItem.chunkCount, 2);

      final results = docService.queryRelevantChunks('What background color does Ollivo use?');
      expect(results.length, greaterThanOrEqualTo(1));
      expect(results.first, contains('Onyx background'));

      tempDir.deleteSync(recursive: true);
    });

    test('4. AIService fetches installed models via /api/tags mock', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/tags') {
          return http.Response(
            '{"models": [{"name": "qwen2.5-coder:1.5b", "size": 980000000, "digest": "abc1234567890", "modified_at": "2026-10-10"}]}',
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final aiService = AIService(client: mockClient);
      final installed = await aiService.fetchInstalledModels();

      expect(installed.length, 1);
      expect(installed.first.name, 'qwen2.5-coder:1.5b');
    });

    test('5. ModelController handles recommendations & installed list', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService();
      await settings.init(testPrefs: await SharedPreferences.getInstance());

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/version') {
          return http.Response('{"version": "0.4.2"}', 200);
        }
        if (request.url.path == '/api/tags') {
          return http.Response(
            '{"models": [{"name": "llama3.2:3b", "size": 2000000000, "digest": "xyz9876543210", "modified_at": "2026-10-10"}]}',
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final aiService = AIService(client: mockClient);
      final modelController = ModelController(aiService: aiService, settingsService: settings);

      await modelController.refreshModels();

      expect(modelController.isOllamaOnline, true);
      expect(modelController.installedModels.length, 1);
      expect(modelController.isInstalled('llama3.2:3b'), true);
    });
  });
}
