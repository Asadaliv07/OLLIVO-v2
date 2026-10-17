import 'dart:async';
import 'package:flutter/material.dart';
import '../models/model_catalog_item.dart';
import '../models/rag_pipeline_recommendation.dart';
import '../services/ai_service.dart';
import '../services/hardware_service.dart';
import '../services/model_catalog_service.dart';
import '../services/model_discovery_service.dart';
import '../services/process_service.dart';
import '../services/providers/backend_provider.dart';
import '../services/settings_service.dart';
import '../theme.dart';

/// VRAM & Unified Memory Guidance Classification (MOD-001)
class ModelMemoryGuidance {
  final String label;
  final Color color;
  final String recommendation;
  final int minRamGb;

  const ModelMemoryGuidance({
    required this.label,
    required this.color,
    required this.recommendation,
    required this.minRamGb,
  });
}

/// Recommended Model Metadata
class RecommendedModel {
  final String id;
  final String name;
  final String family; // 'Coding', 'General Chat', 'Reasoning', 'Lightweight'
  final String size;
  final String description;
  final String hardwareRequirements;

  const RecommendedModel({
    required this.id,
    required this.name,
    required this.family,
    required this.size,
    required this.description,
    required this.hardwareRequirements,
  });
}

class ModelController extends ChangeNotifier {
  final AIService _aiService;
  final SettingsService _settingsService;
  final ProcessService _processService;
  final HardwareService _hardwareService;
  final ProviderRegistry _providerRegistry;
  final ModelDiscoveryService _discoveryService;

  List<OllamaModelInfo> _installedModels = [];
  List<OllamaLoadedModelInfo> _loadedModels = [];
  HardwareProfile? _hardwareProfile;

  bool _isLoading = false;
  bool _isOllamaOnline = false;
  bool _isAirLLMOnline = false;
  bool _isRecoveringDaemon = false;
  int? _daemonLatencyMs;
  int? _airllmLatencyMs;
  String? _ollamaVersion;
  String? _errorMessage;
  String? _recoveryStatusMessage;
  Map<String, dynamic>? _airllmStatus;

  // Active Download Progress State
  String? _activeDownloadingModel;
  OllamaPullProgress? _downloadProgress;
  StreamSubscription<OllamaPullProgress>? _pullSubscription;

  // Dynamic Upstream Discovery State
  bool _isDiscovering = false;
  String? _discoveryMessage;
  List<ModelCatalogItem> _discoveredModels = [];

  // Catalog Filter & Search State
  String _catalogSearchQuery = '';
  String _selectedCategory = 'All';
  String _selectedSize = 'All'; // 'All', 'Lightweight', 'Medium', 'Large'
  String _selectedSizeTier = 'All'; // 'All', 'Ultra-light', 'Lightweight', 'Medium', 'Advanced', 'Large', 'Extra-large'
  String _selectedFamily = 'All';
  String _selectedRagRole = 'All';
  String _selectedModality = 'All';
  String _selectedTask = 'All';
  String _selectedVerification = 'All';
  String _selectedStatus = 'All'; // 'All', 'Installed', 'Not Installed', 'Favorites'
  String _selectedSortBy = 'Popularity'; // 'Popularity', 'Name', 'Size', 'Context'
  bool _hardwareCompatibleOnly = false;

