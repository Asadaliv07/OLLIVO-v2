import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../ai_service.dart';
import '../settings_service.dart';

/// Common Model Provider Interface (MOD-PROV-001)
abstract class InferenceBackendProvider {
  String get id;
  String get name;
  String get description;
  String get endpointUrl;
  bool get isLocalOnly;
  List<String> get supportedCategories;

  Future<bool> checkInstalled();
  Future<Map<String, dynamic>> checkHealth();
  Future<List<String>> listAvailableModels();
}

/// Official Ollama Backend Provider for local LLMs, Vision & Embeddings
class OllamaBackendProvider implements InferenceBackendProvider {
  final AIService _aiService;
  final String _customHost;

  OllamaBackendProvider({AIService? aiService, String? host})
      : _aiService = aiService ?? AIService(),
        _customHost = host ?? 'http://localhost:11434';

  @override
  String get id => 'ollama';

  @override
  String get name => 'Ollama Local Daemon';

  @override
  String get description => 'Primary local inference runtime for LLMs, vision, and dense vector embeddings.';

  @override
  String get endpointUrl => _customHost;

  @override
  bool get isLocalOnly => true;

  @override
  List<String> get supportedCategories => [
        'Lightweight',
        'Medium',
        'Coding',
        'Reasoning',
        'Vision',
        'Embeddings',
      ];

  @override
  Future<bool> checkInstalled() async {
    return _aiService.checkHealth(customHost: _customHost);
  }

  @override
  Future<Map<String, dynamic>> checkHealth() async {
    return _aiService.checkHealthDetails(customHost: _customHost);
  }

  @override
  Future<List<String>> listAvailableModels() async {
    final installed = await _aiService.fetchInstalledModels(customHost: _customHost);
    return installed.map((m) => m.name).toList();
  }
}

/// Modular Image Generation Provider Adapter (ComfyUI / SD WebUI / Diffusers)
class ImageGenBackendProvider implements InferenceBackendProvider {
  final String _endpointUrl;
  final http.Client _client;

  ImageGenBackendProvider({String? endpointUrl, http.Client? client})
      : _endpointUrl = endpointUrl ?? 'http://localhost:8188',
        _client = client ?? http.Client();

  @override
  String get id => 'comfyui';

  @override
  String get name => 'Local ComfyUI / Stable Diffusion';

  @override
  String get description => 'Modular local backend adapter for diffusion pipelines (SD 1.5, SDXL, FLUX.1).';

  @override
  String get endpointUrl => _endpointUrl;

  @override
  bool get isLocalOnly => true;

  @override
  List<String> get supportedCategories => ['Image Generation'];

  @override
  Future<bool> checkInstalled() async {
    try {
      final res = await _client.get(Uri.parse('$_endpointUrl/system_stats')).timeout(const Duration(seconds: 2));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>> checkHealth() async {
    try {
      final res = await _client.get(Uri.parse('$_endpointUrl/system_stats')).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        return {
          'isOnline': true,
          'status': 'Online',
          'message': 'Connected to local ComfyUI engine at $_endpointUrl',
        };
      }
    } catch (_) {}
    return {
      'isOnline': false,
      'status': 'Offline',
      'message': 'ComfyUI is not currently responding at $_endpointUrl. Start ComfyUI locally or configure endpoint.',
    };
  }

  @override
  Future<List<String>> listAvailableModels() async {
    return [
      'v1-5-pruned-emaonly.safetensors',
      'sd_xl_base_1.0.safetensors',
      'flux1-schnell.safetensors',
    ];
  }
}

/// Modular Audio & Speech Provider Adapter (Whisper STT / Piper / Kokoro TTS)
class AudioBackendProvider implements InferenceBackendProvider {
  final String _endpointUrl;
  final http.Client _client;

  AudioBackendProvider({String? endpointUrl, http.Client? client})
      : _endpointUrl = endpointUrl ?? 'http://localhost:8000',
        _client = client ?? http.Client();

  @override
  String get id => 'whisper_piper';

  @override
  String get name => 'Local Whisper & Piper Audio Engine';

  @override
  String get description => 'Modular audio engine for local STT speech recognition and neural text-to-speech.';

  @override
  String get endpointUrl => _endpointUrl;

  @override
  bool get isLocalOnly => true;

  @override
  List<String> get supportedCategories => ['Audio'];

  @override
  Future<bool> checkInstalled() async {
    try {
      final res = await _client.get(Uri.parse('$_endpointUrl/health')).timeout(const Duration(seconds: 2));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>> checkHealth() async {
    try {
      final res = await _client.get(Uri.parse('$_endpointUrl/health')).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        return {
          'isOnline': true,
          'status': 'Online',
          'message': 'Connected to local audio engine at $_endpointUrl',
        };
      }
    } catch (_) {}
    return {
      'isOnline': false,
      'status': 'Standby',
      'message': 'Audio engine running on-demand via native macOS CoreAudio and local binaries.',
    };
  }

  @override
  Future<List<String>> listAvailableModels() async {
    return [
      'whisper-base',
      'whisper-small',
      'kokoro-82m',
      'piper-en-ryan',
    ];
  }
}

/// Modular Video Provider Adapter
class VideoBackendProvider implements InferenceBackendProvider {
  final String _endpointUrl;

