import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'audit_service.dart';
import 'database_service.dart';
import 'settings_service.dart';

/// Manifest metadata stored inside an Ollivo backup archive
class BackupManifest {
  final int version;
  final String app;
  final String appVersion;
  final int createdAt;
  final Map<String, int> tableCounts;
  final String checksum;

  const BackupManifest({
    required this.version,
    required this.app,
    required this.appVersion,
    required this.createdAt,
    required this.tableCounts,
    required this.checksum,
  });

  Map<String, dynamic> toMap() => {
        'version': version,
        'app': app,
        'appVersion': appVersion,
        'createdAt': createdAt,
        'tableCounts': tableCounts,
        'checksum': checksum,
      };

  factory BackupManifest.fromMap(Map<String, dynamic> map) {
    final countsRaw = map['tableCounts'] as Map<String, dynamic>? ?? {};
    final counts = countsRaw.map((k, v) => MapEntry(k, v as int? ?? 0));

    return BackupManifest(
      version: map['version'] as int? ?? 1,
      app: map['app'] as String? ?? 'Ollivo',
      appVersion: map['appVersion'] as String? ?? '1.0.0',
      createdAt: map['createdAt'] as int? ?? 0,
      tableCounts: counts,
      checksum: map['checksum'] as String? ?? '',
    );
  }

  int get totalRecords => tableCounts.values.fold(0, (sum, count) => sum + count);
}

/// Result of backup operation
class BackupResult {
  final bool success;
  final String? filePath;
  final BackupManifest? manifest;
  final String message;

  const BackupResult({
    required this.success,
    this.filePath,
    this.manifest,
    required this.message,
  });
}

/// Result of pre-restore backup validation
class BackupValidationResult {
  final bool isValid;
  final BackupManifest? manifest;
  final Map<String, dynamic>? data;
  final Map<String, dynamic>? settings;
  final String? error;

  const BackupValidationResult({
    required this.isValid,
    this.manifest,
    this.data,
    this.settings,
    this.error,
  });
}

/// Result of restore operation
class RestoreResult {
  final bool success;
  final int restoredRecords;
  final String message;

  const RestoreResult({
    required this.success,
    this.restoredRecords = 0,
    required this.message,
  });
}

/// Safe, Atomic Backup and Restore Service (SET-002)
/// Format: GZip-compressed JSON with SHA-256 integrity verification
/// Note: Unencrypted archive.
class BackupService {
  final DatabaseService _dbService;
  final SettingsService _settingsService;

  BackupService({
    DatabaseService? dbService,
    SettingsService? settingsService,
  })  : _dbService = dbService ?? DatabaseService(),
        _settingsService = settingsService ?? SettingsService();

  static const List<String> supportedTables = [
    'conversations',
    'messages',
    'memories',
    'documents',
    'tasks',
  ];

