import 'dart:convert';

/// Per-Model Advanced Configuration Schema for Local AI Execution (MOD-CFG-001)
/// Supports Ollama, llama.cpp, and external engines with parameter validation and precedence resolution.
class ModelConfiguration {
  final String modelId;
  final String backend; // 'ollama', 'comfyui', 'whisper_cpp', 'other'
  final int configVersion;
  final DateTime updatedAt;

  // --- Generation Parameters ---
  final double? temperature; // 0.0 - 2.0 (null = inherit global)
  final double? topP; // 0.0 - 1.0
  final int? topK; // 1 - 100
  final double? minP; // 0.0 - 1.0 (Ollama / llama.cpp)
  final double? typicalP; // 0.0 - 1.0
  final double? repeatPenalty; // 1.0 - 2.0
  final int? repeatLastN; // 0 - 256
  final double? presencePenalty; // -2.0 - 2.0
  final double? frequencyPenalty; // -2.0 - 2.0
  final int? maxTokens; // num_predict (e.g. 512, 2048, 4096)
  final List<String>? stopSequences; // custom stop tokens
  final int? seed; // -1 for random, or specific integer
  final int? mirostat; // 0 = disabled, 1 = Mirostat, 2 = Mirostat 2.0
  final double? mirostatTau; // target surprise (e.g. 5.0)
  final double? mirostatEta; // learning rate (e.g. 0.1)
  final bool? jsonOutputMode; // format: 'json'

  // --- Context & Memory Parameters ---
  final int? contextLength; // num_ctx (e.g. 2048, 4096, 8192, 16384, 32768, 131072)
  final String? keepAlive; // e.g. '5m', '15m', '30m', '1h', '-1', '0'
  final int? historyLimit; // max messages in conversation history
  final bool? ragEnabled; // whether RAG is active for this model
  final int? retrievedDocCount; // top-k document chunks
  final double? similarityThreshold; // 0.0 - 1.0
  final String? embeddingModelOverride;
  final String? rerankerModelOverride;

  // --- System Prompt & Template ---
  final String? systemPrompt;
  final String? promptTemplateId;

  // --- Runtime & Hardware Configuration ---
  final int? numThreads; // CPU threads
  final int? numGpuLayers; // GPU offloading layers (-1 = all)
  final bool? f16Kv; // FP16 KV cache
  final bool? flashAttention; // Flash Attention acceleration

  const ModelConfiguration({
    required this.modelId,
    this.backend = 'ollama',
    this.configVersion = 1,
    required this.updatedAt,
    this.temperature,
    this.topP,
    this.topK,
    this.minP,
    this.typicalP,
    this.repeatPenalty,
    this.repeatLastN,
    this.presencePenalty,
    this.frequencyPenalty,
    this.maxTokens,
    this.stopSequences,
    this.seed,
    this.mirostat,
    this.mirostatTau,
    this.mirostatEta,
    this.jsonOutputMode,
    this.contextLength,
    this.keepAlive,
    this.historyLimit,
    this.ragEnabled,
    this.retrievedDocCount,
    this.similarityThreshold,
    this.embeddingModelOverride,
    this.rerankerModelOverride,
    this.systemPrompt,
    this.promptTemplateId,
    this.numThreads,
    this.numGpuLayers,
    this.f16Kv,
    this.flashAttention,
  });

  /// Factory for default empty configuration (inheriting all global defaults)
  factory ModelConfiguration.defaults(String modelId, {String backend = 'ollama'}) {
    return ModelConfiguration(
      modelId: modelId,
      backend: backend,
      configVersion: 1,
      updatedAt: DateTime.now(),
    );
  }

  /// Whether this model configuration has any custom overrides set
  bool get hasOverrides {
    return temperature != null ||
        topP != null ||
        topK != null ||
        minP != null ||
        typicalP != null ||
        repeatPenalty != null ||
        repeatLastN != null ||
        presencePenalty != null ||
        frequencyPenalty != null ||
        maxTokens != null ||
        (stopSequences != null && stopSequences!.isNotEmpty) ||
        seed != null ||
        mirostat != null ||
        jsonOutputMode != null ||
        contextLength != null ||
        keepAlive != null ||
        historyLimit != null ||
        ragEnabled != null ||
        retrievedDocCount != null ||
        similarityThreshold != null ||
        embeddingModelOverride != null ||
        rerankerModelOverride != null ||
        (systemPrompt != null && systemPrompt!.trim().isNotEmpty) ||
        promptTemplateId != null ||
        numThreads != null ||
        numGpuLayers != null ||
        f16Kv != null ||
        flashAttention != null;
  }