  // Curated Model Library Recommendations
  static const List<RecommendedModel> recommendedModels = [
    RecommendedModel(
      id: 'qwen2.5-coder:1.5b',
      name: 'Qwen 2.5 Coder 1.5B',
      family: 'Coding',
      size: '980 MB',
      description: 'Ultra-fast, lightweight coding model optimized for Dart, Flutter, Python, and SQL code generation.',
      hardwareRequirements: '8 GB RAM (Apple Silicon M1/M2/M3/M4 or Intel)',
    ),
    RecommendedModel(
      id: 'qwen2.5-coder:7b',
      name: 'Qwen 2.5 Coder 7B',
      family: 'Coding',
      size: '4.7 GB',
      description: 'High-accuracy code assistant for complex refactoring, multi-file architecture, and deep debugging.',
      hardwareRequirements: '16 GB RAM (Apple Silicon M-series recommended)',
    ),
    RecommendedModel(
      id: 'llama3.2:3b',
      name: 'Llama 3.2 3B',
      family: 'General Chat',
      size: '2.0 GB',
      description: 'Meta\'s compact, highly efficient assistant for multi-turn conversations, summaries, and drafting.',
      hardwareRequirements: '8 GB RAM',
    ),
    RecommendedModel(
      id: 'llama3.2:1b',
      name: 'Llama 3.2 1B',
      family: 'Lightweight',
      size: '1.3 GB',
      description: 'Ultra-lightweight model with lowest memory footprint for instant response times on any Mac.',
      hardwareRequirements: '8 GB RAM',
    ),
    RecommendedModel(
      id: 'deepseek-r1:1.5b',
      name: 'DeepSeek R1 1.5B',
      family: 'Reasoning',
      size: '1.1 GB',
      description: 'Fast reasoning model trained for step-by-step logic, math, and structured analysis.',
      hardwareRequirements: '8 GB RAM',
    ),
    RecommendedModel(
      id: 'deepseek-r1:8b',
      name: 'DeepSeek R1 8B',
      family: 'Reasoning',
      size: '4.9 GB',
      description: 'Advanced reasoning model capable of complex problem solving and step-by-step chain of thought.',
      hardwareRequirements: '16 GB RAM',
    ),
    RecommendedModel(
      id: 'mistral:7b',
      name: 'Mistral 7B',
      family: 'General Chat',
      size: '4.1 GB',
      description: 'Popular 7B model offering strong performance across writing, coding, and general knowledge tasks.',
      hardwareRequirements: '16 GB RAM',
    ),
    RecommendedModel(
      id: 'meta-llama/Meta-Llama-3-70B-Instruct',
      name: 'Llama 3 70B Instruct (AirLLM)',
      family: 'Layer-Streaming',
      size: '39.8 GB',
      description: 'Massive 70B flagship model running seamlessly via AirLLM layer-streaming directly from SSD on 16GB RAM.',
      hardwareRequirements: '16 GB RAM + 45 GB SSD Free (AirLLM layer streaming)',
    ),
    RecommendedModel(
      id: 'deepseek-ai/DeepSeek-R1-Distill-Llama-70B',
      name: 'DeepSeek R1 70B (AirLLM)',
      family: 'Layer-Streaming',
      size: '39.5 GB',
      description: 'State-of-the-art open reasoning model executed layer-by-layer without requiring expensive multi-GPU clusters.',
      hardwareRequirements: '16 GB RAM + 45 GB SSD Free (AirLLM layer streaming)',
    ),
  ];

  ModelController({
    AIService? aiService,
    SettingsService? settingsService,
    ProcessService? processService,
    HardwareService? hardwareService,
    ProviderRegistry? providerRegistry,
    ModelDiscoveryService? discoveryService,
  })  : _aiService = aiService ?? AIService(),
        _settingsService = settingsService ?? SettingsService(),
        _processService = processService ?? ProcessService(aiService: aiService),
        _hardwareService = hardwareService ?? HardwareService(),
        _providerRegistry = providerRegistry ?? ProviderRegistry(aiService: aiService),
        _discoveryService = discoveryService ?? ModelDiscoveryService() {
    refreshModels();
    _initHardwareProfile();
  }

  Future<void> _initHardwareProfile() async {
    try {
      _hardwareProfile = await _hardwareService.detectHardware();
      notifyListeners();
    } catch (_) {}
  }

  List<OllamaModelInfo> get installedModels => List.unmodifiable(_installedModels);
  List<OllamaLoadedModelInfo> get loadedModels => List.unmodifiable(_loadedModels);
  HardwareProfile? get hardwareProfile => _hardwareProfile;
  HardwareService get hardwareService => _hardwareService;
  ProviderRegistry get providerRegistry => _providerRegistry;
  ModelDiscoveryService get discoveryService => _discoveryService;

