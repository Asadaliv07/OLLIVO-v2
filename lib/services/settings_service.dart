import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';

/// Centralized Persistent Settings Service for Ollivo macOS Desktop (SET-001)
/// Handles all 10 Settings Categories, per-model configuration fallbacks, storage management, and export/import.
class SettingsService extends ChangeNotifier {
  static SharedPreferences? _prefs;

  // --- Category 1: General Keys ---
  static const String _keyLaunchAtLogin = 'launch_at_login';
  static const String _keyStartMinimized = 'gen_start_minimized';
  static const String _keyDefaultAppView = 'gen_default_app_view';
  static const String _keyDefaultChatMode = 'gen_default_chat_mode';
  static const String _keyAutoTitleGeneration = 'gen_auto_title_gen';
  static const String _keyConfirmDeleteConversations = 'gen_confirm_delete_conversations';
  static const String _keyConfirmRemoveModels = 'gen_confirm_remove_models';
  static const String _keyRestorePreviousSession = 'gen_restore_session';
  static const String _keyRememberWindowBounds = 'gen_remember_window_bounds';
  static const String _keyLocalePreference = 'gen_locale_preference';
  static const String _keyDateFormat = 'gen_date_format';
  static const String _keyTimeFormat = 'gen_time_format';
  static const String _keyShowTooltips = 'gen_show_tooltips';
  static const String _keyDesktopNotifications = 'gen_desktop_notifications';
  static const String _keyUpdateCheckInterval = 'gen_update_check_interval';

  // --- Category 2: Appearance & Interface Keys ---
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyAccentColorName = 'app_accent_color';
  static const String _keyInterfaceDensity = 'app_interface_density';
  static const String _keySidebarWidth = 'app_sidebar_width';
  static const String _keyChatContentMaxWidth = 'app_chat_content_max_width';
  static const String _keyMessageSpacing = 'app_message_spacing';
  static const String _keyUiFontFamily = 'app_ui_font_family';
  static const String _keyUiFontSize = 'app_ui_font_size';
  static const String _keyChatFontSize = 'app_chat_font_size';
  static const String _keyCodeFontSize = 'app_code_font_size';
  static const String _keySyntaxHighlightTheme = 'app_syntax_theme';
  static const String _keyRoundedCornerStyle = 'app_rounded_style';
  static const String _keyShowAvatars = 'app_show_avatars';
  static const String _keyShowTimestamps = 'app_show_timestamps';
  static const String _keyShowTokenCounts = 'app_show_token_counts';
  static const String _keyShowGenerationSpeed = 'app_show_gen_speed';
  static const String _keyShowContextUtilization = 'app_show_ctx_utilization';
  static const String _keyShowModelStatus = 'app_show_model_status';
  static const String _keyReducedMotion = 'app_reduced_motion';
  static const String _keyStreamingDisplayMode = 'app_streaming_display_mode';

  // --- Category 3: Chat & Response Behavior Keys ---
  static const String _keyActiveModel = 'active_model';
  static const String _keyChatTemperature = 'chat_temperature';
  static const String _keyContextWindow = 'model_context_window';
  static const String _keyTopP = 'model_top_p';
  static const String _keyTopK = 'model_top_k';
  static const String _keyMinP = 'chat_min_p';
  static const String _keyTypicalP = 'chat_typical_p';
  static const String _keyRepeatPenalty = 'model_repeat_penalty';
  static const String _keyRepeatLastN = 'chat_repeat_last_n';
  static const String _keyPresencePenalty = 'chat_presence_penalty';
  static const String _keyFrequencyPenalty = 'chat_frequency_penalty';
  static const String _keyMaxOutputTokens = 'chat_max_output_tokens';
  static const String _keyStopSequences = 'chat_stop_sequences';
  static const String _keySeed = 'chat_seed';
  static const String _keySystemPrompt = 'model_system_prompt';
  static const String _keyStreamingEnabled = 'chat_streaming_enabled';
  static const String _keyKeepAliveDuration = 'chat_keep_alive_duration';
  static const String _keyJsonOutputMode = 'chat_json_output_mode';
  static const String _keyAutoScrollDuringGeneration = 'chat_auto_scroll';
  static const String _keyHistoryLimit = 'chat_history_limit';
  static const String _keyRequestTimeoutSeconds = 'chat_request_timeout';
  static const String _keyRetryOnFailure = 'chat_retry_on_failure';

  // --- Category 4: Runtime & Engine Keys ---
  static const String _keyOllamaHost = 'ollama_host';
  static const String _keyActiveBackend = 'runtime_active_backend';
  static const String _keyConnectionTimeoutSeconds = 'runtime_conn_timeout';
  static const String _keyQueuePolicy = 'runtime_queue_policy';
  static const String _keyWarnRemoteEndpoints = 'runtime_warn_remote';
  static const String _keyAirllmEnabled = 'airllm_enabled';
  static const String _keyAirllmHost = 'airllm_host';
  static const String _keyAirllmModel = 'airllm_model';
  static const String _keyAirllmCompression = 'airllm_compression';
  static const String _keyAirllmDevice = 'airllm_device';
  static const String _keyAirllmShardsPath = 'airllm_shards_path';
  static const String _keyAirllmAutoLaunch = 'airllm_auto_launch';

  // --- Category 5: Performance & Hardware Keys ---
  static const String _keyMaxConcurrentModelLoads = 'perf_max_model_loads';
  static const String _keyAutoUnloadIdleMinutes = 'perf_auto_unload_idle_min';
  static const String _keyPerformanceMetricsCollection = 'perf_metrics_collection';

  // --- Category 6: Storage Locations & Download Keys ---
  static const String _keyDocumentsPath = 'storage_documents_path';
  static const String _keyEmbeddingsPath = 'storage_embeddings_path';
  static const String _keyBackupsPath = 'storage_backups_path';
  static const String _keyDatabasePath = 'storage_database_path';
  static const String _keyDownloadConcurrency = 'storage_download_concurrency';
  static const String _keyDownloadBandwidthLimit = 'storage_download_bw_limit';
  static const String _keyDiskSpaceWarningThresholdGb = 'storage_disk_warning_gb';

  // --- Category 7: Knowledge & RAG Keys ---
  static const String _keyRagGloballyEnabled = 'rag_globally_enabled';
  static const String _keyDefaultEmbeddingModel = 'rag_default_embedding_model';
  static const String _keyDefaultRerankerModel = 'rag_default_reranker_model';
  static const String _keyRagChunkSize = 'rag_chunk_size';
  static const String _keyRagChunkOverlap = 'rag_chunk_overlap';
  static const String _keyRagRetrievalTopK = 'rag_retrieval_top_k';
  static const String _keyRagSimilarityThreshold = 'rag_similarity_threshold';
  static const String _keyRagHybridSearch = 'rag_hybrid_search';
  static const String _keyRagShowCitations = 'rag_show_citations';
  static const String _keyRagMaxContextTokens = 'rag_max_context_tokens';

  // --- Category 8: Multimodal Keys ---
  static const String _keyDefaultVisionModel = 'multi_default_vision_model';
  static const String _keyDefaultOcrModel = 'multi_default_ocr_model';
  static const String _keyDefaultAudioModel = 'multi_default_audio_model';
  static const String _keyVideoFrameInterval = 'multi_video_frame_interval';
  static const String _keyVideoMaxSampledFrames = 'multi_video_max_frames';
  static const String _keyImageMaxDimension = 'multi_image_max_dim';
  static const String _keyMediaAutoCleanup = 'multi_media_auto_cleanup';

  // --- Category 9: Privacy & Security Keys ---
  static const String _keyStrictLocalOnly = 'sec_strict_local_only';
  static const String _keyMaskSensitiveSecrets = 'sec_mask_secrets';
  static const String _keyConversationRetentionDays = 'sec_conversation_retention_days';
  static const String _keyTelemetryOptIn = 'sec_telemetry_opt_in';

  // --- Category 10: Advanced Developer Keys ---
  static const String _keyShowDeveloperSettings = 'dev_show_settings';
  static const String _keyVerboseLogging = 'dev_verbose_logging';
  static const String _keyExperimentalFeatures = 'dev_experimental_features';

  // Desktop State Restoration Keys (MAC-004)
  static const String _keyLastSelectedTab = 'desktop_last_selected_tab';
  static const String _keySidebarVisible = 'desktop_sidebar_visible';
  static const String _keyFavoriteModels = 'favorite_models';
  static const String _keyRecentModels = 'recent_models';
  static const String _keyActiveKnowledgeBase = 'active_knowledge_base';

  bool _initialized = false;
  bool get isInitialized => _initialized;

  // Cached General Properties
  bool _launchAtLogin = false;
  bool _startMinimized = false;
  String _defaultAppView = 'chat';
  String _defaultChatMode = 'chat';
  bool _autoTitleGeneration = true;
  bool _confirmDeleteConversations = true;
  bool _confirmRemoveModels = true;
  bool _restorePreviousSession = true;
  bool _rememberWindowBounds = true;
  String _localePreference = 'en_US';
  String _dateFormat = 'MMM d, yyyy';
  String _timeFormat = '12h';
  bool _showTooltips = true;
  bool _desktopNotifications = true;
  String _updateCheckInterval = 'weekly';

  // Cached Appearance Properties
  String _themeMode = 'dark';
  String _accentColorName = 'emerald';
  String _interfaceDensity = 'comfortable';
  double _sidebarWidth = 240.0;
  double _chatContentMaxWidth = 860.0;
  double _messageSpacing = 16.0;
  String _uiFontFamily = 'System SF Pro';
  double _uiFontSize = 13.0;
  double _chatFontSize = 14.0;
  double _codeFontSize = 13.0;
  String _syntaxHighlightTheme = 'atom-one-dark';
  String _roundedCornerStyle = 'modern';
  bool _showAvatars = true;
  bool _showTimestamps = true;
  bool _showTokenCounts = true;
  bool _showGenerationSpeed = true;
  bool _showContextUtilization = true;
  bool _showModelStatus = true;
  bool _reducedMotion = false;
  String _streamingDisplayMode = 'token';

