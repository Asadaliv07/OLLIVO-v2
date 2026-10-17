import 'package:flutter/material.dart';
import '../theme.dart';
import 'ollivo_components.dart';

/// Keyboard shortcut definition item
class ShortcutItem {
  final String category;
  final List<String> keys;
  final String label;
  final String description;

  const ShortcutItem({
    required this.category,
    required this.keys,
    required this.label,
    required this.description,
  });
}

/// Keyboard Shortcuts Cheat Sheet Dialog (`UI-001`)
/// Shows all available desktop shortcuts categorized with an interactive search filter.
class ShortcutsSheetDialog extends StatefulWidget {
  const ShortcutsSheetDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => const ShortcutsSheetDialog(),
    );
  }

  @override
  State<ShortcutsSheetDialog> createState() => _ShortcutsSheetDialogState();
}

class _ShortcutsSheetDialogState extends State<ShortcutsSheetDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  static const List<ShortcutItem> _allShortcuts = [
    // Navigation
    ShortcutItem(
      category: 'Navigation',
      keys: ['⌘', '1'],
      label: 'AI Assistant Chat',
      description: 'Switch to primary chat workspace',
    ),
    ShortcutItem(
      category: 'Navigation',
      keys: ['⌘', '2'],
      label: 'Local Memory Center',
      description: 'Browse, edit, and organize long-term memories',
    ),
    ShortcutItem(
      category: 'Navigation',
      keys: ['⌘', '3'],
      label: 'Documents & Local RAG',
      description: 'Ingest and query local knowledge documents',
    ),
    ShortcutItem(
      category: 'Navigation',
      keys: ['⌘', '4'],
      label: 'Task Workspace',
      description: 'View scheduled action items and task lifecycle',
    ),
    ShortcutItem(
      category: 'Navigation',
      keys: ['⌘', '5'],
      label: 'Model Library',
      description: 'Manage local GGUF models and Ollama weights',
    ),
    ShortcutItem(
      category: 'Navigation',
      keys: ['⌘', '6'],
      label: 'Settings & Storage',
      description: 'Adjust inference parameters, paths, and audit log',
    ),

    // Chat & Conversation
    ShortcutItem(
      category: 'Chat & Conversation',
      keys: ['⌘', 'N'],
      label: 'New Chat Session',
      description: 'Start a fresh conversation without context pollution',
    ),
    ShortcutItem(
      category: 'Chat & Conversation',
      keys: ['⌘', 'K'],
      label: 'Spotlight Quick Ask',
      description: 'Open floating instant-answer Spotlight modal',
    ),
    ShortcutItem(
      category: 'Chat & Conversation',
      keys: ['⇧', '⌘', 'Space'],
      label: 'Quick Ask (Alternative)',
      description: 'Alternative shortcut for Spotlight Quick Ask',
    ),
    ShortcutItem(
      category: 'Chat & Conversation',
      keys: ['⌘', 'L'],
      label: 'Clear Current Session',
      description: 'Clear active chat history and reset context',
    ),
    ShortcutItem(
      category: 'Chat & Conversation',
      keys: ['Esc'],
      label: 'Dismiss / Unfocus',
      description: 'Close active popups or unfocus chat input field',
    ),

    // Desktop & Window
    ShortcutItem(
      category: 'Desktop & Window',
      keys: ['⌘', '\\'],
      label: 'Toggle Sidebar',
      description: 'Show or collapse left navigation sidebar',
    ),
    ShortcutItem(
      category: 'Desktop & Window',
      keys: ['⌘', ','],
      label: 'Preferences / Settings',
      description: 'Jump directly to settings and storage configuration',
    ),
    ShortcutItem(
      category: 'Desktop & Window',
      keys: ['⌘', '/'],
      label: 'Keyboard Shortcuts Cheat Sheet',
      description: 'Open this keyboard shortcuts quick reference modal',
    ),
    ShortcutItem(
      category: 'Desktop & Window',
      keys: ['⌘', 'M'],
      label: 'Minimize Window',
      description: 'Standard macOS window minimize action',
    ),

    // Power Tools & Privacy
    ShortcutItem(
      category: 'Power Tools & Privacy',
      keys: ['Shield'],
      label: 'Air-Gapped Privacy Seal',
      description: 'Inspect 100% offline security certificate and telemetry',
    ),
    ShortcutItem(
      category: 'Power Tools & Privacy',
      keys: ['Templates'],
      label: 'Prompt Templates',
      description: 'Open templated prompts with dynamic {{variable}} slots',
    ),
    ShortcutItem(
      category: 'Power Tools & Privacy',
      keys: ['Personas'],
      label: 'Persona Presets',
      description: 'Switch between Architect, Writer, Minimalist personas',
    ),
    ShortcutItem(
      category: 'Power Tools & Privacy',
      keys: ['VACUUM'],
      label: 'Database Optimizer',
      description: 'Execute SQLite VACUUM to reclaim local disk space',
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ShortcutItem> get _filteredShortcuts {
    if (_query.trim().isEmpty) return _allShortcuts;
    final q = _query.toLowerCase().trim();
    return _allShortcuts.where((item) {
      return item.label.toLowerCase().contains(q) ||
          item.description.toLowerCase().contains(q) ||
          item.category.toLowerCase().contains(q) ||
          item.keys.any((k) => k.toLowerCase().contains(q));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredShortcuts;
    final categories = filtered.map((e) => e.category).toSet().toList();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 600),
        child: Material(
          color: OllivoTheme.surfaceDark,
          borderRadius: BorderRadius.circular(OllivoTheme.radiusLg),
          elevation: 24,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(OllivoTheme.radiusLg),
              border: Border.all(color: OllivoTheme.borderDark),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: OllivoTheme.oliveEmerald.withAlpha(30),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.keyboard_outlined, color: OllivoTheme.oliveEmerald, size: 22),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Keyboard Shortcuts',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Press ⌘/ anytime to toggle this quick reference sheet',
                              style: TextStyle(
                                fontSize: 12,
                                color: OllivoTheme.textSecondaryDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: OllivoTheme.textSecondaryDark, size: 20),
                        tooltip: 'Close (Esc)',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(color: OllivoTheme.borderDark, height: 1),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _query = val),
                    style: const TextStyle(fontSize: 13, color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search shortcuts (e.g., chat, quick ask, sidebar, cmd)...',
                      hintStyle: const TextStyle(fontSize: 13, color: OllivoTheme.textSecondaryDark),
                      prefixIcon: const Icon(Icons.search, size: 18, color: OllivoTheme.textSecondaryDark),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16, color: OllivoTheme.textSecondaryDark),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: OllivoTheme.cardDark,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: OllivoTheme.borderDark),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: OllivoTheme.borderDark),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: OllivoTheme.oliveEmerald),
                      ),
                    ),
                  ),
                ),

                // Shortcuts List
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.search_off, size: 40, color: OllivoTheme.textSecondaryDark),
                              const SizedBox(height: 10),
                              Text(
                                'No shortcuts found for "$_query"',
                                style: const TextStyle(color: OllivoTheme.textSecondaryDark, fontSize: 14),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          itemCount: categories.length,
                          itemBuilder: (context, catIndex) {
                            final cat = categories[catIndex];
                            final catShortcuts = filtered.where((e) => e.category == cat).toList();

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8, left: 4),
                                    child: Text(
                                      cat.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.1,
                                        color: OllivoTheme.oliveEmerald,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: OllivoTheme.cardDark,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: OllivoTheme.borderDark),
                                    ),
                                    child: Column(
                                      children: [
                                        for (int i = 0; i < catShortcuts.length; i++) ...[
                                          _buildShortcutRow(catShortcuts[i]),
                                          if (i < catShortcuts.length - 1)
                                            const Divider(color: OllivoTheme.borderDark, height: 1),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),

                const Divider(color: OllivoTheme.borderDark, height: 1),

                // Footer
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${filtered.length} shortcuts available',
                        style: const TextStyle(fontSize: 12, color: OllivoTheme.textSecondaryDark),
                      ),
                      OllivoSecondaryButton(
                        label: 'Done',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShortcutRow(ShortcutItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.description,
                  style: const TextStyle(
                    fontSize: 11,
                    color: OllivoTheme.textSecondaryDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final key in item.keys) ...[
                _buildKeyBadge(key),
                if (key != item.keys.last) const SizedBox(width: 4),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKeyBadge(String label) {
    return Container(
      constraints: const BoxConstraints(minWidth: 24),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: OllivoTheme.surfaceDark,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: OllivoTheme.borderDark.withAlpha(200)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            offset: Offset(0, 1),
            blurRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontFamily: 'SF Pro Text',
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
