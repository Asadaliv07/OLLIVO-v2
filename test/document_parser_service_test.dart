import 'package:flutter_test/flutter_test.dart';
import 'package:ollivo/services/document_parser_service.dart';

void main() {
  group('DocumentParserService Layout-Aware Extraction & Chunking Tests', () {
    late DocumentParserService parser;

    setUp(() {
      parser = DocumentParserService();
    });

    test('Parses Markdown headings, paragraphs, code blocks, and tables', () {
      const sampleMarkdown = '''
# Technical Architecture

This document describes the modular local AI architecture of Ollivo.

```dart
void main() {
  runApp(const OllivoApp());
}
```

| Component | Status | Latency |
|---|---|---|
| LlamaCpp | Active | 12ms |
| FasterWhisper | Active | 45ms |

### Security Measures

All processing occurs strictly on-device without telemetry.
''';

      final doc = parser.parseMarkdown(sampleMarkdown, filename: 'architecture.md');

      expect(doc.filename, equals('architecture.md'));
      expect(doc.characterCount, equals(sampleMarkdown.length));

      // Validate extracted elements
      expect(doc.elements.isNotEmpty, isTrue);

      // Check headings
      final headings = doc.headings;
      expect(headings.length, greaterThanOrEqualTo(2));
      expect(headings.any((h) => h.content.contains('Technical Architecture')), isTrue);
      expect(headings.any((h) => h.content.contains('Security Measures')), isTrue);

      // Check code block
      final codeBlocks = doc.elements.where((e) => e.type == DocumentElementType.codeBlock).toList();
      expect(codeBlocks.length, equals(1));
      expect(codeBlocks.first.content, contains('OllivoApp()'));

      // Check table
      final tables = doc.tables;
      expect(tables.length, equals(1));
      expect(tables.first.content, contains('FasterWhisper'));
    });

    test('Chunks parsed document with boundary preservation and citations', () {
      const longText = '''
# Section 1: Overview
Ollivo is a 100% local-first macOS desktop AI workspace engineered for Apple Silicon.
It provides zero-cloud inference, on-device document extraction, unified vector search,
and multimodal interactions.

# Section 2: Hardware Acceleration
Utilizing Metal and unified memory architecture, models run with low latency and high energy efficiency.
Quantization formats like GGUF Q4_K_M and Q8_0 provide optimal tradeoffs between perplexity and VRAM consumption.

# Section 3: Guardrails and Privacy
NeMo-inspired multi-layered input and output guardrails protect against prompt injection,
PII leakage, and unauthorized terminal execution.
''';

      final doc = parser.parseMarkdown(longText, filename: 'ollivo_manual.md');
      final chunks = parser.chunkDocument(doc, chunkSize: 120, chunkOverlap: 20);

      expect(chunks.length, greaterThan(1));
      expect(chunks.first.filename, equals('ollivo_manual.md'));
      expect(chunks.first.chunkIndex, equals(0));
      expect(chunks.first.text.isNotEmpty, isTrue);
      expect(chunks.first.citationTag, equals('[Document: ollivo_manual.md (Chunk #1)]'));

      // Check subsequent chunk indexing
      expect(chunks[1].chunkIndex, equals(1));
      expect(chunks[1].citationTag, equals('[Document: ollivo_manual.md (Chunk #2)]'));
    });

    test('Handles empty markdown content gracefully', () {
      final doc = parser.parseMarkdown('', filename: 'empty.md');
      expect(doc.elements, isEmpty);
      expect(doc.characterCount, equals(0));

      final chunks = parser.chunkDocument(doc);
      expect(chunks, isEmpty);
    });
  });
}