  bool get isLoading => _isLoading;
  bool get isOllamaOnline => _isOllamaOnline;
  bool get isAirLLMOnline => _isAirLLMOnline;
  bool get isRecoveringDaemon => _isRecoveringDaemon;
  int? get daemonLatencyMs => _daemonLatencyMs;
  int? get airllmLatencyMs => _airllmLatencyMs;
  String? get ollamaVersion => _ollamaVersion;
  String? get errorMessage => _errorMessage;
  String? get recoveryStatusMessage => _recoveryStatusMessage;
  Map<String, dynamic>? get airllmStatus => _airllmStatus;
  String get airllmHost => _settingsService.airllmHost;
  bool get airllmEnabled => _settingsService.airllmEnabled;
  String get effectiveInferenceBackend => _settingsService.effectiveInferenceBackend;
  String get effectiveInferenceHost => _settingsService.effectiveInferenceHost;
  String get effectiveInferenceModel => _settingsService.effectiveInferenceModel;
  String get airllmCompression => _settingsService.airllmCompression;
  String get airllmDevice => _settingsService.airllmDevice;
  String? get airllmActiveModel => _airllmStatus?['activeModel'] as String? ?? (_settingsService.airllmModel.isNotEmpty ? _settingsService.airllmModel : null);
  bool get isAirLLMDaemonRunning => _isAirLLMOnline || _processService.isLaunchingAirllm;
  bool get isAirLLMBusy => _processService.isLaunchingAirllm || _processService.isStoppingAirllm || _isRecoveringDaemon;

  Future<void> setAirllmEnabled(bool enabled) async {
    await _settingsService.setAirllmEnabled(enabled);
    notifyListeners();
  }

  String? get activeDownloadingModel => _activeDownloadingModel;
  OllamaPullProgress? get downloadProgress => _downloadProgress;

  String get activeModel => _settingsService.activeModel;
  String get ollamaHost => _settingsService.ollamaHost;

  // Favorites & Recents
  List<String> get favoriteModels => _settingsService.favoriteModels;
  List<String> get recentModels => _settingsService.recentModels;

  bool isFavorite(String modelId) => _settingsService.favoriteModels.contains(modelId);

  Future<void> toggleFavorite(String modelId) async {
    await _settingsService.toggleFavorite(modelId);
    notifyListeners();
  }

  // Dynamic Discovery Getters and Methods
  bool get isDiscovering => _isDiscovering;
  String? get discoveryMessage => _discoveryMessage;
  List<ModelCatalogItem> get discoveredModels => List.unmodifiable(_discoveredModels);

  Future<void> refreshDiscovery({String query = '', String source = 'all'}) async {
    _isDiscovering = true;
    _discoveryMessage = 'Searching upstream model catalogs ($source)...';
    notifyListeners();

    try {
      final result = await _discoveryService.discoverUpstreamModels(
        query: query,
        source: source,
        forceRefresh: true,
      );
      _discoveredModels = result.models;
      ModelCatalogService.registerDiscoveredModels(result.models);
      _discoveryMessage = 'Found ${result.models.length} models across sources';
    } catch (e) {
      _discoveryMessage = 'Discovery failed: $e';
    } finally {
      _isDiscovering = false;
      notifyListeners();
    }
  }

  // Catalog Filter Getters and Setters
  String get catalogSearchQuery => _catalogSearchQuery;
  String get selectedCategory => _selectedCategory;
  String get selectedSize => _selectedSize;
  String get selectedSizeTier => _selectedSizeTier;
  String get selectedFamily => _selectedFamily;
  String get selectedRagRole => _selectedRagRole;
  String get selectedModality => _selectedModality;
  String get selectedTask => _selectedTask;
  String get selectedVerification => _selectedVerification;
  String get selectedStatus => _selectedStatus;
  String get selectedSortBy => _selectedSortBy;
  bool get hardwareCompatibleOnly => _hardwareCompatibleOnly;

  void setCatalogSearchQuery(String q) {
    _catalogSearchQuery = q;
    notifyListeners();
  }

  void setSelectedCategory(String cat) {
    _selectedCategory = cat;
    notifyListeners();
  }

  void setSelectedSize(String size) {
    _selectedSize = size;
    notifyListeners();
  }

  void setSelectedSizeTier(String tier) {
    _selectedSizeTier = tier;
    notifyListeners();
  }

  void setSelectedFamily(String family) {
    _selectedFamily = family;
    notifyListeners();
  }

