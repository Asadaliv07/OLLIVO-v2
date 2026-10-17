/// Ollivo Core Constants & Environment Configurations
class AppConstants {
  // Local Ollama Default Configuration
  static const String defaultOllamaHost = 'http://127.0.0.1:11434';
  static const String defaultModel = 'qwen2.5-coder:1.5b';

  // Database Configurations
  static const String databaseName = 'ollivo.db';
  static const int databaseVersion = 2;

  // AI Inference Constraints
  static const int maxPromptTokens = 2048;
  static const int maxRAGContextChunks = 3;

  // Privacy Sanitization Patterns (Prevents saving secrets to vector memory)
  static final RegExp sensitiveDataPattern = RegExp(
    r'(password|secret|api_key|token|bearer|private_key|auth_key)\s*[:=]\s*[^\s]+',
    caseSensitive: false,
  );

  /// Filters out sensitive credentials from raw text before storing into memory
  static String sanitizeText(String input) {
    return input.replaceAll(sensitiveDataPattern, '[REDACTED SECRET]');
  }
}
