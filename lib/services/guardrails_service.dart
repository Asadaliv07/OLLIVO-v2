import 'package:flutter/foundation.dart';

/// Severity level of a detected guardrail violation
enum GuardrailSeverity { info, warning, high, critical }

/// Category of security or quality policy violation
enum GuardrailCategory {
  promptInjection,
  piiLeakage,
  harmfulCommand,
  jailbreakAttempt,
  malformedInput,
  hallucinationRisk,
}

/// Details of a single detected guardrail violation
class GuardrailViolation {
  final GuardrailCategory category;
  final GuardrailSeverity severity;
  final String rule;
  final String message;
  final String? matchedSnippet;

  const GuardrailViolation({
    required this.category,
    required this.severity,
    required this.rule,
    required this.message,
    this.matchedSnippet,
  });

  Map<String, dynamic> toMap() => {
        'category': category.name,
        'severity': severity.name,
        'rule': rule,
        'message': message,
        'matchedSnippet': matchedSnippet,
      };

  @override
  String toString() => '[$severity] $category ($rule): $message';
}

/// Result of evaluating content against safety guardrails
class GuardrailResult {
  final bool isAllowed;
  final String sanitizedText;
  final List<GuardrailViolation> violations;
  final Map<String, dynamic> metadata;

  const GuardrailResult({
    required this.isAllowed,
    required this.sanitizedText,
    required this.violations,
    this.metadata = const {},
  });

  bool get hasViolations => violations.isNotEmpty;
  bool get hasCriticalViolation =>
      violations.any((v) => v.severity == GuardrailSeverity.critical);
}

/// Configuration policy for Guardrails inspection
class GuardrailsPolicy {
  final bool blockPromptInjection;
  final bool maskPii;
  final bool blockDestructiveCommands;
  final bool allowDeveloperModeKeywords;
  final int maxInputLength;

  const GuardrailsPolicy({
    this.blockPromptInjection = true,
    this.maskPii = true,
    this.blockDestructiveCommands = true,
    this.allowDeveloperModeKeywords = false,
    this.maxInputLength = 65536,
  });

  static const GuardrailsPolicy standard = GuardrailsPolicy();
  static const GuardrailsPolicy relaxed = GuardrailsPolicy(
    blockPromptInjection: false,
    maskPii: false,
    blockDestructiveCommands: true,
  );
  static const GuardrailsPolicy strict = GuardrailsPolicy(
    blockPromptInjection: true,
    maskPii: true,
    blockDestructiveCommands: true,
    allowDeveloperModeKeywords: false,
    maxInputLength: 32768,
  );
}

/// Multi-layered Security & Content Guardrails Service (NeMo & Guardrails AI inspired)
class GuardrailsService extends ChangeNotifier {
  static final GuardrailsService _instance = GuardrailsService._internal();
  factory GuardrailsService() => _instance;
  GuardrailsService._internal();

  GuardrailsPolicy _policy = GuardrailsPolicy.standard;
  GuardrailsPolicy get policy => _policy;

  void updatePolicy(GuardrailsPolicy newPolicy) {
    _policy = newPolicy;
    notifyListeners();
  }

  // --- Normalization for Obfuscated / Encoded Inputs ---
  static String normalizeText(String input) {
    if (input.isEmpty) return input;
    // 1. Strip zero-width, invisible, and soft-hyphen characters
    String normalized = input.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF\u00AD\u2060]'), '');

    // 2. Normalize fullwidth Latin characters (U+FF01 to U+FF5E) to ASCII
    final buffer = StringBuffer();
    for (int i = 0; i < normalized.length; i++) {
      final code = normalized.codeUnitAt(i);
      if (code >= 0xFF01 && code <= 0xFF5E) {
        buffer.writeCharCode(code - 0xFEE0);
      } else {
        buffer.writeCharCode(code);
      }
    }
    normalized = buffer.toString();

    // 3. Decode URL-encoded patterns if present
    if (normalized.contains('%')) {
      try {
        normalized = Uri.decodeComponent(normalized);
      } catch (_) {}
    }

