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
import 'package:ollivo/services/settings_service.dart';
import 'package:ollivo/views/chat/chat_view.dart';
import 'package:ollivo/views/documents/documents_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Document Import Buttons & Local RAG Tests', () {
    late DatabaseService dbService;
    late DocumentService documentService;
    late SettingsService settingsService;
    late Directory tempDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tempDir = Directory.systemTemp.createTempSync('ollivo_doc_test');

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

      settingsService = SettingsService();
      await settingsService.init(
        testPrefs: await SharedPreferences.getInstance(),
        testAppSupportPath: tempDir.path,
      );

      documentService = DocumentService(dbService: dbService);
    });

    tearDown(() async {
      await dbService.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('importAndIndexDocumentFromBytes correctly writes bytes, chunks text, and saves to database', () async {
      const sampleText = '''
# Local AI Architecture
Ollivo runs fully offline with Ollama and SQLite.
Zero data leaves the machine. All documents remain local.
''';

      final item = await documentService.importAndIndexDocumentFromBytes(
        'Architecture.md',
        sampleText.codeUnits,
        tempDir.path,
      );

      expect(item.filename, 'Architecture.md');
      expect(item.chunkCount, greaterThan(0));

      final docs = await documentService.getDocuments();
      expect(docs.length, 1);
      expect(docs.first.filename, 'Architecture.md');
      expect(docs.first.chunkCount, item.chunkCount);
    });

    testWidgets('DocumentsView renders Import Document, Paste Note, and Sample Doc buttons', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final key = GlobalKey<DocumentsViewState>();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DocumentsView(
            key: key,
            documentService: documentService,
            settingsService: settingsService,
            initialDocuments: const [],
          ),
        ),
      ));
      await tester.pump();

      // Check Header action buttons
      expect(find.text('Import Document'), findsOneWidget);
      expect(find.text('Paste / Write Note'), findsOneWidget);
      expect(find.text('Add Sample Doc'), findsOneWidget);
      expect(find.text('No documents imported yet'), findsOneWidget);
      expect(find.text('Select & Import File'), findsOneWidget);

      // Verify Paste / Write Note modal dialog opens
      await tester.tap(find.text('Paste / Write Note'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Create / Paste Document to Index'), findsOneWidget);
      expect(find.text('DOCUMENT FILENAME'), findsOneWidget);
      expect(find.text('Index Document'), findsOneWidget);

      // Close modal
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Create / Paste Document to Index'), findsNothing);
    });

    testWidgets('DocumentsView renders imported documents list and details', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final sampleDoc = DocumentItem(
        id: 'doc-123',
        filename: 'test_spec.pdf',
        filePath: '/tmp/test_spec.pdf',
        fileSize: 2048,
        chunkCount: 5,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DocumentsView(
            documentService: documentService,
            settingsService: settingsService,
            initialDocuments: [sampleDoc],
          ),
        ),
      ));
      await tester.pump();

      expect(find.text('test_spec.pdf'), findsOneWidget);
      expect(find.text('Indexed Documents (1)'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('ChatView renders file attachment button next to text input', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockClient = MockClient((request) async {
        return http.Response('{"models": []}', 200);
      });
      final aiService = AIService(client: mockClient);
      final chatController = ChatController(
        aiService: aiService,
        dbService: dbService,
        documentService: documentService,
        settingsService: settingsService,
      );
      final modelController = ModelController(
        aiService: aiService,
        settingsService: settingsService,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ChatView(
            chatController: chatController,
            modelController: modelController,
          ),
        ),
      ));
      await tester.pump();

      // Verify attach file icon button is present
      expect(find.byIcon(Icons.attach_file), findsOneWidget);
    });
  });
}
