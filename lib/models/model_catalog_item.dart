// ignore_for_file: prefer_initializing_formals

/// Quantization variant descriptor linked to a parent model (MOD-CAT-001)
class ModelQuantizationVariant {
  final String tag;
  final String diskSize;
  final int diskSizeBytes;
  final double memoryRequiredGb;
  final String description;

  const ModelQuantizationVariant({
    required this.tag,
    required this.diskSize,
    required this.diskSizeBytes,
    required this.memoryRequiredGb,
    this.description = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'tag': tag,
      'diskSize': diskSize,
      'diskSizeBytes': diskSizeBytes,
      'memoryRequiredGb': memoryRequiredGb,
      'description': description,
    };
  }

  factory ModelQuantizationVariant.fromMap(Map<String, dynamic> map) {
    return ModelQuantizationVariant(
      tag: map['tag'] as String? ?? 'Q4_K_M',
      diskSize: map['diskSize'] as String? ?? '',
      diskSizeBytes: map['diskSizeBytes'] as int? ?? 0,
      memoryRequiredGb: (map['memoryRequiredGb'] as num?)?.toDouble() ?? 2.0,
      description: map['description'] as String? ?? '',
    );
  }
}

/// Structured Model Catalog Item Schema with Rich Capabilities, RAG Roles & Hardware Tiers (MOD-CAT-001)
class ModelCatalogItem {
  final String id;
  final String name;
  final String family;
  final String category; // 'Lightweight', 'Medium', 'Advanced', 'Large', 'Extra-large', 'Coding', 'Reasoning', 'Vision', 'Embeddings', 'Reranking', 'Audio', 'Image Generation', 'Video'
  final String provider;
  final String backend; // 'ollama', 'comfyui', 'whisper_cpp', 'piper_tts', 'video_engine'
  final List<String> verifiedTags;
  final String parameterCount;
  final String quantization;
  final String estimatedDiskSize;
  final int estimatedDiskSizeBytes;
  final String estimatedMemory;
  final double estimatedMemoryGb;
  final int contextLength;
  final List<String> capabilities;
  final String license;
  final String sourceUrl;
  final String downloadIdentifier;
  final String hardwareRequirements;
  final String compatibilityStatus;
  final String lastVerified;
  final String description;

  // Rich Multi-Dimensional Catalog Fields
  final String _sizeTier; // 'Ultra-light', 'Lightweight', 'Medium', 'Advanced', 'Large', 'Extra-large'
  final String? activeParameterCount; // For MoE (e.g. '2.4B active')
  final List<ModelQuantizationVariant> quantizationVariants;
  final List<String> _supportedModalities; // 'text_in', 'text_out', 'image_in', 'audio_in', 'audio_out', 'video_in', 'embedding', 'rerank'
  final List<String> _supportedTasks; // 'chat', 'coding', 'reasoning', 'math', 'vision_qa', 'ocr', 'embedding', 'rerank', 'structured_json', 'tool_calling', 'speech_transcription'
  final String _ragRole; // 'generator', 'embedding', 'reranker', 'document_parser', 'vision_rag', 'none'
  final int? _embeddingDimensions; // e.g. 768, 1024, 1536
  final List<String> supportedLanguages;
  final String architecture; // 'Dense Transformer', 'Mixture of Experts (MoE)', 'Bi-Encoder', 'Cross-Encoder', 'Encoder-Decoder'
  final bool isAppleSiliconOptimized;
  final bool isCpuPractical;
  final String verificationStatus; // 'curated', 'official', 'community', 'unverified'
  final String strengths;
  final String limitations;
  final List<String> recommendedUseCases;

  const ModelCatalogItem({
    required this.id,
    required this.name,
    required this.family,
    required this.category,
    required this.provider,
    required this.backend,
    required this.verifiedTags,
    required this.parameterCount,
    required this.quantization,
    required this.estimatedDiskSize,
    required this.estimatedDiskSizeBytes,
    required this.estimatedMemory,
    required this.estimatedMemoryGb,
    required this.contextLength,
    required this.capabilities,
    required this.license,
    required this.sourceUrl,
    required this.downloadIdentifier,
    required this.hardwareRequirements,
    required this.compatibilityStatus,
    required this.lastVerified,
    required this.description,
    String sizeTier = 'Medium',
    this.activeParameterCount,
    this.quantizationVariants = const [],
    List<String> supportedModalities = const ['text_in', 'text_out'],
    List<String> supportedTasks = const ['chat'],
    String ragRole = 'none',
    int? embeddingDimensions,
    this.supportedLanguages = const ['English', 'Multilingual'],
    this.architecture = 'Dense Transformer',
    this.isAppleSiliconOptimized = true,
    this.isCpuPractical = true,
    this.verificationStatus = 'curated',
    this.strengths = '',
    this.limitations = '',
    this.recommendedUseCases = const [],
  })  : _sizeTier = sizeTier,
        _supportedModalities = supportedModalities,
        _supportedTasks = supportedTasks,
        _ragRole = ragRole,
        _embeddingDimensions = embeddingDimensions;

