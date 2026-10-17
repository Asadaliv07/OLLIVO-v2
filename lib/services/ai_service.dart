import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';

/// Installed Ollama Model Information Data Model
class OllamaModelInfo {
  final String name;
  final int size;
  final String digest;
  final String modifiedAt;

  OllamaModelInfo({
    required this.name,
    required this.size,
    required this.digest,
    required this.modifiedAt,
  });

  factory OllamaModelInfo.fromJson(Map<String, dynamic> json) {
    return OllamaModelInfo(
      name: json['name'] as String? ?? 'unknown',
      size: json['size'] as int? ?? 0,
      digest: json['digest'] as String? ?? '',
      modifiedAt: json['modified_at'] as String? ?? '',
    );
  }

  String get formattedSize {
    if (size <= 0) return 'Unknown size';
    final double gb = size / (1024 * 1024 * 1024);
    if (gb >= 1.0) {
      return '${gb.toStringAsFixed(1)} GB';
    }
    final double mb = size / (1024 * 1024);
    return '${mb.toStringAsFixed(0)} MB';
  }
}

/// Currently Loaded / Running Ollama Model Information via GET /api/ps
class OllamaLoadedModelInfo {
  final String name;
  final String model;
  final int size;
  final int sizeVram;
  final String digest;
  final String expiresAt;
  final String parameterSize;
  final String quantizationLevel;
  final String format;
  final String family;

  OllamaLoadedModelInfo({
    required this.name,
    required this.model,
    required this.size,
    required this.sizeVram,
    required this.digest,
    required this.expiresAt,
    this.parameterSize = '',
    this.quantizationLevel = '',
    this.format = 'gguf',
    this.family = '',
  });

  factory OllamaLoadedModelInfo.fromJson(Map<String, dynamic> json) {
    final details = json['details'] as Map<String, dynamic>? ?? {};
    return OllamaLoadedModelInfo(
      name: json['name'] as String? ?? 'unknown',
      model: json['model'] as String? ?? json['name'] as String? ?? 'unknown',
      size: json['size'] as int? ?? 0,
      sizeVram: json['size_vram'] as int? ?? 0,
      digest: json['digest'] as String? ?? '',
      expiresAt: json['expires_at'] as String? ?? '',
      parameterSize: details['parameter_size'] as String? ?? '',
      quantizationLevel: details['quantization_level'] as String? ?? '',
      format: details['format'] as String? ?? 'gguf',
      family: details['family'] as String? ?? '',
    );
  }

  String get formattedVram {
    if (sizeVram <= 0) return '0 MB VRAM';
    final double gb = sizeVram / (1024 * 1024 * 1024);
    if (gb >= 1.0) {
      return '${gb.toStringAsFixed(1)} GB VRAM';
    }
    final double mb = sizeVram / (1024 * 1024);
    return '${mb.toStringAsFixed(0)} MB VRAM';
  }

  String get formattedSize {
    if (size <= 0) return 'Unknown size';
    final double gb = size / (1024 * 1024 * 1024);
    if (gb >= 1.0) {
      return '${gb.toStringAsFixed(1)} GB';
    }
    final double mb = size / (1024 * 1024);
    return '${mb.toStringAsFixed(0)} MB';
  }
}

/// Download / Pull Model Progress Event
class OllamaPullProgress {
  final String status;
  final String? digest;
  final int total;
  final int completed;
  final bool isFinished;
  final String? error;

  OllamaPullProgress({
    required this.status,
    this.digest,
    this.total = 0,
    this.completed = 0,
    this.isFinished = false,
    this.error,
  });

  double get progressPercentage {
    if (total <= 0) return 0.0;
    return (completed / total).clamp(0.0, 1.0);
  }

  String get formattedProgress {
    if (total <= 0) return status;
    final double compGb = completed / (1024 * 1024 * 1024);
    final double totGb = total / (1024 * 1024 * 1024);
    final int pct = (progressPercentage * 100).toInt();
    return '$status (${compGb.toStringAsFixed(1)} / ${totGb.toStringAsFixed(1)} GB - $pct%)';
  }
}

/// Comprehensive Local Ollama REST Client Service
class AIService {
  final String _ollamaHost;
  final String _modelName;
  final http.Client _client;

  bool _isGenerating = false;
  bool _isCancelled = false;
  http.Client? _activePullClient;

