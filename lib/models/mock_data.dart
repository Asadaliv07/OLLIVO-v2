/// Realistic Mock Data for Ollivo UI Prototype
/// Clearly separated from future production SQLite / Ollama services.
class OllivoMockData {
  static final List<Map<String, String>> starterPrompts = [
    {
      'title': 'Save Project Preference',
      'prompt': 'Remember that our Flutter app uses #121212 Onyx background and #6B9E78 Emerald primary color.',
      'category': 'Memory',
    },
    {
      'title': 'Summarize Notes',
      'prompt': 'Summarize the key requirements from my local project notes.',
      'category': 'Documents',
    },
    {
      'title': 'Generate Action Items',
      'prompt': 'Create a 3-step launch checklist for my cross-platform app.',
      'category': 'Tasks',
    },
  ];

  static final List<Map<String, dynamic>> initialChatMessages = [
    {
      'id': 'msg-1',
      'role': 'assistant',
      'content': 'Welcome to **Ollivo**! I am your 100% local AI assistant. Your data never leaves your physical device.\n\nHow can I help you organize your project today?',
      'timestamp': '10:30 AM',
      'isMemorySaved': false,
    },
  ];
}
