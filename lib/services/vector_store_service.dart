import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Supported vector database backends in Ollivo
enum VectorStoreBackend {
  sqliteVec,
  qdrant,
  chroma,
  inMemoryFaiss,
}

/// A single vectorized document chunk stored in the database
class VectorDocument {
  final String id;
  final List<double> vector;
  final String text;
  final Map<String, dynamic> metadata;

  const VectorDocument({
    required this.id,
    required this.vector,
    required this.text,
    this.metadata = const {},
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'vector': vector,
        'text': text,
        'metadata': metadata,
      };

  factory VectorDocument.fromMap(Map<String, dynamic> map) => VectorDocument(
        id: map['id'] as String,
        vector: (map['vector'] as List).map((e) => (e as num).toDouble()).toList(),
        text: map['text'] as String? ?? '',
        metadata: map['metadata'] as Map<String, dynamic>? ?? {},
      );
}

/// Similarity search query result
class VectorSearchResult {
  final String id;
  final double score;
  final String text;
  final Map<String, dynamic> metadata;

  const VectorSearchResult({
    required this.id,
    required this.score,
    required this.text,
    this.metadata = const {},
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'score': score,
        'text': text,
        'metadata': metadata,
      };

  @override
  String toString() => 'VectorSearchResult($id, score: ${score.toStringAsFixed(4)})';
}

/// Multi-backend Vector Database Service (SQLite-vec, Qdrant, Chroma, In-Memory)
class VectorStoreService extends ChangeNotifier {
  static final VectorStoreService _instance = VectorStoreService._internal();
  factory VectorStoreService({http.Client? client}) {
    if (client != null) _instance._client = client;
    return _instance;
  }
  VectorStoreService._internal() : _client = http.Client();

  http.Client _client;
  VectorStoreBackend _activeBackend = VectorStoreBackend.sqliteVec;
  String _endpointUrl = 'http://127.0.0.1:6333'; // Default Qdrant port

  // In-memory collection storage for sqliteVec / inMemoryFaiss fallback
  final Map<String, Map<String, VectorDocument>> _inMemoryCollections = {};

  VectorStoreBackend get activeBackend => _activeBackend;
  String get endpointUrl => _endpointUrl;

  void configure({required VectorStoreBackend backend, String? endpointUrl}) {
    _activeBackend = backend;
    if (endpointUrl != null && endpointUrl.isNotEmpty) {
      _endpointUrl = endpointUrl;
    }
    notifyListeners();
  }