    return normalized;
  }

  // --- Regex Rules for Prompt Injection & Jailbreaks ---
  static final List<RegExp> _injectionPatterns = [
    RegExp(r'ignore\s+(all\s+)?(previous|prior|above)\s+(instructions|directives|rules|prompts)', caseSensitive: false),
    RegExp(r'disregard\s+(all\s+)?(previous|prior|above)\s+(instructions|directives|prompts)', caseSensitive: false),
    RegExp(r'you\s+are\s+now\s+(in\s+)?(developer\s+mode|unrestricted\s+mode|dan\s+mode)', caseSensitive: false),
    RegExp(r'(activate|switch\s+to|enter|enable)\s+(developer\s+mode|unrestricted\s+mode|jailbreak\s+mode|dan\s+mode)', caseSensitive: false),
    RegExp(r'\bdeveloper\s+mode\s*:\s*(on|enabled|active)\b', caseSensitive: false),
    RegExp(r'\bdeveloper\s+mode\s+is\s+(on|enabled|activated)\b', caseSensitive: false),
    RegExp(r'\bdeveloper\s+mode\s+(activated|enabled)\b', caseSensitive: false),
    RegExp(r'(bypass|disable|override)\s+(all\s+)?(safety|security|content|your\s+)?(filters|rules|guidelines|guardrails)', caseSensitive: false),
    RegExp(r'<\s*\|\s*(system|im_start|im_end)\s*\|?>', caseSensitive: false),
    RegExp(r'\[\s*(INST|SYS)\s*\]', caseSensitive: false),
    RegExp(r'<<\s*SYS\s*>>', caseSensitive: false),
  ];

  // --- Regex Rules for Sensitive Information & PII ---
  static final RegExp _emailRegex = RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,7}\b');
  static final RegExp _phoneRegex = RegExp(r'\b(?:\+?1[-. ]?)?\(?([0-9]{3})\)?[-. ]?([0-9]{3})[-. ]?([0-9]{4})\b');
  static final RegExp _ssnRegex = RegExp(r'\b\d{3}-\d{2}-\d{4}\b');
  static final RegExp _creditCardRegex = RegExp(r'\b(?:4[0-9]{12}(?:[0-9]{3})?|5[1-5][0-9]{14}|3[47][0-9]{13}|3(?:0[0-5]|[68][0-9])[0-9]{11}|6(?:011|5[0-9]{2})[0-9]{12}|(?:2131|1800|35\d{3})\d{11})\b');
  static final RegExp _apiKeyRegex = RegExp(r'\b(?:sk-[a-zA-Z0-9]{20,}|ghp_[a-zA-Z0-9]{20,}|hf_[a-zA-Z0-9]{20,}|AIza[0-9A-Za-z-_]{35})\b');

  // --- Regex Rules for Destructive Terminal & System Commands ---
  static final List<RegExp> _destructiveCommands = [
    RegExp(r'\brm\s+(-rf|-fr|--recursive)\s+[/~*]', caseSensitive: false),
    RegExp(r'\bmkfs\b', caseSensitive: false),
    RegExp(r'\bdd\s+if=/dev/zero', caseSensitive: false),
    RegExp(r':\(\)\s*\{\s*:\s*\|\s*:\s*&\s*\}\s*;\s*:', caseSensitive: false), // Fork bomb
    RegExp(r'\bformat\s+[A-Za-z]:\s+/fs', caseSensitive: false),
    RegExp(r'>\s*/dev/sd[a-z]', caseSensitive: false),
    RegExp(r'\bchmod\s+(-R\s+)?777\s+/', caseSensitive: false),
  ];

  /// Inspect and sanitize user prompts before sending to inference engines
  GuardrailResult inspectPrompt(String prompt, {GuardrailsPolicy? overridePolicy}) {
    final effectivePolicy = overridePolicy ?? _policy;
    final List<GuardrailViolation> violations = [];
    final normalized = normalizeText(prompt);
    String sanitized = normalized;

    // 1. Length validation
    if (normalized.length > effectivePolicy.maxInputLength) {
      violations.add(GuardrailViolation(
        category: GuardrailCategory.malformedInput,
        severity: GuardrailSeverity.critical,
        rule: 'max_input_length',
        message: 'Prompt exceeds maximum permitted length of ${effectivePolicy.maxInputLength} characters.',
      ));
      return GuardrailResult(
        isAllowed: false,
        sanitizedText: normalized.substring(0, effectivePolicy.maxInputLength),
        violations: violations,
      );
    }

    // 2. Prompt Injection and Jailbreak Detection
    if (effectivePolicy.blockPromptInjection) {
      for (final pattern in _injectionPatterns) {
        final match = pattern.firstMatch(normalized);
        if (match != null) {
          violations.add(GuardrailViolation(
            category: GuardrailCategory.promptInjection,
            severity: GuardrailSeverity.critical,
            rule: 'prompt_injection_pattern',
            message: 'Detected prompt injection or system override attempt.',
            matchedSnippet: match.group(0),
          ));
        }
      }
    }

    // 3. Destructive Command Detection
    if (effectivePolicy.blockDestructiveCommands) {
      for (final cmdPattern in _destructiveCommands) {
        final match = cmdPattern.firstMatch(normalized);
        if (match != null) {
          violations.add(GuardrailViolation(
            category: GuardrailCategory.harmfulCommand,
            severity: GuardrailSeverity.critical,
            rule: 'destructive_command_pattern',
            message: 'Detected potentially destructive system or terminal command.',
            matchedSnippet: match.group(0),
          ));
        }
      }
    }

    // 4. PII Redaction / Masking
    if (effectivePolicy.maskPii) {
      sanitized = _maskPii(sanitized, violations);
    }

    final bool isAllowed = !violations.any((v) => v.severity == GuardrailSeverity.critical);

    return GuardrailResult(
      isAllowed: isAllowed,
      sanitizedText: sanitized,
      violations: violations,
      metadata: {
        'original_length': prompt.length,
        'sanitized_length': sanitized.length,
        'policy': effectivePolicy == GuardrailsPolicy.strict ? 'strict' : 'standard',
      },
    );
  }

  /// Inspect model output responses before rendering to user
  GuardrailResult inspectResponse(String responseText, {GuardrailsPolicy? overridePolicy}) {
    final effectivePolicy = overridePolicy ?? _policy;
    final List<GuardrailViolation> violations = [];
    String sanitized = responseText;

    // Check for dangerous shell execution instructions in generated response
    if (effectivePolicy.blockDestructiveCommands) {
      for (final cmdPattern in _destructiveCommands) {
        final match = cmdPattern.firstMatch(responseText);
        if (match != null) {
          violations.add(GuardrailViolation(
            category: GuardrailCategory.harmfulCommand,
            severity: GuardrailSeverity.warning,
            rule: 'generated_destructive_command',
            message: 'Model generated a command with potential system-altering side effects.',
            matchedSnippet: match.group(0),
          ));
        }
      }
    }

    // Mask any PII generated or repeated by the model
    if (effectivePolicy.maskPii) {
      sanitized = _maskPii(sanitized, violations);
    }

    return GuardrailResult(
      isAllowed: true, // Output rails flag or mask, rather than blocking view completely
      sanitizedText: sanitized,
      violations: violations,
    );
  }

  /// Masks sensitive PII patterns with replacement placeholders
  String _maskPii(String text, List<GuardrailViolation> violations) {
    var output = text;

    if (_apiKeyRegex.hasMatch(output)) {
      final matches = _apiKeyRegex.allMatches(output);
      for (final m in matches) {
        violations.add(GuardrailViolation(
          category: GuardrailCategory.piiLeakage,
          severity: GuardrailSeverity.warning,
          rule: 'api_key_redaction',
          message: 'API Key or Token detected and masked.',
          matchedSnippet: m.group(0) != null ? '${m.group(0)!.substring(0, 4)}...' : null,
        ));
      }
      output = output.replaceAll(_apiKeyRegex, '[REDACTED_API_KEY]');
    }

    if (_creditCardRegex.hasMatch(output)) {
      violations.add(const GuardrailViolation(
        category: GuardrailCategory.piiLeakage,
        severity: GuardrailSeverity.warning,
        rule: 'credit_card_redaction',
        message: 'Credit card number pattern detected and masked.',
      ));
      output = output.replaceAll(_creditCardRegex, '[REDACTED_CARD_NUMBER]');
    }

    if (_ssnRegex.hasMatch(output)) {
      violations.add(const GuardrailViolation(
        category: GuardrailCategory.piiLeakage,
        severity: GuardrailSeverity.warning,
        rule: 'ssn_redaction',
        message: 'Social Security Number pattern detected and masked.',
      ));
      output = output.replaceAll(_ssnRegex, '[REDACTED_SSN]');
    }

    if (_emailRegex.hasMatch(output)) {
      output = output.replaceAll(_emailRegex, '[REDACTED_EMAIL]');
    }

    if (_phoneRegex.hasMatch(output)) {
      output = output.replaceAll(_phoneRegex, '[REDACTED_PHONE]');
    }

    return output;
  }

  /// Inspect and sanitize retrieved RAG document chunks to prevent indirect prompt injection
  GuardrailResult inspectRetrievedDocument(String documentText) {
    final normalized = normalizeText(documentText);
    final List<GuardrailViolation> violations = [];
    var sanitized = normalized;

    // Check and neutralize delimiter injections or indirect system overrides inside documents
    for (final pattern in _injectionPatterns) {
      final matches = pattern.allMatches(sanitized);
      for (final match in matches) {
        violations.add(GuardrailViolation(
          category: GuardrailCategory.promptInjection,
          severity: GuardrailSeverity.warning,
          rule: 'indirect_prompt_injection_in_document',
          message: 'Retrieved document contains system directive or injection pattern.',
          matchedSnippet: match.group(0),
        ));
      }
      if (pattern.hasMatch(sanitized)) {
        sanitized = sanitized.replaceAll(pattern, '[INDIRECT_PROMPT_INJECTION_REMOVED]');
      }
    }

    // Scrub any sensitive secrets found inside ingested documentation
    sanitized = _maskPii(sanitized, violations);

    return GuardrailResult(
      isAllowed: !violations.any((v) => v.severity == GuardrailSeverity.critical),
      sanitizedText: sanitized,
      violations: violations,
      metadata: {'source': 'retrieved_document'},
    );
  }
}