  AIService({
    String? ollamaHost,
    String? modelName,
    http.Client? client,
  })  : _ollamaHost = ollamaHost ?? AppConstants.defaultOllamaHost,
        _modelName = modelName ?? AppConstants.defaultModel,
        _client = client ?? http.Client();

  bool get isGenerating => _isGenerating;
  String get ollamaHost => _ollamaHost;
  String get modelName => _modelName;

  /// Cancel active AI stream generation
  void cancelGeneration() {
    _isCancelled = true;
    _isGenerating = false;
  }

  /// Basic Health Check - Ping /api/version
  Future<bool> checkHealth({String? customHost}) async {
    final host = customHost ?? _ollamaHost;
    try {
      final response = await _client
          .get(Uri.parse('$host/api/version'))
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Detailed Health Check - Returns status code, version string or error details
  Future<Map<String, dynamic>> checkHealthDetails({String? customHost}) async {
    final host = customHost ?? _ollamaHost;
    try {
      final stopwatch = Stopwatch()..start();
      final response = await _client
          .get(Uri.parse('$host/api/version'))
          .timeout(const Duration(seconds: 4));
      stopwatch.stop();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'isOnline': true,
          'version': data['version'] ?? 'unknown',
          'latencyMs': stopwatch.elapsedMilliseconds,
          'host': host,
          'error': null,
        };
      } else {
        return {
          'isOnline': false,
          'version': null,
          'latencyMs': stopwatch.elapsedMilliseconds,
          'host': host,
          'error': 'Ollama daemon returned HTTP ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'isOnline': false,
        'version': null,
        'latencyMs': -1,
        'host': host,
        'error': 'Cannot connect to Ollama daemon at $host (${e.toString()})',
      };
    }
  }

  /// List Locally Installed Models via GET /api/tags
  Future<List<OllamaModelInfo>> fetchInstalledModels({String? customHost}) async {
    final host = customHost ?? _ollamaHost;
    try {
      final response = await _client
          .get(Uri.parse('$host/api/tags'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data.containsKey('models') && data['models'] is List) {
          final List modelsJson = data['models'];
          return modelsJson.map((m) => OllamaModelInfo.fromJson(m)).toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Check if a specific model is installed locally
  Future<bool> isModelInstalled(String targetModelName, {String? customHost}) async {
    final installed = await fetchInstalledModels(customHost: customHost);
    final targetLower = targetModelName.toLowerCase().trim();
    return installed.any((m) {
      final mNameLower = m.name.toLowerCase().trim();
      return mNameLower == targetLower || mNameLower.startsWith('$targetLower:');
    });
  }

  /// List Currently Running / Loaded Models in Memory via GET /api/ps
  Future<List<OllamaLoadedModelInfo>> fetchLoadedModels({String? customHost}) async {
    final host = customHost ?? _ollamaHost;
    try {
      final response = await _client
          .get(Uri.parse('$host/api/ps'))
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data.containsKey('models') && data['models'] is List) {
          final List modelsJson = data['models'];
          return modelsJson.map((m) => OllamaLoadedModelInfo.fromJson(m)).toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Preload / Warm up a Model into VRAM / RAM via POST /api/generate
  Future<bool> preloadModel(String targetModelName, {String? customHost}) async {
    final host = customHost ?? _ollamaHost;
    try {
      final response = await _client.post(
        Uri.parse('$host/api/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': targetModelName,
          'prompt': '',
          'keep_alive': '5m',
        }),
      ).timeout(const Duration(seconds: 25));

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Unload Model from VRAM / RAM immediately via POST /api/generate with keep_alive: 0
  Future<bool> unloadModel(String targetModelName, {String? customHost}) async {
    final host = customHost ?? _ollamaHost;
    try {
      final response = await _client.post(
        Uri.parse('$host/api/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': targetModelName,
          'keep_alive': 0,
        }),
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Pull / Download Model from Ollama library via POST /api/pull with streaming progress
  Stream<OllamaPullProgress> pullModelStream(String targetModelName, {String? customHost}) async* {
    final host = customHost ?? _ollamaHost;
    final cancelableClient = http.Client();
    _activePullClient = cancelableClient;

    try {
      final request = http.Request('POST', Uri.parse('$host/api/pull'))
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode({
          'name': targetModelName,
          'stream': true,
        });

      final response = await cancelableClient.send(request);

      if (response.statusCode != 200) {
        yield OllamaPullProgress(
          status: 'Failed to start download',
          error: 'HTTP ${response.statusCode}: Model not found or network error',
          isFinished: true,
        );
        return;
      }

      final stream = response.stream.transform(utf8.decoder).transform(const LineSplitter());

      await for (final line in stream) {
        if (line.trim().isEmpty) continue;
        try {
          final Map<String, dynamic> data = jsonDecode(line);

          if (data.containsKey('error')) {
            yield OllamaPullProgress(
              status: 'Error',
              error: data['error'] as String,
              isFinished: true,
            );
            return;
          }

          final status = data['status'] as String? ?? 'Downloading...';
          final digest = data['digest'] as String?;
          final total = data['total'] as int? ?? 0;
          final completed = data['completed'] as int? ?? 0;
          final isSuccess = status.contains('success');

          yield OllamaPullProgress(
            status: status,
            digest: digest,
            total: total,
            completed: completed,
            isFinished: isSuccess,
          );

          if (isSuccess) break;
        } catch (_) {}
      }
    } catch (e) {
      yield OllamaPullProgress(
        status: 'Download cancelled or failed',
        error: e.toString(),
        isFinished: true,
      );
    } finally {
      _activePullClient = null;
    }
  }

  /// Cancel active pull / download operation
  void cancelPullModel() {
    _activePullClient?.close();
    _activePullClient = null;
  }

  /// Delete Model via DELETE /api/delete
  Future<bool> deleteModel(String targetModelName, {String? customHost}) async {
    final host = customHost ?? _ollamaHost;
    try {
      final request = http.Request('DELETE', Uri.parse('$host/api/delete'))
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode({'name': targetModelName});

      final response = await _client.send(request).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Streaming Generation Request to Local Ollama Model
  Stream<String> generateStream(
    String prompt, {
    String? customHost,
    String? customModel,
    String? backendId,
    String? systemContext,
    double temperature = 0.7,
    int? contextWindow,
    double? topP,
    int? topK,
    double? minP,
    double? typicalP,
    double? repeatPenalty,
    int? repeatLastN,
    double? presencePenalty,
    double? frequencyPenalty,
    int? maxTokens,
    List<String>? stopSequences,
    int? seed,
    int? mirostat,
    double? mirostatTau,
    double? mirostatEta,
    int? numThreads,
    String? keepAlive,
    String? systemPrompt,
    Map<String, dynamic>? extraOptions,
  }) async* {
    if (_isGenerating) {
      throw StateError('AI service is busy processing a request. Only 1 generation allowed at a time.');
    }

    _isGenerating = true;
    _isCancelled = false;
    final host = customHost ?? _ollamaHost;
    final model = customModel ?? _modelName;

    try {
      final sanitizedPrompt = AppConstants.sanitizeText(prompt);

      final Map<String, dynamic> options = {
        'num_predict': maxTokens ?? AppConstants.maxPromptTokens,
        'temperature': temperature,
      };
      if (contextWindow != null && contextWindow > 0) {
        options['num_ctx'] = contextWindow;
      }
      if (topP != null) {
        options['top_p'] = topP;
      }
      if (topK != null && topK > 0) {
        options['top_k'] = topK;
      }
      if (minP != null && minP > 0.0) {
        options['min_p'] = minP;
      }
      if (typicalP != null && typicalP < 1.0) {
        options['typical_p'] = typicalP;
      }
      if (repeatPenalty != null && repeatPenalty > 0) {
        options['repeat_penalty'] = repeatPenalty;
      }
      if (repeatLastN != null && repeatLastN > 0) {
        options['repeat_last_n'] = repeatLastN;
      }
      if (presencePenalty != null && presencePenalty != 0.0) {
        options['presence_penalty'] = presencePenalty;
      }
      if (frequencyPenalty != null && frequencyPenalty != 0.0) {
        options['frequency_penalty'] = frequencyPenalty;
      }
      if (stopSequences != null && stopSequences.isNotEmpty) {
        options['stop'] = stopSequences;
      }
      if (seed != null) {
        options['seed'] = seed;
      }
      if (mirostat != null && mirostat > 0) {
        options['mirostat'] = mirostat;
        if (mirostatTau != null) options['mirostat_tau'] = mirostatTau;
        if (mirostatEta != null) options['mirostat_eta'] = mirostatEta;
      }
      if (numThreads != null && numThreads > 0) {
        options['num_thread'] = numThreads;
      }
      if (extraOptions != null && extraOptions.isNotEmpty) {
        options.addAll(extraOptions);
      }

      String? effectiveSystem;
      if (systemPrompt != null && systemPrompt.trim().isNotEmpty) {
        effectiveSystem = systemContext != null && systemContext.trim().isNotEmpty
            ? '${systemPrompt.trim()}\n\n${systemContext.trim()}'
            : systemPrompt.trim();
      } else {
        effectiveSystem = systemContext;
      }

      final bool isChatCompletions = backendId == 'llamacpp' || backendId == 'litellm';

      final http.Request request;
      if (isChatCompletions) {
        final List<Map<String, String>> messages = [];
        if (effectiveSystem != null && effectiveSystem.isNotEmpty) {
          messages.add({'role': 'system', 'content': effectiveSystem});
        }
        messages.add({'role': 'user', 'content': sanitizedPrompt});

        final Map<String, dynamic> payload = {
          'model': model,
          'messages': messages,
          'stream': true,
          'temperature': temperature,
          'max_tokens': maxTokens ?? AppConstants.maxPromptTokens,
        };
        request = http.Request('POST', Uri.parse('$host/v1/chat/completions'))
          ..headers['Content-Type'] = 'application/json'
          ..body = jsonEncode(payload);
      } else {
        final Map<String, dynamic> payload = {
          'model': model,
          'prompt': sanitizedPrompt,
          'system': effectiveSystem,
          'stream': true,
          'options': options,
        };
        if (keepAlive != null && keepAlive.isNotEmpty) {
          payload['keep_alive'] = keepAlive;
        }
        request = http.Request('POST', Uri.parse('$host/api/generate'))
          ..headers['Content-Type'] = 'application/json'
          ..body = jsonEncode(payload);
      }

      final response = await _client.send(request);

      if (response.statusCode != 200) {
        String detail = '';
        try {
          final errBody = await response.stream.transform(utf8.decoder).join();
          final errJson = jsonDecode(errBody);
          if (errJson is Map) {
            detail = errJson['detail']?.toString() ?? errJson['error']?.toString() ?? '';
          }
        } catch (_) {}

        final errSuffix = detail.isNotEmpty ? ': $detail' : '';
        if (backendId == 'airllm') {
          yield 'Error: AirLLM service returned HTTP ${response.statusCode}$errSuffix. Ensure model "$model" is loaded in memory (Settings -> AirLLM).';
        } else if (backendId == 'llamacpp') {
          yield 'Error: llama.cpp server returned HTTP ${response.statusCode}$errSuffix. Ensure llama.cpp server is running at $host.';
        } else if (backendId == 'litellm') {
          yield 'Error: LiteLLM proxy returned HTTP ${response.statusCode}$errSuffix. Ensure LiteLLM is running at $host.';
        } else {
          yield 'Error: Local Ollama service returned HTTP ${response.statusCode}. Make sure model "$model" is installed.';
        }
        return;
      }

      final stream = response.stream.transform(utf8.decoder).transform(const LineSplitter());

      await for (final line in stream) {
        if (_isCancelled) break;
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        if (isChatCompletions) {
          if (trimmed == 'data: [DONE]' || trimmed == '[DONE]') break;
          final jsonStr = trimmed.startsWith('data: ') ? trimmed.substring(6).trim() : trimmed;
          try {
            final data = jsonDecode(jsonStr);
            if (data is Map<String, dynamic> && data.containsKey('choices')) {
              final choices = data['choices'] as List?;
              if (choices != null && choices.isNotEmpty) {
                final delta = choices.first['delta'] as Map<String, dynamic>?;
                final text = delta?['content'] as String?;
                if (text != null && text.isNotEmpty) {
                  yield text;
                }
              }
            }
          } catch (_) {
            // Ignore partial SSE chunk decode errors
          }
        } else {
          try {
            final data = jsonDecode(trimmed);
            if (data is Map<String, dynamic> && data.containsKey('response')) {
              yield data['response'] as String;
            }
          } catch (_) {
            // Ignore partial chunk decode errors
          }
        }
      }
    } catch (e) {
      if (_isCancelled) return;
      if (backendId == 'airllm') {
        yield 'Error: Failed to connect to AirLLM daemon at $host. Ensure the local Python service is running (Settings -> AirLLM).';
      } else if (backendId == 'llamacpp') {
        yield 'Error: Failed to connect to llama.cpp server at $host. Ensure llama-server is running.';
      } else if (backendId == 'litellm') {
        yield 'Error: Failed to connect to LiteLLM proxy at $host. Ensure LiteLLM is running.';
      } else {
        yield 'Error: Failed to connect to local Ollama daemon at $host. Ensure Ollama is running and model "$model" exists.';
      }
    } finally {
      _isGenerating = false;
    }
  }

  /// Generate a dense vector embedding using local Ollama /api/embeddings or /api/embed (DOC-001)
  Future<List<double>?> generateEmbedding(
    String text, {
    String? customHost,
    String? customModel,
  }) async {
    final host = customHost ?? _ollamaHost;
    final model = customModel ?? _modelName;
    final sanitizedText = AppConstants.sanitizeText(text).trim();
    if (sanitizedText.isEmpty) return null;

    try {
      // 1. Attempt POST /api/embeddings (standard endpoint)
      final url = Uri.parse('$host/api/embeddings');
      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': model,
          'prompt': sanitizedText,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data['embedding'] is List) {
          return (data['embedding'] as List).map((e) => (e as num).toDouble()).toList();
        }
      }

      // 2. Fallback to /api/embed (newer Ollama batch endpoint)
      final embedUrl = Uri.parse('$host/api/embed');
      final embedResponse = await _client.post(
        embedUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': model,
          'input': sanitizedText,
        }),
      ).timeout(const Duration(seconds: 10));

      if (embedResponse.statusCode == 200) {
        final data = jsonDecode(embedResponse.body);
        if (data is Map<String, dynamic> && data['embeddings'] is List && (data['embeddings'] as List).isNotEmpty) {
          final first = (data['embeddings'] as List).first;
          if (first is List) {
            return first.map((e) => (e as num).toDouble()).toList();
          }
        }
      }
    } catch (_) {
      // Graceful fallback when model doesn't support embeddings or offline
    }
    return null;
  }

  /// Check health of local AirLLM inference daemon via GET /health (AIR-001)
  Future<Map<String, dynamic>> checkAirLLMHealthDetails({String? customHost}) async {
    final host = customHost ?? 'http://127.0.0.1:8765';
    try {
      final stopwatch = Stopwatch()..start();
      final response = await _client
          .get(Uri.parse('$host/health'))
          .timeout(const Duration(seconds: 4));
      stopwatch.stop();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'isOnline': true,
          'status': data['model_state'] ?? data['status'] ?? 'ready',
          'modelId': data['model_id'] ?? data['active_model'],
          'latencyMs': stopwatch.elapsedMilliseconds,
          'host': host,
          'error': null,
        };
      } else {
        return {
          'isOnline': false,
          'status': 'offline',
          'latencyMs': stopwatch.elapsedMilliseconds,
          'host': host,
          'error': 'AirLLM daemon returned HTTP ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'isOnline': false,
        'status': 'offline',
        'latencyMs': -1,
        'host': host,
        'error': 'Cannot connect to AirLLM daemon at $host',
      };
    }
  }

  /// Detailed AirLLM status with resource, disk, and queue metrics via GET /api/ai/status
  Future<Map<String, dynamic>?> fetchAirLLMStatus({String? customHost}) async {
    final host = customHost ?? 'http://127.0.0.1:8765';
    try {
      final response = await _client
          .get(Uri.parse('$host/api/ai/status'))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// Request AirLLM service to load an approved model via POST /api/ai/models/load
  Future<bool> loadAirLLMModel(String modelId, {String? customHost}) async {
    final host = customHost ?? 'http://127.0.0.1:8765';
    try {
      final response = await _client.post(
        Uri.parse('$host/api/ai/models/load'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'model_id': modelId}),
      ).timeout(const Duration(seconds: 30));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Request AirLLM service to unload active model and free memory via POST /api/ai/models/unload
  Future<bool> unloadAirLLMModel({String? customHost}) async {
    final host = customHost ?? 'http://127.0.0.1:8765';
    try {
      final response = await _client.post(
        Uri.parse('$host/api/ai/models/unload'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

