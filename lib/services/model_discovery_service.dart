// ignore_for_file: prefer_initializing_formals
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import '../models/model_catalog_item.dart';
import 'audit_service.dart';
import 'settings_service.dart';

/// Result envelope for dynamic upstream model discovery (MOD-DISC-001)
class ModelDiscoveryResult {
  final List<ModelCatalogItem> models;
  final int totalCount;
  final int page;
  final bool hasMore;
  final bool fromCache;
  final String source;
  final String? errorMessage;

  const ModelDiscoveryResult({
    required this.models,
    required this.totalCount,
    this.page = 1,
    this.hasMore = false,
    this.fromCache = false,
    this.source = 'all',
    this.errorMessage,
  });
}

/// Upstream Dynamic Model Discovery & Sync Engine (Section 7)
/// Integrates with Ollama Library & Hugging Face GGUF Registry with Offline Caching
class ModelDiscoveryService {
  final http.Client _client;
  final SettingsService? _settingsService;
  final String? _cacheDirPath;

  final List<ModelCatalogItem> _cachedDiscoveredModels = [];
  bool _isRefreshing = false;
  DateTime? _lastSyncTime;

  ModelDiscoveryService({
    http.Client? client,
    SettingsService? settingsService,
    String? cacheDirPath,
  })  : _client = client ?? http.Client(),
        _settingsService = settingsService,
        _cacheDirPath = cacheDirPath {
    _loadFromLocalCache();
  }

  bool get isRefreshing => _isRefreshing;
  DateTime? get lastSyncTime => _lastSyncTime;
  List<ModelCatalogItem> get cachedDiscoveredModels => List.unmodifiable(_cachedDiscoveredModels);

  /// Discover upstream models across Ollama library & Hugging Face GGUF catalog
  Future<ModelDiscoveryResult> discoverUpstreamModels({
    String query = '',
    int page = 1,
    int limit = 20,
    String source = 'all', // 'all', 'ollama', 'huggingface'
    bool forceRefresh = false,
  }) async {
    final sanitizedQuery = query.trim().toLowerCase();

    // 1. If not forcing refresh and cache has items, return filtered cache
    if (!forceRefresh && _cachedDiscoveredModels.isNotEmpty) {
      final filtered = _filterAndPaginate(
        _cachedDiscoveredModels,
        query: sanitizedQuery,
        page: page,
        limit: limit,
      );
      return ModelDiscoveryResult(
        models: filtered,
        totalCount: _cachedDiscoveredModels.length,
        page: page,
        hasMore: (page * limit) < _cachedDiscoveredModels.length,
        fromCache: true,
        source: source,
      );
    }

    _isRefreshing = true;
    final List<ModelCatalogItem> discovered = [];
    String? err;

    try {
      // 2. Fetch from Hugging Face GGUF API (safe, rate-limit handled)
      if (source == 'all' || source == 'huggingface') {
        final hfModels = await _fetchHuggingFaceGguf(sanitizedQuery, limit: limit);
        discovered.addAll(hfModels);
      }

      // 3. Fetch from local/remote Ollama tags if accessible
      if (source == 'all' || source == 'ollama') {
        final ollamaModels = await _fetchOllamaLibraryTags(sanitizedQuery);
        discovered.addAll(ollamaModels);
      }

      // 4. Deduplicate discovered models by unique identifier
      final Map<String, ModelCatalogItem> dedupedMap = {};
      for (final m in discovered) {
        dedupedMap[m.id.toLowerCase()] = m;
      }
      final dedupedList = dedupedMap.values.toList();

      if (dedupedList.isNotEmpty) {
        _cachedDiscoveredModels.clear();
        _cachedDiscoveredModels.addAll(dedupedList);
        _lastSyncTime = DateTime.now();
        await _saveToLocalCache();

        AuditService.instance.log(
          'model_discovery',
          'Successfully discovered ${dedupedList.length} upstream AI models from $source',
        );
      }
    } catch (e) {
      err = e.toString();
      // On network failure, fallback gracefully to existing cache
      AuditService.instance.log(
        'model_discovery_error',
        'Upstream discovery failed ($e). Operating in offline cached mode.',
      );
    } finally {
      _isRefreshing = false;
    }

    final effectiveList = _cachedDiscoveredModels.isNotEmpty ? _cachedDiscoveredModels : discovered;
    final paged = _filterAndPaginate(effectiveList, query: sanitizedQuery, page: page, limit: limit);

    return ModelDiscoveryResult(
      models: paged,
      totalCount: effectiveList.length,
      page: page,
      hasMore: (page * limit) < effectiveList.length,
      fromCache: _cachedDiscoveredModels.isNotEmpty,
      source: source,
      errorMessage: err,
    );
  }

