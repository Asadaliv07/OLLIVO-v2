import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ollivo/services/database_service.dart';
import 'package:ollivo/services/document_service.dart';
import 'package:ollivo/services/task_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Phase 4: Local RAG, Documents & Task Automation Tests', () {
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

    test('DOC-001: Vector Cosine Similarity & Hybrid Retrieval Engine', () async {
      // 1. Identical vectors
      final v1 = [1.0, 0.0, 0.0];
      final v2 = [1.0, 0.0, 0.0];
      expect(DocumentService.cosineSimilarity(v1, v2), closeTo(1.0, 0.001));

      // 2. Orthogonal vectors
      final v3 = [0.0, 1.0, 0.0];
      expect(DocumentService.cosineSimilarity(v1, v3), closeTo(0.0, 0.001));

      // 3. Similar vectors
      final v4 = [0.8, 0.6, 0.0];
      final v5 = [0.6, 0.8, 0.0];
      expect(DocumentService.cosineSimilarity(v4, v5), greaterThan(0.95));

      // 4. Test Hybrid retrieval with in-memory chunks
      final docService = DocumentService(dbService: dbService);
      final tempDir = Directory.systemTemp.createTempSync('rag_hybrid_test');
      final testFile = File('${tempDir.path}/apple_silicon.md');
      await testFile.writeAsString(
        'Apple Silicon M-series chips use unified memory architecture for GPU and neural engine operations.',
      );

      final doc = await docService.importAndIndexDocument(testFile.path, '${tempDir.path}/docs');
      expect(doc.chunkCount, greaterThanOrEqualTo(1));

      // Detailed retrieval
      final results = await docService.retrieveDetailed('Apple Silicon unified memory');
      expect(results.isNotEmpty, true);
      final top = results.first;
      expect(top.chunk.filename, 'apple_silicon.md');
      expect(top.keywordMatches, greaterThanOrEqualTo(2));
      expect(top.formattedScore, contains('% match'));

      tempDir.deleteSync(recursive: true);
    });

    test('DOC-002: Semantic Sliding-Window Chunking and Native PDF Extraction', () async {
      // 1. Sliding window chunking with overlap
      final longText = List.generate(50, (i) => 'Sentence number $i explaining local desktop AI features.').join(' ');
      final chunks = DocumentService.chunkText(longText, chunkSize: 200, chunkOverlap: 40);

      expect(chunks.length, greaterThan(1));
      for (final chunk in chunks) {
        expect(chunk.isNotEmpty, true);
      }

      // 2. Native PDF Text Extraction test with synthetic PDF structure
      final tempDir = Directory.systemTemp.createTempSync('pdf_extract_test');
      final pdfFile = File('${tempDir.path}/sample.pdf');
      
      // Minimal valid PDF text stream with BT ... ET text object
      final syntheticPdf = '%PDF-1.4\n1 0 obj\n<< /Length 55 >>\nstream\nBT /F1 12 Tf 72 712 Td (Hello Ollivo PDF Reader) Tj ET\nendstream\nendobj\ntrailer\n<< /Root 1 0 R >>\n%%EOF';
      await pdfFile.writeAsBytes(latin1.encode(syntheticPdf));

      final extracted = await DocumentService.extractTextFromPdf(pdfFile);
      expect(extracted, contains('Hello Ollivo PDF Reader'));

      tempDir.deleteSync(recursive: true);
    });

    test('DOC-003: Source Citation Metadata Serialization and Formatting', () {
      final chunk = DocumentChunk(
        docId: 'doc-123',
        filename: 'manual.pdf',
        chunkIndex: 2,
        text: 'Ollivo operates 100% locally on your machine.',
      );

      final retrieved = RetrievedChunk(
        chunk: chunk,
        score: 0.92,
        keywordMatches: 4,
        vectorSimilarity: 0.945,
      );

      expect(retrieved.citationLabel, '[Document: manual.pdf (Chunk #3)]');
      expect(retrieved.formattedScore, '92% match');

      final map = retrieved.toMap();
      expect(map['filename'], 'manual.pdf');
      expect(map['chunkIndex'], 2);
      expect(map['score'], 0.92);

      final restored = RetrievedChunk.fromMap(map);
      expect(restored.chunk.filename, 'manual.pdf');
      expect(restored.chunk.chunkIndex, 2);
      expect(restored.score, 0.92);
      expect(restored.vectorSimilarity, 0.945);
    });

    test('TSK-001: Action Item Parsing from Natural Language & Batch Creation', () async {
      const responseText = '''
Here is the plan for your application:
- [ ] Implement local RAG with cosine similarity (urgent)
- [ ] Add PDF document parsing support
* 3. Refactor task manager with relative due dates
- Optional: Add extra icon animations (minor)
''';

      final parsed = TaskService.parseTasksFromText(responseText);
      expect(parsed.length, 4);

      // Verify task titles
      expect(parsed[0].title, contains('Implement local RAG'));
      expect(parsed[0].priority, 'high'); // Detected from "urgent"

      expect(parsed[1].title, contains('Add PDF document parsing'));
      expect(parsed[1].priority, 'medium');

      expect(parsed[2].title, contains('Refactor task manager'));
      expect(parsed[2].priority, 'medium');

      expect(parsed[3].title, contains('Add extra icon animations'));
      expect(parsed[3].priority, 'low'); // Detected from "minor"

      // Batch creation into SQLite
      final taskService = TaskService(dbService: dbService);
      await taskService.batchCreateTasks(parsed);

      final loaded = await taskService.getTasks();
      expect(loaded.length, 4);
    });

    test('TSK-002: Relative Due Date Calculations and Overdue Detection', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 12, 0).millisecondsSinceEpoch;
      final tomorrow = DateTime(now.year, now.month, now.day + 1, 12, 0).millisecondsSinceEpoch;
      final inThreeDays = DateTime(now.year, now.month, now.day + 3, 12, 0).millisecondsSinceEpoch;
      final yesterday = DateTime(now.year, now.month, now.day - 1, 12, 0).millisecondsSinceEpoch;

      final taskToday = TaskItem(id: 't1', title: 'Task 1', dueDate: today, createdAt: 0);
      final taskTomorrow = TaskItem(id: 't2', title: 'Task 2', dueDate: tomorrow, createdAt: 0);
      final taskIn3 = TaskItem(id: 't3', title: 'Task 3', dueDate: inThreeDays, createdAt: 0);
      final taskOverdue = TaskItem(id: 't4', title: 'Task 4', dueDate: yesterday, createdAt: 0);
      final taskCompletedPast = TaskItem(id: 't5', title: 'Task 5', status: 'completed', dueDate: yesterday, createdAt: 0);

      expect(taskToday.relativeDueDate, 'Today');
      expect(taskToday.isOverdue, false);

      expect(taskTomorrow.relativeDueDate, 'Tomorrow');
      expect(taskTomorrow.isOverdue, false);

      expect(taskIn3.relativeDueDate, 'In 3 days');
      expect(taskIn3.isOverdue, false);

      expect(taskOverdue.relativeDueDate, 'Overdue');
      expect(taskOverdue.isOverdue, true);

      // Completed tasks in the past should not be flagged as overdue
      expect(taskCompletedPast.isOverdue, false);
    });

    test('TSK-003: 3-State Workflow (To Do -> In Progress -> Completed)', () async {
      final taskService = TaskService(dbService: dbService);
      final task = TaskItem(
        id: 't-state',
        title: 'Document Testing',
        status: 'todo',
        priority: 'high',
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      await taskService.createTask(task);

      var list = await taskService.getTasks(statusFilter: 'todo');
      expect(list.length, 1);
      expect(list.first.isTodo, true);

      // Transition to in_progress
      await taskService.updateTaskStatus('t-state', 'in_progress');
      list = await taskService.getTasks(statusFilter: 'in_progress');
      expect(list.length, 1);
      expect(list.first.isInProgress, true);

      // Transition to completed
      await taskService.updateTaskStatus('t-state', 'completed');
      list = await taskService.getTasks(statusFilter: 'completed');
      expect(list.length, 1);
      expect(list.first.isCompleted, true);

      // Update due date
      final targetDue = DateTime.now().add(const Duration(days: 2)).millisecondsSinceEpoch;
      await taskService.updateTaskDueDate('t-state', targetDue);
      final updated = (await taskService.getTasks()).first;
      expect(updated.dueDate, targetDue);
    });
  });
}
