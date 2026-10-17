import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ollivo/components/privacy_seal_dialog.dart';
import 'package:ollivo/components/shortcuts_sheet_dialog.dart';
import 'package:ollivo/controllers/model_controller.dart';
import 'package:ollivo/services/ai_service.dart';
import 'package:ollivo/services/audit_service.dart';
import 'package:ollivo/services/database_service.dart';
import 'package:ollivo/services/settings_service.dart';
import 'package:ollivo/views/settings/settings_view.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Phase 6: Privacy Hardening, Audit Logs & Desktop Release Tests', () {
    late AuditService auditService;
    late SettingsService settingsService;
    late AIService aiService;
    late DatabaseService dbService;

    setUp(() async {
      auditService = AuditService.isolated();

      SharedPreferences.setMockInitialValues({
        'theme_mode': 'dark',
        'ollama_host': 'http://127.0.0.1:11434',
        'active_model': 'qwen2.5-coder:1.5b',
      });
      final prefs = await SharedPreferences.getInstance();
      settingsService = SettingsService();
      await settingsService.init(
        testPrefs: prefs,
        testAppSupportPath: Directory.systemTemp.path,
      );

      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/api/version')) {
          return http.Response('{"version": "0.40.2"}', 200);
        } else if (request.url.path.endsWith('/api/tags')) {
          return http.Response('{"models": [{"name": "qwen2.5-coder:1.5b", "size": 980000000}]}', 200);
        }
        return http.Response('{"response": "Local response"}', 200);
      });
      aiService = AIService(client: mockClient);
      dbService = DatabaseService();
    });

    test('SEC-001: AuditService logs local operations and enforces zero telemetry', () {
      // 1. Initial boot entry
      expect(auditService.totalLocalActions, 1);
      expect(auditService.entries.first.action, 'system_init');
      expect(auditService.totalRemoteTelemetryBytes, 0);
      expect(auditService.isZeroLeakVerified, isTrue);

      // 2. Log local events
      auditService.log('query', 'Local AI model inference executed for prompt of length 42');
      auditService.log('document_read', 'Retrieved 2 document chunks via cosine similarity');
      auditService.log('memory_write', 'Saved personal memory fact to local SQLite table');

      expect(auditService.totalLocalActions, 4);
      final latest = auditService.entries.first;
      expect(latest.action, 'memory_write');
      expect(latest.isLocalOnly, isTrue);
      expect(latest.telemetryBytesSent, 0);
      expect(latest.endpoint, contains('127.0.0.1'));

      // 3. JSON verification report export
      final jsonReport = auditService.exportAsJson();
      expect(jsonReport, contains('ollivo_audit_manifest'));
      expect(jsonReport, contains('"air_gapped_verified": true'));
      expect(jsonReport, contains('"cloud_telemetry_bytes": 0'));

      final parsed = jsonDecode(jsonReport) as Map<String, dynamic>;
      final manifest = parsed['ollivo_audit_manifest'] as Map<String, dynamic>;
      expect(manifest['air_gapped_verified'], isTrue);
      expect(manifest['cloud_telemetry_bytes'], 0);
      expect(manifest['total_actions_recorded'], 4);

      // 4. CSV report export
      final csvReport = auditService.exportAsCsv();
      expect(csvReport, contains('ID,Timestamp,Action,Details,IsLocalOnly,TelemetryBytesSent,Endpoint'));
      expect(csvReport, contains('memory_write'));
      expect(csvReport, contains('true,0'));

      // 5. Clear log history
      auditService.clearLogs();
      expect(auditService.totalLocalActions, 1);
      expect(auditService.entries.first.action, 'audit_cleared');
      expect(auditService.entries.first.isLocalOnly, isTrue);
    });

    test('SEC-001: AuditLogEntry JSON serialization and roundtrip integrity', () {
      final now = DateTime.now();
      final original = AuditLogEntry(
        id: 'test_123',
        timestamp: now,
        action: 'vacuum_executed',
        details: 'SQLite vacuum completed successfully',
        isLocalOnly: true,
        telemetryBytesSent: 0,
        endpoint: '127.0.0.1 (Localhost)',
      );

      final map = original.toMap();
      expect(map['id'], 'test_123');
      expect(map['action'], 'vacuum_executed');
      expect(map['is_local_only'], true);
      expect(map['telemetry_bytes_sent'], 0);

      final restored = AuditLogEntry.fromMap(map);
      expect(restored.id, original.id);
      expect(restored.action, original.action);
      expect(restored.details, original.details);
      expect(restored.isLocalOnly, isTrue);
      expect(restored.telemetryBytesSent, 0);

      final jsonStr = original.toJson();
      final fromJson = AuditLogEntry.fromJson(jsonStr);
      expect(fromJson.id, original.id);
      expect(fromJson.action, original.action);
    });

    testWidgets('SEC-002: PrivacySealDialog renders air-gapped certificate and metrics', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool inspectedAuditLog = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrivacySealDialog(
              onInspectAuditLog: () => inspectedAuditLog = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify certificate titles & live metrics
      expect(find.text('Air-Gapped Privacy Seal'), findsOneWidget);
      expect(find.text('100% On-Device · Zero Cloud Telemetry Verified'), findsOneWidget);
      expect(find.text('0 Bytes (100% Zero Leakage)'), findsOneWidget);
      expect(find.text('SECURITY & AIR-GAP GUARANTEES'), findsOneWidget);
      expect(find.text('Zero Third-Party Telemetry'), findsOneWidget);
      expect(find.text('Local Hardware Execution'), findsOneWidget);
      expect(find.text('Sandboxed SQLite Storage'), findsOneWidget);

      // Verify actions
      expect(find.text('Inspect Audit Log'), findsOneWidget);
      expect(find.text('Copy Proof'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);

      // Tap Inspect Audit Log
      await tester.tap(find.text('Inspect Audit Log'));
      await tester.pumpAndSettle();
      expect(inspectedAuditLog, isTrue);
    });

    testWidgets('UI-001: ShortcutsSheetDialog renders categories and supports live search filtering', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShortcutsSheetDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header
      expect(find.text('Keyboard Shortcuts'), findsOneWidget);
      expect(find.text('Press ⌘/ anytime to toggle this quick reference sheet'), findsOneWidget);

      // Verify Initial Category & Shortcut
      expect(find.text('NAVIGATION'), findsOneWidget);
      expect(find.text('AI Assistant Chat'), findsOneWidget);

      // Test Search Filtering: filter for 'Spotlight'
      await tester.enterText(find.byType(TextField), 'Spotlight');
      await tester.pumpAndSettle();

      expect(find.text('Spotlight Quick Ask'), findsOneWidget);
      expect(find.text('AI Assistant Chat'), findsNothing);

      // Clear search
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();

      expect(find.text('AI Assistant Chat'), findsOneWidget);
    });

    testWidgets('SEC-001 & UI-002: SettingsView renders Local Privacy & Security Audit Log card in Advanced tab', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final modelController = ModelController(
        aiService: aiService,
        settingsService: settingsService,
      );

      // Add a known audit log entry
      AuditService.instance.log('test_action', 'Verification event for Phase 6 settings UI');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsView(
              settingsService: settingsService,
              modelController: modelController,
              aiService: aiService,
              databaseService: dbService,
              initialDbSizeBytes: 10240,
              initialTableCounts: const {'messages': 10, 'conversations': 2},
              initialTabIndex: 4,
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify Audit Log card is rendered
      expect(find.text('Local Privacy & Security Audit Log'), findsOneWidget);
      expect(find.text('Zero cloud telemetry verification · 100% on-device ledger'), findsOneWidget);
      expect(find.text('100% Air-Gapped'), findsOneWidget);
      expect(find.text('0 Bytes Outbound Telemetry'), findsOneWidget);
      expect(find.text('Copy JSON Report'), findsOneWidget);
      expect(find.text('Clear Log'), findsOneWidget);
    });
  });
}