  void setSelectedRagRole(String role) {
    _selectedRagRole = role;
    notifyListeners();
  }

  void setSelectedModality(String modality) {
    _selectedModality = modality;
    notifyListeners();
  }

  void setSelectedTask(String task) {
    _selectedTask = task;
    notifyListeners();
  }

  void setSelectedVerification(String v) {
    _selectedVerification = v;
    notifyListeners();
  }

  void setSelectedStatus(String status) {
    _selectedStatus = status;
    notifyListeners();
  }

  void setSelectedSortBy(String sort) {
    _selectedSortBy = sort;
    notifyListeners();
  }

  void setHardwareCompatibleOnly(bool enabled) {
    _hardwareCompatibleOnly = enabled;
    notifyListeners();
  }

  void resetAllFilters() {
    _catalogSearchQuery = '';
    _selectedCategory = 'All';
    _selectedSize = 'All';
    _selectedSizeTier = 'All';
    _selectedFamily = 'All';
    _selectedRagRole = 'All';
    _selectedModality = 'All';
    _selectedTask = 'All';
    _selectedVerification = 'All';
    _selectedStatus = 'All';
    _hardwareCompatibleOnly = false;
    _selectedSortBy = 'Popularity';
    notifyListeners();
  }

  List<RagPipelineRecommendation> get ragPipelineRecommendations =>
      ModelCatalogService.getRagPipelineRecommendations();

  /// Full Catalog Items
  List<ModelCatalogItem> get catalogModels => ModelCatalogService.catalog;

  /// Filtered Catalog Items based on active filters
  List<ModelCatalogItem> get filteredCatalogModels {
    final installedNames = _installedModels.map((m) => m.name).toList();
    final favList = _settingsService.favoriteModels;
    final ram = _hardwareProfile?.totalRamGb ?? 16.0;

    return ModelCatalogService.searchModels(
      query: _catalogSearchQuery,
      category: _selectedCategory,
      sizeFilter: _selectedSize,
      hardwareCompatibleOnly: _hardwareCompatibleOnly,
      systemRamGb: ram,
      installedModelIds: installedNames,
      statusFilter: _selectedStatus,
      favoriteIds: favList,
      sortBy: _selectedSortBy,
      sizeTier: _selectedSizeTier,
      familyFilter: _selectedFamily,
      ragRoleFilter: _selectedRagRole,
      modalityFilter: _selectedModality,
      taskFilter: _selectedTask,
      verificationFilter: _selectedVerification,
    );
  }

  /// Launch or recover local Ollama daemon
  Future<DaemonLaunchResult> launchOrRecoverOllama() async {
    _isRecoveringDaemon = true;
    _recoveryStatusMessage = 'Checking daemon and initiating recovery...';
    notifyListeners();

    try {
      final result = await _processService.launchDaemon(customHost: _settingsService.ollamaHost);
      _recoveryStatusMessage = result.message;

      if (result.success) {
        await refreshModels();
      } else {
        _errorMessage = result.message;
      }
      return result;
    } finally {
      _isRecoveringDaemon = false;
      notifyListeners();
    }
  }

  /// One-Click Start Ollama Daemon
  Future<DaemonLaunchResult> startOllama() => launchOrRecoverOllama();

  /// One-Click Stop Ollama Daemon
  Future<DaemonStopResult> stopOllama() async {
    _isRecoveringDaemon = true;
    _recoveryStatusMessage = 'Stopping Ollama daemon...';
    notifyListeners();

    try {
      final result = await _processService.stopDaemon(customHost: _settingsService.ollamaHost);
      _recoveryStatusMessage = result.message;
      await refreshModels();
      return result;
    } finally {
      _isRecoveringDaemon = false;
      notifyListeners();
    }
  }

  /// One-Click Restart Ollama Daemon
  Future<DaemonLaunchResult> restartOllama() async {
    _isRecoveringDaemon = true;
    _recoveryStatusMessage = 'Restarting Ollama daemon...';
    notifyListeners();

    try {
      final result = await _processService.restartDaemon(customHost: _settingsService.ollamaHost);
      _recoveryStatusMessage = result.message;
      await refreshModels();
      return result;
    } finally {
      _isRecoveringDaemon = false;
      notifyListeners();
    }
  }