  // Cached Chat Properties
  String _activeModel = AppConstants.defaultModel;
  double _chatTemperature = 0.7;
  int _contextWindow = 4096;
  double _topP = 0.9;
  int _topK = 40;
  double _minP = 0.0;
  double _typicalP = 1.0;
  double _repeatPenalty = 1.1;
  int _repeatLastN = 64;
  double _presencePenalty = 0.0;
  double _frequencyPenalty = 0.0;
  int _maxOutputTokens = 2048;
  List<String> _stopSequences = [];
  int _seed = -1;
  String _systemPrompt = '';
  bool _streamingEnabled = true;
  String _keepAliveDuration = '5m';
  bool _jsonOutputMode = false;
  bool _autoScrollDuringGeneration = true;
  int _historyLimit = 20;
  int _requestTimeoutSeconds = 60;
  bool _retryOnFailure = false;

  // Cached Runtime Properties
  String _ollamaHost = AppConstants.defaultOllamaHost;
  String _activeBackend = 'ollama';
  int _connectionTimeoutSeconds = 10;
  String _queuePolicy = 'queue_fifo';
  bool _warnRemoteEndpoints = true;
  bool _airllmEnabled = false;
  String _airllmHost = 'http://127.0.0.1:8765';
  String _airllmModel = 'meta-llama/Meta-Llama-3-8B-Instruct';
  String _airllmCompression = '4bit';
  String _airllmDevice = 'auto';
  String _airllmShardsPath = '';
  bool _airllmAutoLaunch = true;

  // Cached Performance Properties
  int _maxConcurrentModelLoads = 1;
  int _autoUnloadIdleMinutes = 15;
  bool _performanceMetricsCollection = true;

  // Cached Storage Properties
  String _documentsPath = '';
  String _embeddingsPath = '';
  String _backupsPath = '';
  String _databasePath = '';
  String _defaultAppSupportPath = '';
  int _downloadConcurrency = 1;
  int _downloadBandwidthLimit = 0;
  double _diskSpaceWarningThresholdGb = 5.0;

  // Cached RAG Properties
  bool _ragGloballyEnabled = true;
  String _defaultEmbeddingModel = 'nomic-embed-text:latest';
  String _defaultRerankerModel = 'bge-reranker-v2-m3:latest';
  int _ragChunkSize = 512;
  int _ragChunkOverlap = 64;
  int _ragRetrievalTopK = 3;
  double _ragSimilarityThreshold = 0.45;
  bool _ragHybridSearch = true;
  bool _ragShowCitations = true;
  int _ragMaxContextTokens = 1536;

  // Cached Multimodal Properties
  String _defaultVisionModel = 'qwen2.5-vl:7b';
  String _defaultOcrModel = 'got-ocr2:latest';
  String _defaultAudioModel = 'whisper-large-v3-turbo:latest';
  double _videoFrameInterval = 1.0;
  int _videoMaxSampledFrames = 16;
  int _imageMaxDimension = 1536;
  bool _mediaAutoCleanup = true;

  // Cached Privacy Properties
  bool _strictLocalOnly = false;
  bool _maskSensitiveSecrets = true;
  int _conversationRetentionDays = 0;
  bool _telemetryOptIn = false;

  // Cached Developer Properties
  bool _showDeveloperSettings = false;
  bool _verboseLogging = false;
  bool _experimentalFeatures = false;

  bool _checkForUpdates = true;
  String _codeFontFamily = 'SF Mono';
  bool _showCopyButton = true;
  bool _autoUnloadOnMemoryPressure = true;
  bool _preloadActiveModelOnLaunch = false;
  String _ocrEngine = 'apple_vision';
  int _maxImagesPerPrompt = 4;
  int _maxPdfPageCount = 20;

  // Desktop State Restoration Properties
  int _lastSelectedTab = 0;
  bool _sidebarVisible = true;
  List<String> _favoriteModels = [];
  List<String> _recentModels = [];
  String _activeKnowledgeBase = 'default';

  // --- Getters: General ---
  bool get launchAtLogin => _launchAtLogin;
  bool get startMinimized => _startMinimized;
  String get defaultAppView => _defaultAppView;
  String get defaultChatMode => _defaultChatMode;
  bool get autoTitleGeneration => _autoTitleGeneration;
  bool get confirmDeleteConversations => _confirmDeleteConversations;
  bool get confirmRemoveModels => _confirmRemoveModels;
  bool get restorePreviousSession => _restorePreviousSession;
  bool get rememberWindowBounds => _rememberWindowBounds;
  String get localePreference => _localePreference;
  String get dateFormat => _dateFormat;
  String get timeFormat => _timeFormat;
  bool get showTooltips => _showTooltips;
  bool get desktopNotifications => _desktopNotifications;
  String get updateCheckInterval => _updateCheckInterval;

  // --- Getters: Appearance ---
  String get themeMode => _themeMode;
  String get accentColorName => _accentColorName;
  String get interfaceDensity => _interfaceDensity;
  double get sidebarWidth => _sidebarWidth;
  double get chatContentMaxWidth => _chatContentMaxWidth;
  double get messageSpacing => _messageSpacing;
  String get uiFontFamily => _uiFontFamily;
  double get uiFontSize => _uiFontSize;
  double get chatFontSize => _chatFontSize;
  double get codeFontSize => _codeFontSize;
  String get syntaxHighlightTheme => _syntaxHighlightTheme;
  String get roundedCornerStyle => _roundedCornerStyle;
  bool get showAvatars => _showAvatars;
  bool get showTimestamps => _showTimestamps;
  bool get showTokenCounts => _showTokenCounts;
  bool get showGenerationSpeed => _showGenerationSpeed;
  bool get showContextUtilization => _showContextUtilization;
  bool get showModelStatus => _showModelStatus;
  bool get reducedMotion => _reducedMotion;
  String get streamingDisplayMode => _streamingDisplayMode;

  // --- Getters: Chat Defaults ---
  String get activeModel => _activeModel;
  double get chatTemperature => _chatTemperature;
  int get contextWindow => _contextWindow;
  double get topP => _topP;
  int get topK => _topK;
  double get minP => _minP;
  double get typicalP => _typicalP;
  double get repeatPenalty => _repeatPenalty;
  int get repeatLastN => _repeatLastN;
  double get presencePenalty => _presencePenalty;
  double get frequencyPenalty => _frequencyPenalty;
  int get maxOutputTokens => _maxOutputTokens;
  List<String> get stopSequences => List.unmodifiable(_stopSequences);
  int get seed => _seed;
  String get systemPrompt => _systemPrompt;
  bool get streamingEnabled => _streamingEnabled;
  String get keepAliveDuration => _keepAliveDuration;
  bool get jsonOutputMode => _jsonOutputMode;
  bool get autoScrollDuringGeneration => _autoScrollDuringGeneration;
  int get historyLimit => _historyLimit;
  int get requestTimeoutSeconds => _requestTimeoutSeconds;
  bool get retryOnFailure => _retryOnFailure;

  // --- Getters: Runtime ---
  String get ollamaHost => _ollamaHost;
  String get activeBackend => _activeBackend;
  int get connectionTimeoutSeconds => _connectionTimeoutSeconds;
  String get queuePolicy => _queuePolicy;
  bool get warnRemoteEndpoints => _warnRemoteEndpoints;
  bool get airllmEnabled => _airllmEnabled;
  String get airllmHost => _airllmHost;
  String get airllmModel => _airllmModel;
  String get airllmCompression => _airllmCompression;
  String get airllmDevice => _airllmDevice;
  String get airllmShardsPath => _airllmShardsPath;
  bool get airllmAutoLaunch => _airllmAutoLaunch;

  // Central Inference Engine Routing (AIR-ROUTER-001)
  /// Authoritative active inference backend ('airllm' when enabled, else configured backend e.g. 'ollama')
  String get effectiveInferenceBackend => _airllmEnabled ? 'airllm' : _activeBackend;

  /// Authoritative endpoint URL for active text inference
  String get effectiveInferenceHost => _airllmEnabled ? _airllmHost : _ollamaHost;

  /// Authoritative model identifier for active text inference
  String get effectiveInferenceModel => _airllmEnabled ? _airllmModel : _activeModel;

  // --- Getters: Performance ---
  int get maxConcurrentModelLoads => _maxConcurrentModelLoads;
  int get autoUnloadIdleMinutes => _autoUnloadIdleMinutes;
  bool get performanceMetricsCollection => _performanceMetricsCollection;

  // --- Getters: Storage ---
  String get documentsPath => _documentsPath;
  String get embeddingsPath => _embeddingsPath;
  String get backupsPath => _backupsPath;
  String get databasePath => _databasePath;
  String get defaultAppSupportPath => _defaultAppSupportPath;
  int get downloadConcurrency => _downloadConcurrency;
  int get downloadBandwidthLimit => _downloadBandwidthLimit;
  double get diskSpaceWarningThresholdGb => _diskSpaceWarningThresholdGb;

  // --- Getters: RAG ---
  bool get ragGloballyEnabled => _ragGloballyEnabled;
  String get defaultEmbeddingModel => _defaultEmbeddingModel;
  String get defaultRerankerModel => _defaultRerankerModel;
  int get ragChunkSize => _ragChunkSize;
  int get ragChunkOverlap => _ragChunkOverlap;
  int get ragRetrievalTopK => _ragRetrievalTopK;
  double get ragSimilarityThreshold => _ragSimilarityThreshold;
  bool get ragHybridSearch => _ragHybridSearch;
  bool get ragShowCitations => _ragShowCitations;
  int get ragMaxContextTokens => _ragMaxContextTokens;

  // --- Getters: Multimodal ---
  String get defaultVisionModel => _defaultVisionModel;
  String get defaultOcrModel => _defaultOcrModel;
  String get defaultAudioModel => _defaultAudioModel;
  double get videoFrameInterval => _videoFrameInterval;
  int get videoMaxSampledFrames => _videoMaxSampledFrames;
  int get imageMaxDimension => _imageMaxDimension;
  bool get mediaAutoCleanup => _mediaAutoCleanup;

