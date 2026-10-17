/// Dedicated RAG Pipeline Recommendation Specification (MOD-RAG-001)
class RagPipelineRecommendation {
  final String id;
  final String title;
  final String subtitle;
  final String description;
  final String targetHardware;
  final String generatorModelId;
  final String embeddingModelId;
  final String? rerankerModelId;
  final String? documentParserModelId;
  final double estimatedTotalMemoryGb;
  final List<String> supportedDocumentTypes;
  final String recommendedQuantization;
  final List<String> keyStrengths;

  const RagPipelineRecommendation({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.targetHardware,
    required this.generatorModelId,
    required this.embeddingModelId,
    this.rerankerModelId,
    this.documentParserModelId,
    required this.estimatedTotalMemoryGb,
    required this.supportedDocumentTypes,
    required this.recommendedQuantization,
    required this.keyStrengths,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'description': description,
      'targetHardware': targetHardware,
      'generatorModelId': generatorModelId,
      'embeddingModelId': embeddingModelId,
      'rerankerModelId': rerankerModelId,
      'documentParserModelId': documentParserModelId,
      'estimatedTotalMemoryGb': estimatedTotalMemoryGb,
      'supportedDocumentTypes': supportedDocumentTypes,
      'recommendedQuantization': recommendedQuantization,
      'keyStrengths': keyStrengths,
    };
  }

  factory RagPipelineRecommendation.fromMap(Map<String, dynamic> map) {
    return RagPipelineRecommendation(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      subtitle: map['subtitle'] as String? ?? '',
      description: map['description'] as String? ?? '',
      targetHardware: map['targetHardware'] as String? ?? '',
      generatorModelId: map['generatorModelId'] as String? ?? '',
      embeddingModelId: map['embeddingModelId'] as String? ?? '',
      rerankerModelId: map['rerankerModelId'] as String?,
      documentParserModelId: map['documentParserModelId'] as String?,
      estimatedTotalMemoryGb: (map['estimatedTotalMemoryGb'] as num?)?.toDouble() ?? 4.0,
      supportedDocumentTypes: (map['supportedDocumentTypes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const ['PDF', 'TXT', 'MD'],
      recommendedQuantization: map['recommendedQuantization'] as String? ?? 'Q4_K_M',
      keyStrengths: (map['keyStrengths'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}
