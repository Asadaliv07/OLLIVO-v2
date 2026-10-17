import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ollivo/components/markdown_view.dart';
import 'package:ollivo/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 2 Markdown & Code Highlighting Tests (CORE-001, CORE-002, CORE-003)', () {
    testWidgets('Renders fenced code block with language badge and line numbers (CORE-001)', (WidgetTester tester) async {
      const sampleMarkdown = '''
Here is a Dart example:
```dart
import 'package:flutter/material.dart';

void main() {
  print("Hello Ollivo");
}
```
''';

      await tester.pumpWidget(
        MaterialApp(
          theme: OllivoTheme.darkTheme,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: RichMarkdownView(markdown: sampleMarkdown),
            ),
          ),
        ),
      );

      // Verify text and language badge
      expect(find.text('Here is a Dart example:'), findsOneWidget);
      expect(find.text('DART'), findsOneWidget);
      expect(find.text('5 lines'), findsOneWidget);
      expect(find.text('Copy Code'), findsOneWidget);
    });

    testWidgets('One-click Copy Code button triggers clipboard and shows visual feedback (CORE-003)', (WidgetTester tester) async {
      String? copiedClipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            copiedClipboardText = (methodCall.arguments as Map)['text'] as String?;
            return null;
          }
          return null;
        },
      );

      const codeSample = 'final x = 42;\nreturn x;';

      await tester.pumpWidget(
        MaterialApp(
          theme: OllivoTheme.darkTheme,
          home: const Scaffold(
            body: CodeBlockWidget(
              code: codeSample,
              language: 'dart',
            ),
          ),
        ),
      );

      expect(find.text('Copy Code'), findsOneWidget);
      expect(find.byIcon(Icons.copy_rounded), findsOneWidget);

      // Tap Copy Code button
      await tester.tap(find.text('Copy Code'));
      await tester.pump();

      // Verify clipboard received code
      expect(copiedClipboardText, codeSample);

      // Verify visual feedback state
      expect(find.text('Copied!'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

      // Fast-forward past 2-second timer
      await tester.pump(const Duration(seconds: 3));

      // Verify reverts back
      expect(find.text('Copy Code'), findsOneWidget);
      expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
    });

    testWidgets('Renders block math and inline math with LaTeX formatting (CORE-002)', (WidgetTester tester) async {
      const mathMarkdown = '''
Consider Euler's identity:
\$\$e^{i\\pi} + 1 = 0\$\$
And inline equation: \$x^2 + y^2 = r^2\$.
''';

      await tester.pumpWidget(
        MaterialApp(
          theme: OllivoTheme.darkTheme,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: RichMarkdownView(markdown: mathMarkdown),
            ),
          ),
        ),
      );

      expect(find.text('MATH FORMULA'), findsOneWidget);
      expect(find.text('Copy LaTeX'), findsOneWidget);
      expect(find.byType(MathBlockWidget), findsOneWidget);
    });

    testWidgets('Renders headings, bullet lists, blockquotes, and inline code', (WidgetTester tester) async {
      const richContent = '''
# Master Heading
## Section Two
> Local first AI architecture
- First Item
- Second Item
1. Step One
2. Step Two
Use the `AppConstants` class for configurations.
''';

      await tester.pumpWidget(
        MaterialApp(
          theme: OllivoTheme.darkTheme,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: RichMarkdownView(markdown: richContent),
            ),
          ),
        ),
      );

      expect(find.text('Master Heading'), findsOneWidget);
      expect(find.text('Section Two'), findsOneWidget);
      expect(find.text('Local first AI architecture'), findsOneWidget);
      expect(find.text('First Item'), findsOneWidget);
      expect(find.text('Second Item'), findsOneWidget);
      expect(find.text('Step One'), findsOneWidget);
      expect(find.text('Step Two'), findsOneWidget);
      expect(find.text('AppConstants'), findsOneWidget);
    });
  });
}
