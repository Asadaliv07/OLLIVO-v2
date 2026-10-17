import 'package:flutter_test/flutter_test.dart';
import 'package:ollivo/services/vector_store_service.dart';

void main() {
  group('VectorStoreService Unit and Vector Search Tests', () {
    late VectorStoreService vectorStore;

    setUp(() {
      vectorStore = VectorStoreService();
      vectorStore.configure(backend: VectorStoreBackend.sqliteVec);
    });

    test('Cosine similarity mathematical properties', () {
      // Identical vectors -> 1.0
      expect(VectorStoreService.cosineSimilarity([1.0, 0.0, 0.0], [1.0, 0.0, 0.0]), closeTo(1.0, 0.0001));

      // Orthogonal vectors -> 0.0
      expect(VectorStoreService.cosineSimilarity([1.0, 0.0], [0.0, 1.0]), closeTo(0.0, 0.0001));

      // Opposite vectors -> -1.0
      expect(VectorStoreService.cosineSimilarity([1.0, 2.0], [-1.0, -2.0]), closeTo(-1.0, 0.0001));

      // Zero or mismatched vectors -> 0.0
      expect(VectorStoreService.cosineSimilarity([], [1.0]), equals(0.0));
      expect(VectorStoreService.cosineSimilarity([1.0, 2.0], [1.0]), equals(0.0));
    });

    test('Upsert and count documents in a collection', () async {
      await vectorStore.clearCollection('test_kb');

      final docs = [
        const VectorDocument(
          id: 'doc_1',
          vector: [1.0, 0.0, 0.0],
          text: 'Introduction to Artificial Intelligence',
          metadata: {'author': 'Turing'},
        ),
        const VectorDocument(
          id: 'doc_2',
          vector: [0.0, 1.0, 0.0],
          text: 'Quantum Computing and Superposition',
          metadata: {'author': 'Feynman'},
        ),
      ];

      final countUpserted = await vectorStore.upsert('test_kb', docs);
      expect(countUpserted, equals(2));

      final total = await vectorStore.count('test_kb');
      expect(total, equals(2));
    });

    test('Search returns nearest vectors ranked by similarity score', () async {
      await vectorStore.clearCollection('test_kb');

      final docs = [
        const VectorDocument(
          id: 'doc_ai',
          vector: [0.9, 0.1, 0.0],
          text: 'Deep learning neural network architectures',
        ),
        const VectorDocument(
          id: 'doc_cooking',
          vector: [0.0, 0.1, 0.9],
          text: 'Baking sourdough bread and pastries',
        ),
      ];
      await vectorStore.upsert('test_kb', docs);

      // Query vector strongly aligned with AI
      final query = [1.0, 0.0, 0.0];
      final results = await vectorStore.search('test_kb', query, topK: 2);

      expect(results.length, equals(2));
      expect(results.first.id, equals('doc_ai'));
      expect(results.first.score, greaterThan(0.8));
      expect(results.first.text, contains('Deep learning'));
      expect(results.last.id, equals('doc_cooking'));
    });

    test('Delete removes documents and updates collection count', () async {
      await vectorStore.clearCollection('test_kb');

      final docs = [
        const VectorDocument(id: 'del_1', vector: [0.5, 0.5], text: 'Delete me'),
        const VectorDocument(id: 'keep_1', vector: [0.1, 0.9], text: 'Keep me'),
      ];
      await vectorStore.upsert('test_kb', docs);
      expect(await vectorStore.count('test_kb'), equals(2));

      final deleted = await vectorStore.delete('test_kb', ['del_1']);
      expect(deleted, isTrue);
      expect(await vectorStore.count('test_kb'), equals(1));

      final remaining = await vectorStore.search('test_kb', [0.5, 0.5]);
      expect(remaining.any((r) => r.id == 'del_1'), isFalse);
    });

    test('Configures and switches vector backends safely', () {
      vectorStore.configure(
        backend: VectorStoreBackend.qdrant,
        endpointUrl: 'http://localhost:6333',
      );
      expect(vectorStore.activeBackend, equals(VectorStoreBackend.qdrant));
      expect(vectorStore.endpointUrl, equals('http://localhost:6333'));

      vectorStore.configure(backend: VectorStoreBackend.inMemoryFaiss);
      expect(vectorStore.activeBackend, equals(VectorStoreBackend.inMemoryFaiss));
    });
  });
}
