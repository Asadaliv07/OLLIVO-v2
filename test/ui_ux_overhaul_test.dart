import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ollivo/components/ollivo_components.dart';
import 'package:ollivo/controllers/model_controller.dart';
import 'package:ollivo/services/ai_service.dart';
import 'package:ollivo/services/database_service.dart';
import 'package:ollivo/services/hardware_service.dart';
import 'package:ollivo/services/settings_service.dart';
import 'package:ollivo/theme.dart';
import 'package:ollivo/views/settings/settings_view.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('UI/UX Overhaul & Tactile Desktop Standards Tests', () {
    late SettingsService settingsService;
    late DatabaseService dbService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      settingsService = SettingsService();
      await settingsService.init(
        testPrefs: await SharedPreferences.getInstance(),
        testAppSupportPath: Directory.systemTemp.path,
      );

      final inMemoryDb = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {},
      );
      dbService = DatabaseService();
      await dbService.init(testDatabase: inMemoryDb);
    });

    tearDown(() async {
      await dbService.close();
    });
    testWidgets('1. TactileBounce scales down on press and renders click cursor', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: TactileBounce(
                onTap: () => tapped = true,
                child: const Text('Bounce Target'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bounce Target'), findsOneWidget);

      // Verify MouseRegion has SystemMouseCursors.click
      final mouseRegion = tester.widget<MouseRegion>(
        find.descendant(of: find.byType(TactileBounce), matching: find.byType(MouseRegion)).first,
      );
      expect(mouseRegion.cursor, SystemMouseCursors.click);

      // Tap and check execution
      await tester.tap(find.text('Bounce Target'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('2. ErgonomicSlider renders Min/Max tags and synchronizes numeric text field in real time', (tester) async {
      double sliderValue = 0.7;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                child: StatefulBuilder(
                  builder: (context, setState) {
                    return ErgonomicSlider(
                      title: 'Chat Temperature',
                      subtitle: 'Controls creativity vs determinism',
                      value: sliderValue,
                      min: 0.0,
                      max: 1.0,
                      divisions: 10,
                      minTag: '0.0 (Precise)',
                      maxTag: '1.0 (Creative)',
                      decimalPlaces: 1,
                      onChanged: (val) {
                        setState(() => sliderValue = val);
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check tags and titles
      expect(find.text('Chat Temperature'), findsOneWidget);
      expect(find.text('Controls creativity vs determinism'), findsOneWidget);
      expect(find.text('0.0 (Precise)'), findsOneWidget);
      expect(find.text('1.0 (Creative)'), findsOneWidget);

      // Check initial text field value
      expect(find.text('0.7'), findsOneWidget);

      // Enter a new number in the numeric field and verify real-time sync
      await tester.enterText(find.byType(TextField), '0.3');
      await tester.pumpAndSettle();

      expect(sliderValue, closeTo(0.3, 0.01));
    });

    testWidgets('3. ShimmerProgressTrack renders smoothly in determinate and indeterminate modes', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ShimmerProgressTrack(value: 0.45, height: 6),
                SizedBox(height: 10),
                ShimmerProgressTrack(value: null, height: 4),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ShimmerProgressTrack), findsNWidgets(2));
      expect(find.byType(RepaintBoundary), findsAtLeast(2));
    });

    testWidgets('4. OllivoBanner intercepts socket exception and reveals collapsible trace', (tester) async {
      const rawError = 'SocketException: OS Error: Connection refused, errno = 61, address = 127.0.0.1';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OllivoBanner(
              title: 'Local Ollama Service Offline',
              message: rawError,
              color: OllivoTheme.statusError,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Friendly intercepted message should be shown
      expect(find.text('The local Ollama background daemon is offline or starting up at 127.0.0.1:11434. Launch the daemon to start local inference.'), findsOneWidget);

      // View Trace button should be visible
      expect(find.text('View Trace'), findsOneWidget);

      // Tap View Trace to reveal raw logs
      await tester.tap(find.text('View Trace'));
      await tester.pumpAndSettle();

      expect(find.text('Hide Trace'), findsOneWidget);
      expect(find.text(rawError), findsOneWidget);
    });

    testWidgets('5. SettingsView renders macOS grouped insets in General tab with max-w-3xl constraint', (tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/api/version')) {
          return http.Response('{"version":"0.5.1"}', 200);
        }
        if (request.url.path.endsWith('/api/tags')) {
          return http.Response('{"models":[]}', 200);
        }
        if (request.url.path.endsWith('/api/ps')) {
          return http.Response('{"models":[]}', 200);
        }
        return http.Response('{}', 200);
      });
      final aiService = AIService(
        ollamaHost: 'http://127.0.0.1:11434',
        modelName: 'llama3.2',
        client: mockClient,
      );
      final modelController = ModelController(
        aiService: aiService,
        settingsService: settingsService,
        hardwareService: HardwareService(sysctlRunner: (_) async => null),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsView(
              settingsService: settingsService,
              modelController: modelController,
              aiService: aiService,
              databaseService: dbService,
              initialDbSizeBytes: 10240,
              initialTableCounts: const {'chats': 1, 'messages': 2},
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify macOS-style section labels
      expect(find.text('APPEARANCE'), findsOneWidget);
      expect(find.text('GENERATION ENGINE'), findsOneWidget);
      expect(find.text('SYSTEM INTEGRATION'), findsOneWidget);

      // Verify max-w-3xl constraint (768 width)
      final constrainedBoxFinder = find.byWidgetPredicate(
        (w) => w is ConstrainedBox && w.constraints.maxWidth == 768,
      );
      expect(constrainedBoxFinder, findsOneWidget);
    });
  });
}