  /// Count of active overrides
  int get overrideCount {
    int count = 0;
    if (temperature != null) count++;
    if (topP != null) count++;
    if (topK != null) count++;
    if (minP != null) count++;
    if (typicalP != null) count++;
    if (repeatPenalty != null) count++;
    if (repeatLastN != null) count++;
    if (presencePenalty != null) count++;
    if (frequencyPenalty != null) count++;
    if (maxTokens != null) count++;
    if (stopSequences != null && stopSequences!.isNotEmpty) count++;
    if (seed != null) count++;
    if (mirostat != null) count++;
    if (jsonOutputMode != null) count++;
    if (contextLength != null) count++;
    if (keepAlive != null) count++;
    if (historyLimit != null) count++;
    if (ragEnabled != null) count++;
    if (retrievedDocCount != null) count++;
    if (similarityThreshold != null) count++;
    if (embeddingModelOverride != null) count++;
    if (rerankerModelOverride != null) count++;
    if (systemPrompt != null && systemPrompt!.trim().isNotEmpty) count++;
    if (promptTemplateId != null) count++;
    if (numThreads != null) count++;
    if (numGpuLayers != null) count++;
    if (f16Kv != null) count++;
    if (flashAttention != null) count++;
    return count;
  }

  /// Convert to SQLite or JSON map
  Map<String, dynamic> toMap() {
    return {
      'model_id': modelId,
      'backend': backend,
      'config_version': configVersion,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'temperature': temperature,
      'top_p': topP,
      'top_k': topK,
      'min_p': minP,
      'typical_p': typicalP,
      'repeat_penalty': repeatPenalty,
      'repeat_last_n': repeatLastN,
      'presence_penalty': presencePenalty,
      'frequency_penalty': frequencyPenalty,
      'max_tokens': maxTokens,
      'stop_sequences': stopSequences == null ? null : jsonEncode(stopSequences),
      'seed': seed,
      'mirostat': mirostat,
      'mirostat_tau': mirostatTau,
      'mirostat_eta': mirostatEta,
      'json_output_mode': jsonOutputMode == null ? null : (jsonOutputMode! ? 1 : 0),
      'context_length': contextLength,
      'keep_alive': keepAlive,
      'history_limit': historyLimit,
      'rag_enabled': ragEnabled == null ? null : (ragEnabled! ? 1 : 0),
      'retrieved_doc_count': retrievedDocCount,
      'similarity_threshold': similarityThreshold,
      'embedding_model_override': embeddingModelOverride,
      'reranker_model_override': rerankerModelOverride,
      'system_prompt': systemPrompt,
      'prompt_template_id': promptTemplateId,
      'num_threads': numThreads,
      'num_gpu_layers': numGpuLayers,
      'f16_kv': f16Kv == null ? null : (f16Kv! ? 1 : 0),
      'flash_attention': flashAttention == null ? null : (flashAttention! ? 1 : 0),
    };
  }