  VideoBackendProvider({String? endpointUrl}) : _endpointUrl = endpointUrl ?? 'http://localhost:8200';

  @override
  String get id => 'video_engine';

  @override
  String get name => 'Local Video Processing Engine';

  @override
  String get description => 'Modular local adapter for video captioning, spatio-temporal reasoning, and generation.';

  @override
  String get endpointUrl => _endpointUrl;

  @override
  bool get isLocalOnly => true;

  @override
  List<String> get supportedCategories => ['Video'];

  @override
  Future<bool> checkInstalled() async => false;

  @override
  Future<Map<String, dynamic>> checkHealth() async {
    return {
      'isOnline': false,
      'status': 'Optional Integration',
      'message': 'Requires local Video-LLaMA or CogVideoX engine daemon.',
    };
  }

  @override
  Future<List<String>> listAvailableModels() async => ['video-llama2:7b', 'cogvideox-2b'];
}

/// Official AirLLM Layer-Streaming Backend Provider for 70B+ LLMs (AIR-PROV-001)
class AirLLMBackendProvider implements InferenceBackendProvider {
  final String _endpointUrl;
  final http.Client _client;

  AirLLMBackendProvider({String? endpointUrl, http.Client? client})
      : _endpointUrl = endpointUrl ?? 'http://127.0.0.1:8765',
        _client = client ?? http.Client();

  @override
  String get id => 'airllm';

  @override
  String get name => 'AirLLM Layer-Streaming Engine';

  @override
  String get description =>
      'Ultra-efficient local layer-streaming inference engine for running 70B+ LLMs on low-VRAM Macs directly from SSD.';

  @override
  String get endpointUrl => _endpointUrl;

  @override
  bool get isLocalOnly => true;

  @override
  List<String> get supportedCategories => [
        'AirLLM (70B+)',
        'Layer Streaming',
        'Large Models',
        'DeepSeek',
        'Llama 70B',
        'AirLLM',
      ];

  @override
  Future<bool> checkInstalled() async {
    try {
      final res = await _client
          .get(Uri.parse('$_endpointUrl/health'))
          .timeout(const Duration(seconds: 2));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>> checkHealth() async {
    try {
      final res = await _client
          .get(Uri.parse('$_endpointUrl/api/ai/status'))
          .timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final state = data['state'] as String? ?? data['status'] as String? ?? 'unknown';
        final isOnline = state == 'ready' || state == 'busy' || state == 'unloaded' || state == 'healthy';
        final modelId = data['model_id'] as String? ?? data['active_model'] as String? ?? 'None loaded';
        final freeDisk = data['free_disk_gb']?.toString() ?? 'N/A';
        final rss = data['rss_memory_mb']?.toString() ?? 'N/A';
        return {
          'isOnline': isOnline,
          'status': isOnline ? (state == 'ready' ? 'Online · Ready' : state.toUpperCase()) : 'Offline',
          'state': state,
          'modelId': modelId,
          'freeDiskGb': freeDisk,
          'rssMemoryMb': rss,
          'message': 'Connected to AirLLM Service at $_endpointUrl (Active: $modelId, Free Disk: ${freeDisk}GB, RAM: ${rss}MB)',
        };
      }
    } catch (_) {}
    return {
      'isOnline': false,
      'status': 'Offline',
      'state': 'offline',
      'message': 'AirLLM service is not responding at $_endpointUrl. Start the daemon from Settings -> Runtime.',
    };
  }

  @override
  Future<List<String>> listAvailableModels() async {
    try {
      final res = await _client
          .get(Uri.parse('$_endpointUrl/api/ai/models'))
          .timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data.containsKey('models') && data['models'] is List) {
          final list = data['models'] as List;
          return list
              .map((m) => (m['id'] as String? ?? m['name'] as String? ?? ''))
              .where((s) => s.isNotEmpty)
              .toList();
        }
      }
    } catch (_) {}
    return [
      'meta-llama/Meta-Llama-3-70B-Instruct',
      'deepseek-ai/DeepSeek-R1-Distill-Llama-70B',
      'Qwen/Qwen2.5-72B-Instruct',
      'meta-llama/Meta-Llama-3-8B-Instruct',
    ];
  }
}

/// llama.cpp GGUF Inference Engine Provider (ggml-org/llama.cpp)
class LlamaCppBackendProvider implements InferenceBackendProvider {
  final String _endpointUrl;
  final http.Client _client;

  LlamaCppBackendProvider({String? endpointUrl, http.Client? client})
      : _endpointUrl = endpointUrl ?? 'http://127.0.0.1:8080',
        _client = client ?? http.Client();

  @override
  String get id => 'llamacpp';

  @override
  String get name => 'llama.cpp GGUF Server';

