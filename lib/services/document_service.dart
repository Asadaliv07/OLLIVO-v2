import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../core/constants.dart';
import 'ai_service.dart';
import 'database_service.dart';
import 'vector_store_service.dart';

/// Metadata for an indexed document in Ollivo
class DocumentItem {
  final String id;
  final String filename;
  final String filePath;
  final int fileSize;
  final int chunkCount;
  final int createdAt;

  DocumentItem({
    required this.id,
    required this.filename,
    required this.filePath,
    required this.fileSize,
    required this.chunkCount,
    required this.createdAt,
  });

  factory DocumentItem.fromMap(Map<String, dynamic> map) {
    return DocumentItem(
      id: map['id'] as String,
      filename: map['filename'] as String,
      filePath: map['file_path'] as String,
      fileSize: map['file_size'] as int? ?? 0,
      chunkCount: map['chunk_count'] as int? ?? 0,
      createdAt: map['created_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'filename': filename,
      'file_path': filePath,
      'file_size': fileSize,
      'chunk_count': chunkCount,
      'created_at': createdAt,
    };
  }

  String get formattedSize {
    if (fileSize <= 0) return '0 B';
    final double kb = fileSize / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final double mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }
}

/// An individual indexed text chunk with optional dense embedding (DOC-001)
class DocumentChunk {
  final String docId;
  final String filename;
  final String text;
  final int chunkIndex;
  List<double>? embedding;

  DocumentChunk({
    required this.docId,
    required this.filename,
    required this.text,
    this.chunkIndex = 0,
    this.embedding,
  });
}

/// Result of hybrid RAG retrieval with citation relevance scores (DOC-003)
class RetrievedChunk {
  final DocumentChunk chunk;
  final double score;
  final int keywordMatches;
  final double? vectorSimilarity;

  RetrievedChunk({
    required this.chunk,
    required this.score,
    required this.keywordMatches,
    this.vectorSimilarity,
  });

  String get citationLabel => '[Document: ${chunk.filename} (Chunk #${chunk.chunkIndex + 1})]';
  String get formattedScore => '${(score * 100).toInt()}% match';

  Map<String, dynamic> toMap() {
    return {
      'docId': chunk.docId,
      'filename': chunk.filename,
      'chunkIndex': chunk.chunkIndex,
      'text': chunk.text,
      'score': score,
      'keywordMatches': keywordMatches,
      'vectorSimilarity': vectorSimilarity,
      'citationLabel': citationLabel,
      'formattedScore': formattedScore,
    };
  }

  factory RetrievedChunk.fromMap(Map<String, dynamic> map) {
    return RetrievedChunk(
      chunk: DocumentChunk(
        docId: map['docId'] as String? ?? '',
        filename: map['filename'] as String? ?? '',
        chunkIndex: map['chunkIndex'] as int? ?? 0,
        text: map['text'] as String? ?? '',
      ),
      score: (map['score'] as num?)?.toDouble() ?? 0.0,
      keywordMatches: map['keywordMatches'] as int? ?? 0,
      vectorSimilarity: (map['vectorSimilarity'] as num?)?.toDouble(),
    );
  }
}

/// Core Local Document Processing & Hybrid RAG Retrieval Engine (DOC-001, DOC-002, DOC-003)
class DocumentService {
  final DatabaseService _dbService;
  final AIService? _aiService;
  final VectorStoreService? _vectorStore;

  // In-memory document chunk index
  final List<DocumentChunk> _indexedChunks = [];

  DocumentService({
    DatabaseService? dbService,
    this._aiService,
    this._vectorStore,
  }) : _dbService = dbService ?? DatabaseService();

  VectorStoreService? get vectorStore => _vectorStore;

  List<DocumentChunk> get indexedChunks => List.unmodifiable(_indexedChunks);

  /// Get indexed chunks for a specific document (DOC-002)
  List<DocumentChunk> getChunksForDocument(String docId) {
    return _indexedChunks.where((c) => c.docId == docId).toList();
  }