  // --- Getters: Privacy ---
  bool get strictLocalOnly => _strictLocalOnly;
  bool get maskSensitiveSecrets => _maskSensitiveSecrets;
  int get conversationRetentionDays => _conversationRetentionDays;
  bool get telemetryOptIn => _telemetryOptIn;

  // --- Getters: Developer ---
  bool get showDeveloperSettings => _showDeveloperSettings;
  bool get verboseLogging => _verboseLogging;
  bool get experimentalFeatures => _experimentalFeatures;

  // --- Desktop Session ---
  int get lastSelectedTab => _lastSelectedTab;
  bool get sidebarVisible => _sidebarVisible;
  List<String> get favoriteModels => List.unmodifiable(_favoriteModels);
  List<String> get recentModels => List.unmodifiable(_recentModels);
  String get activeKnowledgeBase => _activeKnowledgeBase;

  // --- Convenience Getters & Aliases for Settings UI & Controllers ---
  bool get rememberWindowPosition => _rememberWindowBounds;
  Future<void> setRememberWindowPosition(bool value) => setRememberWindowBounds(value);

  bool get confirmDeleteConversation => _confirmDeleteConversations;
  Future<void> setConfirmDeleteConversation(bool value) => setConfirmDeleteConversations(value);

  bool get confirmRemoveModel => _confirmRemoveModels;
  Future<void> setConfirmRemoveModel(bool value) => setConfirmRemoveModels(value);

  String get appLocale {
    if (_localePreference == 'en_GB' || _localePreference == 'de' || _localePreference == 'fr' || _localePreference == 'ja') {
      return _localePreference;
    }
    return 'en';
  }
  Future<void> setAppLocale(String value) => setLocalePreference(value);

  bool get checkForUpdates => _checkForUpdates;
  Future<void> setCheckForUpdates(bool value) async {
    _checkForUpdates = value;
    await _prefs?.setBool('gen_check_for_updates', value);
    notifyListeners();
  }

  String get accentColor => _accentColorName;
  Future<void> setAccentColor(String value) => setAccentColorName(value);

  String get codeFontFamily => _codeFontFamily;
  Future<void> setCodeFontFamily(String value) async {
    _codeFontFamily = value;
    await _prefs?.setString('app_code_font_family', value);
    notifyListeners();
  }

  bool get showPerformanceMetrics => _showGenerationSpeed;
  Future<void> setShowPerformanceMetrics(bool value) => setShowGenerationSpeed(value);

  bool get showCopyButton => _showCopyButton;
  Future<void> setShowCopyButton(bool value) async {
    _showCopyButton = value;
    await _prefs?.setBool('chat_show_copy_button', value);
    notifyListeners();
  }

  String get defaultKeepAlive => _keepAliveDuration;
  Future<void> setDefaultKeepAlive(String value) => setKeepAliveDuration(value);

  bool get autoUnloadOnMemoryPressure => _autoUnloadOnMemoryPressure;
  Future<void> setAutoUnloadOnMemoryPressure(bool value) async {
    _autoUnloadOnMemoryPressure = value;
    await _prefs?.setBool('perf_auto_unload_mem_pressure', value);
    notifyListeners();
  }

  bool get preloadActiveModelOnLaunch => _preloadActiveModelOnLaunch;
  Future<void> setPreloadActiveModelOnLaunch(bool value) async {
    _preloadActiveModelOnLaunch = value;
    await _prefs?.setBool('perf_preload_active_model', value);
    notifyListeners();
  }

  bool get collectPerformanceTelemetry => _performanceMetricsCollection;
  Future<void> setCollectPerformanceTelemetry(bool value) => setPerformanceMetricsCollection(value);

  bool get ragEnabled => _ragGloballyEnabled;
  Future<void> setRagEnabled(bool value) => setRagGloballyEnabled(value);

  bool get showCitations => _ragShowCitations;
  Future<void> setShowCitations(bool value) => setRagShowCitations(value);

  int get ragTopK => _ragRetrievalTopK;
  Future<void> setRagTopK(int value) => setRagRetrievalTopK(value);

  String get embeddingModel => _defaultEmbeddingModel;
  Future<void> setEmbeddingModel(String value) => setDefaultEmbeddingModel(value);

  String get ocrEngine => _ocrEngine;
  Future<void> setOcrEngine(String value) async {
    _ocrEngine = value;
    await _prefs?.setString('multi_ocr_engine', value);
    notifyListeners();
  }

  String get visionModel => _defaultVisionModel;
  Future<void> setVisionModel(String value) => setDefaultVisionModel(value);

  int get maxImagesPerPrompt => _maxImagesPerPrompt;
  Future<void> setMaxImagesPerPrompt(int value) async {
    _maxImagesPerPrompt = value;
    await _prefs?.setInt('multi_max_images_per_prompt', value);
    notifyListeners();
  }

  int get maxPdfPageCount => _maxPdfPageCount;
  Future<void> setMaxPdfPageCount(int value) async {
    _maxPdfPageCount = value;
    await _prefs?.setInt('multi_max_pdf_page_count', value);
    notifyListeners();
  }

  bool get autoCleanupMediaOnExit => _mediaAutoCleanup;
  Future<void> setAutoCleanupMediaOnExit(bool value) => setMediaAutoCleanup(value);

  bool get localOnlyMode => _strictLocalOnly;
  Future<void> setLocalOnlyMode(bool value) => setStrictLocalOnly(value);

  bool get warnOnRemoteEndpoint => _warnRemoteEndpoints;
  Future<void> setWarnOnRemoteEndpoint(bool value) => setWarnRemoteEndpoints(value);

  bool get redactSecretsInLogs => _maskSensitiveSecrets;
  Future<void> setRedactSecretsInLogs(bool value) => setMaskSensitiveSecrets(value);

  bool get showAdvancedControls => _showDeveloperSettings;
  Future<void> setShowAdvancedControls(bool value) => setShowDeveloperSettings(value);

