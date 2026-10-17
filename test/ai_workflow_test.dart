import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ollivo/controllers/chat_controller.dart';
import 'package:ollivo/services/ai_service.dart';
import 'package:ollivo/services/database_service.dart';
import 'package:ollivo/services/memory_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('End-to-End AI Workflow Tests', () {
    late DatabaseService dbService;
    late MemoryService memoryService;

    setUp(() async {
      dbService = DatabaseService();
      final inMemoryDb = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('CREATE TABLE messages (id TEXT PRIMARY KEY, conversation_id TEXT NOT NULL, role TEXT NOT NULL, content TEXT NOT NULL, is_memory_saved INTEGER DEFAULT 0, created_at INTEGER NOT NULL);');
          await db.execute('CREATE TABLE memories (id TEXT PRIMARY KEY, fact TEXT NOT NULL, category TEXT DEFAULT "general", created_at INTEGER NOT NULL);');
        },
      );
      await dbService.init(testDatabase: inMemoryDb);
      memoryService = MemoryService(dbService: dbService);
    });

    tearDown(() async {
      await dbService.close();
    });

    test('1. Successful AI streaming workflow with mock response', () async {
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
      final controller = ChatController(
        aiService: aiService,
        dbService: dbService,
        memoryService: memoryService,
      );

      await controller.sendUserPrompt('Hello Ollivo');

      expect(controller.errorMessage, isNull);
      expect(controller.messages.length, 3); // Welcome + User + Assistant
      expect(controller.messages.last['content'], 'Hello World!');
    });

    test('2. Input validation: Empty prompts are rejected', () async {
      final controller = ChatController(
        aiService: AIService(),
        dbService: dbService,
        memoryService: memoryService,
      );

      await controller.sendUserPrompt('   ');

      expect(controller.errorMessage, 'Prompt cannot be empty.');
    });

    test('3. Secret Sanitization: Credentials are stripped before AI submission', () async {
      final mockClient = MockClient.streaming((request, bodyStream) async {
        return http.StreamedResponse(
          Stream.fromIterable(['{"response": "Acknowledged."}\n'.codeUnits]),
          200,
        );
      });

      final controller = ChatController(
        aiService: AIService(client: mockClient),
        dbService: dbService,
        memoryService: memoryService,
      );

      await controller.sendUserPrompt('My password: SuperSecretPass123!');

      expect(controller.messages[1]['content'], isNot(contains('SuperSecretPass123!')));
      expect(controller.messages[1]['content'], contains('[REDACTED SECRET]'));
    });

    test('4. Fact Memory Extraction & Persistence', () async {
      final mockClient = MockClient.streaming((request, bodyStream) async {
        return http.StreamedResponse(
          Stream.fromIterable(['{"response": "Saved preference."}\n'.codeUnits]),
          200,
        );
      });

      final controller = ChatController(
        aiService: AIService(client: mockClient),
        dbService: dbService,
        memoryService: memoryService,
      );

      await controller.sendUserPrompt('Remember our color is Emerald #6B9E78');

      expect(controller.recentSavedMemory, isNotNull);
      expect(controller.recentSavedMemory, contains('Emerald #6B9E78'));

      final storedMemories = await memoryService.getMemories();
      expect(storedMemories.length, 1);
      expect(storedMemories.first['fact'], contains('Emerald #6B9E78'));
    });

    test('5. Provider Error Handling: HTTP failures emit graceful error state', () async {
      final mockClient = MockClient.streaming((request, bodyStream) async {
        return http.StreamedResponse(
          Stream.fromIterable(['Server Error'.codeUnits]),
          500,
        );
      });

      final controller = ChatController(
        aiService: AIService(client: mockClient),
        dbService: dbService,
        memoryService: memoryService,
      );

      await controller.sendUserPrompt('Test error prompt');

      expect(controller.messages.last['content'], contains('Error: Local Ollama service returned HTTP 500'));
    });

    test('6. Regression (L-01): clearSavedMemoryBanner resets recentSavedMemory state', () async {
      final mockClient = MockClient.streaming((request, bodyStream) async {
        return http.StreamedResponse(
          Stream.fromIterable(['{"response": "Saved preference."}\n'.codeUnits]),
          200,
        );
      });

      final controller = ChatController(
        aiService: AIService(client: mockClient),
        dbService: dbService,
        memoryService: memoryService,
      );

      await controller.sendUserPrompt('Remember our color is Emerald #6B9E78');
      expect(controller.recentSavedMemory, isNotNull);

      controller.clearSavedMemoryBanner();
      expect(controller.recentSavedMemory, isNull);
    });
  });
}