  /// Factory from SQLite or JSON map
  factory ModelConfiguration.fromMap(Map<String, dynamic> map) {
    List<String>? parsedStopSequences;
    final rawStop = map['stop_sequences'];
    if (rawStop is String && rawStop.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawStop);
        if (decoded is List) {
          parsedStopSequences = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    } else if (rawStop is List) {
      parsedStopSequences = rawStop.map((e) => e.toString()).toList();
    }

    final rawUpdated = map['updated_at'];
    DateTime updatedDate;
    if (rawUpdated is int) {
      updatedDate = DateTime.fromMillisecondsSinceEpoch(rawUpdated);
    } else if (rawUpdated is String) {
      updatedDate = DateTime.tryParse(rawUpdated) ?? DateTime.now();
    } else {
      updatedDate = DateTime.now();
    }

    return ModelConfiguration(
      modelId: (map['model_id'] as String?) ?? (map['modelId'] as String? ?? 'unknown'),
      backend: (map['backend'] as String?) ?? 'ollama',
      configVersion: (map['config_version'] as int?) ?? (map['configVersion'] as int? ?? 1),
      updatedAt: updatedDate,
      temperature: (map['temperature'] as num?)?.toDouble(),
      topP: (map['top_p'] as num?)?.toDouble() ?? (map['topP'] as num?)?.toDouble(),
      topK: (map['top_k'] as num?)?.toInt() ?? (map['topK'] as num?)?.toInt(),
      minP: (map['min_p'] as num?)?.toDouble() ?? (map['minP'] as num?)?.toDouble(),
      typicalP: (map['typical_p'] as num?)?.toDouble() ?? (map['typicalP'] as num?)?.toDouble(),
      repeatPenalty: (map['repeat_penalty'] as num?)?.toDouble() ?? (map['repeatPenalty'] as num?)?.toDouble(),
      repeatLastN: (map['repeat_last_n'] as num?)?.toInt() ?? (map['repeatLastN'] as num?)?.toInt(),
      presencePenalty: (map['presence_penalty'] as num?)?.toDouble() ?? (map['presencePenalty'] as num?)?.toDouble(),
      frequencyPenalty: (map['frequency_penalty'] as num?)?.toDouble() ?? (map['frequencyPenalty'] as num?)?.toDouble(),
      maxTokens: (map['max_tokens'] as num?)?.toInt() ?? (map['maxTokens'] as num?)?.toInt(),
      stopSequences: parsedStopSequences,
      seed: (map['seed'] as num?)?.toInt(),
      mirostat: (map['mirostat'] as num?)?.toInt(),
      mirostatTau: (map['mirostat_tau'] as num?)?.toDouble() ?? (map['mirostatTau'] as num?)?.toDouble(),
      mirostatEta: (map['mirostat_eta'] as num?)?.toDouble() ?? (map['mirostatEta'] as num?)?.toDouble(),
      jsonOutputMode: map['json_output_mode'] != null
          ? (map['json_output_mode'] == 1 || map['json_output_mode'] == true)
          : (map['jsonOutputMode'] as bool?),
      contextLength: (map['context_length'] as num?)?.toInt() ?? (map['contextLength'] as num?)?.toInt(),
      keepAlive: map['keep_alive'] as String? ?? map['keepAlive'] as String?,
      historyLimit: (map['history_limit'] as num?)?.toInt() ?? (map['historyLimit'] as num?)?.toInt(),
      ragEnabled: map['rag_enabled'] != null
          ? (map['rag_enabled'] == 1 || map['rag_enabled'] == true)
          : (map['ragEnabled'] as bool?),
      retrievedDocCount: (map['retrieved_doc_count'] as num?)?.toInt() ?? (map['retrievedDocCount'] as num?)?.toInt(),
      similarityThreshold: (map['similarity_threshold'] as num?)?.toDouble() ?? (map['similarityThreshold'] as num?)?.toDouble(),
      embeddingModelOverride: map['embedding_model_override'] as String? ?? map['embeddingModelOverride'] as String?,
      rerankerModelOverride: map['reranker_model_override'] as String? ?? map['rerankerModelOverride'] as String?,
      systemPrompt: map['system_prompt'] as String? ?? map['systemPrompt'] as String?,
      promptTemplateId: map['prompt_template_id'] as String? ?? map['promptTemplateId'] as String?,
      numThreads: (map['num_threads'] as num?)?.toInt() ?? (map['numThreads'] as num?)?.toInt(),
      numGpuLayers: (map['num_gpu_layers'] as num?)?.toInt() ?? (map['numGpuLayers'] as num?)?.toInt(),
      f16Kv: map['f16_kv'] != null
          ? (map['f16_kv'] == 1 || map['f16_kv'] == true)
          : (map['f16Kv'] as bool?),
      flashAttention: map['flash_attention'] != null
          ? (map['flash_attention'] == 1 || map['flash_attention'] == true)
          : (map['flashAttention'] as bool?),
    );
  }

  GenerationParameters get generationParams => GenerationParameters(
        temperature: temperature ?? 0.7,
        topP: topP ?? 0.9,
        topK: topK ?? 40,
        minP: minP ?? 0.0,
        typicalP: typicalP ?? 1.0,
        repeatPenalty: repeatPenalty ?? 1.1,
        repeatLastN: repeatLastN ?? 64,
        presencePenalty: presencePenalty ?? 0.0,
        frequencyPenalty: frequencyPenalty ?? 0.0,
        maxOutputTokens: maxTokens ?? 2048,
        seed: seed,
        mirostat: mirostat ?? 0,
        mirostatTau: mirostatTau ?? 5.0,
        mirostatEta: mirostatEta ?? 0.1,
        jsonOutputMode: jsonOutputMode ?? false,
      );