  @override
  String get description =>
      'Blazing-fast C/C++ GGUF inference engine with native Metal hardware acceleration on Apple Silicon.';

  @override
  String get endpointUrl => _endpointUrl;

  @override
  bool get isLocalOnly => true;

  @override
  List<String> get supportedCategories => [
        'GGUF',
        'llama.cpp',
        'Metal',
        'Quantized',
        'Local LLM',
      ];

  @override
  Future<bool> checkInstalled() async {
    try {
      final res = await _client
          .get(Uri.parse('$_endpointUrl/health'))
          .timeout(const Duration(seconds: 2));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>> checkHealth() async {
    try {
      final res = await _client
          .get(Uri.parse('$_endpointUrl/health'))
          .timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        return {
          'isOnline': true,
          'status': 'Online · Ready',
          'message': 'Connected to llama.cpp server at $_endpointUrl',
        };
      }
    } catch (_) {}
    return {
      'isOnline': false,
      'status': 'Offline',
      'message': 'llama.cpp server is not responding at $_endpointUrl',
    };
  }

  @override
  Future<List<String>> listAvailableModels() async {
    try {
      final res = await _client
          .get(Uri.parse('$_endpointUrl/v1/models'))
          .timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data.containsKey('data') && data['data'] is List) {
          final list = data['data'] as List;
          return list
              .map((m) => (m['id'] as String? ?? ''))
              .where((s) => s.isNotEmpty)
              .toList();
        }
      }
    } catch (_) {}
    return ['local-model.gguf'];
  }
}

/// LiteLLM Universal Proxy Gateway Provider (BerriAI/litellm)
class LiteLLMBackendProvider implements InferenceBackendProvider {
  final String _endpointUrl;
  final http.Client _client;

  LiteLLMBackendProvider({String? endpointUrl, http.Client? client})
      : _endpointUrl = endpointUrl ?? 'http://127.0.0.1:4000',
        _client = client ?? http.Client();

  @override
  String get id => 'litellm';

  @override
  String get name => 'LiteLLM Universal Proxy';

  @override
  String get description =>
      'Universal proxy gateway providing an OpenAI-compatible interface to 100+ local and cloud LLMs.';

  @override
  String get endpointUrl => _endpointUrl;

  @override
  bool get isLocalOnly => false;

  @override
  List<String> get supportedCategories => [
        'LiteLLM',
        'Universal Gateway',
        'Proxy',
        'Multi-Provider',
      ];

  @override
  Future<bool> checkInstalled() async {
    try {
      final res = await _client
          .get(Uri.parse('$_endpointUrl/health/readiness'))
          .timeout(const Duration(seconds: 2));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>> checkHealth() async {
    try {
      final res = await _client
          .get(Uri.parse('$_endpointUrl/health/readiness'))
          .timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        return {
          'isOnline': true,
          'status': 'Online · Ready',
          'message': 'Connected to LiteLLM Gateway at $_endpointUrl',
        };
      }
    } catch (_) {}
    return {
      'isOnline': false,
      'status': 'Offline',
      'message': 'LiteLLM Gateway is not responding at $_endpointUrl',
    };
  }

  @override
  Future<List<String>> listAvailableModels() async {
    try {
      final res = await _client
          .get(Uri.parse('$_endpointUrl/v1/models'))
          .timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data.containsKey('data') && data['data'] is List) {
          final list = data['data'] as List;
          return list
              .map((m) => (m['id'] as String? ?? ''))
              .where((s) => s.isNotEmpty)
              .toList();
        }
      }
    } catch (_) {}
    return ['gpt-4o-mini', 'claude-3-5-sonnet', 'ollama/llama3:8b'];
  }
}

/// Provider Registry Service (MOD-PROV-002)
class ProviderRegistry {
  final List<InferenceBackendProvider> _providers = [];

  ProviderRegistry({AIService? aiService, String? airllmHost, String? llamaCppHost, String? litellmHost}) {
    _providers.addAll([
      OllamaBackendProvider(aiService: aiService),
      AirLLMBackendProvider(endpointUrl: airllmHost),
      LlamaCppBackendProvider(endpointUrl: llamaCppHost),
      LiteLLMBackendProvider(endpointUrl: litellmHost),
      ImageGenBackendProvider(),
      AudioBackendProvider(),
      VideoBackendProvider(),
    ]);
  }

  List<InferenceBackendProvider> get providers => List.unmodifiable(_providers);

  InferenceBackendProvider? getProviderForCategory(String category) {
    for (final p in _providers) {
      if (p.supportedCategories.contains(category)) {
        return p;
      }
    }
    return _providers.first; // fallback to Ollama
  }

  InferenceBackendProvider? getProviderById(String id) {
    for (final p in _providers) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Resolves the authoritative active inference provider based on the central SettingsService switch (AIR-ROUTER-002)
  InferenceBackendProvider getActiveProvider(SettingsService settings) {
    if (settings.airllmEnabled) {
      return getProviderById('airllm') ?? _providers.first;
    }
    return getProviderById(settings.activeBackend) ?? _providers.first;
  }
}