  /// Native Multi-Format Text Extractor supporting PDF, Markdown, Plain Text & Source Code (DOC-002)
  static Future<String> extractTextFromFile(File file) async {
    final extension = p.extension(file.path).toLowerCase();
    if (extension == '.pdf') {
      return extractTextFromPdf(file);
    }

    try {
      final raw = await file.readAsString(encoding: utf8);
      return AppConstants.sanitizeText(raw);
    } catch (_) {
      // Fallback with lossy decoding for non-standard encodings
      final bytes = await file.readAsBytes();
      final decoded = utf8.decode(bytes, allowMalformed: true);
      return AppConstants.sanitizeText(decoded);
    }
  }

  /// Pure Native Dart PDF Text Stream Parser (Zero C-Bindings / Third-Party Native Dependencies)
  static Future<String> extractTextFromPdf(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final buffer = StringBuffer();

      // Find all PDF streams
      final streamPattern = RegExp(r'stream\r?\n([\s\S]*?)\r?\nendstream');
      final latin1String = latin1.decode(bytes);

      for (final match in streamPattern.allMatches(latin1String)) {
        final streamContent = match.group(1);
        if (streamContent == null || streamContent.isEmpty) continue;

        List<int> decompressedBytes = [];
        try {
          // Attempt FlateDecode (zlib decompress)
          final streamBytes = latin1.encode(streamContent);
          decompressedBytes = zlib.decode(streamBytes);
        } catch (_) {
          // If not zlib compressed or fails, use raw stream bytes
          decompressedBytes = latin1.encode(streamContent);
        }

        final decodedText = latin1.decode(decompressedBytes);

        // Extract text operator sequences: (text) Tj, 'text', [(t1)...(t2)] TJ
        final tjPattern = RegExp(r'\((.*?)\)\s*Tj');
        for (final m in tjPattern.allMatches(decodedText)) {
          final t = _unescapePdfString(m.group(1) ?? '');
          if (t.trim().isNotEmpty) buffer.write('$t ');
        }

        final arrayTjPattern = RegExp(r'\[(.*?)\]\s*TJ');
        for (final m in arrayTjPattern.allMatches(decodedText)) {
          final inside = m.group(1) ?? '';
          final strInside = RegExp(r'\((.*?)\)');
          for (final sm in strInside.allMatches(inside)) {
            final t = _unescapePdfString(sm.group(1) ?? '');
            if (t.trim().isNotEmpty) buffer.write('$t ');
          }
        }
      }

      final extracted = buffer.toString().trim();
      if (extracted.isNotEmpty) {
        return AppConstants.sanitizeText(extracted);
      }

      // Fallback: If structure operators were missing, extract readable ASCII runs
      final readableRuns = RegExp(r"""[A-Za-z0-9 .,;:!?"'-]{4,}""");
      final fallbackMatches = readableRuns.allMatches(latin1String).map((m) => m.group(0)).join(' ');
      return AppConstants.sanitizeText(fallbackMatches);
    } catch (_) {
      return '';
    }
  }

