import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ollivo/controllers/chat_controller.dart';
import 'package:ollivo/controllers/model_controller.dart';
import 'package:ollivo/services/database_service.dart';
import 'package:ollivo/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 3 Desktop Power & Model Management Tests', () {
    test('MOD-001: VRAM & Unified Memory guidance classification', () {
      // Byte size < 2GB -> 8GB RAM Comfortable
      final smallGuidance = ModelController.getMemoryGuidance(sizeBytes: 1500 * 1024 * 1024);
      expect(smallGuidance.minRamGb, 8);
      expect(smallGuidance.label, contains('8GB RAM'));

      // Byte size 2GB - 5GB -> 8GB - 16GB RAM Recommended
      final midGuidance = ModelController.getMemoryGuidance(sizeBytes: 4500 * 1024 * 1024);
      expect(midGuidance.minRamGb, 16);
      expect(midGuidance.label, contains('16GB RAM'));

      // Byte size > 5GB -> 24GB+ RAM Required
      final largeGuidance = ModelController.getMemoryGuidance(sizeBytes: 8500 * 1024 * 1024);
      expect(largeGuidance.minRamGb, 24);
      expect(largeGuidance.label, contains('24GB+'));

      // Size string parsing
      final mbGuidance = ModelController.getMemoryGuidance(sizeString: '980 MB');
      expect(mbGuidance.minRamGb, 8);

      final gbMidGuidance = ModelController.getMemoryGuidance(sizeString: '4.7 GB');
      expect(gbMidGuidance.minRamGb, 16);

      final gbLargeGuidance = ModelController.getMemoryGuidance(sizeString: '9.2 GB');
      expect(gbLargeGuidance.minRamGb, 24);

      // Model ID tag parameter heuristics
      final tag1b = ModelController.getMemoryGuidance(modelId: 'llama3.2:1b');
      expect(tag1b.minRamGb, 8);

      final tag7b = ModelController.getMemoryGuidance(modelId: 'qwen2.5-coder:7b');
      expect(tag7b.minRamGb, 16);

      final tag14b = ModelController.getMemoryGuidance(modelId: 'deepseek-r1:14b');
      expect(tag14b.minRamGb, 24);
    });

    test('MOD-003: Custom Model Tag validation rules', () {
      // Valid tags
      expect(ModelController.validateCustomTag('llama3.2:1b'), isNull);
      expect(ModelController.validateCustomTag('deepseek-r1:1.5b'), isNull);
      expect(ModelController.validateCustomTag('mistral:7b'), isNull);
      expect(ModelController.validateCustomTag('hf.co/bartowski/Llama-3.2-1B-Instruct-GGUF'), isNull);

      // Invalid tags
      expect(ModelController.validateCustomTag(''), isNotNull);
      expect(ModelController.validateCustomTag('   '), isNotNull);
      expect(ModelController.validateCustomTag('llama 3.2:1b'), contains('whitespace'));
      expect(ModelController.validateCustomTag('model!@#\$%'), contains('invalid'));
    });

    test('MAC-004: Window and desktop state restoration across launches', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsService();
      await settings.init(
        testPrefs: prefs,
        testAppSupportPath: Directory.systemTemp.path,
      );

      // Default state
      expect(settings.lastSelectedTab, 0);
      expect(settings.sidebarVisible, isTrue);

      // Set custom desktop state
      await settings.setLastSelectedTab(4); // Model library
      await settings.setSidebarVisible(false); // Collapsed sidebar

      expect(settings.lastSelectedTab, 4);
      expect(settings.sidebarVisible, isFalse);

      // Verify persistence in SharedPreferences
      expect(prefs.getInt('desktop_last_selected_tab'), 4);
      expect(prefs.getBool('desktop_sidebar_visible'), false);

      // Verify state restoration in fresh SettingsService instance
      final reloadedSettings = SettingsService();
      await reloadedSettings.init(
        testPrefs: prefs,
        testAppSupportPath: Directory.systemTemp.path,
      );
      expect(reloadedSettings.lastSelectedTab, 4);
      expect(reloadedSettings.sidebarVisible, isFalse);
    });

    test('MAC-001: ChatController.addCompletedExchange injects Quick Ask exchange', () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final inMemoryDb = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('CREATE TABLE conversations (id TEXT PRIMARY KEY, title TEXT NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL);');
          await db.execute('CREATE TABLE messages (id TEXT PRIMARY KEY, conversation_id TEXT NOT NULL, role TEXT NOT NULL, content TEXT NOT NULL, is_memory_saved INTEGER DEFAULT 0, created_at INTEGER NOT NULL);');
        },
      );
      final localDbService = DatabaseService();
      await localDbService.init(testDatabase: inMemoryDb);

      final chatController = ChatController(dbService: localDbService);
      await chatController.loadConversations();
      final initialCount = chatController.messages.length;

      await chatController.addCompletedExchange(
        'What is an Apple Silicon Neural Engine?',
        'The Apple Neural Engine (ANE) is an on-die hardware accelerator for ML inference.',
      );

      expect(chatController.messages.length, initialCount + 2);
      expect(chatController.messages[initialCount]['role'], 'user');
      expect(chatController.messages[initialCount]['content'], 'What is an Apple Silicon Neural Engine?');
      expect(chatController.messages[initialCount + 1]['role'], 'assistant');
      expect(chatController.messages[initialCount + 1]['content'], contains('Apple Neural Engine'));

      await localDbService.close();
    });
  });
}