  /// Check Connection action
  Future<DaemonStatusResult> checkConnection() async {
    final result = await _processService.checkConnection(customHost: _settingsService.ollamaHost);
    await refreshModels();
    return result;
  }

  /// Fetch installed models, loaded models, & check Ollama and AirLLM status
  Future<void> refreshModels() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final health = await _aiService.checkHealthDetails(customHost: _settingsService.ollamaHost);
      _isOllamaOnline = health['isOnline'] == true;
      _ollamaVersion = health['version'] as String?;
      _daemonLatencyMs = health['latencyMs'] as int?;

      // Check AirLLM daemon health concurrently
      try {
        final airllmHealth = await _aiService.checkAirLLMHealthDetails(customHost: _settingsService.airllmHost);
        _isAirLLMOnline = airllmHealth['isOnline'] == true;
        _airllmLatencyMs = airllmHealth['latencyMs'] as int?;
        if (_isAirLLMOnline) {
          _airllmStatus = await _aiService.fetchAirLLMStatus(customHost: _settingsService.airllmHost);
        } else {
          _airllmStatus = null;
        }
      } catch (_) {
        _isAirLLMOnline = false;
        _airllmLatencyMs = null;
        _airllmStatus = null;
      }

      if (_isOllamaOnline) {
        _installedModels = await _aiService.fetchInstalledModels(customHost: _settingsService.ollamaHost);
        _loadedModels = await _aiService.fetchLoadedModels(customHost: _settingsService.ollamaHost);
      } else {
        _installedModels = [];
        _loadedModels = [];
        if (!_isAirLLMOnline) {
          _errorMessage = health['error'] as String? ?? 'Ollama service offline.';
        }
      }
    } catch (e) {
      _isOllamaOnline = false;
      _installedModels = [];
      _loadedModels = [];
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Launch AirLLM Daemon
  Future<DaemonLaunchResult> launchAirLLMDaemon() async {
    _isRecoveringDaemon = true;
    _recoveryStatusMessage = 'Launching AirLLM layer-streaming daemon...';
    notifyListeners();

    try {
      final result = await _processService.launchAirLLMDaemon(
        customHost: _settingsService.airllmHost,
        customModel: _settingsService.airllmModel,
        compression: _settingsService.airllmCompression,
        device: _settingsService.airllmDevice,
      );
      _recoveryStatusMessage = result.message;
      await refreshModels();
      return result;
    } finally {
      _isRecoveringDaemon = false;
      notifyListeners();
    }
  }

  /// Stop AirLLM Daemon
  Future<DaemonStopResult> stopAirLLMDaemon() async {
    _isRecoveringDaemon = true;
    _recoveryStatusMessage = 'Stopping AirLLM daemon...';
    notifyListeners();

    try {
      final result = await _processService.stopAirLLMDaemon(customHost: _settingsService.airllmHost);
      _recoveryStatusMessage = result.message;
      await refreshModels();
      return result;
    } finally {
      _isRecoveringDaemon = false;
      notifyListeners();
    }
  }

  /// Restart AirLLM Daemon
  Future<DaemonLaunchResult> restartAirLLMDaemon() async {
    _isRecoveringDaemon = true;
    _recoveryStatusMessage = 'Restarting AirLLM daemon...';
    notifyListeners();

    try {
      final result = await _processService.restartAirLLMDaemon(
        customHost: _settingsService.airllmHost,
        customModel: _settingsService.airllmModel,
        compression: _settingsService.airllmCompression,
        device: _settingsService.airllmDevice,
      );
      _recoveryStatusMessage = result.message;
      await refreshModels();
      return result;
    } finally {
      _isRecoveringDaemon = false;
      notifyListeners();
    }
  }

  /// Alias for launchAirLLMDaemon
  Future<DaemonLaunchResult> startAirLLMDaemon() => launchAirLLMDaemon();

  /// Check AirLLM daemon status and latency
  Future<void> checkAirLLMStatus() async {
    try {
      final airllmHealth = await _aiService.checkAirLLMHealthDetails(customHost: _settingsService.airllmHost);
      _isAirLLMOnline = airllmHealth['isOnline'] == true;
      _airllmLatencyMs = airllmHealth['latencyMs'] as int?;
      if (_isAirLLMOnline) {
        _airllmStatus = await _aiService.fetchAirLLMStatus(customHost: _settingsService.airllmHost);
      } else {
        _airllmStatus = null;
      }
    } catch (_) {
      _isAirLLMOnline = false;
      _airllmLatencyMs = null;
      _airllmStatus = null;
    }
    notifyListeners();
  }

  /// Preload model into RAM/VRAM
  Future<bool> preloadModel(String modelName) async {
    try {
      final success = await _aiService.preloadModel(modelName, customHost: _settingsService.ollamaHost);
      if (success) {
        await _settingsService.addRecentModel(modelName);
        _loadedModels = await _aiService.fetchLoadedModels(customHost: _settingsService.ollamaHost);
        notifyListeners();
      }
      return success;
    } catch (e) {
      _errorMessage = 'Failed to load model: $e';
      notifyListeners();
      return false;
    }
  }

  /// Unload model from RAM/VRAM (keep_alive: 0)
  Future<bool> unloadModel(String modelName) async {
    try {
      final success = await _aiService.unloadModel(modelName, customHost: _settingsService.ollamaHost);
      if (success) {
        _loadedModels = await _aiService.fetchLoadedModels(customHost: _settingsService.ollamaHost);
        notifyListeners();
      }
      return success;
    } catch (e) {
      _errorMessage = 'Failed to unload model: $e';
      notifyListeners();
      return false;
    }
  }

  /// Check whether a model is currently loaded in memory
  bool isModelLoaded(String modelName) {
    final target = modelName.toLowerCase().trim();
    return _loadedModels.any((m) {
      final mLower = m.name.toLowerCase().trim();
      return mLower == target || mLower.startsWith('$target:');
    });
  }

  /// Computes memory and VRAM tier estimation guidance (MOD-001)
  static ModelMemoryGuidance getMemoryGuidance({
    int? sizeBytes,
    String? sizeString,
    String? modelId,
  }) {
    double? sizeGb;

    if (sizeBytes != null && sizeBytes > 0) {
      sizeGb = sizeBytes / (1024 * 1024 * 1024);
    } else if (sizeString != null && sizeString.isNotEmpty) {
      final upper = sizeString.toUpperCase().trim();
      final match = RegExp(r'([\d.]+)\s*(GB|MB)').firstMatch(upper);
      if (match != null) {
        final val = double.tryParse(match.group(1) ?? '');
        final unit = match.group(2);
        if (val != null) {
          sizeGb = (unit == 'GB') ? val : (val / 1024.0);
        }
      }
    }

    if (sizeGb != null) {
      if (sizeGb < 2.0) {
        return const ModelMemoryGuidance(
          label: 'Comfortable on 8GB RAM',
          color: OllivoTheme.oliveEmerald,
          recommendation: 'Smooth on any Mac (8GB+ RAM, Intel or Apple Silicon M1-M4).',
          minRamGb: 8,
        );
      } else if (sizeGb < 5.0) {
        return const ModelMemoryGuidance(
          label: '8GB - 16GB RAM Recommended',
          color: OllivoTheme.statusWarning,
          recommendation: 'Runs well with Apple Silicon Unified Memory or 16GB system RAM.',
          minRamGb: 16,
        );
      } else {
        return const ModelMemoryGuidance(
          label: 'Apple Silicon 24GB+ Recommended',
          color: Color(0xFFE06C75),
          recommendation: 'High memory footprint. 24GB+ Unified Memory recommended for long context.',
          minRamGb: 24,
        );
      }
    }

    // Fallback parameter size heuristics based on tag name
    final tag = (modelId ?? '').toLowerCase();
    if (tag.contains('70b') || tag.contains('32b') || tag.contains('14b') || tag.contains('27b')) {
      return const ModelMemoryGuidance(
        label: 'Apple Silicon 24GB+ Recommended',
        color: Color(0xFFE06C75),
        recommendation: 'High memory footprint. 24GB+ Unified Memory recommended.',
        minRamGb: 24,
      );
    } else if (tag.contains('7b') || tag.contains('8b') || tag.contains('9b') || tag.contains('13b')) {
      return const ModelMemoryGuidance(
        label: '8GB - 16GB RAM Recommended',
        color: OllivoTheme.statusWarning,
        recommendation: 'Runs well with Apple Silicon Unified Memory or 16GB system RAM.',
        minRamGb: 16,
      );
    } else {
      return const ModelMemoryGuidance(
        label: 'Comfortable on 8GB RAM',
        color: OllivoTheme.oliveEmerald,
        recommendation: 'Low memory footprint. Smooth on any Mac.',
        minRamGb: 8,
      );
    }
  }

  /// Validates an arbitrary Ollama or HuggingFace model tag (MOD-003)
  static String? validateCustomTag(String tag) {
    final trimmed = tag.trim();
    if (trimmed.isEmpty) {
      return 'Please enter a model name or tag.';
    }
    if (trimmed.contains(' ')) {
      return 'Model tag cannot contain whitespace.';
    }
    if (!RegExp(r'^[a-zA-Z0-9_\-./:]+$').hasMatch(trimmed)) {
      return 'Tag contains invalid characters. Use alphanumeric, dashes, colons, or slashes.';
    }
    return null; // valid
  }

  /// Select active model
  Future<void> selectActiveModel(String modelName) async {
    await _settingsService.setActiveModel(modelName);
    if (modelName.isNotEmpty) {
      await _settingsService.addRecentModel(modelName);
    }
    notifyListeners();
  }

  /// Download model using real-time Ollama streaming pull endpoint
  Future<void> downloadModel(String modelId) async {
    if (_activeDownloadingModel != null) {
      _errorMessage = 'A model download is already in progress.';
      notifyListeners();
      return;
    }

    _activeDownloadingModel = modelId;
    _downloadProgress = OllamaPullProgress(status: 'Starting download...');
    _errorMessage = null;
    notifyListeners();

    _pullSubscription?.cancel();
    _pullSubscription = _aiService.pullModelStream(modelId, customHost: _settingsService.ollamaHost).listen(
      (progress) {
        _downloadProgress = progress;
        notifyListeners();

        if (progress.isFinished) {
          _activeDownloadingModel = null;
          _downloadProgress = null;
          _settingsService.addRecentModel(modelId);
          refreshModels();
        } else if (progress.error != null) {
          _errorMessage = 'Download failed: ${progress.error}';
          _activeDownloadingModel = null;
          _downloadProgress = null;
          notifyListeners();
        }
      },
      onError: (e) {
        _errorMessage = 'Download error: ${e.toString()}';
        _activeDownloadingModel = null;
        _downloadProgress = null;
        notifyListeners();
      },
      onDone: () {
        if (_activeDownloadingModel != null) {
          _activeDownloadingModel = null;
          _downloadProgress = null;
          refreshModels();
        }
      },
    );
  }

  /// Cancel active model download
  void cancelDownload() {
    _aiService.cancelPullModel();
    _pullSubscription?.cancel();
    _pullSubscription = null;
    _activeDownloadingModel = null;
    _downloadProgress = null;
    notifyListeners();
  }

  /// Delete installed model
  Future<bool> deleteModel(String modelName) async {
    _isLoading = true;
    notifyListeners();

    try {
      final success = await _aiService.deleteModel(modelName, customHost: _settingsService.ollamaHost);
      if (success) {
        if (_settingsService.activeModel == modelName) {
          final remaining = await _aiService.fetchInstalledModels(customHost: _settingsService.ollamaHost);
          if (remaining.isNotEmpty) {
            await selectActiveModel(remaining.first.name);
          } else {
            await selectActiveModel('');
          }
        }
        await refreshModels();
        return true;
      } else {
        _errorMessage = 'Failed to delete model "$modelName".';
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error deleting model: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  bool isInstalled(String modelId) {
    final targetLower = modelId.toLowerCase().trim();
    return _installedModels.any((m) {
      final mNameLower = m.name.toLowerCase().trim();
      return mNameLower == targetLower || mNameLower.startsWith('$targetLower:');
    });
  }

  @override
  void dispose() {
    _pullSubscription?.cancel();
    super.dispose();
  }
}

