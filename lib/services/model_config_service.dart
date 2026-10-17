import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/model_configuration.dart';
import 'database_service.dart';
import 'settings_service.dart';

/// Precedence Source for an effective parameter
class ParameterSource {
  static const String conversation = 'conversation';
  static const String modelOverride = 'model_override';
  static const String globalDefault = 'global_default';
  static const String backendDefault = 'backend_default';
}

/// Resolved Generation Parameters after applying:
/// Conversation override -> Model-specific setting -> Global default -> Backend default (MOD-CFG-002)
class ResolvedGenerationParameters {
  final String modelId;
  final double temperature;
  final double topP;
  final int topK;
  final double minP;
  final double typicalP;
  final double repeatPenalty;
  final int repeatLastN;
  final double presencePenalty;
  final double frequencyPenalty;
  final int maxTokens;
  final List<String> stopSequences;
  final int? seed;
  final int contextLength;
  final String keepAlive;
  final String systemPrompt;
  final bool jsonOutputMode;
  final int mirostat;
  final double mirostatTau;
  final double mirostatEta;
  final int? numThreads;
  final int? numGpuLayers;
  final bool f16Kv;
  final bool flashAttention;
  final bool ragEnabled;
  final int retrievedDocCount;
  final double similarityThreshold;
  final String? embeddingModel;
  final String? rerankerModel;

  /// Parameter name -> ParameterSource tracking
  final Map<String, String> parameterSources;

  const ResolvedGenerationParameters({
    required this.modelId,
    required this.temperature,
    required this.topP,
    required this.topK,
    required this.minP,
    required this.typicalP,
    required this.repeatPenalty,
    required this.repeatLastN,
    required this.presencePenalty,
    required this.frequencyPenalty,
    required this.maxTokens,
    required this.stopSequences,
    this.seed,
    required this.contextLength,
    required this.keepAlive,
    required this.systemPrompt,
    required this.jsonOutputMode,
    required this.mirostat,
    required this.mirostatTau,
    required this.mirostatEta,
    this.numThreads,
    this.numGpuLayers,
    required this.f16Kv,
    required this.flashAttention,
    required this.ragEnabled,
    required this.retrievedDocCount,
    required this.similarityThreshold,
    this.embeddingModel,
    this.rerankerModel,
    required this.parameterSources,
  });

  /// Convert to Ollama /api/generate options map
  Map<String, dynamic> toOllamaOptions() {
    final Map<String, dynamic> opts = {
      'temperature': temperature,
      'top_p': topP,
      'top_k': topK,
      'repeat_penalty': repeatPenalty,
      'repeat_last_n': repeatLastN,
      'num_predict': maxTokens,
      'num_ctx': contextLength,
    };

    if (minP > 0.0) opts['min_p'] = minP;
    if (typicalP < 1.0) opts['typical_p'] = typicalP;
    if (presencePenalty != 0.0) opts['presence_penalty'] = presencePenalty;
    if (frequencyPenalty != 0.0) opts['frequency_penalty'] = frequencyPenalty;
    if (stopSequences.isNotEmpty) opts['stop'] = stopSequences;
    if (seed != null && seed! >= 0) opts['seed'] = seed;
    if (mirostat > 0) {
      opts['mirostat'] = mirostat;
      opts['mirostat_tau'] = mirostatTau;
      opts['mirostat_eta'] = mirostatEta;
    }
    if (numThreads != null && numThreads! > 0) opts['num_thread'] = numThreads;
    if (numGpuLayers != null) opts['num_gpu'] = numGpuLayers;
    if (f16Kv) opts['f16_kv'] = true;

    return opts;
  }
}

/// Validation result for model configurations
class ModelConfigValidationResult {
  final bool isValid;
  final List<String> errors;

  const ModelConfigValidationResult({
    required this.isValid,
    this.errors = const [],
  });
}

/// Central Service for Per-Model Configuration Management (MOD-CFG-001)
class ModelConfigService extends ChangeNotifier {
  final DatabaseService? _dbService;
  final SettingsService? _settingsService;
  final Map<String, ModelConfiguration> _cache = {};
  bool _isLoaded = false;

  ModelConfigService({
    DatabaseService? dbService,
    SettingsService? settingsService,
  // ignore: prefer_initializing_formals
  })  : _dbService = dbService,
        // ignore: prefer_initializing_formals
        _settingsService = settingsService;

  bool get isLoaded => _isLoaded;