  static String _unescapePdfString(String input) {
    return input
        .replaceAll(r'\(', '(')
        .replaceAll(r'\)', ')')
        .replaceAll(r'\\', r'\')
        .replaceAll(r'\r', '\n')
        .replaceAll(r'\n', '\n');
  }

  /// Semantic Sliding-Window Text Chunking with Overlap (DOC-002)
  static List<String> chunkText(String text, {int chunkSize = 400, int chunkOverlap = 80}) {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return [];

    // If text has natural paragraph breaks, preserve them as semantic chunks if within size
    final paragraphs = cleaned.split(RegExp(r'\n\s*\n')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (paragraphs.length > 1 && paragraphs.every((p) => p.length <= chunkSize)) {
      return paragraphs;
    }

    if (cleaned.length <= chunkSize) return [cleaned];

    final List<String> chunks = [];
    int start = 0;

    while (start < cleaned.length) {
      int end = math.min(start + chunkSize, cleaned.length);

      // Attempt to break at natural boundary (newline, period, exclamation, question mark, or space)
      if (end < cleaned.length) {
        int bestBreak = -1;
        for (int i = end; i > start + (chunkSize ~/ 2); i--) {
          final char = cleaned[i - 1];
          if (char == '\n' || char == '.' || char == '!' || char == '?') {
            bestBreak = i;
            break;
          }
        }
        if (bestBreak != -1) {
          end = bestBreak;
        } else {
          // Fallback to word boundary
          final spaceIndex = cleaned.lastIndexOf(' ', end);
          if (spaceIndex > start + (chunkSize ~/ 2)) {
            end = spaceIndex + 1;
          }
        }
      }

      final chunkContent = cleaned.substring(start, end).trim();
      if (chunkContent.isNotEmpty) {
        chunks.add(chunkContent);
      }

      if (end >= cleaned.length) break;

      // Advance start with overlap
      final nextStart = end - chunkOverlap;
      start = nextStart > start ? nextStart : end;
    }

    return chunks;
  }

  /// Cosine Similarity calculation between two dense embedding vectors
  static double cosineSimilarity(List<double> v1, List<double> v2) {
    if (v1.length != v2.length || v1.isEmpty) return 0.0;

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < v1.length; i++) {
      dotProduct += v1[i] * v2[i];
      normA += v1[i] * v1[i];
      normB += v2[i] * v2[i];
    }

    if (normA <= 0.0 || normB <= 0.0) return 0.0;
    return (dotProduct / (math.sqrt(normA) * math.sqrt(normB))).clamp(0.0, 1.0);
  }

  /// Read, parse, chunk, and index document into database & RAG index (DOC-001, DOC-002)
  Future<DocumentItem> importAndIndexDocument(
    String sourcePath,
    String targetDirectory, {
    String? embeddingModel,
    String? customHost,
  }) async {
    final file = File(sourcePath);
    if (!await file.exists()) {
      throw FileSystemException('Source file does not exist', sourcePath);
    }

    final filename = p.basename(sourcePath);
    final fileSize = await file.length();
    final sanitizedText = await extractTextFromFile(file);

    // Copy to sandbox documents directory if not already there
    final validTargetDir = targetDirectory.trim().isNotEmpty
        ? targetDirectory
        : p.dirname(sourcePath);
    final destDir = Directory(validTargetDir);
    if (!await destDir.exists()) {
      await destDir.create(recursive: true);
    }
    final destPath = p.join(destDir.path, filename);
    if (p.canonicalize(file.path) != p.canonicalize(destPath)) {
      try {
        await file.copy(destPath);
      } catch (_) {
        // Fallback: If copy is restricted, read bytes and write
        final bytes = await file.readAsBytes();
        await File(destPath).writeAsBytes(bytes);
      }
    }

    // Chunk text using semantic sliding-window chunking
    final chunkTexts = chunkText(sanitizedText);
    final chunkCount = chunkTexts.isEmpty ? 1 : chunkTexts.length;
    final docId = 'doc-${DateTime.now().millisecondsSinceEpoch}';

    final docItem = DocumentItem(
      id: docId,
      filename: filename,
      filePath: destPath,
      fileSize: fileSize,
      chunkCount: chunkCount,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    // Persist in SQLite
    final db = _dbService.database;

    // Purge any existing document with same file_path to prevent stale or duplicate chunks
    final existingDocs = await db.query(
      'documents',
      where: 'file_path = ?',
      whereArgs: [destPath],
    );
    for (final existing in existingDocs) {
      final oldId = existing['id'] as String;
      if (_vectorStore != null) {
        final chunkIds = _indexedChunks
            .where((c) => c.docId == oldId)
            .map((c) => '${c.docId}_${c.chunkIndex}')
            .toList();
        final oldCount = existing['chunk_count'] as int? ?? 0;
        final allOldIds = chunkIds.isNotEmpty
            ? chunkIds
            : List.generate(oldCount, (i) => '${oldId}_$i');
        if (allOldIds.isNotEmpty) {
          try {
            await _vectorStore.delete('documents', allOldIds);
          } catch (_) {}
        }
      }
      _indexedChunks.removeWhere((c) => c.docId == oldId);
      await db.delete('documents', where: 'id = ?', whereArgs: [oldId]);
    }

    await db.insert('documents', docItem.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

    // Populate in-memory chunk index
    final List<DocumentChunk> newChunks = [];
    if (chunkTexts.isEmpty) {
      newChunks.add(DocumentChunk(docId: docId, filename: filename, text: sanitizedText, chunkIndex: 0));
    } else {
      for (int i = 0; i < chunkTexts.length; i++) {
        newChunks.add(DocumentChunk(
          docId: docId,
          filename: filename,
          text: chunkTexts[i],
          chunkIndex: i,
        ));
      }
    }

    // Generate local vector embeddings if AIService is available (DOC-001)
    if (_aiService != null && newChunks.isNotEmpty) {
      for (final chunk in newChunks.take(15)) { // Embed up to first 15 chunks immediately
        try {
          final vector = await _aiService.generateEmbedding(
            chunk.text,
            customHost: customHost,
            customModel: embeddingModel,
          );
          if (vector != null) {
            chunk.embedding = vector;
          }
        } catch (_) {}
      }
    }

    if (_vectorStore != null) {
      final vectorDocs = newChunks
          .where((c) => c.embedding != null)
          .map((c) => VectorDocument(
                id: '${c.docId}_${c.chunkIndex}',
                vector: c.embedding!,
                text: c.text,
                metadata: {'docId': c.docId, 'filename': c.filename, 'chunkIndex': c.chunkIndex},
              ))
          .toList();
      if (vectorDocs.isNotEmpty) {
        try {
          await _vectorStore.upsert('documents', vectorDocs);
        } catch (_) {}
      }
    }

    _indexedChunks.addAll(newChunks);
    return docItem;
  }

  /// Import and index a document directly from raw bytes (supports web, sandboxed picker, and drag-and-drop)
  Future<DocumentItem> importAndIndexDocumentFromBytes(
    String filename,
    List<int> bytes,
    String targetDirectory, {
    String? embeddingModel,
    String? customHost,
  }) async {
    final validTargetDir = targetDirectory.trim().isNotEmpty
        ? targetDirectory
        : Directory.systemTemp.path;
    final destDir = Directory(validTargetDir);
    if (!await destDir.exists()) {
      await destDir.create(recursive: true);
    }
    final destPath = p.join(destDir.path, filename);
    final file = File(destPath);
    await file.writeAsBytes(bytes);

    return importAndIndexDocument(
      destPath,
      targetDirectory,
      embeddingModel: embeddingModel,
      customHost: customHost,
    );
  }

  /// Get list of indexed documents
  Future<List<DocumentItem>> getDocuments() async {
    final db = _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query('documents', orderBy: 'created_at DESC');
    return maps.map((m) => DocumentItem.fromMap(m)).toList();
  }

  /// Retrieve relevant chunks with detailed citation metrics (DOC-001, DOC-003)
  Future<List<RetrievedChunk>> retrieveDetailed(
    String userQuery, {
    int maxResults = 3,
    String? embeddingModel,
    String? customHost,
    double? minSimilarity,
  }) async {
    if (_indexedChunks.isEmpty || userQuery.trim().isEmpty) return [];

    final queryWords = userQuery.toLowerCase().split(RegExp(r'\s+')).where((w) => w.length > 2).toSet();

    // Generate vector embedding for user query if AIService is available
    List<double>? queryVector;
    if (_aiService != null) {
      try {
        queryVector = await _aiService.generateEmbedding(
          userQuery,
          customHost: customHost,
          customModel: embeddingModel,
        );
      } catch (_) {}
    }

    final List<RetrievedChunk> results = [];
    final double threshold = minSimilarity ?? 0.05;

    for (final chunk in _indexedChunks) {
      final chunkLower = chunk.text.toLowerCase();
      int kwMatches = 0;
      for (final word in queryWords) {
        if (chunkLower.contains(word)) {
          kwMatches++;
        }
      }

      final double kwScore = queryWords.isNotEmpty ? (kwMatches / queryWords.length).clamp(0.0, 1.0) : 0.0;

      double? vecSim;
      if (queryVector != null && chunk.embedding != null) {
        vecSim = cosineSimilarity(queryVector, chunk.embedding!);
      }

      // Hybrid score weighting (40% keyword + 60% semantic vector, or pure keyword if no vector)
      double combinedScore;
      if (vecSim != null) {
        combinedScore = (kwScore * 0.4) + (vecSim * 0.6);
      } else {
        combinedScore = kwScore;
      }

      if (combinedScore >= threshold || kwMatches > 0) {
        results.add(RetrievedChunk(
          chunk: chunk,
          score: combinedScore,
          keywordMatches: kwMatches,
          vectorSimilarity: vecSim,
        ));
      }
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results.take(maxResults).toList();
  }

  /// Backward-compatible query string retrieval for prompt construction
  List<String> queryRelevantChunks(String userQuery, {int maxResults = 3}) {
    if (_indexedChunks.isEmpty || userQuery.trim().isEmpty) return [];

    final queryWords = userQuery.toLowerCase().split(RegExp(r'\s+')).where((w) => w.length > 2).toSet();
    if (queryWords.isEmpty) return [];

    final List<RetrievedChunk> candidates = [];
    for (final chunk in _indexedChunks) {
      final chunkLower = chunk.text.toLowerCase();
      int matches = 0;
      for (final word in queryWords) {
        if (chunkLower.contains(word)) matches++;
      }
      if (matches > 0) {
        candidates.add(RetrievedChunk(
          chunk: chunk,
          score: matches.toDouble(),
          keywordMatches: matches,
        ));
      }
    }

    candidates.sort((a, b) => b.score.compareTo(a.score));
    return candidates.take(maxResults).map((c) => '[Document: ${c.chunk.filename}]: ${c.chunk.text}').toList();
  }

  /// Delete document and its chunks
  Future<void> deleteDocument(String id) async {
    final db = _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query('documents', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      final docPath = maps.first['file_path'] as String?;
      if (docPath != null) {
        try {
          final f = File(docPath);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
    }
    await db.delete('documents', where: 'id = ?', whereArgs: [id]);

    // Deletion propagation to VectorStoreService
    if (_vectorStore != null) {
      final chunkIds = _indexedChunks
          .where((c) => c.docId == id)
          .map((c) => '${c.docId}_${c.chunkIndex}')
          .toList();
      final chunkCount = maps.isNotEmpty ? (maps.first['chunk_count'] as int? ?? 0) : 0;
      final allChunkIds = chunkIds.isNotEmpty
          ? chunkIds
          : List.generate(chunkCount, (i) => '${id}_$i');
      if (allChunkIds.isNotEmpty) {
        try {
          await _vectorStore.delete('documents', allChunkIds);
        } catch (_) {}
      }
    }

    _indexedChunks.removeWhere((c) => c.docId == id);
  }

  /// Restore and index all persisted documents from SQLite and disk into RAG memory across app restarts
  Future<void> loadPersistedDocuments({
    String? embeddingModel,
    String? customHost,
  }) async {
    try {
      final db = _dbService.database;
      final List<Map<String, dynamic>> maps = await db.query('documents', orderBy: 'created_at ASC');
      for (final map in maps) {
        final doc = DocumentItem.fromMap(map);
        if (_indexedChunks.any((c) => c.docId == doc.id)) continue;

        final file = File(doc.filePath);
        if (await file.exists()) {
          final sanitizedText = await extractTextFromFile(file);
          final chunkTexts = chunkText(sanitizedText);
          final List<DocumentChunk> newChunks = [];
          if (chunkTexts.isEmpty) {
            newChunks.add(DocumentChunk(docId: doc.id, filename: doc.filename, text: sanitizedText, chunkIndex: 0));
          } else {
            for (int i = 0; i < chunkTexts.length; i++) {
              newChunks.add(DocumentChunk(
                docId: doc.id,
                filename: doc.filename,
                text: chunkTexts[i],
                chunkIndex: i,
              ));
            }
          }
          _indexedChunks.addAll(newChunks);
        }
      }
    } catch (_) {}
  }

  /// Re-index an existing document by ID, updating chunks and embeddings without duplicates
  Future<DocumentItem> reindexDocument(
    String id, {
    String? embeddingModel,
    String? customHost,
  }) async {
    final db = _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'documents',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) {
      throw StateError('Document not found with ID "$id"');
    }
    final docItem = DocumentItem.fromMap(maps.first);
    final file = File(docItem.filePath);
    if (!await file.exists()) {
      throw FileSystemException('Document file does not exist on disk', docItem.filePath);
    }

    // 1. Purge previous vector store entries and in-memory chunks
    if (_vectorStore != null) {
      final chunkIds = _indexedChunks
          .where((c) => c.docId == id)
          .map((c) => '${c.docId}_${c.chunkIndex}')
          .toList();
      final allChunkIds = chunkIds.isNotEmpty
          ? chunkIds
          : List.generate(docItem.chunkCount, (i) => '${id}_$i');
      if (allChunkIds.isNotEmpty) {
        try {
          await _vectorStore.delete('documents', allChunkIds);
        } catch (_) {}
      }
    }
    _indexedChunks.removeWhere((c) => c.docId == id);

    // 2. Extract and re-chunk
    final sanitizedText = await extractTextFromFile(file);
    final chunkTexts = chunkText(sanitizedText);
    final chunkCount = chunkTexts.isEmpty ? 1 : chunkTexts.length;

    final updatedDoc = DocumentItem(
      id: id,
      filename: docItem.filename,
      filePath: docItem.filePath,
      fileSize: await file.length(),
      chunkCount: chunkCount,
      createdAt: docItem.createdAt,
    );

    // 3. Update SQLite
    await db.update(
      'documents',
      updatedDoc.toMap(),
      where: 'id = ?',
      whereArgs: [id],
    );

    // 4. Populate new in-memory chunks
    final List<DocumentChunk> newChunks = [];
    if (chunkTexts.isEmpty) {
      newChunks.add(DocumentChunk(docId: id, filename: docItem.filename, text: sanitizedText, chunkIndex: 0));
    } else {
      for (int i = 0; i < chunkTexts.length; i++) {
        newChunks.add(DocumentChunk(
          docId: id,
          filename: docItem.filename,
          text: chunkTexts[i],
          chunkIndex: i,
        ));
      }
    }

    // 5. Compute embeddings if available
    if (_aiService != null && newChunks.isNotEmpty) {
      for (final chunk in newChunks.take(15)) {
        try {
          final vector = await _aiService.generateEmbedding(
            chunk.text,
            customHost: customHost,
            customModel: embeddingModel,
          );
          if (vector != null) {
            chunk.embedding = vector;
          }
        } catch (_) {}
      }
    }

    if (_vectorStore != null) {
      final vectorDocs = newChunks
          .where((c) => c.embedding != null)
          .map((c) => VectorDocument(
                id: '${c.docId}_${c.chunkIndex}',
                vector: c.embedding!,
                text: c.text,
                metadata: {'docId': c.docId, 'filename': c.filename, 'chunkIndex': c.chunkIndex},
              ))
          .toList();
      if (vectorDocs.isNotEmpty) {
        try {
          await _vectorStore.upsert('documents', vectorDocs);
        } catch (_) {}
      }
    }

    _indexedChunks.addAll(newChunks);
    return updatedDoc;
  }
}