  ContextSettings get contextSettings => ContextSettings(
        contextLength: contextLength ?? 4096,
        keepAlive: keepAlive ?? '5m',
        ragEnabled: ragEnabled ?? true,
        retrievedDocCount: retrievedDocCount ?? 3,
        similarityThreshold: similarityThreshold ?? 0.45,
      );

  RuntimeConfig get runtimeConfig => RuntimeConfig(
        executionBackend: backend,
        flashAttention: flashAttention ?? false,
        f16Kv: f16Kv ?? true,
        numThreads: numThreads,
        numGpuLayers: numGpuLayers,
      );

  /// Copy with modifications
  ModelConfiguration copyWith({
    String? modelId,
    String? backend,
    int? configVersion,
    DateTime? updatedAt,
    double? temperature,
    bool clearTemperature = false,
    double? topP,
    bool clearTopP = false,
    int? topK,
    bool clearTopK = false,
    double? minP,
    bool clearMinP = false,
    double? typicalP,
    bool clearTypicalP = false,
    double? repeatPenalty,
    bool clearRepeatPenalty = false,
    int? repeatLastN,
    bool clearRepeatLastN = false,
    double? presencePenalty,
    bool clearPresencePenalty = false,
    double? frequencyPenalty,
    bool clearFrequencyPenalty = false,
    int? maxTokens,
    bool clearMaxTokens = false,
    List<String>? stopSequences,
    bool clearStopSequences = false,
    int? seed,
    bool clearSeed = false,
    int? mirostat,
    bool clearMirostat = false,
    double? mirostatTau,
    double? mirostatEta,
    bool? jsonOutputMode,
    bool clearJsonOutputMode = false,
    int? contextLength,
    bool clearContextLength = false,
    String? keepAlive,
    bool clearKeepAlive = false,
    int? historyLimit,
    bool clearHistoryLimit = false,
    bool? ragEnabled,
    bool clearRagEnabled = false,
    int? retrievedDocCount,
    bool clearRetrievedDocCount = false,
    double? similarityThreshold,
    bool clearSimilarityThreshold = false,
    String? embeddingModelOverride,
    bool clearEmbeddingModelOverride = false,
    String? rerankerModelOverride,
    bool clearRerankerModelOverride = false,
    String? systemPrompt,
    bool clearSystemPrompt = false,
    String? promptTemplateId,
    bool clearPromptTemplateId = false,
    int? numThreads,
    bool clearNumThreads = false,
    int? numGpuLayers,
    bool clearNumGpuLayers = false,
    bool? f16Kv,
    bool clearF16Kv = false,
    bool? flashAttention,
    bool clearFlashAttention = false,
    GenerationParameters? generationParams,
    ContextSettings? contextSettings,
    RuntimeConfig? runtimeConfig,
  }) {
    return ModelConfiguration(
      modelId: modelId ?? this.modelId,
      backend: runtimeConfig != null ? runtimeConfig.executionBackend : (backend ?? this.backend),
      configVersion: configVersion ?? this.configVersion,
      updatedAt: updatedAt ?? DateTime.now(),
      temperature: generationParams != null
          ? generationParams.temperature
          : (clearTemperature ? null : (temperature ?? this.temperature)),
      topP: generationParams != null
          ? generationParams.topP
          : (clearTopP ? null : (topP ?? this.topP)),
      topK: generationParams != null
          ? generationParams.topK
          : (clearTopK ? null : (topK ?? this.topK)),
      minP: generationParams != null
          ? generationParams.minP
          : (clearMinP ? null : (minP ?? this.minP)),
      typicalP: generationParams != null
          ? generationParams.typicalP
          : (clearTypicalP ? null : (typicalP ?? this.typicalP)),
      repeatPenalty: generationParams != null
          ? generationParams.repeatPenalty
          : (clearRepeatPenalty ? null : (repeatPenalty ?? this.repeatPenalty)),
      repeatLastN: generationParams != null
          ? generationParams.repeatLastN
          : (clearRepeatLastN ? null : (repeatLastN ?? this.repeatLastN)),
      presencePenalty: generationParams != null
          ? generationParams.presencePenalty
          : (clearPresencePenalty ? null : (presencePenalty ?? this.presencePenalty)),
      frequencyPenalty: generationParams != null
          ? generationParams.frequencyPenalty
          : (clearFrequencyPenalty ? null : (frequencyPenalty ?? this.frequencyPenalty)),
      maxTokens: generationParams != null
          ? generationParams.maxOutputTokens
          : (clearMaxTokens ? null : (maxTokens ?? this.maxTokens)),
      stopSequences: clearStopSequences ? null : (stopSequences ?? this.stopSequences),
      seed: generationParams != null
          ? generationParams.seed
          : (clearSeed ? null : (seed ?? this.seed)),
      mirostat: generationParams != null
          ? generationParams.mirostat
          : (clearMirostat ? null : (mirostat ?? this.mirostat)),
      mirostatTau: generationParams != null
          ? generationParams.mirostatTau
          : (mirostatTau ?? this.mirostatTau),
      mirostatEta: generationParams != null
          ? generationParams.mirostatEta
          : (mirostatEta ?? this.mirostatEta),
      jsonOutputMode: generationParams != null
          ? generationParams.jsonOutputMode
          : (clearJsonOutputMode ? null : (jsonOutputMode ?? this.jsonOutputMode)),
      contextLength: contextSettings != null
          ? contextSettings.contextLength
          : (clearContextLength ? null : (contextLength ?? this.contextLength)),
      keepAlive: contextSettings != null
          ? contextSettings.keepAlive
          : (clearKeepAlive ? null : (keepAlive ?? this.keepAlive)),
      historyLimit: clearHistoryLimit ? null : (historyLimit ?? this.historyLimit),
      ragEnabled: contextSettings != null
          ? contextSettings.ragEnabled
          : (clearRagEnabled ? null : (ragEnabled ?? this.ragEnabled)),
      retrievedDocCount: contextSettings != null
          ? contextSettings.retrievedDocCount
          : (clearRetrievedDocCount ? null : (retrievedDocCount ?? this.retrievedDocCount)),
      similarityThreshold: contextSettings != null
          ? contextSettings.similarityThreshold
          : (clearSimilarityThreshold ? null : (similarityThreshold ?? this.similarityThreshold)),
      embeddingModelOverride: clearEmbeddingModelOverride ? null : (embeddingModelOverride ?? this.embeddingModelOverride),
      rerankerModelOverride: clearRerankerModelOverride ? null : (rerankerModelOverride ?? this.rerankerModelOverride),
      systemPrompt: clearSystemPrompt ? null : (systemPrompt ?? this.systemPrompt),
      promptTemplateId: clearPromptTemplateId ? null : (promptTemplateId ?? this.promptTemplateId),
      numThreads: runtimeConfig != null
          ? runtimeConfig.numThreads
          : (clearNumThreads ? null : (numThreads ?? this.numThreads)),
      numGpuLayers: runtimeConfig != null
          ? runtimeConfig.numGpuLayers
          : (clearNumGpuLayers ? null : (numGpuLayers ?? this.numGpuLayers)),
      f16Kv: runtimeConfig != null
          ? runtimeConfig.f16Kv
          : (clearF16Kv ? null : (f16Kv ?? this.f16Kv)),
      flashAttention: runtimeConfig != null
          ? runtimeConfig.flashAttention
          : (clearFlashAttention ? null : (flashAttention ?? this.flashAttention)),
    );
  }