  /// Generate a timestamped backup archive file
  Future<BackupResult> createBackup({
    String? targetDirectory,
    String? customFileName,
  }) async {
    try {
      final db = _dbService.database;

      // 1. Gather all database records in a consistent read
      final Map<String, List<Map<String, dynamic>>> dataPayload = {};
      final Map<String, int> tableCounts = {};

      for (final table in supportedTables) {
        final records = await db.query(table);
        dataPayload[table] = records;
        tableCounts[table] = records.length;
      }

      // 2. Gather application settings
      final settingsPayload = {
        'themeMode': _settingsService.themeMode,
        'ollamaHost': _settingsService.ollamaHost,
        'activeModel': _settingsService.activeModel,
        'chatTemperature': _settingsService.chatTemperature,
        'launchAtLogin': _settingsService.launchAtLogin,
      };

      // 3. Calculate payload SHA-256 checksum
      final payloadJson = jsonEncode(dataPayload);
      final checksum = sha256.convert(utf8.encode(payloadJson)).toString();

      final manifest = BackupManifest(
        version: 1,
        app: 'Ollivo',
        appVersion: '1.0.0',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        tableCounts: tableCounts,
        checksum: checksum,
      );

      final fullArchiveMap = {
        'manifest': manifest.toMap(),
        'settings': settingsPayload,
        'payload': dataPayload,
      };

      final fullArchiveJson = jsonEncode(fullArchiveMap);
      final compressedBytes = GZipCodec().encode(utf8.encode(fullArchiveJson));

      // 4. Determine destination path
      final outDir = targetDirectory ?? _settingsService.backupsPath;
      final dir = Directory(outDir);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      final fileName = customFileName ??
          'ollivo_backup_${DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first}.ollivobackup';
      final finalPath = p.join(outDir, fileName);

      // 5. Write to a temporary file first for atomic creation
      final tempPath = '$finalPath.tmp';
      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(compressedBytes, flush: true);

      // Rename atomically to target file
      await tempFile.rename(finalPath);

      // 6. Validate the created archive immediately to guarantee zero silent corruption
      final valResult = await validateBackup(File(finalPath));
      if (!valResult.isValid) {
        await File(finalPath).delete();
        return BackupResult(
          success: false,
          message: 'Post-backup integrity validation failed: ${valResult.error}',
        );
      }

      AuditService.instance.log(
        'backup_created',
        'Created local archive with ${manifest.totalRecords} records (SHA-256 verified): ${p.basename(finalPath)}',
      );

      return BackupResult(
        success: true,
        filePath: finalPath,
        manifest: manifest,
        message: 'Backup created successfully (${manifest.totalRecords} records, SHA-256 verified).',
      );
    } catch (e) {
      return BackupResult(
        success: false,
        message: 'Failed to create backup: $e',
      );
    }
  }

  /// Inspect and validate a backup archive file before attempting restoration
  Future<BackupValidationResult> validateBackup(File backupFile) async {
    if (!backupFile.existsSync()) {
      return const BackupValidationResult(
        isValid: false,
        error: 'Backup file does not exist on disk.',
      );
    }

    try {
      final compressedBytes = await backupFile.readAsBytes();
      if (compressedBytes.isEmpty) {
        return const BackupValidationResult(
          isValid: false,
          error: 'Backup file is empty.',
        );
      }

      // 1. Attempt GZip decompression
      List<int> decompressed;
      try {
        decompressed = GZipCodec().decode(compressedBytes);
      } catch (e) {
        return const BackupValidationResult(
          isValid: false,
          error: 'Archive decompression failed. File may be corrupted or not an Ollivo backup.',
        );
      }

      // 2. Parse JSON archive envelope
      final jsonString = utf8.decode(decompressed);
      final dynamic decoded = jsonDecode(jsonString);

      if (decoded is! Map<String, dynamic>) {
        return const BackupValidationResult(
          isValid: false,
          error: 'Invalid archive structure: root must be a JSON object.',
        );
      }

      final manifestRaw = decoded['manifest'];
      if (manifestRaw is! Map<String, dynamic>) {
        return const BackupValidationResult(
          isValid: false,
          error: 'Missing manifest header in backup archive.',
        );
      }

      final manifest = BackupManifest.fromMap(manifestRaw);
      if (manifest.app != 'Ollivo') {
        return BackupValidationResult(
          isValid: false,
          error: 'Incompatible application identifier "${manifest.app}". Expected "Ollivo".',
        );
      }

      if (manifest.version > 1) {
        return BackupValidationResult(
          isValid: false,
          error: 'Backup version ${manifest.version} is not supported by this version of Ollivo.',
        );
      }

      final dataRaw = decoded['payload'];
      if (dataRaw is! Map<String, dynamic>) {
        return const BackupValidationResult(
          isValid: false,
          error: 'Missing data payload in backup archive.',
        );
      }

      // 3. Verify SHA-256 checksum integrity
      final payloadJson = jsonEncode(dataRaw);
      final calculatedChecksum = sha256.convert(utf8.encode(payloadJson)).toString();

      if (manifest.checksum.isNotEmpty && calculatedChecksum != manifest.checksum) {
        return const BackupValidationResult(
          isValid: false,
          error: 'SHA-256 checksum mismatch! The backup payload appears damaged or tampered with.',
        );
      }

      final settingsRaw = decoded['settings'] as Map<String, dynamic>?;

      return BackupValidationResult(
        isValid: true,
        manifest: manifest,
        data: dataRaw,
        settings: settingsRaw,
      );
    } catch (e) {
      return BackupValidationResult(
        isValid: false,
        error: 'Failed to read or parse backup file: $e',
      );
    }
  }