  /// Initialize persistent settings from SharedPreferences & path_provider
  Future<void> init({SharedPreferences? testPrefs, String? testAppSupportPath}) async {
    if (_initialized && testPrefs == null && testAppSupportPath == null) return;

    _prefs = testPrefs ?? await SharedPreferences.getInstance();

    if (testAppSupportPath != null) {
      _defaultAppSupportPath = testAppSupportPath;
    } else {
      try {
        if (Platform.isMacOS) {
          final appSupportDir = await getApplicationSupportDirectory();
          _defaultAppSupportPath = appSupportDir.path;
        } else {
          _defaultAppSupportPath = Directory.current.path;
        }
      } catch (_) {
        _defaultAppSupportPath = Directory.current.path;
      }
    }

    // 1. General
    _launchAtLogin = _prefs?.getBool(_keyLaunchAtLogin) ?? false;
    _startMinimized = _prefs?.getBool(_keyStartMinimized) ?? false;
    _defaultAppView = _prefs?.getString(_keyDefaultAppView) ?? 'chat';
    _defaultChatMode = _prefs?.getString(_keyDefaultChatMode) ?? 'chat';
    _autoTitleGeneration = _prefs?.getBool(_keyAutoTitleGeneration) ?? true;
    _confirmDeleteConversations = _prefs?.getBool(_keyConfirmDeleteConversations) ?? true;
    _confirmRemoveModels = _prefs?.getBool(_keyConfirmRemoveModels) ?? true;
    _restorePreviousSession = _prefs?.getBool(_keyRestorePreviousSession) ?? true;
    _rememberWindowBounds = _prefs?.getBool(_keyRememberWindowBounds) ?? true;
    _localePreference = _prefs?.getString(_keyLocalePreference) ?? 'en_US';
    _dateFormat = _prefs?.getString(_keyDateFormat) ?? 'MMM d, yyyy';
    _timeFormat = _prefs?.getString(_keyTimeFormat) ?? '12h';
    _showTooltips = _prefs?.getBool(_keyShowTooltips) ?? true;
    _desktopNotifications = _prefs?.getBool(_keyDesktopNotifications) ?? true;
    _updateCheckInterval = _prefs?.getString(_keyUpdateCheckInterval) ?? 'weekly';

    // 2. Appearance
    _themeMode = _prefs?.getString(_keyThemeMode) ?? 'dark';
    _accentColorName = _prefs?.getString(_keyAccentColorName) ?? 'emerald';
    _interfaceDensity = _prefs?.getString(_keyInterfaceDensity) ?? 'comfortable';
    _sidebarWidth = _prefs?.getDouble(_keySidebarWidth) ?? 240.0;
    _chatContentMaxWidth = _prefs?.getDouble(_keyChatContentMaxWidth) ?? 860.0;
    _messageSpacing = _prefs?.getDouble(_keyMessageSpacing) ?? 16.0;
    _uiFontFamily = _prefs?.getString(_keyUiFontFamily) ?? 'System SF Pro';
    _uiFontSize = _prefs?.getDouble(_keyUiFontSize) ?? 13.0;
    _chatFontSize = _prefs?.getDouble(_keyChatFontSize) ?? 14.0;
    _codeFontSize = _prefs?.getDouble(_keyCodeFontSize) ?? 13.0;
    _syntaxHighlightTheme = _prefs?.getString(_keySyntaxHighlightTheme) ?? 'atom-one-dark';
    _roundedCornerStyle = _prefs?.getString(_keyRoundedCornerStyle) ?? 'modern';
    _showAvatars = _prefs?.getBool(_keyShowAvatars) ?? true;
    _showTimestamps = _prefs?.getBool(_keyShowTimestamps) ?? true;
    _showTokenCounts = _prefs?.getBool(_keyShowTokenCounts) ?? true;
    _showGenerationSpeed = _prefs?.getBool(_keyShowGenerationSpeed) ?? true;
    _showContextUtilization = _prefs?.getBool(_keyShowContextUtilization) ?? true;
    _showModelStatus = _prefs?.getBool(_keyShowModelStatus) ?? true;
    _reducedMotion = _prefs?.getBool(_keyReducedMotion) ?? false;
    _streamingDisplayMode = _prefs?.getString(_keyStreamingDisplayMode) ?? 'token';

    // 3. Chat Defaults
    _activeModel = _prefs?.getString(_keyActiveModel) ?? AppConstants.defaultModel;
    _chatTemperature = _prefs?.getDouble(_keyChatTemperature) ?? 0.7;
    _contextWindow = _prefs?.getInt(_keyContextWindow) ?? 4096;
    _topP = _prefs?.getDouble(_keyTopP) ?? 0.9;
    _topK = _prefs?.getInt(_keyTopK) ?? 40;
    _minP = _prefs?.getDouble(_keyMinP) ?? 0.0;
    _typicalP = _prefs?.getDouble(_keyTypicalP) ?? 1.0;
    _repeatPenalty = _prefs?.getDouble(_keyRepeatPenalty) ?? 1.1;
    _repeatLastN = _prefs?.getInt(_keyRepeatLastN) ?? 64;
    _presencePenalty = _prefs?.getDouble(_keyPresencePenalty) ?? 0.0;
    _frequencyPenalty = _prefs?.getDouble(_keyFrequencyPenalty) ?? 0.0;
    _maxOutputTokens = _prefs?.getInt(_keyMaxOutputTokens) ?? 2048;
    _stopSequences = _prefs?.getStringList(_keyStopSequences) ?? [];
    _seed = _prefs?.getInt(_keySeed) ?? -1;
    _systemPrompt = _prefs?.getString(_keySystemPrompt) ?? '';
    _streamingEnabled = _prefs?.getBool(_keyStreamingEnabled) ?? true;
    _keepAliveDuration = _prefs?.getString(_keyKeepAliveDuration) ?? '5m';
    _jsonOutputMode = _prefs?.getBool(_keyJsonOutputMode) ?? false;
    _autoScrollDuringGeneration = _prefs?.getBool(_keyAutoScrollDuringGeneration) ?? true;
    _historyLimit = _prefs?.getInt(_keyHistoryLimit) ?? 20;
    _requestTimeoutSeconds = _prefs?.getInt(_keyRequestTimeoutSeconds) ?? 60;
    _retryOnFailure = _prefs?.getBool(_keyRetryOnFailure) ?? false;

    // 4. Runtime
    _ollamaHost = _prefs?.getString(_keyOllamaHost) ?? AppConstants.defaultOllamaHost;
    _activeBackend = _prefs?.getString(_keyActiveBackend) ?? 'ollama';
    _connectionTimeoutSeconds = _prefs?.getInt(_keyConnectionTimeoutSeconds) ?? 10;
    _queuePolicy = _prefs?.getString(_keyQueuePolicy) ?? 'queue_fifo';
    _warnRemoteEndpoints = _prefs?.getBool(_keyWarnRemoteEndpoints) ?? true;
    _airllmEnabled = _prefs?.getBool(_keyAirllmEnabled) ?? false;
    _airllmHost = _prefs?.getString(_keyAirllmHost) ?? 'http://127.0.0.1:8765';
    _airllmModel = _prefs?.getString(_keyAirllmModel) ?? 'meta-llama/Meta-Llama-3-8B-Instruct';
    _airllmCompression = _prefs?.getString(_keyAirllmCompression) ?? '4bit';
    _airllmDevice = _prefs?.getString(_keyAirllmDevice) ?? 'auto';
    _airllmShardsPath = _prefs?.getString(_keyAirllmShardsPath) ?? '';
    _airllmAutoLaunch = _prefs?.getBool(_keyAirllmAutoLaunch) ?? true;

    // 5. Performance
    _maxConcurrentModelLoads = _prefs?.getInt(_keyMaxConcurrentModelLoads) ?? 1;
    _autoUnloadIdleMinutes = _prefs?.getInt(_keyAutoUnloadIdleMinutes) ?? 15;
    _performanceMetricsCollection = _prefs?.getBool(_keyPerformanceMetricsCollection) ?? true;

    // 6. Storage
    _documentsPath = _prefs?.getString(_keyDocumentsPath) ?? p.join(_defaultAppSupportPath, 'documents');
    _embeddingsPath = _prefs?.getString(_keyEmbeddingsPath) ?? p.join(_defaultAppSupportPath, 'embeddings');
    _backupsPath = _prefs?.getString(_keyBackupsPath) ?? p.join(_defaultAppSupportPath, 'backups');
    _databasePath = _prefs?.getString(_keyDatabasePath) ?? p.join(_defaultAppSupportPath, 'database');
    _downloadConcurrency = _prefs?.getInt(_keyDownloadConcurrency) ?? 1;
    _downloadBandwidthLimit = _prefs?.getInt(_keyDownloadBandwidthLimit) ?? 0;
    _diskSpaceWarningThresholdGb = _prefs?.getDouble(_keyDiskSpaceWarningThresholdGb) ?? 5.0;

    // 7. RAG
    _ragGloballyEnabled = _prefs?.getBool(_keyRagGloballyEnabled) ?? true;
    _defaultEmbeddingModel = _prefs?.getString(_keyDefaultEmbeddingModel) ?? 'nomic-embed-text:latest';
    _defaultRerankerModel = _prefs?.getString(_keyDefaultRerankerModel) ?? 'bge-reranker-v2-m3:latest';
    _ragChunkSize = _prefs?.getInt(_keyRagChunkSize) ?? 512;
    _ragChunkOverlap = _prefs?.getInt(_keyRagChunkOverlap) ?? 64;
    _ragRetrievalTopK = _prefs?.getInt(_keyRagRetrievalTopK) ?? 3;
    _ragSimilarityThreshold = _prefs?.getDouble(_keyRagSimilarityThreshold) ?? 0.45;
    _ragHybridSearch = _prefs?.getBool(_keyRagHybridSearch) ?? true;
    _ragShowCitations = _prefs?.getBool(_keyRagShowCitations) ?? true;
    _ragMaxContextTokens = _prefs?.getInt(_keyRagMaxContextTokens) ?? 1536;

    // 8. Multimodal
    _defaultVisionModel = _prefs?.getString(_keyDefaultVisionModel) ?? 'qwen2.5-vl:7b';
    _defaultOcrModel = _prefs?.getString(_keyDefaultOcrModel) ?? 'got-ocr2:latest';
    _defaultAudioModel = _prefs?.getString(_keyDefaultAudioModel) ?? 'whisper-large-v3-turbo:latest';
    _videoFrameInterval = _prefs?.getDouble(_keyVideoFrameInterval) ?? 1.0;
    _videoMaxSampledFrames = _prefs?.getInt(_keyVideoMaxSampledFrames) ?? 16;
    _imageMaxDimension = _prefs?.getInt(_keyImageMaxDimension) ?? 1536;
    _mediaAutoCleanup = _prefs?.getBool(_keyMediaAutoCleanup) ?? true;

    // 9. Privacy
    _strictLocalOnly = _prefs?.getBool(_keyStrictLocalOnly) ?? false;
    _maskSensitiveSecrets = _prefs?.getBool(_keyMaskSensitiveSecrets) ?? true;
    _conversationRetentionDays = _prefs?.getInt(_keyConversationRetentionDays) ?? 0;
    _telemetryOptIn = _prefs?.getBool(_keyTelemetryOptIn) ?? false;

    // 10. Developer
    _showDeveloperSettings = _prefs?.getBool(_keyShowDeveloperSettings) ?? false;
    _verboseLogging = _prefs?.getBool(_keyVerboseLogging) ?? false;
    _experimentalFeatures = _prefs?.getBool(_keyExperimentalFeatures) ?? false;

    _checkForUpdates = _prefs?.getBool('gen_check_for_updates') ?? true;
    _codeFontFamily = _prefs?.getString('app_code_font_family') ?? 'SF Mono';
    _showCopyButton = _prefs?.getBool('chat_show_copy_button') ?? true;
    _autoUnloadOnMemoryPressure = _prefs?.getBool('perf_auto_unload_mem_pressure') ?? true;
    _preloadActiveModelOnLaunch = _prefs?.getBool('perf_preload_active_model') ?? false;
    _ocrEngine = _prefs?.getString('multi_ocr_engine') ?? 'apple_vision';
    _maxImagesPerPrompt = _prefs?.getInt('multi_max_images_per_prompt') ?? 4;
    _maxPdfPageCount = _prefs?.getInt('multi_max_pdf_page_count') ?? 20;

    // Desktop State
    _lastSelectedTab = _prefs?.getInt(_keyLastSelectedTab) ?? 0;
    _sidebarVisible = _prefs?.getBool(_keySidebarVisible) ?? true;
    _favoriteModels = _prefs?.getStringList(_keyFavoriteModels) ?? [];
    _recentModels = _prefs?.getStringList(_keyRecentModels) ?? [];
    _activeKnowledgeBase = _prefs?.getString(_keyActiveKnowledgeBase) ?? 'default';

    // Ensure default directories exist
    await _ensureDirectoryExists(_documentsPath);
    await _ensureDirectoryExists(_embeddingsPath);
    await _ensureDirectoryExists(_backupsPath);
    await _ensureDirectoryExists(_databasePath);

    _initialized = true;
    notifyListeners();
  }

  Future<void> _ensureDirectoryExists(String path) async {
    if (path.isEmpty) return;
    try {
      final dir = Directory(path);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    } catch (_) {}
  }

  // --- Favorite & Recent Models ---
  Future<void> toggleFavorite(String modelId) async {
    if (_favoriteModels.contains(modelId)) {
      _favoriteModels.remove(modelId);
    } else {
      _favoriteModels.add(modelId);
    }
    await _prefs?.setStringList(_keyFavoriteModels, _favoriteModels);
    notifyListeners();
  }

  Future<void> addRecentModel(String modelId) async {
    if (modelId.trim().isEmpty) return;
    _recentModels.remove(modelId);
    _recentModels.insert(0, modelId);
    if (_recentModels.length > 10) {
      _recentModels = _recentModels.sublist(0, 10);
    }
    await _prefs?.setStringList(_keyRecentModels, _recentModels);
    notifyListeners();
  }

