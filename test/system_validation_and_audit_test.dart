import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ollivo/controllers/chat_controller.dart';
import 'package:ollivo/services/ai_service.dart';
import 'package:ollivo/services/database_service.dart';
import 'package:ollivo/services/document_service.dart';
import 'package:ollivo/services/memory_service.dart';
import 'package:ollivo/services/settings_service.dart';
import 'package:ollivo/services/task_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('System Validation & Audit Regression Test Suite', () {
    late Database db;
    late DatabaseService dbService;
    late SettingsService settingsService;
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ollivo_audit_test_');
      SharedPreferences.setMockInitialValues({});
      settingsService = SettingsService();
      await settingsService.init(
        testPrefs: await SharedPreferences.getInstance(),
        testAppSupportPath: tempDir.path,
      );

      // Open in-memory database with strictly enforced foreign keys
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onConfigure: (database) async {
          await database.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (database, version) async {
          await database.execute('''
            CREATE TABLE conversations (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            );
          ''');

          await database.execute('''
            CREATE TABLE messages (
              id TEXT PRIMARY KEY,
              conversation_id TEXT NOT NULL,
              role TEXT CHECK(role IN ('user', 'assistant', 'system')) NOT NULL,
              content TEXT NOT NULL,
              is_memory_saved INTEGER DEFAULT 0,
              created_at INTEGER NOT NULL,
              FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
            );
          ''');

          await database.execute('''
            CREATE TABLE memories (
              id TEXT PRIMARY KEY,
              fact TEXT NOT NULL,
              category TEXT DEFAULT 'general',
              created_at INTEGER NOT NULL
            );
          ''');

          await database.execute('''
            CREATE TABLE documents (
              id TEXT PRIMARY KEY,
              filename TEXT NOT NULL,
              file_path TEXT NOT NULL,
              file_size INTEGER NOT NULL,
              chunk_count INTEGER NOT NULL,
              created_at INTEGER NOT NULL
            );
          ''');

          await database.execute('''
            CREATE TABLE tasks (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              description TEXT,
              status TEXT CHECK(status IN ('todo', 'in_progress', 'completed')) DEFAULT 'todo',
              priority TEXT CHECK(priority IN ('low', 'medium', 'high')) DEFAULT 'medium',
              due_date INTEGER,
              created_at INTEGER NOT NULL
            );
          ''');
        },
      );

      dbService = DatabaseService();
      await dbService.init(testDatabase: db);
    });

    tearDown(() async {
      await dbService.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('1. Foreign Key Message Persistence: Default conversation auto-created and messages persisted', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/api/generate')) {
          return http.Response(
            '{"response": "Here is the local reply.", "done": true}\n',
            200,
          );
        }
        return http.Response('{}', 200);
      });

      final aiService = AIService(client: mockClient);
      final chatController = ChatController(
        aiService: aiService,
        dbService: dbService,
        settingsService: settingsService,
      );

      // Verify initial state
      expect(chatController.activeConversationId, 'default-session');

      // Send prompt on default session
      await chatController.sendUserPrompt('Hello Ollivo local AI!');

      // Check SQLite conversations table
      final convs = await db.query('conversations', where: 'id = ?', whereArgs: ['default-session']);
      expect(convs.length, 1, reason: 'default-session row must exist in conversations table to satisfy FK');
      expect(convs.first['title'], 'General Session');

      // Check SQLite messages table
      final msgs = await db.query('messages', where: 'conversation_id = ?', whereArgs: ['default-session']);
      expect(msgs.length, 2, reason: 'Both user and assistant messages must be persisted in SQLite');
      expect(msgs[0]['role'], 'user');
      expect(msgs[0]['content'], 'Hello Ollivo local AI!');
      expect(msgs[1]['role'], 'assistant');
      expect(msgs[1]['content'], contains('local reply'));

      // Test Quick Ask exchange injection via addCompletedExchange
      await chatController.addCompletedExchange(
        'Quick question?',
        'Quick response.',
      );

      final updatedMsgs = await db.query('messages', where: 'conversation_id = ?', whereArgs: ['default-session']);
      expect(updatedMsgs.length, 4, reason: 'Quick ask exchange must also be successfully persisted');
    });

    test('2. Multi-Conversation Switching & Isolation', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"response": "Answer", "done": true}\n', 200);
      });
      final aiService = AIService(client: mockClient);
      final chatController = ChatController(
        aiService: aiService,
        dbService: dbService,
        settingsService: settingsService,
      );

      await chatController.sendUserPrompt('Message in session 1');

      // Create second conversation
      await chatController.createNewConversation('Project Alpha');
      expect(chatController.activeConversationTitle, 'Project Alpha');
      await chatController.sendUserPrompt('Message in Project Alpha');

      // Verify conversation 1 messages
      await chatController.switchConversation('default-session', 'General Session');
      expect(chatController.messages.any((m) => m['content'] == 'Message in session 1'), isTrue);
      expect(chatController.messages.any((m) => m['content'] == 'Message in Project Alpha'), isFalse);

      // Verify conversation 2 messages
      final alphaConv = chatController.conversations.firstWhere((c) => c.title == 'Project Alpha');
      await chatController.switchConversation(alphaConv.id, alphaConv.title);
      expect(chatController.messages.any((m) => m['content'] == 'Message in Project Alpha'), isTrue);
      expect(chatController.messages.any((m) => m['content'] == 'Message in session 1'), isFalse);

      // Delete conversation cascades to messages
      await chatController.deleteConversation(alphaConv.id);
      final deletedMsgs = await db.query('messages', where: 'conversation_id = ?', whereArgs: [alphaConv.id]);
      expect(deletedMsgs, isEmpty, reason: 'Deleting conversation must cascade delete all associated messages');
    });

    test('3. Persistent Document RAG Reload Across Restarts', () async {
      final docService = DocumentService(dbService: dbService);
      const docText = '''
# Ollivo Engine Architecture
Ollivo utilizes sliding-window semantic chunking with 400 character chunks and 80 character overlap.
Embeddings are computed locally using Metal GPU acceleration on Apple Silicon.
RAG retrieval computes hybrid cosine similarity combined with keyword matching.
''';

      // Import document
      final docItem = await docService.importAndIndexDocumentFromBytes(
        'architecture.md',
        utf8.encode(docText),
        tempDir.path,
      );

      expect(docService.indexedChunks.isNotEmpty, isTrue);
      final initialChunkCount = docService.indexedChunks.length;

      // Simulate app restart with a fresh DocumentService instance
      final restartedDocService = DocumentService(dbService: dbService);
      expect(restartedDocService.indexedChunks, isEmpty, reason: 'Fresh service starts with empty in-memory index');

      // Reload persisted documents
      await restartedDocService.loadPersistedDocuments();
      expect(restartedDocService.indexedChunks.length, initialChunkCount, reason: 'All document chunks must be restored from disk/SQLite');

      // Test RAG retrieval on reloaded service
      final retrieved = await restartedDocService.retrieveDetailed('sliding-window chunking');
      expect(retrieved.isNotEmpty, isTrue);
      expect(retrieved.first.chunk.filename, 'architecture.md');
      expect(retrieved.first.chunk.text, contains('sliding-window'));

      // Test getChunksForDocument
      final chunks = restartedDocService.getChunksForDocument(docItem.id);
      expect(chunks.length, initialChunkCount);
    });

    test('4. Safe Unicode & Multi-Byte Document Import', () async {
      final docService = DocumentService(dbService: dbService);
      const unicodeContent = '''
# 🚀 Ollivo Internationalization & Unicode Spec
- 日本語: ローカルAIアシスタント
- Deutsch: Lokale KI-Datenschutzprüfung mit Äpfeln & Prüfungen
- Español: Privacidad total sin conexión a la nube 🔒
- Math & Symbols: ∑(x_i) ≥ 0, ∀x ∈ ℝ, 𝝅 ≈ 3.14159
''';

      // Ensure import does not throw ArgumentError on utf-8 encoded bytes
      final doc = await docService.importAndIndexDocumentFromBytes(
        'unicode_test.md',
        utf8.encode(unicodeContent),
        tempDir.path,
      );

      expect(doc.filename, 'unicode_test.md');
      final file = File(doc.filePath);
      expect(await file.exists(), isTrue);

      final extracted = await DocumentService.extractTextFromFile(file);
      expect(extracted, contains('日本語'));
      expect(extracted, contains('Äpfeln & Prüfungen'));
      expect(extracted, contains('🔒'));
    });

    test('5. Long-term Fact Memory Deduplication & Search', () async {
      final memoryService = MemoryService(dbService: dbService);

      // Save fact 1
      final id1 = await memoryService.saveFactWithDedup(
        'User prefers dark mode Onyx UI theme',
        category: 'preference',
      );

      // Save similar fact 2 (should update id1 rather than duplicate)
      final id2 = await memoryService.saveFactWithDedup(
        'User prefers dark mode Onyx UI theme always',
        category: 'preference',
      );

      expect(id2, id1, reason: 'Semantic deduplication should update the existing memory record');

      final memories = await memoryService.getMemories();
      expect(memories.length, 1);
      expect(memories.first['fact'], 'User prefers dark mode Onyx UI theme always');

      // Forget/Delete fact
      await memoryService.deleteMemory(id1);
      final emptyMemories = await memoryService.getMemories();
      expect(emptyMemories, isEmpty);
    });

    test('6. Task Workspace Lifecycle, Filtering & Due Date Calculations', () async {
      final taskService = TaskService(dbService: dbService);
      final now = DateTime.now();

      final task = TaskItem(
        id: 'tsk-1',
        title: 'Implement Metal acceleration profiling',
        status: 'todo',
        priority: 'high',
        dueDate: now.add(const Duration(days: 2)).millisecondsSinceEpoch,
        createdAt: now.millisecondsSinceEpoch,
      );

      await taskService.createTask(task);
      var tasks = await taskService.getTasks();
      expect(tasks.length, 1);
      expect(tasks.first.relativeDueDate, 'In 2 days');
      expect(tasks.first.isOverdue, isFalse);

      // Cycle status to in_progress
      await taskService.updateTaskStatus('tsk-1', 'in_progress');
      tasks = await taskService.getTasks(statusFilter: 'in_progress');
      expect(tasks.length, 1);
      expect(tasks.first.isInProgress, isTrue);

      // Cycle status to completed
      await taskService.updateTaskStatus('tsk-1', 'completed');
      tasks = await taskService.getTasks(statusFilter: 'completed');
      expect(tasks.length, 1);
      expect(tasks.first.isCompleted, isTrue);

      // Overdue calculation test
      final overdueTask = TaskItem(
        id: 'tsk-overdue',
        title: 'Past due milestone',
        status: 'todo',
        dueDate: now.subtract(const Duration(days: 3)).millisecondsSinceEpoch,
        createdAt: now.subtract(const Duration(days: 5)).millisecondsSinceEpoch,
      );
      expect(overdueTask.isOverdue, isTrue);
      expect(overdueTask.relativeDueDate, 'Overdue');
    });
  });
}