  /// Load all stored model configurations from SQLite
  Future<void> init() async {
    if (_isLoaded) return;
    if (_dbService != null) {
      try {
        final configs = await _dbService.getAllModelConfigurations();
        for (final cfg in configs) {
          _cache[cfg.modelId] = cfg;
        }
      } catch (_) {}
    }
    _isLoaded = true;
    notifyListeners();
  }

  /// Get model configuration, returning defaults if no custom overrides exist
  ModelConfiguration getConfiguration(String modelId) {
    if (_cache.containsKey(modelId)) {
      return _cache[modelId]!;
    }
    return ModelConfiguration.defaults(modelId);
  }

  ModelConfiguration? getConfig(String modelId) => getConfiguration(modelId);

  ModelConfiguration createDefaultConfig(String modelId) => ModelConfiguration.defaults(modelId);

  String? validateConfig(ModelConfiguration config) {
    final v = validate(config);
    return v.isValid ? null : v.errors.join('; ');
  }

  Future<bool> saveConfig(ModelConfiguration config) => saveConfiguration(config);

  Future<void> resetConfig(String modelId) => resetConfiguration(modelId);

  Future<void> duplicateConfig(String source, String target) => duplicateConfiguration(source, target);

  String exportConfig(String modelId) => exportConfigurationJson(modelId);

  Future<ModelConfiguration?> importConfig(String json) => importConfigurationJson(json);

  /// Check whether model has custom overrides
  bool hasOverrides(String modelId) {
    final cfg = _cache[modelId];
    return cfg != null && cfg.hasOverrides;
  }