  Future<void> setActiveKnowledgeBase(String kbId) async {
    _activeKnowledgeBase = kbId;
    await _prefs?.setString(_keyActiveKnowledgeBase, kbId);
    notifyListeners();
  }

  // ==========================================
  // --- Setters: Category 1 General ---
  // ==========================================
  Future<void> setLaunchAtLogin(bool value) async {
    _launchAtLogin = value;
    await _prefs?.setBool(_keyLaunchAtLogin, value);
    notifyListeners();
  }

  Future<void> setStartMinimized(bool value) async {
    _startMinimized = value;
    await _prefs?.setBool(_keyStartMinimized, value);
    notifyListeners();
  }

  Future<void> setDefaultAppView(String value) async {
    _defaultAppView = value;
    await _prefs?.setString(_keyDefaultAppView, value);
    notifyListeners();
  }

  Future<void> setDefaultChatMode(String value) async {
    _defaultChatMode = value;
    await _prefs?.setString(_keyDefaultChatMode, value);
    notifyListeners();
  }

  Future<void> setAutoTitleGeneration(bool value) async {
    _autoTitleGeneration = value;
    await _prefs?.setBool(_keyAutoTitleGeneration, value);
    notifyListeners();
  }

  Future<void> setConfirmDeleteConversations(bool value) async {
    _confirmDeleteConversations = value;
    await _prefs?.setBool(_keyConfirmDeleteConversations, value);
    notifyListeners();
  }

  Future<void> setConfirmRemoveModels(bool value) async {
    _confirmRemoveModels = value;
    await _prefs?.setBool(_keyConfirmRemoveModels, value);
    notifyListeners();
  }

  Future<void> setRestorePreviousSession(bool value) async {
    _restorePreviousSession = value;
    await _prefs?.setBool(_keyRestorePreviousSession, value);
    notifyListeners();
  }

  Future<void> setRememberWindowBounds(bool value) async {
    _rememberWindowBounds = value;
    await _prefs?.setBool(_keyRememberWindowBounds, value);
    notifyListeners();
  }

  Future<void> setLocalePreference(String value) async {
    _localePreference = value;
    await _prefs?.setString(_keyLocalePreference, value);
    notifyListeners();
  }

  Future<void> setDateFormat(String value) async {
    _dateFormat = value;
    await _prefs?.setString(_keyDateFormat, value);
    notifyListeners();
  }

  Future<void> setTimeFormat(String value) async {
    _timeFormat = value;
    await _prefs?.setString(_keyTimeFormat, value);
    notifyListeners();
  }

  Future<void> setShowTooltips(bool value) async {
    _showTooltips = value;
    await _prefs?.setBool(_keyShowTooltips, value);
    notifyListeners();
  }

  Future<void> setDesktopNotifications(bool value) async {
    _desktopNotifications = value;
    await _prefs?.setBool(_keyDesktopNotifications, value);
    notifyListeners();
  }

  Future<void> setUpdateCheckInterval(String value) async {
    _updateCheckInterval = value;
    await _prefs?.setString(_keyUpdateCheckInterval, value);
    notifyListeners();
  }

  // ==========================================
  // --- Setters: Category 2 Appearance ---
  // ==========================================
  Future<void> setThemeMode(String mode) async {
    _themeMode = mode;
    await _prefs?.setString(_keyThemeMode, mode);
    notifyListeners();
  }

  Future<void> setAccentColorName(String name) async {
    _accentColorName = name;
    await _prefs?.setString(_keyAccentColorName, name);
    notifyListeners();
  }

  Future<void> setInterfaceDensity(String density) async {
    _interfaceDensity = density;
    await _prefs?.setString(_keyInterfaceDensity, density);
    notifyListeners();
  }

  Future<void> setSidebarWidth(double width) async {
    _sidebarWidth = width.clamp(180.0, 360.0);
    await _prefs?.setDouble(_keySidebarWidth, _sidebarWidth);
    notifyListeners();
  }

  Future<void> setChatContentMaxWidth(double width) async {
    _chatContentMaxWidth = width.clamp(600.0, 1400.0);
    await _prefs?.setDouble(_keyChatContentMaxWidth, _chatContentMaxWidth);
    notifyListeners();
  }

  Future<void> setMessageSpacing(double spacing) async {
    _messageSpacing = spacing.clamp(8.0, 32.0);
    await _prefs?.setDouble(_keyMessageSpacing, _messageSpacing);
    notifyListeners();
  }

  Future<void> setUiFontFamily(String family) async {
    _uiFontFamily = family;
    await _prefs?.setString(_keyUiFontFamily, family);
    notifyListeners();
  }

  Future<void> setUiFontSize(double size) async {
    _uiFontSize = size.clamp(10.0, 18.0);
    await _prefs?.setDouble(_keyUiFontSize, _uiFontSize);
    notifyListeners();
  }

  Future<void> setChatFontSize(double size) async {
    _chatFontSize = size.clamp(11.0, 20.0);
    await _prefs?.setDouble(_keyChatFontSize, _chatFontSize);
    notifyListeners();
  }

  Future<void> setCodeFontSize(double size) async {
    _codeFontSize = size.clamp(10.0, 18.0);
    await _prefs?.setDouble(_keyCodeFontSize, _codeFontSize);
    notifyListeners();
  }

  Future<void> setSyntaxHighlightTheme(String theme) async {
    _syntaxHighlightTheme = theme;
    await _prefs?.setString(_keySyntaxHighlightTheme, theme);
    notifyListeners();
  }

  Future<void> setRoundedCornerStyle(String style) async {
    _roundedCornerStyle = style;
    await _prefs?.setString(_keyRoundedCornerStyle, style);
    notifyListeners();
  }

  Future<void> setShowAvatars(bool value) async {
    _showAvatars = value;
    await _prefs?.setBool(_keyShowAvatars, value);
    notifyListeners();
  }

  Future<void> setShowTimestamps(bool value) async {
    _showTimestamps = value;
    await _prefs?.setBool(_keyShowTimestamps, value);
    notifyListeners();
  }

  Future<void> setShowTokenCounts(bool value) async {
    _showTokenCounts = value;
    await _prefs?.setBool(_keyShowTokenCounts, value);
    notifyListeners();
  }

  Future<void> setShowGenerationSpeed(bool value) async {
    _showGenerationSpeed = value;
    await _prefs?.setBool(_keyShowGenerationSpeed, value);
    notifyListeners();
  }

  Future<void> setShowContextUtilization(bool value) async {
    _showContextUtilization = value;
    await _prefs?.setBool(_keyShowContextUtilization, value);
    notifyListeners();
  }

  Future<void> setShowModelStatus(bool value) async {
    _showModelStatus = value;
    await _prefs?.setBool(_keyShowModelStatus, value);
    notifyListeners();
  }

  Future<void> setReducedMotion(bool value) async {
    _reducedMotion = value;
    await _prefs?.setBool(_keyReducedMotion, value);
    notifyListeners();
  }

  Future<void> setStreamingDisplayMode(String mode) async {
    _streamingDisplayMode = mode;
    await _prefs?.setString(_keyStreamingDisplayMode, mode);
    notifyListeners();
  }

  // ==========================================
  // --- Setters: Category 3 Chat Defaults ---
  // ==========================================
  Future<void> setActiveModel(String modelName) async {
    _activeModel = modelName.trim();
    await _prefs?.setString(_keyActiveModel, _activeModel);
    notifyListeners();
  }

  Future<void> setChatTemperature(double value) async {
    _chatTemperature = value.clamp(0.0, 2.0);
    await _prefs?.setDouble(_keyChatTemperature, _chatTemperature);
    notifyListeners();
  }

  Future<void> setContextWindow(int value) async {
    _contextWindow = value.clamp(512, 1048576);
    await _prefs?.setInt(_keyContextWindow, _contextWindow);
    notifyListeners();
  }

  Future<void> setTopP(double value) async {
    _topP = value.clamp(0.0, 1.0);
    await _prefs?.setDouble(_keyTopP, _topP);
    notifyListeners();
  }

  Future<void> setTopK(int value) async {
    _topK = value.clamp(1, 100);
    await _prefs?.setInt(_keyTopK, _topK);
    notifyListeners();
  }

  Future<void> setMinP(double value) async {
    _minP = value.clamp(0.0, 1.0);
    await _prefs?.setDouble(_keyMinP, _minP);
    notifyListeners();
  }

  Future<void> setTypicalP(double value) async {
    _typicalP = value.clamp(0.0, 1.0);
    await _prefs?.setDouble(_keyTypicalP, _typicalP);
    notifyListeners();
  }

  Future<void> setRepeatPenalty(double value) async {
    _repeatPenalty = value.clamp(1.0, 2.0);
    await _prefs?.setDouble(_keyRepeatPenalty, _repeatPenalty);
    notifyListeners();
  }

  Future<void> setRepeatLastN(int value) async {
    _repeatLastN = value.clamp(0, 2048);
    await _prefs?.setInt(_keyRepeatLastN, _repeatLastN);
    notifyListeners();
  }

  Future<void> setPresencePenalty(double value) async {
    _presencePenalty = value.clamp(-2.0, 2.0);
    await _prefs?.setDouble(_keyPresencePenalty, _presencePenalty);
    notifyListeners();
  }

  Future<void> setFrequencyPenalty(double value) async {
    _frequencyPenalty = value.clamp(-2.0, 2.0);
    await _prefs?.setDouble(_keyFrequencyPenalty, _frequencyPenalty);
    notifyListeners();
  }

  Future<void> setMaxOutputTokens(int value) async {
    _maxOutputTokens = value.clamp(128, 131072);
    await _prefs?.setInt(_keyMaxOutputTokens, _maxOutputTokens);
    notifyListeners();
  }

  Future<void> setStopSequences(List<String> sequences) async {
    _stopSequences = List.from(sequences);
    await _prefs?.setStringList(_keyStopSequences, _stopSequences);
    notifyListeners();
  }

