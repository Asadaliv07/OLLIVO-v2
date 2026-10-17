import 'package:flutter_test/flutter_test.dart';
import 'package:ollivo/services/model_catalog_service.dart';

void main() {
  group('ModelCatalogService & Schema Tests (MOD-CAT-001/002)', () {
    test('Catalog contains at least 100 verified genuine models', () {
      final models = ModelCatalogService.getAllModels();
      expect(models.length, greaterThanOrEqualTo(100));
    });

    test('Every model in catalog satisfies required schema constraints', () {
      final models = ModelCatalogService.getAllModels();
      for (final m in models) {
        expect(m.id.isNotEmpty, isTrue, reason: 'id must not be empty');
        expect(m.name.isNotEmpty, isTrue, reason: 'name must not be empty: ${m.id}');
        expect(m.family.isNotEmpty, isTrue, reason: 'family must not be empty: ${m.id}');
        expect(m.category.isNotEmpty, isTrue, reason: 'category must not be empty: ${m.id}');
        expect(m.backend.isNotEmpty, isTrue, reason: 'backend must not be empty: ${m.id}');
        expect(m.license.isNotEmpty, isTrue, reason: 'license must not be empty: ${m.id}');
        expect(m.downloadIdentifier.isNotEmpty, isTrue, reason: 'downloadIdentifier must not be empty: ${m.id}');
        expect(m.estimatedMemoryGb, greaterThan(0.0), reason: 'estimatedMemoryGb must be > 0: ${m.id}');
        expect(m.contextLength, greaterThan(0), reason: 'contextLength must be > 0: ${m.id}');
        expect(m.capabilities.isNotEmpty, isTrue, reason: 'capabilities must not be empty: ${m.id}');
      }
    });

    test('All required categories are represented in catalog', () {
      final models = ModelCatalogService.getAllModels();
      final categories = models.map((m) => m.category).toSet();

      expect(categories, contains('Lightweight'));
      expect(categories, contains('Medium'));
      expect(categories, contains('Coding'));
      expect(categories, contains('Reasoning'));
      expect(categories, contains('Vision'));
      expect(categories, contains('Embeddings'));
      expect(categories, contains('Image Generation'));
      expect(categories, contains('Audio'));
      expect(categories, contains('Video'));
    });

    test('Search and category filtering filters correctly', () {
      final codingModels = ModelCatalogService.searchModels(category: 'Coding');
      expect(codingModels.isNotEmpty, isTrue);
      expect(codingModels.every((m) => m.category == 'Coding'), isTrue);

      final searchQwen = ModelCatalogService.searchModels(query: 'qwen');
      expect(searchQwen.isNotEmpty, isTrue);
      expect(searchQwen.every((m) =>
          m.name.toLowerCase().contains('qwen') ||
          m.id.toLowerCase().contains('qwen') ||
          m.family.toLowerCase().contains('qwen') ||
          m.description.toLowerCase().contains('qwen') ||
          m.capabilities.any((c) => c.toLowerCase().contains('qwen'))), isTrue);

      final lightweight = ModelCatalogService.searchModels(sizeFilter: 'Lightweight');
      expect(lightweight.isNotEmpty, isTrue);
      expect(lightweight.every((m) => m.estimatedMemoryGb <= 3.0), isTrue);
    });

    test('Hardware compatibility filter returns only models fitting RAM budget', () {
      // On an 8GB machine, 32B models (>12GB) should not appear
      final budget8Gb = ModelCatalogService.searchModels(
        hardwareCompatibleOnly: true,
        systemRamGb: 8.0,
      );
      expect(budget8Gb.isNotEmpty, isTrue);
      expect(budget8Gb.every((m) => m.estimatedMemoryGb <= 7.2), isTrue);
      expect(budget8Gb.any((m) => m.id.contains('70b') || m.id.contains('32b')), isFalse);
    });
  });
}
