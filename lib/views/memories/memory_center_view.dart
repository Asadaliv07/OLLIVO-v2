import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../components/ollivo_components.dart';
import '../../services/memory_service.dart';
import '../../theme.dart';

class MemoryCenterView extends StatefulWidget {
  final MemoryService memoryService;
  final List<Map<String, dynamic>>? initialMemories;

  const MemoryCenterView({
    super.key,
    required this.memoryService,
    this.initialMemories,
  });

  @override
  State<MemoryCenterView> createState() => _MemoryCenterViewState();
}

class _MemoryCenterViewState extends State<MemoryCenterView> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _memories = [];
  bool _isLoading = false;
  String _selectedCategory = 'All';

  static const List<String> _taxonomyCategories = [
    'All',
    'Personal',
    'Preference',
    'Project',
    'General',
  ];

  static const List<String> _editableCategories = [
    'personal',
    'preference',
    'project',
    'general',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialMemories != null) {
      _memories = List.from(widget.initialMemories!);
      _isLoading = false;
    } else {
      _isLoading = true;
      _loadMemories();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMemories() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final list = await widget.memoryService.getMemories(
        category: _selectedCategory == 'All' ? null : _selectedCategory.toLowerCase(),
      );
      if (!mounted) return;
      setState(() {
        _memories = list;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addNewMemoryDialog() async {
    final factController = TextEditingController();
    String category = 'preference';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: OllivoTheme.surfaceDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(OllivoTheme.radiusMd),
            side: const BorderSide(color: OllivoTheme.borderDark),
          ),
          title: const Row(
            children: [
              Icon(Icons.psychology, color: OllivoTheme.oliveEmerald, size: 22),
              SizedBox(width: 8),
              Text('Add Fact to Vector Memory'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OllivoTextField(
                controller: factController,
                hintText: 'Enter fact (e.g., UI uses #121212 Onyx theme)...',
                labelText: 'Fact Statement',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Category Taxonomy'),
                dropdownColor: OllivoTheme.surfaceDark,
                items: _editableCategories.map((c) {
                  return DropdownMenuItem(
                    value: c,
                    child: Text(c[0].toUpperCase() + c.substring(1)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => category = val);
                  }
                },
              ),
            ],
          ),
          actions: [
            OllivoSecondaryButton(label: 'Cancel', onPressed: () => Navigator.pop(context)),
            OllivoPrimaryButton(
              label: 'Save Fact',
              onPressed: () async {
                final text = factController.text.trim();
                if (text.isNotEmpty) {
                  Navigator.pop(context);
                  await widget.memoryService.saveFactWithDedup(text, category: category);
                  await _loadMemories();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editMemoryDialog(String id, String currentFact, String currentCategory) async {
    final factController = TextEditingController(text: currentFact);
    String category = _editableCategories.contains(currentCategory.toLowerCase())
        ? currentCategory.toLowerCase()
        : 'general';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: OllivoTheme.surfaceDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(OllivoTheme.radiusMd),
            side: const BorderSide(color: OllivoTheme.borderDark),
          ),
          title: const Row(
            children: [
              Icon(Icons.edit_note, color: OllivoTheme.oliveEmerald, size: 22),
              SizedBox(width: 8),
              Text('Edit Stored Memory'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OllivoTextField(
                controller: factController,
                hintText: 'Edit fact content...',
                labelText: 'Fact Statement',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Category Taxonomy'),
                dropdownColor: OllivoTheme.surfaceDark,
                items: _editableCategories.map((c) {
                  return DropdownMenuItem(
                    value: c,
                    child: Text(c[0].toUpperCase() + c.substring(1)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => category = val);
                  }
                },
              ),
            ],
          ),
          actions: [
            OllivoSecondaryButton(label: 'Cancel', onPressed: () => Navigator.pop(context)),
            OllivoPrimaryButton(
              label: 'Save Changes',
              onPressed: () async {
                final text = factController.text.trim();
                if (text.isNotEmpty) {
                  Navigator.pop(context);
                  await widget.memoryService.updateMemory(id, text, category: category);
                  await _loadMemories();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteMemory(String id, String fact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OllivoTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OllivoTheme.radiusMd),
          side: const BorderSide(color: OllivoTheme.borderDark),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: OllivoTheme.statusWarning, size: 22),
            SizedBox(width: 8),
            Text('Forget Fact Memory?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to forget this fact? Ollivo will no longer retrieve it into context during conversations.',
              style: TextStyle(fontSize: 13, color: OllivoTheme.textSecondaryDark),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: OllivoTheme.cardDark,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: OllivoTheme.borderDark),
              ),
              child: Text(
                fact,
                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          OllivoSecondaryButton(label: 'Cancel', onPressed: () => Navigator.pop(ctx, false)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: OllivoTheme.statusError,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Forget Fact'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.memoryService.deleteMemory(id);
      await _loadMemories();
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.toLowerCase().trim();
    final filtered = _memories.where((m) {
      final fact = (m['fact'] as String? ?? '').toLowerCase();
      final cat = (m['category'] as String? ?? '').toLowerCase();
      return query.isEmpty || fact.contains(query) || cat.contains(query);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Search Bar & Add Button
        Row(
          children: [
            Expanded(
              child: OllivoTextField(
                controller: _searchController,
                hintText: 'Search stored fact memories...',
                prefixIcon: const Icon(Icons.search, color: OllivoTheme.textSecondaryDark),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            OllivoPrimaryButton(
              label: 'Add Fact',
              icon: Icons.add,
              onPressed: _addNewMemoryDialog,
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Category Filter Chips (MEM-001)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _taxonomyCategories.map((cat) {
              final isSel = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: FilterChip(
                  label: Text(cat),
                  selected: isSel,
                  selectedColor: OllivoTheme.oliveEmerald.withValues(alpha: 0.2),
                  checkmarkColor: OllivoTheme.oliveEmerald,
                  backgroundColor: OllivoTheme.cardDark,
                  side: BorderSide(color: isSel ? OllivoTheme.oliveEmerald : OllivoTheme.borderDark),
                  onSelected: (val) {
                    setState(() => _selectedCategory = cat);
                    _loadMemories();
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // Memories List
        Expanded(
          child: _isLoading
              ? const OllivoLoadingIndicator(label: 'Loading memories from SQLite...')
              : filtered.isEmpty
                  ? OllivoCard(
                      child: OllivoEmptyState(
                        icon: Icons.psychology_outlined,
                        title: 'No memories stored yet',
                        description: 'Tell Ollivo facts during chat (e.g. "Remember our design color is #121212") or add facts manually above.',
                        actionLabel: 'Add Fact Manually',
                        onAction: _addNewMemoryDialog,
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final id = item['id'] as String;
                        final fact = item['fact'] as String;
                        final cat = item['category'] as String? ?? 'general';

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10.0),
                          child: OllivoCard(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: OllivoTheme.oliveEmerald.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.psychology, color: OllivoTheme.oliveEmerald),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: OllivoTheme.borderDark,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              cat.toUpperCase(),
                                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: OllivoTheme.oliveEmerald),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      SelectableText(
                                        fact,
                                        style: const TextStyle(fontSize: 14, color: OllivoTheme.textPrimaryDark),
                                      ),
                                    ],
                                  ),
                                ),
                                // Copy Button
                                IconButton(
                                  icon: const Icon(Icons.copy, size: 18, color: OllivoTheme.textSecondaryDark),
                                  tooltip: 'Copy Fact',
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: fact));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Fact copied to clipboard'),
                                        duration: Duration(seconds: 1),
                                      ),
                                    );
                                  },
                                ),
                                // Edit Button (MEM-002)
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18, color: OllivoTheme.oliveEmerald),
                                  tooltip: 'Edit Memory',
                                  onPressed: () => _editMemoryDialog(id, fact, cat),
                                ),
                                // Delete Button
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20, color: OllivoTheme.statusError),
                                  tooltip: 'Forget Fact',
                                  onPressed: () => _confirmDeleteMemory(id, fact),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