  Future<void> setSeed(int value) async {
    _seed = value;
    await _prefs?.setInt(_keySeed, _seed);
    notifyListeners();
  }

  Future<void> setSystemPrompt(String value) async {
    _systemPrompt = value.trim();
    await _prefs?.setString(_keySystemPrompt, _systemPrompt);
    notifyListeners();
  }

  Future<void> setStreamingEnabled(bool value) async {
    _streamingEnabled = value;
    await _prefs?.setBool(_keyStreamingEnabled, value);
    notifyListeners();
  }

  Future<void> setKeepAliveDuration(String value) async {
    _keepAliveDuration = value.trim();
    await _prefs?.setString(_keyKeepAliveDuration, _keepAliveDuration);
    notifyListeners();
  }

  Future<void> setJsonOutputMode(bool value) async {
    _jsonOutputMode = value;
    await _prefs?.setBool(_keyJsonOutputMode, value);
    notifyListeners();
  }

  Future<void> setAutoScrollDuringGeneration(bool value) async {
    _autoScrollDuringGeneration = value;
    await _prefs?.setBool(_keyAutoScrollDuringGeneration, value);
    notifyListeners();
  }

  Future<void> setHistoryLimit(int value) async {
    _historyLimit = value.clamp(1, 1000);
    await _prefs?.setInt(_keyHistoryLimit, _historyLimit);
    notifyListeners();
  }

  Future<void> setRequestTimeoutSeconds(int value) async {
    _requestTimeoutSeconds = value.clamp(10, 600);
    await _prefs?.setInt(_keyRequestTimeoutSeconds, _requestTimeoutSeconds);
    notifyListeners();
  }

  Future<void> setRetryOnFailure(bool value) async {
    _retryOnFailure = value;
    await _prefs?.setBool(_keyRetryOnFailure, value);
    notifyListeners();
  }

  // ==========================================
  // --- Setters: Category 4 Runtime ---
  // ==========================================
  Future<void> setOllamaHost(String host) async {
    final trimmedHost = host.trim().replaceAll(RegExp(r'/$'), '');
    _ollamaHost = trimmedHost.isEmpty ? AppConstants.defaultOllamaHost : trimmedHost;
    await _prefs?.setString(_keyOllamaHost, _ollamaHost);
    notifyListeners();
  }

  Future<void> setActiveBackend(String backend) async {
    _activeBackend = backend.trim();
    await _prefs?.setString(_keyActiveBackend, _activeBackend);
    notifyListeners();
  }

  Future<void> setConnectionTimeoutSeconds(int seconds) async {
    _connectionTimeoutSeconds = seconds.clamp(2, 60);
    await _prefs?.setInt(_keyConnectionTimeoutSeconds, _connectionTimeoutSeconds);
    notifyListeners();
  }

  Future<void> setQueuePolicy(String policy) async {
    _queuePolicy = policy;
    await _prefs?.setString(_keyQueuePolicy, policy);
    notifyListeners();
  }

  Future<void> setWarnRemoteEndpoints(bool warn) async {
    _warnRemoteEndpoints = warn;
    await _prefs?.setBool(_keyWarnRemoteEndpoints, warn);
    notifyListeners();
  }

  Future<void> setAirllmEnabled(bool enabled) async {
    _airllmEnabled = enabled;
    await _prefs?.setBool(_keyAirllmEnabled, _airllmEnabled);
    notifyListeners();
  }

  Future<void> setAirllmHost(String host) async {
    _airllmHost = host.trim().isEmpty ? 'http://127.0.0.1:8765' : host.trim();
    await _prefs?.setString(_keyAirllmHost, _airllmHost);
    notifyListeners();
  }

  Future<void> setAirllmModel(String model) async {
    _airllmModel = model.trim().isEmpty ? 'meta-llama/Meta-Llama-3-8B-Instruct' : model.trim();
    await _prefs?.setString(_keyAirllmModel, _airllmModel);
    notifyListeners();
  }

  Future<void> setAirllmCompression(String compression) async {
    _airllmCompression = compression;
    await _prefs?.setString(_keyAirllmCompression, _airllmCompression);
    notifyListeners();
  }

  Future<void> setAirllmDevice(String device) async {
    _airllmDevice = device;
    await _prefs?.setString(_keyAirllmDevice, _airllmDevice);
    notifyListeners();
  }

  Future<void> setAirllmShardsPath(String path) async {
    _airllmShardsPath = path;
    await _prefs?.setString(_keyAirllmShardsPath, _airllmShardsPath);
    notifyListeners();
  }

  Future<void> setAirllmAutoLaunch(bool autoLaunch) async {
    _airllmAutoLaunch = autoLaunch;
    await _prefs?.setBool(_keyAirllmAutoLaunch, _airllmAutoLaunch);
    notifyListeners();
  }

  // ==========================================
  // --- Setters: Category 5 Performance ---
  // ==========================================
  Future<void> setMaxConcurrentModelLoads(int count) async {
    _maxConcurrentModelLoads = count.clamp(1, 4);
    await _prefs?.setInt(_keyMaxConcurrentModelLoads, _maxConcurrentModelLoads);
    notifyListeners();
  }

  Future<void> setAutoUnloadIdleMinutes(int minutes) async {
    _autoUnloadIdleMinutes = minutes.clamp(0, 180);
    await _prefs?.setInt(_keyAutoUnloadIdleMinutes, _autoUnloadIdleMinutes);
    notifyListeners();
  }

  Future<void> setPerformanceMetricsCollection(bool enable) async {
    _performanceMetricsCollection = enable;
    await _prefs?.setBool(_keyPerformanceMetricsCollection, enable);
    notifyListeners();
  }

  // ==========================================
  // --- Setters: Category 6 Storage ---
  // ==========================================
  Future<void> setDownloadConcurrency(int count) async {
    _downloadConcurrency = count.clamp(1, 4);
    await _prefs?.setInt(_keyDownloadConcurrency, _downloadConcurrency);
    notifyListeners();
  }

  Future<void> setDownloadBandwidthLimit(int limitMbps) async {
    _downloadBandwidthLimit = limitMbps.clamp(0, 1000);
    await _prefs?.setInt(_keyDownloadBandwidthLimit, _downloadBandwidthLimit);
    notifyListeners();
  }

  Future<void> setDiskSpaceWarningThresholdGb(double gb) async {
    _diskSpaceWarningThresholdGb = gb.clamp(1.0, 50.0);
    await _prefs?.setDouble(_keyDiskSpaceWarningThresholdGb, _diskSpaceWarningThresholdGb);
    notifyListeners();
  }

  Future<bool> setDocumentsPath(String newPath) async {
    final verified = await _validateFolder(newPath);
    if (!verified) return false;
    _documentsPath = newPath;
    await _prefs?.setString(_keyDocumentsPath, newPath);
    notifyListeners();
    return true;
  }

  Future<bool> setEmbeddingsPath(String newPath) async {
    final verified = await _validateFolder(newPath);
    if (!verified) return false;
    _embeddingsPath = newPath;
    await _prefs?.setString(_keyEmbeddingsPath, newPath);
    notifyListeners();
    return true;
  }

  Future<bool> setBackupsPath(String newPath) async {
    final verified = await _validateFolder(newPath);
    if (!verified) return false;
    _backupsPath = newPath;
    await _prefs?.setString(_keyBackupsPath, newPath);
    notifyListeners();
    return true;
  }

  Future<bool> setDatabasePath(String newPath) async {
    final verified = await _validateFolder(newPath);
    if (!verified) return false;
    _databasePath = newPath;
    await _prefs?.setString(_keyDatabasePath, newPath);
    notifyListeners();
    return true;
  }