  /// Export as portable JSON string (stripping any sensitive credentials)
  String exportJson() {
    final map = toMap();
    map['exported_at'] = DateTime.now().toIso8601String();
    map['app'] = 'Ollivo AI';
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  String toJsonString() => exportJson();
}

/// Generation parameters group for model configuration dialog & sliders
class GenerationParameters {
  final double temperature;
  final double topP;
  final int topK;
  final double minP;
  final double typicalP;
  final double repeatPenalty;
  final int repeatLastN;
  final double presencePenalty;
  final double frequencyPenalty;
  final int maxOutputTokens;
  final int? seed;
  final int mirostat;
  final double mirostatTau;
  final double mirostatEta;
  final bool jsonOutputMode;

  const GenerationParameters({
    this.temperature = 0.7,
    this.topP = 0.9,
    this.topK = 40,
    this.minP = 0.0,
    this.typicalP = 1.0,
    this.repeatPenalty = 1.1,
    this.repeatLastN = 64,
    this.presencePenalty = 0.0,
    this.frequencyPenalty = 0.0,
    this.maxOutputTokens = 2048,
    this.seed,
    this.mirostat = 0,
    this.mirostatTau = 5.0,
    this.mirostatEta = 0.1,
    this.jsonOutputMode = false,
  });

  GenerationParameters copyWith({
    double? temperature,
    double? topP,
    int? topK,
    double? minP,
    double? typicalP,
    double? repeatPenalty,
    int? repeatLastN,
    double? presencePenalty,
    double? frequencyPenalty,
    int? maxOutputTokens,
    int? seed,
    int? mirostat,
    double? mirostatTau,
    double? mirostatEta,
    bool? jsonOutputMode,
  }) {
    return GenerationParameters(
      temperature: temperature ?? this.temperature,
      topP: topP ?? this.topP,
      topK: topK ?? this.topK,
      minP: minP ?? this.minP,
      typicalP: typicalP ?? this.typicalP,
      repeatPenalty: repeatPenalty ?? this.repeatPenalty,
      repeatLastN: repeatLastN ?? this.repeatLastN,
      presencePenalty: presencePenalty ?? this.presencePenalty,
      frequencyPenalty: frequencyPenalty ?? this.frequencyPenalty,
      maxOutputTokens: maxOutputTokens ?? this.maxOutputTokens,
      seed: seed ?? this.seed,
      mirostat: mirostat ?? this.mirostat,
      mirostatTau: mirostatTau ?? this.mirostatTau,
      mirostatEta: mirostatEta ?? this.mirostatEta,
      jsonOutputMode: jsonOutputMode ?? this.jsonOutputMode,
    );
  }
}

/// Context and RAG settings group for model configuration dialog
class ContextSettings {
  final int contextLength;
  final String keepAlive;
  final bool ragEnabled;
  final int retrievedDocCount;
  final double similarityThreshold;