  /// Calculates cosine similarity between two dense vectors
  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.isEmpty || b.isEmpty || a.length != b.length) return 0.0;
    double dot = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA == 0.0 || normB == 0.0) return 0.0;
    return dot / (math.sqrt(normA) * math.sqrt(normB));
  }

  /// Upsert a batch of documents into the specified collection
  Future<int> upsert(String collection, List<VectorDocument> documents) async {
    if (documents.isEmpty) return 0;

    switch (_activeBackend) {
      case VectorStoreBackend.qdrant:
        return _upsertQdrant(collection, documents);
      case VectorStoreBackend.chroma:
        return _upsertChroma(collection, documents);
      case VectorStoreBackend.sqliteVec:
      case VectorStoreBackend.inMemoryFaiss:
        return _upsertLocal(collection, documents);
    }
  }

  /// Search for nearest documents by cosine similarity
  Future<List<VectorSearchResult>> search(
    String collection,
    List<double> queryVector, {
    int topK = 5,
    double minScore = 0.0,
  }) async {
    if (queryVector.isEmpty) return [];

    switch (_activeBackend) {
      case VectorStoreBackend.qdrant:
        return _searchQdrant(collection, queryVector, topK, minScore);
      case VectorStoreBackend.chroma:
        return _searchChroma(collection, queryVector, topK, minScore);
      case VectorStoreBackend.sqliteVec:
      case VectorStoreBackend.inMemoryFaiss:
        return _searchLocal(collection, queryVector, topK, minScore);
    }
  }

  /// Delete documents by ID
  Future<bool> delete(String collection, List<String> documentIds) async {
    final col = _inMemoryCollections[collection];
    if (col != null) {
      for (final id in documentIds) {
        col.remove(id);
      }
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Count documents in a collection
  Future<int> count(String collection) async {
    return _inMemoryCollections[collection]?.length ?? 0;
  }

  /// Clear an entire collection
  Future<void> clearCollection(String collection) async {
    _inMemoryCollections[collection]?.clear();
    notifyListeners();
  }

  // --- Local / In-Memory Driver ---
  Future<int> _upsertLocal(String collection, List<VectorDocument> documents) async {
    final col = _inMemoryCollections.putIfAbsent(collection, () => {});
    for (final doc in documents) {
      col[doc.id] = doc;
    }
    notifyListeners();
    return documents.length;
  }

  Future<List<VectorSearchResult>> _searchLocal(
    String collection,
    List<double> queryVector,
    int topK,
    double minScore,
  ) async {
    final col = _inMemoryCollections[collection];
    if (col == null || col.isEmpty) return [];

    final List<VectorSearchResult> scored = [];
    for (final doc in col.values) {
      final score = cosineSimilarity(queryVector, doc.vector);
      if (score >= minScore) {
        scored.add(VectorSearchResult(
          id: doc.id,
          score: score,
          text: doc.text,
          metadata: doc.metadata,
        ));
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(topK).toList();
  }

  // --- Qdrant REST API Driver ---
  Future<int> _upsertQdrant(String collection, List<VectorDocument> documents) async {
    try {
      final points = documents.map((d) => {
            'id': d.id,
            'vector': d.vector,
            'payload': {'text': d.text, ...d.metadata},
          }).toList();

      final res = await _client.put(
        Uri.parse('$_endpointUrl/collections/$collection/points'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'points': points}),
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        return documents.length;
      }
    } catch (_) {}
    // Fall back to local storage if Qdrant daemon is offline
    return _upsertLocal(collection, documents);
  }

  Future<List<VectorSearchResult>> _searchQdrant(
    String collection,
    List<double> queryVector,
    int topK,
    double minScore,
  ) async {
    try {
      final res = await _client.post(
        Uri.parse('$_endpointUrl/collections/$collection/points/search'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'vector': queryVector,
          'limit': topK,
          'score_threshold': minScore,
          'with_payload': true,
        }),
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data['result'] is List) {
          final List points = data['result'];
          return points.map((p) {
            final payload = p['payload'] as Map<String, dynamic>? ?? {};
            return VectorSearchResult(
              id: p['id'].toString(),
              score: (p['score'] as num).toDouble(),
              text: payload['text']?.toString() ?? '',
              metadata: payload,
            );
          }).toList();
        }
      }
    } catch (_) {}
    return _searchLocal(collection, queryVector, topK, minScore);
  }

  // --- Chroma REST API Driver ---
  Future<int> _upsertChroma(String collection, List<VectorDocument> documents) async {
    try {
      final res = await _client.post(
        Uri.parse('$_endpointUrl/api/v1/collections/$collection/add'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'ids': documents.map((d) => d.id).toList(),
          'embeddings': documents.map((d) => d.vector).toList(),
          'documents': documents.map((d) => d.text).toList(),
          'metadatas': documents.map((d) => d.metadata).toList(),
        }),
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200 || res.statusCode == 201) {
        return documents.length;
      }
    } catch (_) {}
    return _upsertLocal(collection, documents);
  }

  Future<List<VectorSearchResult>> _searchChroma(
    String collection,
    List<double> queryVector,
    int topK,
    double minScore,
  ) async {
    try {
      final res = await _client.post(
        Uri.parse('$_endpointUrl/api/v1/collections/$collection/query'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'query_embeddings': [queryVector],
          'n_results': topK,
        }),
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data['ids'] is List && (data['ids'] as List).isNotEmpty) {
          final List ids = data['ids'][0];
          final List dists = data['distances']?[0] ?? [];
          final List docs = data['documents']?[0] ?? [];
          final List metas = data['metadatas']?[0] ?? [];

          final List<VectorSearchResult> results = [];
          for (int i = 0; i < ids.length; i++) {
            final dist = (i < dists.length) ? (dists[i] as num).toDouble() : 0.0;
            final score = 1.0 - dist; // Convert distance to similarity
            if (score >= minScore) {
              results.add(VectorSearchResult(
                id: ids[i].toString(),
                score: score,
                text: (i < docs.length) ? docs[i]?.toString() ?? '' : '',
                metadata: (i < metas.length && metas[i] is Map) ? metas[i] : {},
              ));
            }
          }
          return results;
        }
      }
    } catch (_) {}
    return _searchLocal(collection, queryVector, topK, minScore);
  }
}