  Future<bool> _validateFolder(String path) async {
    if (path.trim().isEmpty) return false;
    try {
      final dir = Directory(path);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final testFile = File(p.join(dir.path, '.perm_test'));
      await testFile.writeAsString('test');
      await testFile.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ==========================================
  // --- Setters: Category 7 Knowledge & RAG ---
  // ==========================================
  Future<void> setRagGloballyEnabled(bool enabled) async {
    _ragGloballyEnabled = enabled;
    await _prefs?.setBool(_keyRagGloballyEnabled, enabled);
    notifyListeners();
  }

  Future<void> setDefaultEmbeddingModel(String modelId) async {
    _defaultEmbeddingModel = modelId.trim();
    await _prefs?.setString(_keyDefaultEmbeddingModel, _defaultEmbeddingModel);
    notifyListeners();
  }

  Future<void> setDefaultRerankerModel(String modelId) async {
    _defaultRerankerModel = modelId.trim();
    await _prefs?.setString(_keyDefaultRerankerModel, _defaultRerankerModel);
    notifyListeners();
  }

  Future<void> setRagChunkSize(int tokens) async {
    _ragChunkSize = tokens.clamp(128, 2048);
    await _prefs?.setInt(_keyRagChunkSize, _ragChunkSize);
    notifyListeners();
  }

  Future<void> setRagChunkOverlap(int tokens) async {
    _ragChunkOverlap = tokens.clamp(0, 512);
    await _prefs?.setInt(_keyRagChunkOverlap, _ragChunkOverlap);
    notifyListeners();
  }

  Future<void> setRagRetrievalTopK(int k) async {
    _ragRetrievalTopK = k.clamp(1, 20);
    await _prefs?.setInt(_keyRagRetrievalTopK, _ragRetrievalTopK);
    notifyListeners();
  }

  Future<void> setRagSimilarityThreshold(double threshold) async {
    _ragSimilarityThreshold = threshold.clamp(0.0, 1.0);
    await _prefs?.setDouble(_keyRagSimilarityThreshold, _ragSimilarityThreshold);
    notifyListeners();
  }

  Future<void> setRagHybridSearch(bool enable) async {
    _ragHybridSearch = enable;
    await _prefs?.setBool(_keyRagHybridSearch, enable);
    notifyListeners();
  }

  Future<void> setRagShowCitations(bool enable) async {
    _ragShowCitations = enable;
    await _prefs?.setBool(_keyRagShowCitations, enable);
    notifyListeners();
  }

  Future<void> setRagMaxContextTokens(int tokens) async {
    _ragMaxContextTokens = tokens.clamp(256, 8192);
    await _prefs?.setInt(_keyRagMaxContextTokens, _ragMaxContextTokens);
    notifyListeners();
  }

  // ==========================================
  // --- Setters: Category 8 Multimodal ---
  // ==========================================
  Future<void> setDefaultVisionModel(String modelId) async {
    _defaultVisionModel = modelId.trim();
    await _prefs?.setString(_keyDefaultVisionModel, _defaultVisionModel);
    notifyListeners();
  }

  Future<void> setDefaultOcrModel(String modelId) async {
    _defaultOcrModel = modelId.trim();
    await _prefs?.setString(_keyDefaultOcrModel, _defaultOcrModel);
    notifyListeners();
  }

  Future<void> setDefaultAudioModel(String modelId) async {
    _defaultAudioModel = modelId.trim();
    await _prefs?.setString(_keyDefaultAudioModel, _defaultAudioModel);
    notifyListeners();
  }

  Future<void> setVideoFrameInterval(double seconds) async {
    _videoFrameInterval = seconds.clamp(0.2, 10.0);
    await _prefs?.setDouble(_keyVideoFrameInterval, _videoFrameInterval);
    notifyListeners();
  }

  Future<void> setVideoMaxSampledFrames(int frames) async {
    _videoMaxSampledFrames = frames.clamp(4, 128);
    await _prefs?.setInt(_keyVideoMaxSampledFrames, _videoMaxSampledFrames);
    notifyListeners();
  }

  Future<void> setImageMaxDimension(int dim) async {
    _imageMaxDimension = dim.clamp(512, 4096);
    await _prefs?.setInt(_keyImageMaxDimension, _imageMaxDimension);
    notifyListeners();
  }

  Future<void> setMediaAutoCleanup(bool cleanup) async {
    _mediaAutoCleanup = cleanup;
    await _prefs?.setBool(_keyMediaAutoCleanup, cleanup);
    notifyListeners();
  }

  // ==========================================
  // --- Setters: Category 9 Privacy ---
  // ==========================================
  Future<void> setStrictLocalOnly(bool strict) async {
    _strictLocalOnly = strict;
    await _prefs?.setBool(_keyStrictLocalOnly, strict);
    notifyListeners();
  }

  Future<void> setMaskSensitiveSecrets(bool mask) async {
    _maskSensitiveSecrets = mask;
    await _prefs?.setBool(_keyMaskSensitiveSecrets, mask);
    notifyListeners();
  }

  Future<void> setConversationRetentionDays(int days) async {
    _conversationRetentionDays = days.clamp(0, 365);
    await _prefs?.setInt(_keyConversationRetentionDays, _conversationRetentionDays);
    notifyListeners();
  }

  Future<void> setTelemetryOptIn(bool optIn) async {
    _telemetryOptIn = optIn;
    await _prefs?.setBool(_keyTelemetryOptIn, optIn);
    notifyListeners();
  }

  // ==========================================
  // --- Setters: Category 10 Developer ---
  // ==========================================
  Future<void> setShowDeveloperSettings(bool show) async {
    _showDeveloperSettings = show;
    await _prefs?.setBool(_keyShowDeveloperSettings, show);
    notifyListeners();
  }

  Future<void> setVerboseLogging(bool enable) async {
    _verboseLogging = enable;
    await _prefs?.setBool(_keyVerboseLogging, enable);
    notifyListeners();
  }

  Future<void> setExperimentalFeatures(bool enable) async {
    _experimentalFeatures = enable;
    await _prefs?.setBool(_keyExperimentalFeatures, enable);
    notifyListeners();
  }

  // ==========================================
  // --- Setters: Desktop State Navigation ---
  // ==========================================
  Future<void> setLastSelectedTab(int index) async {
    _lastSelectedTab = index;
    await _prefs?.setInt(_keyLastSelectedTab, index);
    notifyListeners();
  }

  Future<void> setSidebarVisible(bool visible) async {
    _sidebarVisible = visible;
    await _prefs?.setBool(_keySidebarVisible, visible);
    notifyListeners();
  }

  // ==========================================
  // --- Reset Methods (Section & Global) ---
  // ==========================================

  /// Reset individual section to its recommended defaults
  Future<void> resetSection(String sectionKey) async {
    switch (sectionKey.toLowerCase()) {
      case 'general':
        await setLaunchAtLogin(false);
        await setStartMinimized(false);
        await setDefaultAppView('chat');
        await setDefaultChatMode('chat');
        await setAutoTitleGeneration(true);
        await setConfirmDeleteConversations(true);
        await setConfirmRemoveModels(true);
        await setRestorePreviousSession(true);
        await setRememberWindowBounds(true);
        await setLocalePreference('en_US');
        await setDateFormat('MMM d, yyyy');
        await setTimeFormat('12h');
        await setShowTooltips(true);
        await setDesktopNotifications(true);
        await setUpdateCheckInterval('weekly');
        break;

      case 'appearance':
        await setThemeMode('dark');
        await setAccentColorName('emerald');
        await setInterfaceDensity('comfortable');
        await setSidebarWidth(240.0);
        await setChatContentMaxWidth(860.0);
        await setMessageSpacing(16.0);
        await setUiFontFamily('System SF Pro');
        await setUiFontSize(13.0);
        await setChatFontSize(14.0);
        await setCodeFontSize(13.0);
        await setSyntaxHighlightTheme('atom-one-dark');
        await setRoundedCornerStyle('modern');
        await setShowAvatars(true);
        await setShowTimestamps(true);
        await setShowTokenCounts(true);
        await setShowGenerationSpeed(true);
        await setShowContextUtilization(true);
        await setShowModelStatus(true);
        await setReducedMotion(false);
        await setStreamingDisplayMode('token');
        break;

      case 'chat':
        await setChatTemperature(0.7);
        await setContextWindow(4096);
        await setTopP(0.9);
        await setTopK(40);
        await setMinP(0.0);
        await setTypicalP(1.0);
        await setRepeatPenalty(1.1);
        await setRepeatLastN(64);
        await setPresencePenalty(0.0);
        await setFrequencyPenalty(0.0);
        await setMaxOutputTokens(2048);
        await setStopSequences([]);
        await setSeed(-1);
        await setSystemPrompt('');
        await setStreamingEnabled(true);
        await setKeepAliveDuration('5m');
        await setJsonOutputMode(false);
        await setAutoScrollDuringGeneration(true);
        await setHistoryLimit(20);
        await setRequestTimeoutSeconds(60);
        await setRetryOnFailure(false);
        break;

      case 'runtime':
        await setOllamaHost(AppConstants.defaultOllamaHost);
        await setActiveBackend('ollama');
        await setConnectionTimeoutSeconds(10);
        await setQueuePolicy('queue_fifo');
        await setWarnRemoteEndpoints(true);
        await setAirllmEnabled(false);
        break;

      case 'performance':
        await setMaxConcurrentModelLoads(1);
        await setAutoUnloadIdleMinutes(15);
        await setPerformanceMetricsCollection(true);
        break;

      case 'storage':
        await setDownloadConcurrency(1);
        await setDownloadBandwidthLimit(0);
        await setDiskSpaceWarningThresholdGb(5.0);
        await resetStorageLocationsToDefault();
        break;

      case 'rag':
        await setRagGloballyEnabled(true);
        await setDefaultEmbeddingModel('nomic-embed-text:latest');
        await setDefaultRerankerModel('bge-reranker-v2-m3:latest');
        await setRagChunkSize(512);
        await setRagChunkOverlap(64);
        await setRagRetrievalTopK(3);
        await setRagSimilarityThreshold(0.45);
        await setRagHybridSearch(true);
        await setRagShowCitations(true);
        await setRagMaxContextTokens(1536);
        break;

      case 'multimodal':
        await setDefaultVisionModel('qwen2.5-vl:7b');
        await setDefaultOcrModel('got-ocr2:latest');
        await setDefaultAudioModel('whisper-large-v3-turbo:latest');
        await setVideoFrameInterval(1.0);
        await setVideoMaxSampledFrames(16);
        await setImageMaxDimension(1536);
        await setMediaAutoCleanup(true);
        break;

      case 'privacy':
        await setStrictLocalOnly(false);
        await setMaskSensitiveSecrets(true);
        await setConversationRetentionDays(0);
        await setTelemetryOptIn(false);
        break;

      case 'developer':
        await setShowDeveloperSettings(false);
        await setVerboseLogging(false);
        await setExperimentalFeatures(false);
        break;
    }
    notifyListeners();
  }

  /// Reset Storage Locations to Default Sandbox Folders
  Future<void> resetStorageLocationsToDefault() async {
    _documentsPath = p.join(_defaultAppSupportPath, 'documents');
    _embeddingsPath = p.join(_defaultAppSupportPath, 'embeddings');
    _backupsPath = p.join(_defaultAppSupportPath, 'backups');
    _databasePath = p.join(_defaultAppSupportPath, 'database');

    await _ensureDirectoryExists(_documentsPath);
    await _ensureDirectoryExists(_embeddingsPath);
    await _ensureDirectoryExists(_backupsPath);
    await _ensureDirectoryExists(_databasePath);

    await _prefs?.setString(_keyDocumentsPath, _documentsPath);
    await _prefs?.setString(_keyEmbeddingsPath, _embeddingsPath);
    await _prefs?.setString(_keyBackupsPath, _backupsPath);
    await _prefs?.setString(_keyDatabasePath, _databasePath);

    notifyListeners();
  }

  /// Reset All App Settings with Fresh Defaults
  Future<void> resetAllSettings() async {
    await _prefs?.clear();
    await resetSection('general');
    await resetSection('appearance');
    await resetSection('chat');
    await resetSection('runtime');
    await resetSection('performance');
    await resetSection('storage');
    await resetSection('rag');
    await resetSection('multimodal');
    await resetSection('privacy');
    await resetSection('developer');
    notifyListeners();
  }

  Future<void> resetAllPreferences() => resetAllSettings();
  Future<void> resetGeneralSettings() => resetSection('general');
  Future<void> resetAppearanceSettings() => resetSection('appearance');
  Future<void> resetChatSettings() => resetSection('chat');
  Future<void> resetRuntimeSettings() => resetSection('runtime');
  Future<void> resetPerformanceSettings() => resetSection('performance');
  Future<void> resetStorageSettings() => resetSection('storage');
  Future<void> resetRagSettings() => resetSection('rag');
  Future<void> resetMultimodalSettings() => resetSection('multimodal');
  Future<void> resetPrivacySettings() => resetSection('privacy');

  /// Export settings configuration to JSON string (stripping secrets)
  String exportSettingsJson() {
    final Map<String, dynamic> data = {
      'exported_at': DateTime.now().toIso8601String(),
      'app_version': '1.2.0',
      'general': {
        'launchAtLogin': launchAtLogin,
        'startMinimized': startMinimized,
        'defaultAppView': defaultAppView,
        'defaultChatMode': defaultChatMode,
        'autoTitleGeneration': autoTitleGeneration,
        'confirmDeleteConversations': confirmDeleteConversations,
        'confirmRemoveModels': confirmRemoveModels,
        'restorePreviousSession': restorePreviousSession,
        'rememberWindowBounds': rememberWindowBounds,
        'localePreference': localePreference,
        'dateFormat': dateFormat,
        'timeFormat': timeFormat,
        'showTooltips': showTooltips,
        'desktopNotifications': desktopNotifications,
        'updateCheckInterval': updateCheckInterval,
      },
      'appearance': {
        'themeMode': themeMode,
        'accentColorName': accentColorName,
        'interfaceDensity': interfaceDensity,
        'sidebarWidth': sidebarWidth,
        'chatContentMaxWidth': chatContentMaxWidth,
        'messageSpacing': messageSpacing,
        'uiFontFamily': uiFontFamily,
        'uiFontSize': uiFontSize,
        'chatFontSize': chatFontSize,
        'codeFontSize': codeFontSize,
        'syntaxHighlightTheme': syntaxHighlightTheme,
        'roundedCornerStyle': roundedCornerStyle,
        'showAvatars': showAvatars,
        'showTimestamps': showTimestamps,
        'showTokenCounts': showTokenCounts,
        'showGenerationSpeed': showGenerationSpeed,
        'showContextUtilization': showContextUtilization,
        'showModelStatus': showModelStatus,
        'reducedMotion': reducedMotion,
        'streamingDisplayMode': streamingDisplayMode,
      },
      'chat': {
        'activeModel': activeModel,
        'chatTemperature': chatTemperature,
        'contextWindow': contextWindow,
        'topP': topP,
        'topK': topK,
        'minP': minP,
        'typicalP': typicalP,
        'repeatPenalty': repeatPenalty,
        'repeatLastN': repeatLastN,
        'presencePenalty': presencePenalty,
        'frequencyPenalty': frequencyPenalty,
        'maxOutputTokens': maxOutputTokens,
        'stopSequences': stopSequences,
        'seed': seed,
        'systemPrompt': systemPrompt,
        'streamingEnabled': streamingEnabled,
        'keepAliveDuration': keepAliveDuration,
        'jsonOutputMode': jsonOutputMode,
        'autoScrollDuringGeneration': autoScrollDuringGeneration,
        'historyLimit': historyLimit,
        'requestTimeoutSeconds': requestTimeoutSeconds,
        'retryOnFailure': retryOnFailure,
      },
      'runtime': {
        'ollamaHost': ollamaHost,
        'activeBackend': activeBackend,
        'connectionTimeoutSeconds': connectionTimeoutSeconds,
        'queuePolicy': queuePolicy,
        'warnRemoteEndpoints': warnRemoteEndpoints,
        'airllmEnabled': airllmEnabled,
        'airllmHost': airllmHost,
        'airllmModel': airllmModel,
        'airllmCompression': airllmCompression,
        'airllmDevice': airllmDevice,
        'airllmShardsPath': airllmShardsPath,
        'airllmAutoLaunch': airllmAutoLaunch,
      },
      'performance': {
        'maxConcurrentModelLoads': maxConcurrentModelLoads,
        'autoUnloadIdleMinutes': autoUnloadIdleMinutes,
        'performanceMetricsCollection': performanceMetricsCollection,
      },
      'rag': {
        'ragGloballyEnabled': ragGloballyEnabled,
        'defaultEmbeddingModel': defaultEmbeddingModel,
        'defaultRerankerModel': defaultRerankerModel,
        'ragChunkSize': ragChunkSize,
        'ragChunkOverlap': ragChunkOverlap,
        'ragRetrievalTopK': ragRetrievalTopK,
        'ragSimilarityThreshold': ragSimilarityThreshold,
        'ragHybridSearch': ragHybridSearch,
        'ragShowCitations': ragShowCitations,
        'ragMaxContextTokens': ragMaxContextTokens,
      },
      'multimodal': {
        'defaultVisionModel': defaultVisionModel,
        'defaultOcrModel': defaultOcrModel,
        'defaultAudioModel': defaultAudioModel,
        'videoFrameInterval': videoFrameInterval,
        'videoMaxSampledFrames': videoMaxSampledFrames,
        'imageMaxDimension': imageMaxDimension,
        'mediaAutoCleanup': mediaAutoCleanup,
      },
      'privacy': {
        'strictLocalOnly': strictLocalOnly,
        'maskSensitiveSecrets': maskSensitiveSecrets,
        'conversationRetentionDays': conversationRetentionDays,
        'telemetryOptIn': telemetryOptIn,
      },
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Import settings from JSON string
  Future<bool> importSettingsJson(String jsonString) async {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) return false;

      if (decoded['general'] is Map) {
        final g = decoded['general'] as Map;
        if (g['launchAtLogin'] is bool) await setLaunchAtLogin(g['launchAtLogin']);
        if (g['defaultAppView'] is String) await setDefaultAppView(g['defaultAppView']);
        if (g['confirmDeleteConversations'] is bool) await setConfirmDeleteConversations(g['confirmDeleteConversations']);
        if (g['showTooltips'] is bool) await setShowTooltips(g['showTooltips']);
        if (g['desktopNotifications'] is bool) await setDesktopNotifications(g['desktopNotifications']);
      }

      if (decoded['appearance'] is Map) {
        final a = decoded['appearance'] as Map;
        if (a['themeMode'] is String) await setThemeMode(a['themeMode']);
        if (a['accentColorName'] is String) await setAccentColorName(a['accentColorName']);
        if (a['interfaceDensity'] is String) await setInterfaceDensity(a['interfaceDensity']);
        if (a['uiFontSize'] is num) await setUiFontSize((a['uiFontSize'] as num).toDouble());
        if (a['chatFontSize'] is num) await setChatFontSize((a['chatFontSize'] as num).toDouble());
        if (a['showTimestamps'] is bool) await setShowTimestamps(a['showTimestamps']);
        if (a['showTokenCounts'] is bool) await setShowTokenCounts(a['showTokenCounts']);
        if (a['reducedMotion'] is bool) await setReducedMotion(a['reducedMotion']);
      }

      if (decoded['chat'] is Map) {
        final c = decoded['chat'] as Map;
        if (c['chatTemperature'] is num) await setChatTemperature((c['chatTemperature'] as num).toDouble());
        if (c['contextWindow'] is int) await setContextWindow(c['contextWindow']);
        if (c['topP'] is num) await setTopP((c['topP'] as num).toDouble());
        if (c['topK'] is int) await setTopK(c['topK']);
        if (c['minP'] is num) await setMinP((c['minP'] as num).toDouble());
        if (c['repeatPenalty'] is num) await setRepeatPenalty((c['repeatPenalty'] as num).toDouble());
        if (c['maxOutputTokens'] is int) await setMaxOutputTokens(c['maxOutputTokens']);
        if (c['systemPrompt'] is String) await setSystemPrompt(c['systemPrompt']);
        if (c['jsonOutputMode'] is bool) await setJsonOutputMode(c['jsonOutputMode']);
      }

      if (decoded['runtime'] is Map) {
        final r = decoded['runtime'] as Map;
        if (r['ollamaHost'] is String) await setOllamaHost(r['ollamaHost']);
        if (r['activeBackend'] is String) await setActiveBackend(r['activeBackend']);
        if (r['airllmEnabled'] is bool) await setAirllmEnabled(r['airllmEnabled']);
        if (r['airllmHost'] is String) await setAirllmHost(r['airllmHost']);
        if (r['airllmModel'] is String) await setAirllmModel(r['airllmModel']);
        if (r['airllmCompression'] is String) await setAirllmCompression(r['airllmCompression']);
        if (r['airllmDevice'] is String) await setAirllmDevice(r['airllmDevice']);
        if (r['airllmShardsPath'] is String) await setAirllmShardsPath(r['airllmShardsPath']);
        if (r['airllmAutoLaunch'] is bool) await setAirllmAutoLaunch(r['airllmAutoLaunch']);
      }

      if (decoded['rag'] is Map) {
        final rg = decoded['rag'] as Map;
        if (rg['ragGloballyEnabled'] is bool) await setRagGloballyEnabled(rg['ragGloballyEnabled']);
        if (rg['defaultEmbeddingModel'] is String) await setDefaultEmbeddingModel(rg['defaultEmbeddingModel']);
        if (rg['ragChunkSize'] is int) await setRagChunkSize(rg['ragChunkSize']);
        if (rg['ragRetrievalTopK'] is int) await setRagRetrievalTopK(rg['ragRetrievalTopK']);
        if (rg['ragSimilarityThreshold'] is num) await setRagSimilarityThreshold((rg['ragSimilarityThreshold'] as num).toDouble());
      }

      if (decoded['privacy'] is Map) {
        final p = decoded['privacy'] as Map;
        if (p['maskSensitiveSecrets'] is bool) await setMaskSensitiveSecrets(p['maskSensitiveSecrets']);
        if (p['strictLocalOnly'] is bool) await setStrictLocalOnly(p['strictLocalOnly']);
      }

      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }
}