  const ContextSettings({
    this.contextLength = 4096,
    this.keepAlive = '5m',
    this.ragEnabled = true,
    this.retrievedDocCount = 3,
    this.similarityThreshold = 0.45,
  });

  ContextSettings copyWith({
    int? contextLength,
    String? keepAlive,
    bool? ragEnabled,
    int? retrievedDocCount,
    double? similarityThreshold,
  }) {
    return ContextSettings(
      contextLength: contextLength ?? this.contextLength,
      keepAlive: keepAlive ?? this.keepAlive,
      ragEnabled: ragEnabled ?? this.ragEnabled,
      retrievedDocCount: retrievedDocCount ?? this.retrievedDocCount,
      similarityThreshold: similarityThreshold ?? this.similarityThreshold,
    );
  }
}

/// Runtime & Hardware Offload configuration group
class RuntimeConfig {
  final String executionBackend;
  final bool flashAttention;
  final bool f16Kv;
  final int? numThreads;
  final int? numGpuLayers;

  const RuntimeConfig({
    this.executionBackend = 'auto',
    this.flashAttention = false,
    this.f16Kv = true,
    this.numThreads,
    this.numGpuLayers,
  });
       
  RuntimeConfig copyWith({
    String? executionBackend,
    bool? flashAttention,
    bool? f16Kv,
    int? numThreads,
    int? numGpuLayers,
  }) {
    return RuntimeConfig(
      executionBackend: executionBackend ?? this.executionBackend,
      flashAttention: flashAttention ?? this.flashAttention,
      f16Kv: f16Kv ?? this.f16Kv,
      numThreads: numThreads ?? this.numThreads,
      numGpuLayers: numGpuLayers ?? this.numGpuLayers,
    );
  }
}

/// Conversation-level parameter overrides
class ModelParameterOverrides {
  final double? temperature;
  final double? topP;
  final int? topK;
  final String? systemPrompt;
  final int? maxTokens;
  final Map<String, dynamic> customOptions;

  const ModelParameterOverrides({
    this.temperature,
    this.topP,
    this.topK,
    this.systemPrompt,
    this.maxTokens,
    this.customOptions = const {},
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{...customOptions};
    if (temperature != null) map['temperature'] = temperature;
    if (topP != null) map['top_p'] = topP;
    if (topK != null) map['top_k'] = topK;
    if (systemPrompt != null) map['system_prompt'] = systemPrompt;
    if (maxTokens != null) map['max_tokens'] = maxTokens;
    return map;
  }
}