  String get sizeTier {
    if (_sizeTier != 'Medium' && _sizeTier != 'Lightweight') return _sizeTier;
    if (estimatedMemoryGb <= 1.8) return 'Ultra-light';
    if (estimatedMemoryGb > 1.8 && estimatedMemoryGb <= 4.0) return 'Lightweight';
    if (estimatedMemoryGb > 4.0 && estimatedMemoryGb <= 9.0) return 'Medium';
    if (estimatedMemoryGb > 9.0 && estimatedMemoryGb <= 20.0) return 'Advanced';
    if (estimatedMemoryGb > 20.0 && estimatedMemoryGb <= 40.0) return 'Large';
    if (estimatedMemoryGb > 40.0) return 'Extra-large';
    return _sizeTier;
  }

  String get ragRole {
    if (_ragRole != 'none') return _ragRole;
    if (category == 'Embeddings') return 'embedding';
    if (category == 'Reranking') return 'reranker';
    return 'none';
  }

  int? get embeddingDimensions {
    if (_embeddingDimensions != null) return _embeddingDimensions;
    if (capabilities.contains('1024-dim')) return 1024;
    if (capabilities.contains('768-dim')) return 768;
    if (capabilities.contains('1536-dim')) return 1536;
    if (capabilities.contains('384-dim')) return 384;
    if (capabilities.contains('512-dim')) return 512;
    if (capabilities.contains('4096-dim')) return 4096;
    return null;
  }

  List<String> get supportedTasks {
    final res = List<String>.from(_supportedTasks);
    if ((category == 'Vision' || capabilities.contains('vision')) &&
        !res.any((t) => t.contains('vision') || t.contains('ocr') || t.contains('multimodal'))) {
      res.add('vision_qa');
    }
    if ((category == 'Coding' || capabilities.contains('coding')) && !res.contains('coding')) {
      res.add('coding');
    }
    if ((category == 'Reasoning' || capabilities.contains('reasoning')) && !res.contains('reasoning')) {
      res.add('reasoning');
    }
    if ((category == 'Audio' || capabilities.contains('audio')) && !res.contains('audio')) {
      res.add('audio');
    }
    if ((category == 'Embeddings' || ragRole == 'embedding') && !res.contains('embedding')) {
      res.add('embedding');
    }
    if ((category == 'Reranking' || ragRole == 'reranker') && !res.contains('rerank')) {
      res.add('rerank');
    }
    return res;
  }

  List<String> get supportedModalities {
    final res = List<String>.from(_supportedModalities);
    if ((category == 'Vision' || capabilities.contains('vision')) && !res.contains('image_in')) {
      res.add('image_in');
    }
    if (category == 'Embeddings' && !res.contains('embedding')) {
      res.add('embedding');
    }
    if (category == 'Reranking' && !res.contains('rerank')) {
      res.add('rerank');
    }
    if (category == 'Audio' && !res.contains('audio_in')) {
      res.add('audio_in');
    }
    return res;
  }

  bool get isOllamaNative => backend == 'ollama';
  bool get isEmbedding => category == 'Embeddings' || capabilities.contains('embedding') || ragRole == 'embedding';
  bool get isReranker => category == 'Reranking' || capabilities.contains('rerank') || ragRole == 'reranker';
  bool get isVision => category == 'Vision' || capabilities.contains('vision') || supportedModalities.contains('image_in');
  bool get isAudio => category == 'Audio' || supportedModalities.contains('audio_in') || supportedModalities.contains('audio_out');
  bool get isVideo => category == 'Video' || supportedModalities.contains('video_in');
  bool get isMoE => architecture.toLowerCase().contains('moe') || activeParameterCount != null;
  bool get isUltraLight => sizeTier == 'Ultra-light' || estimatedMemoryGb <= 1.8;

