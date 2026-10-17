import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../core/constants.dart';
import '../models/model_configuration.dart';
import 'audit_service.dart';

/// Local SQLite Database Helper & Migration Service
class DatabaseService {
  Database? _db;

  Database get database {
    if (_db == null) {
      throw StateError('Database not initialized. Call DatabaseService.init() first.');
    }
    return _db!;
  }

  /// Initialize SQLite database and run migrations
  Future<void> init({Database? testDatabase}) async {
    if (testDatabase != null) {
      _db = testDatabase;
      return;
    }

    if (_db != null) return;

    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, AppConstants.databaseName);

    _db = await openDatabase(
      path,
      version: AppConstants.databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  /// Database Schema Initialization
  Future<void> _onCreate(Database db, int version) async {
    // 1. Conversations Table
    await db.execute('''
      CREATE TABLE conversations (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');

    // 2. Messages Table
    await db.execute('''
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

    // 3. Fact Memories Table
    await db.execute('''
      CREATE TABLE memories (
        id TEXT PRIMARY KEY,
        fact TEXT NOT NULL,
        category TEXT DEFAULT 'general',
        created_at INTEGER NOT NULL
      );
    ''');

    // 4. Documents Table
    await db.execute('''
      CREATE TABLE documents (
        id TEXT PRIMARY KEY,
        filename TEXT NOT NULL,
        file_path TEXT NOT NULL,
        file_size INTEGER NOT NULL,
        chunk_count INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      );
    ''');

    // 5. Tasks Table
    await db.execute('''
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

    // 6. Model Configurations Table (MOD-CFG-001)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS model_configurations (
        model_id TEXT PRIMARY KEY,
        backend TEXT NOT NULL DEFAULT 'ollama',
        config_version INTEGER NOT NULL DEFAULT 1,
        updated_at INTEGER NOT NULL,
        temperature REAL,
        top_p REAL,
        top_k INTEGER,
        min_p REAL,
        typical_p REAL,
        repeat_penalty REAL,
        repeat_last_n INTEGER,
        presence_penalty REAL,
        frequency_penalty REAL,
        max_tokens INTEGER,
        stop_sequences TEXT,
        seed INTEGER,
        mirostat INTEGER,
        mirostat_tau REAL,
        mirostat_eta REAL,
        json_output_mode INTEGER,
        context_length INTEGER,
        keep_alive TEXT,
        history_limit INTEGER,
        rag_enabled INTEGER,
        retrieved_doc_count INTEGER,
        similarity_threshold REAL,
        embedding_model_override TEXT,
        reranker_model_override TEXT,
        system_prompt TEXT,
        prompt_template_id TEXT,
        num_threads INTEGER,
        num_gpu_layers INTEGER,
        f16_kv INTEGER,
        flash_attention INTEGER
      );
    ''');

    // Indexes
    await db.execute('CREATE INDEX idx_messages_conversation_id ON messages(conversation_id);');
    await db.execute('CREATE INDEX idx_tasks_status ON tasks(status);');
    await db.execute('CREATE INDEX idx_memories_category ON memories(category);');
  }

  /// Non-destructive schema migration handler
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS model_configurations (
          model_id TEXT PRIMARY KEY,
          backend TEXT NOT NULL DEFAULT 'ollama',
          config_version INTEGER NOT NULL DEFAULT 1,
          updated_at INTEGER NOT NULL,
          temperature REAL,
          top_p REAL,
          top_k INTEGER,
          min_p REAL,
          typical_p REAL,
          repeat_penalty REAL,
          repeat_last_n INTEGER,
          presence_penalty REAL,
          frequency_penalty REAL,
          max_tokens INTEGER,
          stop_sequences TEXT,
          seed INTEGER,
          mirostat INTEGER,
          mirostat_tau REAL,
          mirostat_eta REAL,
          json_output_mode INTEGER,
          context_length INTEGER,
          keep_alive TEXT,
          history_limit INTEGER,
          rag_enabled INTEGER,
          retrieved_doc_count INTEGER,
          similarity_threshold REAL,
          embedding_model_override TEXT,
          reranker_model_override TEXT,
          system_prompt TEXT,
          prompt_template_id TEXT,
          num_threads INTEGER,
          num_gpu_layers INTEGER,
          f16_kv INTEGER,
          flash_attention INTEGER
        );
      ''');
    }
  }

  /// Close database connection
  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }

  /// Factory Reset - Clear All Local Sandbox Data
  Future<void> clearAllData() async {
    final db = database;
    await db.transaction((txn) async {
      await txn.delete('messages');
      await txn.delete('conversations');
      await txn.delete('memories');
      await txn.delete('documents');
      await txn.delete('tasks');
      await txn.delete('model_configurations');
    });
  }

  /// Get approximate database size in bytes (SET-003)
  Future<int> getDatabaseSizeBytes() async {
    final db = database;
    final pageCountRes = await db.rawQuery('PRAGMA page_count;');
    final pageSizeRes = await db.rawQuery('PRAGMA page_size;');
    final pageCount = Sqflite.firstIntValue(pageCountRes) ?? 0;
    final pageSize = Sqflite.firstIntValue(pageSizeRes) ?? 4096;
    return pageCount * pageSize;
  }

  /// Get record counts across all core tables (SET-003)
  Future<Map<String, int>> getTableCounts() async {
    final db = database;
    final tables = ['conversations', 'messages', 'memories', 'documents', 'tasks', 'model_configurations'];
    final counts = <String, int>{};

    for (final table in tables) {
      try {
        final res = await db.rawQuery('SELECT COUNT(*) FROM $table;');
        counts[table] = Sqflite.firstIntValue(res) ?? 0;
      } catch (_) {
        counts[table] = 0;
      }
    }

    return counts;
  }

  /// Perform SQLite VACUUM optimization (SET-003)
  Future<void> vacuum() async {
    final db = database;
    await db.execute('VACUUM;');
    AuditService.instance.log(
      'vacuum_executed',
      'SQLite database VACUUM executed; unallocated pages defragmented and storage reclaimed.',
    );
  }

  /// Check Database Integrity (PRAGMA integrity_check)
  Future<List<String>> checkIntegrity() async {
    final db = database;
    final res = await db.rawQuery('PRAGMA integrity_check;');
    return res.map((r) => r.values.first.toString()).toList();
  }

  /// Save or update a ModelConfiguration (MOD-CFG-001)
  Future<void> saveModelConfiguration(ModelConfiguration config) async {
    final db = database;
    await db.insert(
      'model_configurations',
      config.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get ModelConfiguration by modelId
  Future<ModelConfiguration?> getModelConfiguration(String modelId) async {
    final db = database;
    final results = await db.query(
      'model_configurations',
      where: 'model_id = ?',
      whereArgs: [modelId],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return ModelConfiguration.fromMap(results.first);
  }

  /// Fetch all saved ModelConfigurations
  Future<List<ModelConfiguration>> getAllModelConfigurations() async {
    final db = database;
    final results = await db.query('model_configurations', orderBy: 'updated_at DESC');
    return results.map((m) => ModelConfiguration.fromMap(m)).toList();
  }

  /// Delete ModelConfiguration
  Future<bool> deleteModelConfiguration(String modelId) async {
    final db = database;
    final deleted = await db.delete(
      'model_configurations',
      where: 'model_id = ?',
      whereArgs: [modelId],
    );
    return deleted > 0;
  }
}
