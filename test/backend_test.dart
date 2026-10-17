import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ollivo/core/constants.dart';
import 'package:ollivo/services/ai_service.dart';
import 'package:ollivo/services/database_service.dart';
import 'package:ollivo/services/memory_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    // Initialize FFI for local desktop/in-memory SQLite testing
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('AppConstants & Privacy Sanitization Tests', () {
    test('Secret sanitization strips passwords and private keys', () {
      const rawPrompt = 'My password: SuperSecretPassword123 and auth_key: BearerXYZ';
      final sanitized = AppConstants.sanitizeText(rawPrompt);

      expect(sanitized, isNot(contains('SuperSecretPassword123')));
      expect(sanitized, contains('[REDACTED SECRET]'));
    });
  });

  group('DatabaseService Tests', () {
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
          await db.execute('CREATE TABLE tasks (id TEXT PRIMARY KEY, title TEXT NOT NULL, description TEXT, status TEXT DEFAULT "todo", priority TEXT DEFAULT "medium", due_date INTEGER, created_at INTEGER NOT NULL);');
        },
      );
      await dbService.init(testDatabase: inMemoryDb);
    });

    tearDown(() async {
      await dbService.close();
    });

    test('SQLite tables initialize and insert records cleanly', () async {
      final db = dbService.database;

      await db.insert('conversations', {
        'id': 'conv-1',
        'title': 'Test Chat',
        'created_at': 1000,
        'updated_at': 1000,
      });

      final result = await db.query('conversations');
      expect(result.length, 1);
      expect(result.first['title'], 'Test Chat');
    });
  });

  group('AIService Tests', () {
    test('AIService health check returns true when Ollama is online', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/version') {
          return http.Response('{"version": "0.40.2"}', 200);
        }
        return http.Response('Not Found', 44);
      });

      final aiService = AIService(client: mockClient);
      final isHealthy = await aiService.checkHealth();
      expect(isHealthy, isTrue);
    });

    test('AIService streams response tokens cleanly', () async {
      final mockClient = MockClient.streaming((request, bodyStream) async {
        return http.StreamedResponse(
          Stream.fromIterable([
            '{"response": "Hello "}\n',
            '{"response": "World!"}\n',
          ].map((s) => s.codeUnits)),
          200,
        );
      });

      final aiService = AIService(client: mockClient);
      final tokens = await aiService.generateStream('Hello').toList();

      expect(tokens, ['Hello ', 'World!']);
    });

    test('AIService enforces concurrency lock (max 1 active generation)', () async {
      final mockClient = MockClient.streaming((request, bodyStream) async {
        return http.StreamedResponse(
          Stream.fromIterable(['{"response": "Done"}\n'.codeUnits]),
          200,
        );
      });

      final aiService = AIService(client: mockClient);

      // Listen to first stream to activate lock
      final stream = aiService.generateStream('Test Prompt');
      final subscription = stream.listen((_) {});

      expect(
        aiService.generateStream('Parallel Prompt').toList(),
        throwsA(isA<StateError>()),
      );

      await subscription.cancel();
    });
  });

  group('MemoryService Tests', () {
    late DatabaseService dbService;
    late MemoryService memoryService;

    setUp(() async {
      dbService = DatabaseService();
      final inMemoryDb = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('CREATE TABLE memories (id TEXT PRIMARY KEY, fact TEXT NOT NULL, category TEXT DEFAULT "general", created_at INTEGER NOT NULL);');
        },
      );
      await dbService.init(testDatabase: inMemoryDb);
      memoryService = MemoryService(dbService: dbService);
    });

    tearDown(() async {
      await dbService.close();
    });

    test('MemoryService saves and retrieves facts cleanly', () async {
      await memoryService.saveFact('mem-1', 'Color is #121212', category: 'design');

      final memories = await memoryService.getMemories();
      expect(memories.length, 1);
      expect(memories.first['fact'], 'Color is #121212');
      expect(memories.first['category'], 'design');
    });
  });
}