  String get formattedContext {
    if (contextLength <= 0) return 'Standard';
    if (contextLength >= 1000) {
      final k = contextLength ~/ 1000;
      return '${k}k ctx';
    }
    return '$contextLength ctx';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'family': family,
      'category': category,
      'provider': provider,
      'backend': backend,
      'verifiedTags': verifiedTags,
      'parameterCount': parameterCount,
      'quantization': quantization,
      'estimatedDiskSize': estimatedDiskSize,
      'estimatedDiskSizeBytes': estimatedDiskSizeBytes,
      'estimatedMemory': estimatedMemory,
      'estimatedMemoryGb': estimatedMemoryGb,
      'contextLength': contextLength,
      'capabilities': capabilities,
      'license': license,
      'sourceUrl': sourceUrl,
      'downloadIdentifier': downloadIdentifier,
      'hardwareRequirements': hardwareRequirements,
      'compatibilityStatus': compatibilityStatus,
      'lastVerified': lastVerified,
      'description': description,
      'sizeTier': sizeTier,
      'activeParameterCount': activeParameterCount,
      'quantizationVariants': quantizationVariants.map((v) => v.toMap()).toList(),
      'supportedModalities': supportedModalities,
      'supportedTasks': supportedTasks,
      'ragRole': ragRole,
      'embeddingDimensions': embeddingDimensions,
      'supportedLanguages': supportedLanguages,
      'architecture': architecture,
      'isAppleSiliconOptimized': isAppleSiliconOptimized,
      'isCpuPractical': isCpuPractical,
      'verificationStatus': verificationStatus,
      'strengths': strengths,
      'limitations': limitations,
      'recommendedUseCases': recommendedUseCases,
    };
  }

  factory ModelCatalogItem.fromMap(Map<String, dynamic> map) {
    // Derive size tier if not explicitly specified
    String tier = map['sizeTier'] as String? ?? '';
    final mem = (map['estimatedMemoryGb'] as num?)?.toDouble() ?? 2.0;
    if (tier.isEmpty) {
      if (mem <= 1.8) {
        tier = 'Ultra-light';
      } else if (mem <= 4.0) {
        tier = 'Lightweight';
      } else if (mem <= 10.0) {
        tier = 'Medium';
      } else if (mem <= 22.0) {
        tier = 'Advanced';
      } else if (mem <= 44.0) {
        tier = 'Large';
      } else {
        tier = 'Extra-large';
      }
    }

    final rawVariants = map['quantizationVariants'] as List<dynamic>? ?? [];
    final variants = rawVariants
        .map((v) => ModelQuantizationVariant.fromMap(Map<String, dynamic>.from(v as Map)))
        .toList();

    return ModelCatalogItem(
      id: map['id'] as String,
      name: map['name'] as String,
      family: map['family'] as String? ?? 'General',
      category: map['category'] as String? ?? 'Lightweight',
      provider: map['provider'] as String? ?? 'Community',
      backend: map['backend'] as String? ?? 'ollama',
      verifiedTags: List<String>.from(map['verifiedTags'] ?? []),
      parameterCount: map['parameterCount'] as String? ?? '',
      quantization: map['quantization'] as String? ?? 'Q4_K_M',
      estimatedDiskSize: map['estimatedDiskSize'] as String? ?? '',
      estimatedDiskSizeBytes: map['estimatedDiskSizeBytes'] as int? ?? 0,
      estimatedMemory: map['estimatedMemory'] as String? ?? '',
      estimatedMemoryGb: mem,
      contextLength: map['contextLength'] as int? ?? 4096,
      capabilities: List<String>.from(map['capabilities'] ?? []),
      license: map['license'] as String? ?? 'Open Source',
      sourceUrl: map['sourceUrl'] as String? ?? 'https://ollama.com',
      downloadIdentifier: map['downloadIdentifier'] as String? ?? map['id'] as String,
      hardwareRequirements: map['hardwareRequirements'] as String? ?? '8 GB RAM',
      compatibilityStatus: map['compatibilityStatus'] as String? ?? 'Verified Compatible',
      lastVerified: map['lastVerified'] as String? ?? '2026-10',
      description: map['description'] as String? ?? '',
      sizeTier: tier,
      activeParameterCount: map['activeParameterCount'] as String?,
      quantizationVariants: variants,
      supportedModalities: List<String>.from(map['supportedModalities'] ?? ['text_in', 'text_out']),
      supportedTasks: List<String>.from(map['supportedTasks'] ?? ['chat']),
      ragRole: map['ragRole'] as String? ?? 'none',
      embeddingDimensions: map['embeddingDimensions'] as int?,
      supportedLanguages: List<String>.from(map['supportedLanguages'] ?? ['English', 'Multilingual']),
      architecture: map['architecture'] as String? ?? 'Dense Transformer',
      isAppleSiliconOptimized: map['isAppleSiliconOptimized'] as bool? ?? true,
      isCpuPractical: map['isCpuPractical'] as bool? ?? true,
      verificationStatus: map['verificationStatus'] as String? ?? 'curated',
      strengths: map['strengths'] as String? ?? '',
      limitations: map['limitations'] as String? ?? '',
      recommendedUseCases: List<String>.from(map['recommendedUseCases'] ?? []),
    );
  }
}