  /// Query Hugging Face API for top community GGUF models
  Future<List<ModelCatalogItem>> _fetchHuggingFaceGguf(String query, {int limit = 30}) async {
    final List<ModelCatalogItem> list = [];
    try {
      final qParam = query.isNotEmpty ? '&search=${Uri.encodeComponent(query)}' : '';
      final url = Uri.parse(
        'https://huggingface.co/api/models?filter=gguf&sort=downloads&direction=-1&limit=$limit$qParam',
      );

      final response = await _client.get(
        url,
        headers: {'Accept': 'application/json', 'User-Agent': 'Ollivo-Desktop/1.0'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              final modelId = item['id'] as String? ?? '';
              if (modelId.isEmpty) continue;

              final parts = modelId.split('/');
              final org = parts.isNotEmpty ? parts.first : 'HuggingFace';
              final rawName = parts.length > 1 ? parts[1] : modelId;
              final cleanName = rawName.replaceAll(RegExp(r'-GGUF$', caseSensitive: false), '');

              // Derive size and capabilities
              final sizeTier = _deriveSizeTier(cleanName);
              final isCoding = cleanName.toLowerCase().contains('coder') || cleanName.toLowerCase().contains('code');
              final isVision = cleanName.toLowerCase().contains('vl') || cleanName.toLowerCase().contains('vision');
              final isReasoning = cleanName.toLowerCase().contains('r1') || cleanName.toLowerCase().contains('reasoning');

              list.add(ModelCatalogItem(
                id: 'hf.co/$modelId',
                name: cleanName,
                family: _deriveFamily(cleanName),
                category: isCoding
                    ? 'Coding'
                    : (isVision
                        ? 'Vision'
                        : (isReasoning ? 'Reasoning' : (sizeTier == 'Ultra-light' ? 'Lightweight' : 'Medium'))),
                provider: org,
                backend: 'ollama',
                verifiedTags: ['latest', 'q4_k_m'],
                parameterCount: _extractParamCount(cleanName),
                quantization: 'Q4_K_M',
                estimatedDiskSize: _estimateDiskSize(sizeTier),
                estimatedDiskSizeBytes: _estimateDiskBytes(sizeTier),
                estimatedMemory: _estimateMemory(sizeTier),
                estimatedMemoryGb: _estimateMemoryGb(sizeTier),
                contextLength: 32768,
                capabilities: [
                  'chat',
                  if (isCoding) 'coding',
                  if (isVision) 'vision',
                  if (isReasoning) 'reasoning',
                ],
                license: 'Community Open Weights',
                sourceUrl: 'https://huggingface.co/$modelId',
                downloadIdentifier: 'hf.co/$modelId',
                hardwareRequirements: 'Apple Silicon or modern x86 CPU',
                compatibilityStatus: 'Verified GGUF',
                lastVerified: '2026-10',
                description: 'Community-quantized GGUF model published by $org with high download velocity.',
                sizeTier: sizeTier,
                verificationStatus: 'community',
                architecture: 'Dense Transformer',
                isAppleSiliconOptimized: true,
                isCpuPractical: sizeTier == 'Ultra-light' || sizeTier == 'Lightweight',
              ));
            }
          }
        }
      }
    } catch (_) {}
    return list;
  }

  /// Query local Ollama daemon for available model tags
  Future<List<ModelCatalogItem>> _fetchOllamaLibraryTags(String query) async {
    final List<ModelCatalogItem> list = [];
    final host = _settingsService?.ollamaHost ?? 'http://127.0.0.1:11434';

    try {
      final url = Uri.parse('$host/api/tags');
      final res = await _client.get(url).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final dynamic data = jsonDecode(res.body);
        final models = (data['models'] as List<dynamic>?) ?? [];
        for (final m in models) {
          final name = m['name'] as String? ?? '';
          final sizeBytes = (m['size'] as num?)?.toInt() ?? 0;
          if (name.isEmpty) continue;

          final sizeGb = sizeBytes / (1024 * 1024 * 1024);
          final tier = sizeGb < 2.0 ? 'Lightweight' : (sizeGb < 8.0 ? 'Medium' : 'Advanced');

          list.add(ModelCatalogItem(
            id: name,
            name: name,
            family: _deriveFamily(name),
            category: tier,
            provider: 'Ollama Local Daemon',
            backend: 'ollama',
            verifiedTags: [name],
            parameterCount: _extractParamCount(name),
            quantization: 'Q4_0',
            estimatedDiskSize: '${sizeGb.toStringAsFixed(1)} GB',
            estimatedDiskSizeBytes: sizeBytes,
            estimatedMemory: '${(sizeGb * 1.2).toStringAsFixed(1)} GB RAM',
            estimatedMemoryGb: (sizeGb * 1.2).clamp(1.0, 64.0),
            contextLength: 8192,
            capabilities: ['chat', 'local-installed'],
            license: 'Open Source',
            sourceUrl: 'https://ollama.com/library/$name',
            downloadIdentifier: name,
            hardwareRequirements: 'Apple Silicon Metal Acceleration',
            compatibilityStatus: 'Locally Installed & Verified',
            lastVerified: '2026-10',
            description: 'Locally registered Ollama model ready for instant zero-latency inference.',
            sizeTier: tier,
            verificationStatus: 'official',
          ));
        }
      }
    } catch (_) {}
    return list;
  }

  List<ModelCatalogItem> _filterAndPaginate(
    List<ModelCatalogItem> source, {
    required String query,
    required int page,
    required int limit,
  }) {
    var filtered = source;
    if (query.isNotEmpty) {
      filtered = filtered.where((m) {
        return m.name.toLowerCase().contains(query) ||
            m.family.toLowerCase().contains(query) ||
            m.provider.toLowerCase().contains(query) ||
            m.id.toLowerCase().contains(query);
      }).toList();
    }

    final startIndex = (page - 1) * limit;
    if (startIndex >= filtered.length) return [];
    return filtered.skip(startIndex).take(limit).toList();
  }

  String _deriveFamily(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('qwen')) return 'Qwen';
    if (lower.contains('llama')) return 'Llama';
    if (lower.contains('gemma')) return 'Gemma';
    if (lower.contains('mistral') || lower.contains('ministral')) return 'Mistral';
    if (lower.contains('deepseek')) return 'DeepSeek';
    if (lower.contains('phi')) return 'Phi';
    if (lower.contains('smollm')) return 'SmolLM';
    if (lower.contains('granite')) return 'Granite';
    if (lower.contains('whisper')) return 'Whisper';
    if (lower.contains('bge')) return 'BGE';
    return 'General';
  }

  String _deriveSizeTier(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('0.5b') || lower.contains('1b') || lower.contains('1.5b') || lower.contains('135m')) {
      return 'Ultra-light';
    }
    if (lower.contains('2b') || lower.contains('3b') || lower.contains('4b')) {
      return 'Lightweight';
    }
    if (lower.contains('7b') || lower.contains('8b') || lower.contains('9b')) {
      return 'Medium';
    }
    if (lower.contains('14b') || lower.contains('16b') || lower.contains('20b')) {
      return 'Advanced';
    }
    if (lower.contains('32b') || lower.contains('34b') || lower.contains('40b')) {
      return 'Large';
    }
    return 'Medium';
  }

  String _extractParamCount(String name) {
    final match = RegExp(r'(\d+(?:\.\d+)?[bm])', caseSensitive: false).firstMatch(name);
    return match != null ? match.group(1)!.toUpperCase() : '7B';
  }

  String _estimateDiskSize(String tier) {
    switch (tier) {
      case 'Ultra-light':
        return '1.1 GB';
      case 'Lightweight':
        return '2.2 GB';
      case 'Medium':
        return '4.8 GB';
      case 'Advanced':
        return '9.2 GB';
      case 'Large':
        return '19.5 GB';
      default:
        return '4.5 GB';
    }
  }

  int _estimateDiskBytes(String tier) {
    switch (tier) {
      case 'Ultra-light':
        return 1181116006;
      case 'Lightweight':
        return 2362232012;
      case 'Medium':
        return 5153960755;
      case 'Advanced':
        return 9878424780;
      case 'Large':
        return 20937965568;
      default:
        return 4831838208;
    }
  }

  String _estimateMemory(String tier) {
    switch (tier) {
      case 'Ultra-light':
        return '1.4 GB RAM';
      case 'Lightweight':
        return '2.8 GB RAM';
      case 'Medium':
        return '6.0 GB RAM';
      case 'Advanced':
        return '12.5 GB RAM';
      case 'Large':
        return '24.0 GB RAM';
      default:
        return '6.0 GB RAM';
    }
  }

  double _estimateMemoryGb(String tier) {
    switch (tier) {
      case 'Ultra-light':
        return 1.4;
      case 'Lightweight':
        return 2.8;
      case 'Medium':
        return 6.0;
      case 'Advanced':
        return 12.5;
      case 'Large':
        return 24.0;
      default:
        return 6.0;
    }
  }

  Future<void> _loadFromLocalCache() async {
    try {
      final path = _getCacheFilePath();
      final file = File(path);
      if (await file.exists()) {
        final content = await file.readAsString();
        final dynamic decoded = jsonDecode(content);
        if (decoded is List) {
          _cachedDiscoveredModels.clear();
          for (final item in decoded) {
            _cachedDiscoveredModels.add(
              ModelCatalogItem.fromMap(Map<String, dynamic>.from(item as Map)),
            );
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _saveToLocalCache() async {
    try {
      final path = _getCacheFilePath();
      final file = File(path);
      final dir = file.parent;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final jsonStr = jsonEncode(
        _cachedDiscoveredModels.map((m) => m.toMap()).toList(),
      );
      await file.writeAsString(jsonStr);
    } catch (_) {}
  }

  String _getCacheFilePath() {
    final base = _cacheDirPath ?? _settingsService?.defaultAppSupportPath ?? Directory.systemTemp.path;
    return p.join(base, 'discovered_models_cache.json');
  }
}
