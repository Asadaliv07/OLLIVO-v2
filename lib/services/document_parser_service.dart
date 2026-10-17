import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Semantic structural element in an ingested document
enum DocumentElementType {
  heading,
  paragraph,
  table,
  codeBlock,
  listItem,
}

/// Parsed structural element
class ParsedDocumentElement {
  final DocumentElementType type;
  final String content;
  final Map<String, dynamic> metadata;

  const ParsedDocumentElement({
    required this.type,
    required this.content,
    this.metadata = const {},
  });

  Map<String, dynamic> toMap() => {
        'type': type.name,
        'content': content,
        'metadata': metadata,
      };
}

/// Structured document extracted from PDF, DOCX, or Markdown (Docling/Unstructured pattern)
class ParsedDocument {
  final String filename;
  final String fullMarkdown;
  final List<ParsedDocumentElement> elements;
  final int characterCount;
  final Map<String, dynamic> metadata;

  const ParsedDocument({
    required this.filename,
    required this.fullMarkdown,
    required this.elements,
    required this.characterCount,
    this.metadata = const {},
  });

  List<ParsedDocumentElement> get tables =>
      elements.where((e) => e.type == DocumentElementType.table).toList();

  List<ParsedDocumentElement> get headings =>
      elements.where((e) => e.type == DocumentElementType.heading).toList();
}

/// Ingestion chunk ready for vector embedding
class DocumentChunk {
  final String filename;
  final int chunkIndex;
  final String text;
  final int startOffset;
  final int endOffset;
  final Map<String, dynamic> metadata;

  const DocumentChunk({
    required this.filename,
    required this.chunkIndex,
    required this.text,
    required this.startOffset,
    required this.endOffset,
    this.metadata = const {},
  });

  Map<String, dynamic> toMap() => {
        'filename': filename,
        'chunkIndex': chunkIndex,
        'text': text,
        'startOffset': startOffset,
        'endOffset': endOffset,
        'metadata': metadata,
      };

  String get citationTag => '[Document: $filename (Chunk #${chunkIndex + 1})]';
}

/// Document Parsing and Layout-Aware Extraction Service (Docling & Unstructured inspired)
class DocumentParserService extends ChangeNotifier {
  static final DocumentParserService _instance = DocumentParserService._internal();
  factory DocumentParserService({http.Client? client}) {
    if (client != null) _instance._client = client;
    return _instance;
  }
  DocumentParserService._internal() : _client = http.Client();

  http.Client _client;
  String _serviceEndpoint = 'http://127.0.0.1:8765';

  http.Client get client => _client;
  String get serviceEndpoint => _serviceEndpoint;

  void configure({String? endpoint}) {
    if (endpoint != null && endpoint.isNotEmpty) _serviceEndpoint = endpoint;
    notifyListeners();
  }

  /// Parses Markdown content, identifying headings, code blocks, tables, and paragraphs
  ParsedDocument parseMarkdown(String markdownContent, {String filename = 'document.md'}) {
    final lines = markdownContent.split('\n');
    final List<ParsedDocumentElement> elements = [];

    bool inCodeBlock = false;
    final StringBuffer codeBuffer = StringBuffer();
    bool inTable = false;
    final List<String> tableLines = [];
    final StringBuffer paragraphBuffer = StringBuffer();

    void flushParagraph() {
      final text = paragraphBuffer.toString().trim();
      if (text.isNotEmpty) {
        elements.add(ParsedDocumentElement(
          type: DocumentElementType.paragraph,
          content: text,
        ));
        paragraphBuffer.clear();
      }
    }

    void flushTable() {
      if (tableLines.isNotEmpty) {
        elements.add(ParsedDocumentElement(
          type: DocumentElementType.table,
          content: tableLines.join('\n'),
          metadata: {'rows': tableLines.length},
        ));
        tableLines.clear();
        inTable = false;
      }
    }

    for (final line in lines) {
      final trimmed = line.trim();

      // Code blocks
      if (trimmed.startsWith('```')) {
        if (inCodeBlock) {
          elements.add(ParsedDocumentElement(
            type: DocumentElementType.codeBlock,
            content: codeBuffer.toString().trim(),
          ));
          codeBuffer.clear();
          inCodeBlock = false;
        } else {
          flushParagraph();
          flushTable();
          inCodeBlock = true;
        }
        continue;
      }

      if (inCodeBlock) {
        codeBuffer.writeln(line);
        continue;
      }

      // Tables (pipes)
      if (trimmed.startsWith('|') && trimmed.endsWith('|')) {
        flushParagraph();
        inTable = true;
        tableLines.add(line);
        continue;
      } else if (inTable) {
        flushTable();
      }

      // Headings
      if (trimmed.startsWith('#')) {
        flushParagraph();
        final level = trimmed.indexOf(' ');
        final headingText = level > 0 ? trimmed.substring(level).trim() : trimmed;
        elements.add(ParsedDocumentElement(
          type: DocumentElementType.heading,
          content: headingText,
          metadata: {'level': level > 0 ? level : 1},
        ));
        continue;
      }

      // List items
      if (trimmed.startsWith('- ') || trimmed.startsWith('* ') || RegExp(r'^\d+\.\s').hasMatch(trimmed)) {
        flushParagraph();
        elements.add(ParsedDocumentElement(
          type: DocumentElementType.listItem,
          content: trimmed,
        ));
        continue;
      }

      // Normal paragraph text
      if (trimmed.isEmpty) {
        flushParagraph();
      } else {
        paragraphBuffer.writeln(line);
      }
    }

    flushParagraph();
    flushTable();

    return ParsedDocument(
      filename: filename,
      fullMarkdown: markdownContent,
      elements: elements,
      characterCount: markdownContent.length,
    );
  }

  /// Splits parsed document into overlapping chunks preserving structural coherence
  List<DocumentChunk> chunkDocument(
    ParsedDocument doc, {
    int chunkSize = 512,
    int chunkOverlap = 64,
  }) {
    final text = doc.fullMarkdown;
    if (text.isEmpty) return [];

    final List<DocumentChunk> chunks = [];
    int start = 0;
    int chunkIndex = 0;

    while (start < text.length) {
      int end = start + chunkSize;
      if (end >= text.length) {
        end = text.length;
      } else {
        // Try to break on paragraph or sentence boundary
        final nextNewline = text.indexOf('\n\n', end - 50);
        if (nextNewline != -1 && nextNewline < end + 50) {
          end = nextNewline;
        } else {
          final nextSpace = text.indexOf(' ', end);
          if (nextSpace != -1 && nextSpace < end + 30) {
            end = nextSpace;
          }
        }
      }

      final chunkText = text.substring(start, end).trim();
      if (chunkText.isNotEmpty) {
        chunks.add(DocumentChunk(
          filename: doc.filename,
          chunkIndex: chunkIndex++,
          text: chunkText,
          startOffset: start,
          endOffset: end,
        ));
      }

      if (end >= text.length) break;
      start = (end - chunkOverlap).clamp(start + 1, text.length);
    }

    return chunks;
  }
}
