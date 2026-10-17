import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ollivo/services/backup_service.dart';
import 'package:ollivo/services/database_service.dart';
import 'package:ollivo/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('BackupService (SET-002) Tests', () {
    late DatabaseService dbService;
    late SettingsService settingsService;
    late BackupService backupService;
    late Directory tempDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'theme_mode': 'dark',
        'ollama_host': 'http://127.0.0.1:11434',
        'active_model': 'llama3.2:latest',
        'chat_temperature': 0.7,
      });

      tempDir = Directory.systemTemp.createTempSync('ollivo_backup_test_');

      dbService = DatabaseService();
      final inMemoryDb = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE conversations (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            );
          ''');
          await db.execute('''
            CREATE TABLE messages (
              id TEXT PRIMARY KEY,
              conversation_id TEXT NOT NULL,
              role TEXT NOT NULL,
              content TEXT NOT NULL,
              is_memory_saved INTEGER DEFAULT 0,
              created_at INTEGER NOT NULL,
              FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
            );
          ''');
          await db.execute('''
            CREATE TABLE memories (
              id TEXT PRIMARY KEY,
              fact TEXT NOT NULL,
              category TEXT DEFAULT 'general',
              created_at INTEGER NOT NULL
            );
          ''');
          await db.execute('''
            CREATE TABLE documents (
              id TEXT PRIMARY KEY,
              file_name TEXT NOT NULL,
              file_path TEXT NOT NULL,
              file_size INTEGER NOT NULL,
              extracted_text TEXT,
              created_at INTEGER NOT NULL
            );
          ''');
          await db.execute('''
            CREATE TABLE tasks (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              description TEXT,
              status TEXT DEFAULT 'todo',
              priority TEXT DEFAULT 'medium',
              due_date INTEGER,
              created_at INTEGER NOT NULL
            );
          ''');
        },
      );
      await dbService.init(testDatabase: inMemoryDb);

      settingsService = SettingsService();
      await settingsService.init();

      backupService = BackupService(
        dbService: dbService,
        settingsService: settingsService,
      );

      // Populate test data
      final db = dbService.database;
      await db.insert('conversations', {
        'id': 'conv-101',
        'title': 'Test Backup Conversation',
        'created_at': 1700000000,
        'updated_at': 1700000000,
      });
      await db.insert('messages', {
        'id': 'msg-1',
        'conversation_id': 'conv-101',
        'role': 'user',
        'content': 'Hello from backup test!',
        'is_memory_saved': 0,
        'created_at': 1700000010,
      });
      await db.insert('memories', {
        'id': 'mem-1',
        'fact': 'User prefers dark mode and local LLMs',
        'category': 'preferences',
        'created_at': 1700000020,
      });
      await db.insert('tasks', {
        'id': 'task-1',
        'title': 'Review Ollivo roadmap',
        'description': 'Check Phase 1 deliverables',
        'status': 'todo',
        'priority': 'high',
        'due_date': 1700090000,
        'created_at': 1700000030,
      });
    });

    tearDown(() async {
      await dbService.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('Creates atomic .ollivobackup archive with SHA-256 manifest', () async {
      final result = await backupService.createBackup(
        targetDirectory: tempDir.path,
        customFileName: 'test_backup.ollivobackup',
      );

      expect(result.success, isTrue);
      expect(result.filePath, isNotNull);
      expect(File(result.filePath!).existsSync(), isTrue);
      expect(result.manifest, isNotNull);

      final manifest = result.manifest!;
      expect(manifest.app, 'Ollivo');
      expect(manifest.version, 1);
      expect(manifest.checksum.length, 64); // SHA-256 hex string length
      expect(manifest.tableCounts['conversations'], 1);
      expect(manifest.tableCounts['messages'], 1);
      expect(manifest.tableCounts['memories'], 1);
      expect(manifest.tableCounts['tasks'], 1);
      expect(manifest.totalRecords, 4);
    });

    test('Validates archive integrity and rejects corrupted payload', () async {
      // 1. Create valid archive
      final result = await backupService.createBackup(
        targetDirectory: tempDir.path,
        customFileName: 'valid_test.ollivobackup',
      );
      final file = File(result.filePath!);

      // Validate valid archive
      final validation = await backupService.validateBackup(file);
      expect(validation.isValid, isTrue);
      expect(validation.manifest, isNotNull);
      expect(validation.data, isNotNull);
      expect(validation.settings?['themeMode'], 'dark');

      // 2. Corrupt archive bytes (tampered file)
      final corruptedFile = File('${tempDir.path}/corrupted.ollivobackup');
      final validBytes = file.readAsBytesSync();
      // Replace some compressed bytes to break checksum/gzip
      validBytes[validBytes.length - 20] = 0xFF;
      validBytes[validBytes.length - 21] = 0xAA;
      corruptedFile.writeAsBytesSync(validBytes);

      final corruptValidation = await backupService.validateBackup(corruptedFile);
      expect(corruptValidation.isValid, isFalse);
      expect(corruptValidation.error, isNotNull);
    });

    test('Restores database atomically from valid backup archive', () async {
      // 1. Create backup of current state
      final backupResult = await backupService.createBackup(
        targetDirectory: tempDir.path,
        customFileName: 'restore_test.ollivobackup',
      );
      final file = File(backupResult.filePath!);

      // 2. Mutate active database (clear or alter)
      final db = dbService.database;
      await db.delete('messages');
      await db.delete('conversations');
      await db.delete('memories');
      await db.delete('tasks');

      // Add a rogue conversation that shouldn't exist after restore
      await db.insert('conversations', {
        'id': 'conv-rogue',
        'title': 'Rogue Conv',
        'created_at': 999,
        'updated_at': 999,
      });

      var activeConvs = await db.query('conversations');
      expect(activeConvs.length, 1);
      expect(activeConvs.first['id'], 'conv-rogue');

      // 3. Restore from backup
      final restoreResult = await backupService.restoreBackup(file);
      expect(restoreResult.success, isTrue);
      expect(restoreResult.restoredRecords, 4);

      // 4. Verify original state restored cleanly
      activeConvs = await db.query('conversations');
      expect(activeConvs.length, 1);
      expect(activeConvs.first['id'], 'conv-101');
      expect(activeConvs.first['title'], 'Test Backup Conversation');

      final activeMessages = await db.query('messages');
      expect(activeMessages.length, 1);
      expect(activeMessages.first['content'], 'Hello from backup test!');

      final activeMemories = await db.query('memories');
      expect(activeMemories.length, 1);
      expect(activeMemories.first['fact'], 'User prefers dark mode and local LLMs');
    });

    test('Fails restore gracefully without destroying data on invalid file', () async {
      final dummyFile = File('${tempDir.path}/garbage.ollivobackup');
      dummyFile.writeAsStringSync('not a valid gzip or json archive');

      final db = dbService.database;
      final restoreResult = await backupService.restoreBackup(dummyFile);

      expect(restoreResult.success, isFalse);
      expect(restoreResult.message, contains('Restoration cancelled'));

      // Existing data is untouched
      final convs = await db.query('conversations');
      expect(convs.length, 1);
      expect(convs.first['id'], 'conv-101');
    });
  });
}
