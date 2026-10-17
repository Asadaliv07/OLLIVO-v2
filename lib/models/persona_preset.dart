/// Pre-built AI System Prompt Personas (PRM-001)
class PersonaPreset {
  final String id;
  final String name;
  final String description;
  final String systemPrompt;
  final String icon;

  const PersonaPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.systemPrompt,
    required this.icon,
  });

  static const List<PersonaPreset> presets = [
    PersonaPreset(
      id: 'coding-architect',
      name: 'Coding Architect',
      description: 'Senior software architect & clean code specialist',
      systemPrompt:
          'You are a senior software architect and Flutter/macOS specialist. Provide clean, modular, production-ready, type-safe code with clear design patterns and zero conversational fluff.',
      icon: 'code',
    ),
    PersonaPreset(
      id: 'technical-writer',
      name: 'Technical Writer',
      description: 'Clear, concise documentation & structured guides',
      systemPrompt:
          'You are an expert technical writer. Produce clear, concise, well-structured documentation, markdown tables, precise step-by-step instructions, and thorough explanations.',
      icon: 'description',
    ),
    PersonaPreset(
      id: 'creative-brainstormer',
      name: 'Creative Brainstormer',
      description: 'Innovative ideas, UX designs & divergent thinking',
      systemPrompt:
          'You are an innovative product strategist and creative brainstorming partner. Propose unconventional, high-impact ideas, novel feature concepts, and elegant user-experience solutions.',
      icon: 'lightbulb',
    ),
    PersonaPreset(
      id: 'terse-minimalist',
      name: 'Terse Minimalist',
      description: 'Ultra-concise, direct answers with zero filler',
      systemPrompt:
          'You are an ultra-concise assistant. Give direct, minimal, accurate answers with no conversational filler, preambles, or unrequested explanations. Use bullet points whenever possible.',
      icon: 'flash_on',
    ),
    PersonaPreset(
      id: 'balanced-assistant',
      name: 'Balanced Assistant',
      description: 'Thoughtful, well-rounded and versatile assistant',
      systemPrompt:
          'You are a thoughtful, helpful, privacy-first local AI assistant. Provide balanced, well-reasoned answers tailored for everyday productivity, technical clarity, and task execution.',
      icon: 'smart_toy',
    ),
  ];
}