  /// Validate parameters before saving
  static ModelConfigValidationResult validate(ModelConfiguration config) {
    final List<String> errors = [];

    if (config.temperature != null && (config.temperature! < 0.0 || config.temperature! > 2.0)) {
      errors.add('Temperature must be between 0.0 and 2.0');
    }
    if (config.topP != null && (config.topP! < 0.0 || config.topP! > 1.0)) {
      errors.add('Top-P must be between 0.0 and 1.0');
    }
    if (config.topK != null && (config.topK! < 1 || config.topK! > 100)) {
      errors.add('Top-K must be between 1 and 100');
    }
    if (config.minP != null && (config.minP! < 0.0 || config.minP! > 1.0)) {
      errors.add('Min-P must be between 0.0 and 1.0');
    }
    if (config.repeatPenalty != null && (config.repeatPenalty! < 1.0 || config.repeatPenalty! > 2.0)) {
      errors.add('Repeat penalty must be between 1.0 and 2.0');
    }
    if (config.repeatLastN != null && (config.repeatLastN! < 0 || config.repeatLastN! > 2048)) {
      errors.add('Repeat-last-N must be between 0 and 2048');
    }
    if (config.presencePenalty != null && (config.presencePenalty! < -2.0 || config.presencePenalty! > 2.0)) {
      errors.add('Presence penalty must be between -2.0 and 2.0');
    }
    if (config.frequencyPenalty != null && (config.frequencyPenalty! < -2.0 || config.frequencyPenalty! > 2.0)) {
      errors.add('Frequency penalty must be between -2.0 and 2.0');
    }
    if (config.maxTokens != null && (config.maxTokens! < 1 || config.maxTokens! > 131072)) {
      errors.add('Max output tokens must be between 1 and 131072');
    }
    if (config.contextLength != null && (config.contextLength! < 512 || config.contextLength! > 1048576)) {
      errors.add('Context length must be between 512 and 1,048,576');
    }

    return ModelConfigValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  /// Save model configuration to database & cache
  Future<bool> saveConfiguration(ModelConfiguration config) async {
    final validation = validate(config);
    if (!validation.isValid) {
      return false;
    }

    _cache[config.modelId] = config;
    if (_dbService != null) {
      try {
        await _dbService.saveModelConfiguration(config);
      } catch (_) {}
    }
    notifyListeners();
    return true;
  }

  /// Reset configuration to model defaults
  Future<void> resetConfiguration(String modelId) async {
    _cache.remove(modelId);
    if (_dbService != null) {
      try {
        await _dbService.deleteModelConfiguration(modelId);
      } catch (_) {}
    }
    notifyListeners();
  }

  /// Duplicate a model configuration to another model target
  Future<void> duplicateConfiguration(String sourceModelId, String targetModelId) async {
    final source = getConfiguration(sourceModelId);
    final copy = source.copyWith(
      modelId: targetModelId,
      updatedAt: DateTime.now(),
    );
    await saveConfiguration(copy);
  }

  /// Export configuration as JSON string
  String exportConfigurationJson(String modelId) {
    final config = getConfiguration(modelId);
    return config.exportJson();
  }

  /// Import configuration from JSON string
  Future<ModelConfiguration?> importConfigurationJson(String jsonString) async {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) return null;
      final config = ModelConfiguration.fromMap(decoded);
      final validation = validate(config);
      if (!validation.isValid) return null;
      await saveConfiguration(config);
      return config;
    } catch (_) {
      return null;
    }
  }

  /// Resolve effective parameters applying strict precedence:
  /// Conversation override -> Model-specific setting -> Global default -> Backend default (MOD-CFG-002)
  ResolvedGenerationParameters resolveEffectiveParameters({
    required String modelId,
    Map<String, dynamic>? conversationOverrides,
    SettingsService? globalSettings,
  }) {
    final settings = globalSettings ?? _settingsService ?? SettingsService();
    final modelConfig = getConfiguration(modelId);
    final Map<String, String> sources = {};

    // 1. Temperature
    double effectiveTemp;
    if (conversationOverrides != null && conversationOverrides.containsKey('temperature')) {
      effectiveTemp = (conversationOverrides['temperature'] as num).toDouble();
      sources['temperature'] = ParameterSource.conversation;
    } else if (modelConfig.temperature != null) {
      effectiveTemp = modelConfig.temperature!;
      sources['temperature'] = ParameterSource.modelOverride;
    } else {
      effectiveTemp = settings.chatTemperature;
      sources['temperature'] = ParameterSource.globalDefault;
    }

    // 2. Top-P
    double effectiveTopP;
    if (conversationOverrides != null && conversationOverrides.containsKey('top_p')) {
      effectiveTopP = (conversationOverrides['top_p'] as num).toDouble();
      sources['top_p'] = ParameterSource.conversation;
    } else if (modelConfig.topP != null) {
      effectiveTopP = modelConfig.topP!;
      sources['top_p'] = ParameterSource.modelOverride;
    } else {
      effectiveTopP = settings.topP;
      sources['top_p'] = ParameterSource.globalDefault;
    }

    // 3. Top-K
    int effectiveTopK;
    if (conversationOverrides != null && conversationOverrides.containsKey('top_k')) {
      effectiveTopK = (conversationOverrides['top_k'] as num).toInt();
      sources['top_k'] = ParameterSource.conversation;
    } else if (modelConfig.topK != null) {
      effectiveTopK = modelConfig.topK!;
      sources['top_k'] = ParameterSource.modelOverride;
    } else {
      effectiveTopK = settings.topK;
      sources['top_k'] = ParameterSource.globalDefault;
    }

    // 4. Min-P
    double effectiveMinP;
    if (conversationOverrides != null && conversationOverrides.containsKey('min_p')) {
      effectiveMinP = (conversationOverrides['min_p'] as num).toDouble();
      sources['min_p'] = ParameterSource.conversation;
    } else if (modelConfig.minP != null) {
      effectiveMinP = modelConfig.minP!;
      sources['min_p'] = ParameterSource.modelOverride;
    } else {
      effectiveMinP = 0.0;
      sources['min_p'] = ParameterSource.backendDefault;
    }

    // 5. Typical-P
    double effectiveTypicalP;
    if (conversationOverrides != null && conversationOverrides.containsKey('typical_p')) {
      effectiveTypicalP = (conversationOverrides['typical_p'] as num).toDouble();
      sources['typical_p'] = ParameterSource.conversation;
    } else if (modelConfig.typicalP != null) {
      effectiveTypicalP = modelConfig.typicalP!;
      sources['typical_p'] = ParameterSource.modelOverride;
    } else {
      effectiveTypicalP = 1.0;
      sources['typical_p'] = ParameterSource.backendDefault;
    }

    // 6. Repeat Penalty
    double effectiveRepeatPenalty;
    if (conversationOverrides != null && conversationOverrides.containsKey('repeat_penalty')) {
      effectiveRepeatPenalty = (conversationOverrides['repeat_penalty'] as num).toDouble();
      sources['repeat_penalty'] = ParameterSource.conversation;
    } else if (modelConfig.repeatPenalty != null) {
      effectiveRepeatPenalty = modelConfig.repeatPenalty!;
      sources['repeat_penalty'] = ParameterSource.modelOverride;
    } else {
      effectiveRepeatPenalty = settings.repeatPenalty;
      sources['repeat_penalty'] = ParameterSource.globalDefault;
    }

    // 7. Repeat Last N
    int effectiveRepeatLastN;
    if (conversationOverrides != null && conversationOverrides.containsKey('repeat_last_n')) {
      effectiveRepeatLastN = (conversationOverrides['repeat_last_n'] as num).toInt();
      sources['repeat_last_n'] = ParameterSource.conversation;
    } else if (modelConfig.repeatLastN != null) {
      effectiveRepeatLastN = modelConfig.repeatLastN!;
      sources['repeat_last_n'] = ParameterSource.modelOverride;
    } else {
      effectiveRepeatLastN = 64;
      sources['repeat_last_n'] = ParameterSource.backendDefault;
    }

    // 8. Presence Penalty
    double effectivePresencePenalty;
    if (conversationOverrides != null && conversationOverrides.containsKey('presence_penalty')) {
      effectivePresencePenalty = (conversationOverrides['presence_penalty'] as num).toDouble();
      sources['presence_penalty'] = ParameterSource.conversation;
    } else if (modelConfig.presencePenalty != null) {
      effectivePresencePenalty = modelConfig.presencePenalty!;
      sources['presence_penalty'] = ParameterSource.modelOverride;
    } else {
      effectivePresencePenalty = 0.0;
      sources['presence_penalty'] = ParameterSource.backendDefault;
    }

    // 9. Frequency Penalty
    double effectiveFrequencyPenalty;
    if (conversationOverrides != null && conversationOverrides.containsKey('frequency_penalty')) {
      effectiveFrequencyPenalty = (conversationOverrides['frequency_penalty'] as num).toDouble();
      sources['frequency_penalty'] = ParameterSource.conversation;
    } else if (modelConfig.frequencyPenalty != null) {
      effectiveFrequencyPenalty = modelConfig.frequencyPenalty!;
      sources['frequency_penalty'] = ParameterSource.modelOverride;
    } else {
      effectiveFrequencyPenalty = 0.0;
      sources['frequency_penalty'] = ParameterSource.backendDefault;
    }

    // 10. Max Output Tokens
    int effectiveMaxTokens;
    if (conversationOverrides != null && conversationOverrides.containsKey('max_tokens')) {
      effectiveMaxTokens = (conversationOverrides['max_tokens'] as num).toInt();
      sources['max_tokens'] = ParameterSource.conversation;
    } else if (modelConfig.maxTokens != null) {
      effectiveMaxTokens = modelConfig.maxTokens!;
      sources['max_tokens'] = ParameterSource.modelOverride;
    } else {
      effectiveMaxTokens = 2048;
      sources['max_tokens'] = ParameterSource.backendDefault;
    }

    // 11. Stop Sequences
    List<String> effectiveStop;
    if (conversationOverrides != null && conversationOverrides.containsKey('stop')) {
      effectiveStop = List<String>.from(conversationOverrides['stop']);
      sources['stop'] = ParameterSource.conversation;
    } else if (modelConfig.stopSequences != null && modelConfig.stopSequences!.isNotEmpty) {
      effectiveStop = modelConfig.stopSequences!;
      sources['stop'] = ParameterSource.modelOverride;
    } else {
      effectiveStop = [];
      sources['stop'] = ParameterSource.backendDefault;
    }

    // 12. Context Window Length
    int effectiveContextLength;
    if (conversationOverrides != null && conversationOverrides.containsKey('context_length')) {
      effectiveContextLength = (conversationOverrides['context_length'] as num).toInt();
      sources['context_length'] = ParameterSource.conversation;
    } else if (modelConfig.contextLength != null) {
      effectiveContextLength = modelConfig.contextLength!;
      sources['context_length'] = ParameterSource.modelOverride;
    } else {
      effectiveContextLength = settings.contextWindow;
      sources['context_length'] = ParameterSource.globalDefault;
    }

    // 13. System Prompt
    String effectiveSystem;
    if (conversationOverrides != null && conversationOverrides.containsKey('system_prompt')) {
      effectiveSystem = conversationOverrides['system_prompt'] as String;
      sources['system_prompt'] = ParameterSource.conversation;
    } else if (modelConfig.systemPrompt != null && modelConfig.systemPrompt!.trim().isNotEmpty) {
      effectiveSystem = modelConfig.systemPrompt!.trim();
      sources['system_prompt'] = ParameterSource.modelOverride;
    } else {
      effectiveSystem = settings.systemPrompt;
      sources['system_prompt'] = ParameterSource.globalDefault;
    }

    // 14. Keep Alive
    String effectiveKeepAlive;
    if (conversationOverrides != null && conversationOverrides.containsKey('keep_alive')) {
      effectiveKeepAlive = conversationOverrides['keep_alive'] as String;
      sources['keep_alive'] = ParameterSource.conversation;
    } else if (modelConfig.keepAlive != null) {
      effectiveKeepAlive = modelConfig.keepAlive!;
      sources['keep_alive'] = ParameterSource.modelOverride;
    } else {
      effectiveKeepAlive = '5m';
      sources['keep_alive'] = ParameterSource.backendDefault;
    }

    // 15. JSON Output Mode
    bool effectiveJsonMode;
    if (conversationOverrides != null && conversationOverrides.containsKey('json_output_mode')) {
      effectiveJsonMode = conversationOverrides['json_output_mode'] as bool;
      sources['json_output_mode'] = ParameterSource.conversation;
    } else if (modelConfig.jsonOutputMode != null) {
      effectiveJsonMode = modelConfig.jsonOutputMode!;
      sources['json_output_mode'] = ParameterSource.modelOverride;
    } else {
      effectiveJsonMode = false;
      sources['json_output_mode'] = ParameterSource.backendDefault;
    }

    // 16. Mirostat
    int effectiveMirostat = modelConfig.mirostat ?? 0;
    sources['mirostat'] = modelConfig.mirostat != null ? ParameterSource.modelOverride : ParameterSource.backendDefault;

    double effectiveMirostatTau = modelConfig.mirostatTau ?? 5.0;
    double effectiveMirostatEta = modelConfig.mirostatEta ?? 0.1;

    // 17. Seed
    int? effectiveSeed;
    if (conversationOverrides != null && conversationOverrides.containsKey('seed')) {
      effectiveSeed = conversationOverrides['seed'] as int?;
      sources['seed'] = ParameterSource.conversation;
    } else if (modelConfig.seed != null) {
      effectiveSeed = modelConfig.seed;
      sources['seed'] = ParameterSource.modelOverride;
    }

    // 18. RAG Settings
    bool effectiveRag = modelConfig.ragEnabled ?? true;
    sources['rag_enabled'] = modelConfig.ragEnabled != null ? ParameterSource.modelOverride : ParameterSource.globalDefault;

    int effectiveDocCount = modelConfig.retrievedDocCount ?? 3;
    sources['retrieved_doc_count'] = modelConfig.retrievedDocCount != null ? ParameterSource.modelOverride : ParameterSource.globalDefault;

    double effectiveSimilarity = modelConfig.similarityThreshold ?? 0.45;
    sources['similarity_threshold'] = modelConfig.similarityThreshold != null ? ParameterSource.modelOverride : ParameterSource.globalDefault;

    return ResolvedGenerationParameters(
      modelId: modelId,
      temperature: effectiveTemp,
      topP: effectiveTopP,
      topK: effectiveTopK,
      minP: effectiveMinP,
      typicalP: effectiveTypicalP,
      repeatPenalty: effectiveRepeatPenalty,
      repeatLastN: effectiveRepeatLastN,
      presencePenalty: effectivePresencePenalty,
      frequencyPenalty: effectiveFrequencyPenalty,
      maxTokens: effectiveMaxTokens,
      stopSequences: effectiveStop,
      seed: effectiveSeed,
      contextLength: effectiveContextLength,
      keepAlive: effectiveKeepAlive,
      systemPrompt: effectiveSystem,
      jsonOutputMode: effectiveJsonMode,
      mirostat: effectiveMirostat,
      mirostatTau: effectiveMirostatTau,
      mirostatEta: effectiveMirostatEta,
      numThreads: modelConfig.numThreads,
      numGpuLayers: modelConfig.numGpuLayers,
      f16Kv: modelConfig.f16Kv ?? false,
      flashAttention: modelConfig.flashAttention ?? false,
      ragEnabled: effectiveRag,
      retrievedDocCount: effectiveDocCount,
      similarityThreshold: effectiveSimilarity,
      embeddingModel: modelConfig.embeddingModelOverride,
      rerankerModel: modelConfig.rerankerModelOverride,
      parameterSources: sources,
    );
  }
}
