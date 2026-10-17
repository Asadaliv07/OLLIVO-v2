/// Quick Prompt Template with dynamic slot variable replacement (PRM-002)
class PromptTemplate {
  final String id;
  final String title;
  final String description;
  final String category;
  final String templateText;
  final List<String> variables;

  const PromptTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.templateText,
    required this.variables,
  });

  /// Interpolate template text with provided variable values
  String interpolate(Map<String, String> values) {
    var result = templateText;
    for (final variable in variables) {
      final value = values[variable] ?? '';
      result = result.replaceAll('{{$variable}}', value);
    }
    return result;
  }

  static const List<PromptTemplate> defaultTemplates = [
    PromptTemplate(
      id: 'code-review',
      title: 'Code Review',
      description: 'Audit code for bugs, edge cases, and performance',
      category: 'Engineering',
      templateText:
          'Please perform a thorough code review of the following {{language}} code. Identify potential bugs, edge cases, performance bottlenecks, security flaws, and architectural improvements:\n\n```{{language}}\n{{code}}\n```',
      variables: ['language', 'code'],
    ),
    PromptTemplate(
      id: 'explain-concept',
      title: 'Explain Concept',
      description: 'Break down complex technical or conceptual topics',
      category: 'Learning',
      templateText:
          'Explain the concept of "{{concept}}" to a {{target_audience}}. Use a clean, real-world mental model or practical example to make it immediately intuitive.',
      variables: ['concept', 'target_audience'],
    ),
    PromptTemplate(
      id: 'debug-error',
      title: 'Debug Error',
      description: 'Diagnose runtime error stack trace and suggest fixes',
      category: 'Engineering',
      templateText:
          'I encountered this error in my {{language}} application:\n\nError Message / Stack Trace:\n{{error_message}}\n\nContext / Relevant Code:\n{{context}}\n\nDiagnose the root cause and provide the exact step-by-step fix.',
      variables: ['language', 'error_message', 'context'],
    ),
    PromptTemplate(
      id: 'refactor-code',
      title: 'Refactor Code',
      description: 'Improve readability, modularity, and testability',
      category: 'Engineering',
      templateText:
          'Refactor the following {{language}} code to make it more readable, modular, and maintainable following standard design patterns:\n\n```{{language}}\n{{code}}\n```\n\nExplain the architectural rationale behind your changes.',
      variables: ['language', 'code'],
    ),
    PromptTemplate(
      id: 'document-summary',
      title: 'Document Summary',
      description: 'Extract key takeaways and action items from text',
      category: 'Productivity',
      templateText:
          'Please summarize the following text into key executive takeaways, high-priority bullet points, and actionable items:\n\n{{document_text}}',
      variables: ['document_text'],
    ),
  ];
}
