import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ollivo/models/persona_preset.dart';
import 'package:ollivo/models/prompt_template.dart';
import 'package:ollivo/services/database_service.dart';
import 'package:ollivo/services/memory_service.dart';
import 'package:ollivo/views/memories/memory_center_view.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Phase 5: Long-Term Memory, Prompts & Power Features Tests', () {
    late DatabaseService dbService;
    late MemoryService memoryService;

    setUp(() async {
      dbService = DatabaseService();
      final inMemoryDb = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE conversations (id TEXT PRIMARY KEY, title TEXT NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL);',
          );
          await db.execute(
            'CREATE TABLE messages (id TEXT PRIMARY KEY, conversation_id TEXT NOT NULL, role TEXT NOT NULL, content TEXT NOT NULL, is_memory_saved INTEGER DEFAULT 0, created_at INTEGER NOT NULL);',
          );
          await db.execute(
            'CREATE TABLE memories (id TEXT PRIMARY KEY, fact TEXT NOT NULL, category TEXT DEFAULT "general", created_at INTEGER NOT NULL);',
          );
          await db.execute(
            'CREATE TABLE documents (id TEXT PRIMARY KEY, filename TEXT NOT NULL, file_path TEXT NOT NULL, file_size INTEGER NOT NULL, chunk_count INTEGER NOT NULL, created_at INTEGER NOT NULL);',
          );
          await db.execute(
            'CREATE TABLE tasks (id TEXT PRIMARY KEY, title TEXT NOT NULL, description TEXT, status TEXT DEFAULT "todo", priority TEXT DEFAULT "medium", due_date INTEGER, created_at INTEGER NOT NULL);',
          );
        },
      );
      await dbService.init(testDatabase: inMemoryDb);
      memoryService = MemoryService(dbService: dbService);
    });

    tearDown(() async {
      await dbService.close();
    });

    test('MEM-001 & MEM-002: Memory Taxonomy Filtering and Inline Editing', () async {
      // 1. Save facts across various taxonomy categories
      await memoryService.saveFact('mem-1', 'User prefers Flutter desktop applications.', category: 'preference');
      await memoryService.saveFact('mem-2', 'Ollivo project uses local SQLite and Ollama.', category: 'project');
      await memoryService.saveFact('mem-3', 'Asad Ali Shaikh is lead software engineer.', category: 'personal');
      await memoryService.saveFact('mem-4', 'General observation about desktop performance.', category: 'general');

      // 2. Query all facts
      final allMemories = await memoryService.getMemories();
      expect(allMemories.length, 4);

      // 3. Query filtered by taxonomy category (MEM-001)
      final prefMemories = await memoryService.getMemories(category: 'preference');
      expect(prefMemories.length, 1);
      expect(prefMemories.first['fact'], contains('Flutter desktop'));

      final projMemories = await memoryService.getMemories(category: 'project');
      expect(projMemories.length, 1);
      expect(projMemories.first['fact'], contains('Ollivo project'));

      final persMemories = await memoryService.getMemories(category: 'personal');
      expect(persMemories.length, 1);
      expect(persMemories.first['fact'], contains('Asad Ali Shaikh'));

      // 4. Update memory inline (MEM-002)
      await memoryService.updateMemory(
        'mem-1',
        'User strictly prefers Flutter desktop with Onyx dark theme.',
        category: 'preference',
      );

      final updated = await memoryService.getMemories(category: 'preference');
      expect(updated.length, 1);
      expect(updated.first['fact'], 'User strictly prefers Flutter desktop with Onyx dark theme.');
    });

    test('MEM-003: Semantic Deduplication on Memory Save', () async {
      // 1. Test token-based Jaccard similarity
      final simIdentical = MemoryService.calculateSimilarity(
        'User prefers dark mode Onyx UI theme',
        'User prefers dark mode Onyx UI theme',
      );
      expect(simIdentical, closeTo(1.0, 0.01));

      final simClose = MemoryService.calculateSimilarity(
        'User prefers dark mode Onyx UI theme',
        'User prefers dark mode Onyx theme in the application',
      );
      expect(simClose, greaterThan(0.6));

      final simDifferent = MemoryService.calculateSimilarity(
        'User prefers dark mode UI',
        'Database uses SQLite on macOS desktop',
      );
      expect(simDifferent, lessThan(0.2));

      // 2. Save base fact
      final id1 = await memoryService.saveFactWithDedup(
        'User prefers dark mode Onyx UI theme',
        category: 'preference',
      );

      final memsAfterFirst = await memoryService.getMemories();
      expect(memsAfterFirst.length, 1);
      expect(memsAfterFirst.first['id'], id1);

      // 3. Save highly similar/duplicate fact -> Should update existing rather than creating new row
      final id2 = await memoryService.saveFactWithDedup(
        'User prefers dark mode Onyx UI theme always',
        category: 'preference',
      );

      expect(id2, id1); // Reused identical ID
      final memsAfterDedup = await memoryService.getMemories();
      expect(memsAfterDedup.length, 1); // Deduplicated! Still 1 record
      expect(memsAfterDedup.first['fact'], 'User prefers dark mode Onyx UI theme always');

      // 4. Save distinct fact -> Should create new record
      final id3 = await memoryService.saveFactWithDedup(
        'Local Ollama daemon runs on port 11434',
        category: 'project',
      );
      expect(id3, isNot(id1));
      final memsAfterDistinct = await memoryService.getMemories();
      expect(memsAfterDistinct.length, 2);
    });

    test('PRM-001: Pre-built Persona Presets Library', () {
      final presets = PersonaPreset.presets;
      expect(presets.length, 5);

      final architect = presets.firstWhere((p) => p.id == 'coding-architect');
      expect(architect.name, 'Coding Architect');
      expect(architect.systemPrompt, contains('senior software architect'));

      final writer = presets.firstWhere((p) => p.id == 'technical-writer');
      expect(writer.name, 'Technical Writer');
      expect(writer.systemPrompt, contains('technical writer'));

      final brainstormer = presets.firstWhere((p) => p.id == 'creative-brainstormer');
      expect(brainstormer.name, 'Creative Brainstormer');
      expect(brainstormer.systemPrompt, contains('brainstorming partner'));

      final minimalist = presets.firstWhere((p) => p.id == 'terse-minimalist');
      expect(minimalist.name, 'Terse Minimalist');
      expect(minimalist.systemPrompt, contains('ultra-concise'));

      final balanced = presets.firstWhere((p) => p.id == 'balanced-assistant');
      expect(balanced.name, 'Balanced Assistant');
      expect(balanced.systemPrompt, contains('thoughtful, helpful'));
    });

    test('PRM-002: Prompt Templates with Dynamic Slot Variables', () {
      final templates = PromptTemplate.defaultTemplates;
      expect(templates.length, 5);

      // 1. Code Review template interpolation
      final codeReview = templates.firstWhere((t) => t.id == 'code-review');
      expect(codeReview.variables, containsAll(['language', 'code']));

      final interpolatedReview = codeReview.interpolate({
        'language': 'Dart',
        'code': 'void main() { print("hello"); }',
      });
      expect(interpolatedReview, contains('Dart'));
      expect(interpolatedReview, contains('void main() { print("hello"); }'));
      expect(interpolatedReview, isNot(contains('{{language}}')));
      expect(interpolatedReview, isNot(contains('{{code}}')));

      // 2. Explain Concept template interpolation
      final explain = templates.firstWhere((t) => t.id == 'explain-concept');
      final interpolatedExplain = explain.interpolate({
        'concept': 'RAG Vector Embeddings',
        'target_audience': 'junior',
      });
      expect(interpolatedExplain, contains('"RAG Vector Embeddings"'));
      expect(interpolatedExplain, contains('junior'));

      // 3. Debug Error template interpolation
      final debug = templates.firstWhere((t) => t.id == 'debug-error');
      final interpolatedDebug = debug.interpolate({
        'language': 'Flutter',
        'error_message': 'RenderFlex overflowed by 42 pixels',
        'context': 'Row containing two unbounded Expanded widgets',
      });
      expect(interpolatedDebug, contains('RenderFlex overflowed by 42 pixels'));
      expect(interpolatedDebug, contains('Row containing two unbounded Expanded widgets'));
    });

    test('SET-003: Database Storage Inspector, Table Counts & VACUUM', () async {
      // 1. Insert records across tables
      final db = dbService.database;
      await db.insert('conversations', {
        'id': 'conv-1',
        'title': 'Test Conv',
        'created_at': 1000,
        'updated_at': 1000,
      });
      await db.insert('messages', {
        'id': 'msg-1',
        'conversation_id': 'conv-1',
        'role': 'user',
        'content': 'Hello',
        'created_at': 1000,
      });
      await memoryService.saveFact('mem-1', 'Fact 1');
      await memoryService.saveFact('mem-2', 'Fact 2');

      // 2. Inspect table counts
      final counts = await dbService.getTableCounts();
      expect(counts['conversations'], 1);
      expect(counts['messages'], 1);
      expect(counts['memories'], 2);
      expect(counts['documents'], 0);
      expect(counts['tasks'], 0);

      // 3. Inspect database size
      final size = await dbService.getDatabaseSizeBytes();
      expect(size, greaterThan(0));

      // 4. Run VACUUM optimization
      await dbService.vacuum();
      final sizeAfterVacuum = await dbService.getDatabaseSizeBytes();
      expect(sizeAfterVacuum, greaterThan(0));
    });

    testWidgets('UI: MemoryCenterView renders taxonomy filter chips and edit buttons', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final initialList = [
        {
          'id': 'mem-test',
          'fact': 'Onyx background theme #121212',
          'category': 'preference',
          'created_at': 1000,
        }
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MemoryCenterView(
              memoryService: memoryService,
              initialMemories: initialList,
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify taxonomy chips
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Personal'), findsOneWidget);
      expect(find.text('Preference'), findsOneWidget);
      expect(find.text('Project'), findsOneWidget);
      expect(find.text('General'), findsOneWidget);

      // Verify stored fact card
      expect(find.text('Onyx background theme #121212'), findsOneWidget);

      // Verify edit memory button tooltip
      final editButton = find.byTooltip('Edit Memory');
      expect(editButton, findsOneWidget);

      // Tap edit button to open inline editing dialog
      await tester.tap(editButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify edit dialog opened
      expect(find.text('Edit Stored Memory'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
