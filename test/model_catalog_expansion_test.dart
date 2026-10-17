import 'package:flutter_test/flutter_test.dart';
import 'package:ollivo/services/model_catalog_service.dart';
import 'package:ollivo/services/model_discovery_service.dart';

void main() {
  group('Massive AI Model Catalog Expansion Tests (OLLIVO-EXP-001)', () {
    test('1. Catalog breadth exceeds 160 verified models across diverse domains', () {
      final catalog = ModelCatalogService.catalog;
      expect(catalog.length, greaterThanOrEqualTo(160));

      final uniqueIds = catalog.map((m) => m.id).toSet();
      expect(uniqueIds.length, equals(catalog.length), reason: 'All model IDs must be unique');
    });

    test('2. Covers all requested model families and specialized categories', () {
      final catalog = ModelCatalogService.catalog;

      // General Purpose Families
      expect(catalog.any((m) => m.family.contains('Qwen') || m.id.startsWith('qwen')), isTrue);
      expect(catalog.any((m) => m.family.contains('Llama') || m.id.startsWith('llama')), isTrue);
      expect(catalog.any((m) => m.family.contains('Gemma') || m.id.startsWith('gemma')), isTrue);
      expect(catalog.any((m) => m.family.contains('Mistral') || m.family.contains('Ministral') || m.family.contains('Mixtral')), isTrue);
      expect(catalog.any((m) => m.family.contains('Phi')), isTrue);
      expect(catalog.any((m) => m.family.contains('SmolLM')), isTrue);
      expect(catalog.any((m) => m.family.contains('Granite')), isTrue);
      expect(catalog.any((m) => m.family.contains('DeepSeek')), isTrue);
      expect(catalog.any((m) => m.family.contains('InternLM') || m.id.contains('internlm')), isTrue);
      expect(catalog.any((m) => m.family.contains('Yi') || m.id.contains('yi')), isTrue);
      expect(catalog.any((m) => m.family.contains('Command R') || m.id.contains('command-r')), isTrue);

      // Coding Specialists
      expect(catalog.any((m) => m.id.contains('qwen2.5-coder')), isTrue);
      expect(catalog.any((m) => m.id.contains('deepseek-coder')), isTrue);
      expect(catalog.any((m) => m.id.contains('starcoder2')), isTrue);
      expect(catalog.any((m) => m.id.contains('codegemma')), isTrue);
      expect(catalog.any((m) => m.id.contains('granite-code')), isTrue);
      expect(catalog.any((m) => m.id.contains('devstral')), isTrue);

      // Reasoning Specialists
      expect(catalog.any((m) => m.id.contains('deepseek-r1')), isTrue);
      expect(catalog.any((m) => m.id.contains('qwq')), isTrue);
      expect(catalog.any((m) => m.id.contains('marco-o1')), isTrue);
      expect(catalog.any((m) => m.id.contains('mathstral')), isTrue);
      expect(catalog.any((m) => m.id.contains('numina-math')), isTrue);

      // Vision Models
      expect(catalog.any((m) => m.id.contains('qwen2.5-vl')), isTrue);
      expect(catalog.any((m) => m.id.contains('pixtral')), isTrue);
      expect(catalog.any((m) => m.id.contains('paligemma2')), isTrue);
      expect(catalog.any((m) => m.id.contains('internvl')), isTrue);
      expect(catalog.any((m) => m.id.contains('minicpm-v')), isTrue);
      expect(catalog.any((m) => m.id.contains('smolvlm')), isTrue);

      // Embeddings & Semantic Search
      expect(catalog.any((m) => m.id.contains('bge-m3') || m.id.contains('bge-large')), isTrue);
      expect(catalog.any((m) => m.id.contains('nomic-embed')), isTrue);
      expect(catalog.any((m) => m.id.contains('snowflake-arctic-embed')), isTrue);
      expect(catalog.any((m) => m.id.contains('e5-mistral') || m.id.contains('multilingual-e5')), isTrue);
      expect(catalog.any((m) => m.id.contains('gte')), isTrue);
      expect(catalog.any((m) => m.id.contains('jina-embeddings')), isTrue);

      // Rerankers
      expect(catalog.any((m) => m.ragRole == 'reranker' || m.id.contains('reranker')), isTrue);
      expect(catalog.any((m) => m.id.contains('bge-reranker')), isTrue);
      expect(catalog.any((m) => m.id.contains('qwen2.5-reranker')), isTrue);
      expect(catalog.any((m) => m.id.contains('jina-reranker')), isTrue);

      // Audio & Speech
      expect(catalog.any((m) => m.id.contains('whisper-large-v3-turbo') || m.id.contains('whisper')), isTrue);
      expect(catalog.any((m) => m.id.contains('qwen2-audio')), isTrue);

      // OCR & Specialized
      expect(catalog.any((m) => m.id.contains('got-ocr2')), isTrue);
      expect(catalog.any((m) => m.id.contains('nougat')), isTrue);
      expect(catalog.any((m) => m.id.contains('sqlcoder')), isTrue);
      expect(catalog.any((m) => m.id.contains('duckdb-nsql')), isTrue);
      expect(catalog.any((m) => m.id.contains('nllb-200')), isTrue);
    });

    test('3. Size Tiers and Mixture-of-Experts metadata are properly differentiated', () {
      final catalog = ModelCatalogService.catalog;

      // Ultra-light models
      final ultraLight = catalog.where((m) => m.sizeTier == 'Ultra-light').toList();
      expect(ultraLight.isNotEmpty, isTrue);
      for (final m in ultraLight) {
        expect(m.estimatedMemoryGb, lessThanOrEqualTo(2.5));
      }

      // MoE models correctly declare active vs total parameter count
      final moeModels = catalog.where((m) => m.isMoE).toList();
      expect(moeModels.length, greaterThanOrEqualTo(5));

      final mixtral = catalog.firstWhere((m) => m.id == 'mixtral:8x7b');
      expect(mixtral.isMoE, isTrue);
      expect(mixtral.activeParameterCount, contains('12.9B'));
      expect(mixtral.parameterCount, contains('46.7B'));

      final deepseekV3 = catalog.firstWhere((m) => m.id == 'deepseek-v3:latest');
      expect(deepseekV3.isMoE, isTrue);
      expect(deepseekV3.activeParameterCount, contains('37B'));
      expect(deepseekV3.parameterCount, contains('671B'));
    });

    test('4. Quantization variants are properly structured without fabricating files', () {
      final catalog = ModelCatalogService.catalog;
      final withVariants = catalog.where((m) => m.quantizationVariants.isNotEmpty).toList();
      expect(withVariants.length, greaterThanOrEqualTo(20));

      final qwen7b = catalog.firstWhere((m) => m.id == 'qwen2.5:7b');
      expect(qwen7b.quantizationVariants.length, greaterThanOrEqualTo(4));

      final tags = qwen7b.quantizationVariants.map((v) => v.tag).toList();
      expect(tags, contains('qwen2.5:7b-instruct-q4_K_M'));
      expect(tags, contains('qwen2.5:7b-instruct-q8_0'));

      for (final qv in qwen7b.quantizationVariants) {
        expect(qv.diskSize.isNotEmpty, isTrue);
        expect(qv.diskSizeBytes, greaterThan(0));
        expect(qv.memoryRequiredGb, greaterThan(0));
      }
    });

    test('5. First-class multimodal capabilities differentiate modalities and tasks', () {
      final catalog = ModelCatalogService.catalog;

      // Vision-capable models
      final visionModels = catalog.where((m) => m.isVision).toList();
      expect(visionModels.isNotEmpty, isTrue);
      for (final m in visionModels) {
        expect(m.supportedModalities, contains('image_in'));
        expect(m.supportedTasks.any((t) => t.contains('vision') || t.contains('ocr') || t.contains('multimodal')), isTrue);
      }

      // Audio models
      final audioModels = catalog.where((m) => m.isAudio).toList();
      expect(audioModels.isNotEmpty, isTrue);
      for (final m in audioModels) {
        expect(m.supportedModalities, contains('audio_in'));
      }
    });

    test('6. Complete RAG Collection and Pre-Engineered Recommendation Stacks', () {
      final catalog = ModelCatalogService.catalog;

      // RAG roles distribution
      final generators = catalog.where((m) => m.ragRole == 'generator').toList();
      final embeddings = catalog.where((m) => m.ragRole == 'embedding').toList();
      final rerankers = catalog.where((m) => m.ragRole == 'reranker').toList();
      final parsers = catalog.where((m) => m.ragRole == 'document_parser').toList();

      expect(generators.length, greaterThanOrEqualTo(10));
      expect(embeddings.length, greaterThanOrEqualTo(8));
      expect(rerankers.length, greaterThanOrEqualTo(3));
      expect(parsers.length, greaterThanOrEqualTo(2));

      // Embedding dimensions verified
      final bgeM3 = catalog.firstWhere((m) => m.id == 'bge-m3:latest');
      expect(bgeM3.embeddingDimensions, equals(1024));

      final nomic = catalog.firstWhere((m) => m.id == 'nomic-embed-text:latest');
      expect(nomic.embeddingDimensions, equals(768));

      // 6 RAG Recommendation Stacks
      final recs = ModelCatalogService.getRagPipelineRecommendations();
      expect(recs.length, equals(6));

      for (final rec in recs) {
        expect(rec.id.isNotEmpty, isTrue);
        expect(rec.title.isNotEmpty, isTrue);
        expect(rec.targetHardware.isNotEmpty, isTrue);
        expect(rec.estimatedTotalMemoryGb, greaterThan(0));
        expect(rec.supportedDocumentTypes.isNotEmpty, isTrue);

        // Every recommended model must exist in the catalog
        final gen = ModelCatalogService.getModelById(rec.generatorModelId);
        expect(gen, isNotNull, reason: 'Generator ${rec.generatorModelId} must exist in catalog');

        final emb = ModelCatalogService.getModelById(rec.embeddingModelId);
        expect(emb, isNotNull, reason: 'Embedding model ${rec.embeddingModelId} must exist in catalog');

        if (rec.rerankerModelId != null) {
          final rerank = ModelCatalogService.getModelById(rec.rerankerModelId!);
          expect(rerank, isNotNull, reason: 'Reranker ${rec.rerankerModelId} must exist in catalog');
        }

        if (rec.documentParserModelId != null) {
          final parser = ModelCatalogService.getModelById(rec.documentParserModelId!);
          expect(parser, isNotNull, reason: 'Parser ${rec.documentParserModelId} must exist in catalog');
        }
      }
    });

    test('7. Multi-dimensional search filters and sorting work accurately', () {
      // Size Tier Filter
      final advancedOnly = ModelCatalogService.searchModels(sizeTier: 'Advanced');
      expect(advancedOnly.every((m) => m.sizeTier == 'Advanced'), isTrue);

      // Family Filter
      final qwenOnly = ModelCatalogService.searchModels(familyFilter: 'Qwen 2.5');
      expect(qwenOnly.isNotEmpty, isTrue);
      expect(qwenOnly.every((m) => m.family.toLowerCase() == 'qwen 2.5'), isTrue);

      // RAG Role Filter
      final rerankersOnly = ModelCatalogService.searchModels(ragRoleFilter: 'reranker');
      expect(rerankersOnly.every((m) => m.ragRole == 'reranker'), isTrue);

      // Modality Filter
      final visionModality = ModelCatalogService.searchModels(modalityFilter: 'image_in');
      expect(visionModality.every((m) => m.supportedModalities.contains('image_in')), isTrue);

      // Task Filter
      final codingTasks = ModelCatalogService.searchModels(taskFilter: 'coding');
      expect(codingTasks.every((m) => m.supportedTasks.contains('coding')), isTrue);

      // Sort by Context descending
      final sortedByContext = ModelCatalogService.searchModels(sortBy: 'Context');
      for (int i = 0; i < sortedByContext.length - 1; i++) {
        expect(sortedByContext[i].contextLength, greaterThanOrEqualTo(sortedByContext[i + 1].contextLength));
      }
    });

    test('8. ModelDiscoveryService provides safe upstream querying and fallback', () async {
      final discoveryService = ModelDiscoveryService();

      // Test discovery query
      final result = await discoveryService.discoverUpstreamModels(
        query: 'qwen',
        source: 'all',
        forceRefresh: true,
      );

      expect(result.models.isNotEmpty, isTrue);
      expect(result.source.isNotEmpty, isTrue);
      expect(result.totalCount, greaterThan(0));

      for (final m in result.models) {
        expect(m.id.isNotEmpty, isTrue);
        expect(m.name.isNotEmpty, isTrue);
        expect(m.verificationStatus.isNotEmpty, isTrue);
      }
    });
  });
}