  /// Restore user database and preferences from a validated backup archive
  /// Uses SQLite atomic transaction: any failure rolls back cleanly without data loss!
  Future<RestoreResult> restoreBackup(File backupFile) async {
    // Step 1: Pre-validation
    final validation = await validateBackup(backupFile);
    if (!validation.isValid || validation.data == null) {
      return RestoreResult(
        success: false,
        message: 'Restoration cancelled: ${validation.error ?? "Invalid archive."}',
      );
    }

    final data = validation.data!;
    final manifest = validation.manifest!;
    final db = _dbService.database;

    try {
      int insertedCount = 0;

      // Step 2: Atomic SQLite Transaction
      await db.transaction((txn) async {
        // Clear existing tables in child-to-parent order to respect foreign key constraints
        await txn.delete('messages');
        await txn.delete('conversations');
        await txn.delete('memories');
        await txn.delete('documents');
        await txn.delete('tasks');

        // Repopulate parent tables first
        if (data.containsKey('conversations')) {
          final list = data['conversations'] as List<dynamic>? ?? [];
          for (final item in list) {
            await txn.insert('conversations', Map<String, dynamic>.from(item as Map),
                conflictAlgorithm: ConflictAlgorithm.replace);
            insertedCount++;
          }
        }

        // Repopulate messages
        if (data.containsKey('messages')) {
          final list = data['messages'] as List<dynamic>? ?? [];
          for (final item in list) {
            await txn.insert('messages', Map<String, dynamic>.from(item as Map),
                conflictAlgorithm: ConflictAlgorithm.replace);
            insertedCount++;
          }
        }

        // Repopulate memories
        if (data.containsKey('memories')) {
          final list = data['memories'] as List<dynamic>? ?? [];
          for (final item in list) {
            await txn.insert('memories', Map<String, dynamic>.from(item as Map),
                conflictAlgorithm: ConflictAlgorithm.replace);
            insertedCount++;
          }
        }

        // Repopulate documents
        if (data.containsKey('documents')) {
          final list = data['documents'] as List<dynamic>? ?? [];
          for (final item in list) {
            await txn.insert('documents', Map<String, dynamic>.from(item as Map),
                conflictAlgorithm: ConflictAlgorithm.replace);
            insertedCount++;
          }
        }

        // Repopulate tasks
        if (data.containsKey('tasks')) {
          final list = data['tasks'] as List<dynamic>? ?? [];
          for (final item in list) {
            await txn.insert('tasks', Map<String, dynamic>.from(item as Map),
                conflictAlgorithm: ConflictAlgorithm.replace);
            insertedCount++;
          }
        }
      });

      // Step 3: Restore settings if present
      if (validation.settings != null) {
        final s = validation.settings!;
        if (s['themeMode'] is String) await _settingsService.setThemeMode(s['themeMode'] as String);
        if (s['ollamaHost'] is String) await _settingsService.setOllamaHost(s['ollamaHost'] as String);
        if (s['activeModel'] is String) await _settingsService.setActiveModel(s['activeModel'] as String);
        if (s['chatTemperature'] is double) {
          await _settingsService.setChatTemperature(s['chatTemperature'] as double);
        }
      }

      AuditService.instance.log(
        'backup_restored',
        'Successfully restored $insertedCount records from local backup archive into SQLite',
      );

      return RestoreResult(
        success: true,
        restoredRecords: insertedCount,
        message: 'Successfully restored $insertedCount records from backup created on '
            '${DateTime.fromMillisecondsSinceEpoch(manifest.createdAt).toLocal().toString().split('.').first}.',
      );
    } catch (e) {
      return RestoreResult(
        success: false,
        message: 'Restoration failed and was rolled back safely: $e',
      );
    }
  }
}
