import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../components/ollivo_components.dart';
import '../../models/model_configuration.dart';
import '../../services/model_config_service.dart';
import '../../theme.dart';

/// Modal Dialog for Advanced Per-Model Configuration (LM Studio / Ollama parity)
class ModelConfigDialog extends StatefulWidget {
  final String modelId;
  final ModelConfigService modelConfigService;
  final VoidCallback? onSaved;

  const ModelConfigDialog({
    super.key,
    required this.modelId,
    required this.modelConfigService,
    this.onSaved,
  });

  static Future<void> show(
    BuildContext context, {
    required String modelId,
    required ModelConfigService modelConfigService,
    VoidCallback? onSaved,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ModelConfigDialog(
        modelId: modelId,
        modelConfigService: modelConfigService,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<ModelConfigDialog> createState() => _ModelConfigDialogState();
}

class _ModelConfigDialogState extends State<ModelConfigDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ModelConfiguration _config;
  bool _hasUnsavedChanges = false;
  String? _statusMessage;
  bool _isSuccess = true;

  // Controllers
  late TextEditingController _systemPromptController;
  late TextEditingController _stopSeqController;
  late TextEditingController _seedController;
  late TextEditingController _threadsController;
  late TextEditingController _gpuLayersController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadConfig();
  }

  void _loadConfig() {
    final existing = widget.modelConfigService.getConfig(widget.modelId);
    _config = existing ?? widget.modelConfigService.createDefaultConfig(widget.modelId);

    _systemPromptController = TextEditingController(text: _config.systemPrompt ?? '');
    _stopSeqController = TextEditingController(text: _config.stopSequences?.join(', ') ?? '');
    _seedController = TextEditingController(text: _config.generationParams.seed?.toString() ?? '');
    _threadsController = TextEditingController(text: _config.runtimeConfig.numThreads?.toString() ?? '');
    _gpuLayersController = TextEditingController(text: _config.runtimeConfig.numGpuLayers?.toString() ?? '');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _systemPromptController.dispose();
    _stopSeqController.dispose();
    _seedController.dispose();
    _threadsController.dispose();
    _gpuLayersController.dispose();
    super.dispose();
  }

  void _markChanged() {
    if (!_hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  Future<void> _saveConfig() async {
    // Parse stop sequences
    final stopSeqs = _stopSeqController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    // Parse seed
    final seedVal = int.tryParse(_seedController.text.trim());
    final threadsVal = int.tryParse(_threadsController.text.trim());
    final gpuLayersVal = int.tryParse(_gpuLayersController.text.trim());

    final updated = _config.copyWith(
      systemPrompt: _systemPromptController.text,
      stopSequences: stopSeqs,
      generationParams: _config.generationParams.copyWith(
        seed: seedVal,
      ),
      runtimeConfig: _config.runtimeConfig.copyWith(
        numThreads: threadsVal,
        numGpuLayers: gpuLayersVal,
      ),
    );

    final error = widget.modelConfigService.validateConfig(updated);
    if (error != null) {
      setState(() {
        _statusMessage = 'Validation Error: $error';
        _isSuccess = false;
      });
      return;
    }

    await widget.modelConfigService.saveConfig(updated);
    if (!mounted) return;
    setState(() {
      _config = updated;
      _hasUnsavedChanges = false;
      _statusMessage = 'Model configuration saved and persisted successfully!';
      _isSuccess = true;
    });
    widget.onSaved?.call();
  }

  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OllivoTheme.cardDark,
        title: const Text('Reset Model Configuration?'),
        content: Text('This will reset all parameter overrides for "${widget.modelId}" to global application defaults.'),
        actions: [
          OllivoSecondaryButton(label: 'Cancel', onPressed: () => Navigator.pop(ctx, false)),
          OllivoDangerButton(label: 'Reset to Defaults', onPressed: () => Navigator.pop(ctx, true)),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.modelConfigService.resetConfig(widget.modelId);
      if (!mounted) return;
      setState(() {
        _loadConfig();
        _hasUnsavedChanges = false;
        _statusMessage = 'Configuration reset to defaults.';
        _isSuccess = true;
      });
      widget.onSaved?.call();
    }
  }

  void _exportConfig() {
    final jsonStr = _config.toJsonString();
    Clipboard.setData(ClipboardData(text: jsonStr));
    setState(() {
      _statusMessage = 'Configuration copied to clipboard (JSON format).';
      _isSuccess = true;
    });
  }

  Future<void> _importConfig() async {
    final textController = TextEditingController();
    final imported = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OllivoTheme.cardDark,
        title: const Text('Import Model Configuration (JSON)'),
        content: SizedBox(
          width: 500,
          child: TextField(
            controller: textController,
            maxLines: 10,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            decoration: const InputDecoration(
              hintText: 'Paste configuration JSON here...',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          OllivoSecondaryButton(label: 'Cancel', onPressed: () => Navigator.pop(ctx)),
          OllivoPrimaryButton(label: 'Import', onPressed: () => Navigator.pop(ctx, textController.text)),
        ],
      ),
    );

    if (imported != null && imported.trim().isNotEmpty) {
      final res = await widget.modelConfigService.importConfig(imported.trim());
      if (res != null) {
        setState(() {
          _config = res;
          _systemPromptController.text = _config.systemPrompt ?? '';
          _stopSeqController.text = _config.stopSequences?.join(', ') ?? '';
          _seedController.text = _config.generationParams.seed?.toString() ?? '';
          _threadsController.text = _config.runtimeConfig.numThreads?.toString() ?? '';
          _gpuLayersController.text = _config.runtimeConfig.numGpuLayers?.toString() ?? '';
          _hasUnsavedChanges = false;
          _statusMessage = 'Successfully imported configuration!';
          _isSuccess = true;
        });
      } else {
        setState(() {
          _statusMessage = 'Invalid configuration JSON. Import aborted.';
          _isSuccess = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: OllivoTheme.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: OllivoTheme.borderDark),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960, maxHeight: 780),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              if (_statusMessage != null) ...[
                _buildStatusBanner(),
                const SizedBox(height: 12),
              ],
              _buildTabBar(),
              const SizedBox(height: 16),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSamplingTab(),
                    _buildContextAndRagTab(),
                    _buildSystemPromptTab(),
                    _buildRuntimeTab(),
                    _buildPrecedenceInspectorTab(),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: OllivoTheme.mintAccent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: OllivoTheme.mintAccent.withValues(alpha: 0.25)),
          ),
          child: const Icon(Icons.tune_rounded, color: OllivoTheme.mintPrimary, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    widget.modelId,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: OllivoTheme.cardDark,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: OllivoTheme.borderDark),
                    ),
                    child: const Text('Ollama / Local Engine', style: TextStyle(fontSize: 11, color: OllivoTheme.mintPrimary, fontWeight: FontWeight.w600)),
                  ),
                  if (_hasUnsavedChanges) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: OllivoTheme.statusWarning.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('Unsaved Changes', style: TextStyle(fontSize: 11, color: OllivoTheme.statusWarning, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Per-Model Configuration overrides global defaults for this specific model without modifying other models or underlying weights.',
                style: TextStyle(fontSize: 12, color: OllivoTheme.textSecondaryDark),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded, color: OllivoTheme.textSecondaryDark),
          tooltip: 'Close',
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildStatusBanner() {
    final color = _isSuccess ? OllivoTheme.mintPrimary : OllivoTheme.statusError;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(_isSuccess ? Icons.check_circle_outline : Icons.error_outline, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(_statusMessage!, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500))),
          IconButton(
            icon: const Icon(Icons.close, size: 14),
            color: color,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => setState(() => _statusMessage = null),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: OllivoTheme.borderDark)),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: OllivoTheme.mintPrimary,
        unselectedLabelColor: OllivoTheme.textSecondaryDark,
        indicatorColor: OllivoTheme.mintPrimary,
        indicatorWeight: 2,
        tabAlignment: TabAlignment.start,
        tabs: const [
          Tab(icon: Icon(Icons.tune_rounded, size: 16), text: 'Sampling & Generation'),
          Tab(icon: Icon(Icons.memory_rounded, size: 16), text: 'Context, Memory & RAG'),
          Tab(icon: Icon(Icons.chat_bubble_outline_rounded, size: 16), text: 'System Prompt'),
          Tab(icon: Icon(Icons.speed_rounded, size: 16), text: 'Runtime & Hardware'),
          Tab(icon: Icon(Icons.account_tree_outlined, size: 16), text: 'Precedence Hierarchy'),
        ],
      ),
    );
  }

  Widget _buildSamplingTab() {
    final gen = _config.generationParams;
    return ListView(
      children: [
        _buildSectionHeader('Sampling Randomness & Probability Thresholds'),
        _buildSliderTile(
          label: 'Temperature',
          description: 'Controls sampling randomness. Lower values produce focused, deterministic outputs; higher values increase diversity.',
          value: gen.temperature,
          min: 0.0,
          max: 2.0,
          divisions: 40,
          displayValue: gen.temperature.toStringAsFixed(2),
          onChanged: (v) {
            setState(() => _config = _config.copyWith(generationParams: gen.copyWith(temperature: v)));
            _markChanged();
          },
        ),
        _buildSliderTile(
          label: 'Top-P (Nucleus Sampling)',
          description: 'Limits token selection to cumulative probability threshold. Recommended: 0.90.',
          value: gen.topP,
          min: 0.0,
          max: 1.0,
          divisions: 20,
          displayValue: gen.topP.toStringAsFixed(2),
          onChanged: (v) {
            setState(() => _config = _config.copyWith(generationParams: gen.copyWith(topP: v)));
            _markChanged();
          },
        ),
        _buildSliderTile(
          label: 'Top-K Sampling',
          description: 'Restricts candidate pool to the top K most probable tokens. Set to 0 to disable.',
          value: gen.topK.toDouble(),
          min: 0,
          max: 100,
          divisions: 100,
          displayValue: gen.topK == 0 ? 'Disabled' : gen.topK.toString(),
          onChanged: (v) {
            setState(() => _config = _config.copyWith(generationParams: gen.copyWith(topK: v.toInt())));
            _markChanged();
          },
        ),
        _buildSliderTile(
          label: 'Min-P Threshold',
          description: 'Minimum probability threshold relative to the top token. Scales dynamically with confidence.',
          value: gen.minP,
          min: 0.0,
          max: 1.0,
          divisions: 20,
          displayValue: gen.minP.toStringAsFixed(2),
          onChanged: (v) {
            setState(() => _config = _config.copyWith(generationParams: gen.copyWith(minP: v)));
            _markChanged();
          },
        ),
        _buildSliderTile(
          label: 'Typical-P Sampling',
          description: 'Selects tokens whose information content matches the conditional entropy. Set to 1.0 to disable.',
          value: gen.typicalP,
          min: 0.1,
          max: 1.0,
          divisions: 18,
          displayValue: gen.typicalP.toStringAsFixed(2),
          onChanged: (v) {
            setState(() => _config = _config.copyWith(generationParams: gen.copyWith(typicalP: v)));
            _markChanged();
          },
        ),
        const Divider(color: OllivoTheme.borderDark, height: 28),
        _buildSectionHeader('Repetition Penalties & Constraints'),
        _buildSliderTile(
          label: 'Repeat Penalty',
          description: 'Penalizes previously generated tokens to reduce loops. 1.0 is neutral, 1.1-1.2 is balanced.',
          value: gen.repeatPenalty,
          min: 0.5,
          max: 2.0,
          divisions: 30,
          displayValue: gen.repeatPenalty.toStringAsFixed(2),
          onChanged: (v) {
            setState(() => _config = _config.copyWith(generationParams: gen.copyWith(repeatPenalty: v)));
            _markChanged();
          },
        ),
        _buildSliderTile(
          label: 'Repeat Last N Window',
          description: 'Number of recent tokens examined for repetition penalty. 64 is standard.',
          value: gen.repeatLastN.toDouble(),
          min: 0,
          max: 256,
          divisions: 32,
          displayValue: '${gen.repeatLastN} tokens',
          onChanged: (v) {
            setState(() => _config = _config.copyWith(generationParams: gen.copyWith(repeatLastN: v.toInt())));
            _markChanged();
          },
        ),
        _buildSliderTile(
          label: 'Presence Penalty',
          description: 'Penalizes tokens if they have appeared at all in the output, encouraging topic exploration.',
          value: gen.presencePenalty,
          min: -2.0,
          max: 2.0,
          divisions: 40,
          displayValue: gen.presencePenalty.toStringAsFixed(2),
          onChanged: (v) {
            setState(() => _config = _config.copyWith(generationParams: gen.copyWith(presencePenalty: v)));
            _markChanged();
          },
        ),
        _buildSliderTile(
          label: 'Frequency Penalty',
          description: 'Penalizes tokens proportionally to how many times they appear in the output.',
          value: gen.frequencyPenalty,
          min: -2.0,
          max: 2.0,
          divisions: 40,
          displayValue: gen.frequencyPenalty.toStringAsFixed(2),
          onChanged: (v) {
            setState(() => _config = _config.copyWith(generationParams: gen.copyWith(frequencyPenalty: v)));
            _markChanged();
          },
        ),
        const Divider(color: OllivoTheme.borderDark, height: 28),
        _buildSectionHeader('Output Bounds & Stop Sequences'),
        _buildSliderTile(
          label: 'Maximum Output Tokens (num_predict)',
          description: 'Bounds the maximum number of tokens generated in a single response.',
          value: gen.maxOutputTokens.toDouble(),
          min: 128,
          max: 16384,
          divisions: 127,
          displayValue: '${gen.maxOutputTokens} tokens',
          onChanged: (v) {
            setState(() => _config = _config.copyWith(generationParams: gen.copyWith(maxOutputTokens: v.toInt())));
            _markChanged();
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Stop Sequences (comma-separated)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 4),
              const Text('Generation stops immediately if any of these token strings are emitted.', style: TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark)),
              const SizedBox(height: 8),
              TextField(
                controller: _stopSeqController,
                onChanged: (_) => _markChanged(),
                style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                decoration: const InputDecoration(
                  hintText: 'e.g. <|endoftext|>, User:, Human:',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Deterministic Random Seed (optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 4),
              const Text('Set an integer seed to produce reproducible outputs. Leave blank for randomized sampling.', style: TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark)),
              const SizedBox(height: 8),
              TextField(
                controller: _seedController,
                onChanged: (_) => _markChanged(),
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                decoration: const InputDecoration(
                  hintText: 'e.g. 42 (leave empty for random)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContextAndRagTab() {
    final ctx = _config.contextSettings;
    return ListView(
      children: [
        _buildSectionHeader('Context Window & Memory Retention'),
        _buildSliderTile(
          label: 'Context Window Length (num_ctx)',
          description: 'Maximum tokens kept in active context window (prompt + history). Higher sizes require more VRAM/RAM.',
          value: ctx.contextLength.toDouble(),
          min: 1024,
          max: 65536,
          divisions: 63,
          displayValue: '${ctx.contextLength} tokens',
          onChanged: (v) {
            setState(() => _config = _config.copyWith(contextSettings: ctx.copyWith(contextLength: v.toInt())));
            _markChanged();
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Keep-Alive Inactivity Timeout', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
          subtitle: const Text('Duration the model remains in VRAM after the last inference request. Use "0" to unload immediately, "-1" to pin indefinitely.', style: TextStyle(fontSize: 12, color: OllivoTheme.textSecondaryDark)),
          trailing: DropdownButton<String>(
            value: ctx.keepAlive,
            dropdownColor: OllivoTheme.cardDark,
            items: const [
              DropdownMenuItem(value: '0', child: Text('Unload Immediately (0)')),
              DropdownMenuItem(value: '5m', child: Text('5 minutes (Default)')),
              DropdownMenuItem(value: '15m', child: Text('15 minutes')),
              DropdownMenuItem(value: '30m', child: Text('30 minutes')),
              DropdownMenuItem(value: '1h', child: Text('1 hour')),
              DropdownMenuItem(value: '-1', child: Text('Keep Loaded Forever (-1)')),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() => _config = _config.copyWith(contextSettings: ctx.copyWith(keepAlive: val)));
                _markChanged();
              }
            },
          ),
        ),
        const Divider(color: OllivoTheme.borderDark, height: 28),
        _buildSectionHeader('Per-Model RAG & Vector Retrieval Defaults'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Enable Local Document RAG for this Model', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
          subtitle: const Text('Automatically retrieve and inject relevant document chunks from local vector store into context.', style: TextStyle(fontSize: 12, color: OllivoTheme.textSecondaryDark)),
          value: ctx.ragEnabled,
          activeThumbColor: OllivoTheme.mintPrimary,
          onChanged: (val) {
            setState(() => _config = _config.copyWith(contextSettings: ctx.copyWith(ragEnabled: val)));
            _markChanged();
          },
        ),
        _buildSliderTile(
          label: 'Retrieved Chunks Count (Top-K)',
          description: 'Maximum document citations to inject into this model\'s system prompt per prompt.',
          value: ctx.retrievedDocCount.toDouble(),
          min: 1,
          max: 10,
          divisions: 9,
          displayValue: '${ctx.retrievedDocCount} chunks',
          onChanged: (v) {
            setState(() => _config = _config.copyWith(contextSettings: ctx.copyWith(retrievedDocCount: v.toInt())));
            _markChanged();
          },
        ),
        _buildSliderTile(
          label: 'Vector Cosine Similarity Threshold',
          description: 'Minimum cosine similarity score required for a retrieved document chunk to be injected. Higher values ensure strict relevance.',
          value: ctx.similarityThreshold,
          min: 0.1,
          max: 0.9,
          divisions: 16,
          displayValue: ctx.similarityThreshold.toStringAsFixed(2),
          onChanged: (v) {
            setState(() => _config = _config.copyWith(contextSettings: ctx.copyWith(similarityThreshold: v)));
            _markChanged();
          },
        ),
      ],
    );
  }

  Widget _buildSystemPromptTab() {
    return ListView(
      children: [
        _buildSectionHeader('Model-Specific System Persona & Instructions'),
        const Text(
          'This system prompt is permanently bound to this model profile and sent with every chat session using this model unless explicitly overridden by a conversation template.',
          style: TextStyle(fontSize: 12, color: OllivoTheme.textSecondaryDark),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _systemPromptController,
          onChanged: (_) => _markChanged(),
          maxLines: 12,
          style: const TextStyle(fontSize: 13, height: 1.4),
          decoration: const InputDecoration(
            hintText: 'Enter model system instructions...',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            OllivoSecondaryButton(
              label: 'Restore Default Assistant Prompt',
              icon: Icons.restore_rounded,
              onPressed: () {
                setState(() {
                  _systemPromptController.text = 'You are Ollivo, an intelligent and private AI desktop assistant running locally on macOS. You provide accurate, structured, and helpful responses.';
                  _markChanged();
                });
              },
            ),
            const SizedBox(width: 10),
            OllivoSecondaryButton(
              label: 'Clear Prompt',
              icon: Icons.clear_all_rounded,
              onPressed: () {
                setState(() {
                  _systemPromptController.text = '';
                  _markChanged();
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRuntimeTab() {
    final run = _config.runtimeConfig;
    return ListView(
      children: [
        _buildSectionHeader('Local Inference Engine & Hardware Offload'),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Execution Target Backend', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
          subtitle: const Text('Select execution pipeline preference. Ollama uses Metal acceleration automatically on macOS Apple Silicon.', style: TextStyle(fontSize: 12, color: OllivoTheme.textSecondaryDark)),
          trailing: DropdownButton<String>(
            value: run.executionBackend,
            dropdownColor: OllivoTheme.cardDark,
            items: const [
              DropdownMenuItem(value: 'auto', child: Text('Auto (Metal / GPU Offload)')),
              DropdownMenuItem(value: 'gpu', child: Text('Force GPU / Metal Acceleration')),
              DropdownMenuItem(value: 'cpu', child: Text('Force CPU Only')),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() => _config = _config.copyWith(runtimeConfig: run.copyWith(executionBackend: val)));
                _markChanged();
              }
            },
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Flash Attention (Metal / GPU)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
          subtitle: const Text('Enables memory-efficient attention mechanism for supported architectures.', style: TextStyle(fontSize: 12, color: OllivoTheme.textSecondaryDark)),
          value: run.flashAttention,
          activeThumbColor: OllivoTheme.mintPrimary,
          onChanged: (val) {
            setState(() => _config = _config.copyWith(runtimeConfig: run.copyWith(flashAttention: val)));
            _markChanged();
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('F16 KV-Cache Precision', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
          subtitle: const Text('Uses 16-bit float precision for key-value attention cache.', style: TextStyle(fontSize: 12, color: OllivoTheme.textSecondaryDark)),
          value: run.f16Kv,
          activeThumbColor: OllivoTheme.mintPrimary,
          onChanged: (val) {
            setState(() => _config = _config.copyWith(runtimeConfig: run.copyWith(f16Kv: val)));
            _markChanged();
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('CPU Threads (num_thread)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 4),
              const Text('Leave blank for engine auto-selection based on physical cores.', style: TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark)),
              const SizedBox(height: 8),
              TextField(
                controller: _threadsController,
                onChanged: (_) => _markChanged(),
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                decoration: const InputDecoration(
                  hintText: 'e.g. 8 (leave empty for auto)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('GPU Offload Layers (num_gpu)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 4),
              const Text('Number of transformer layers to offload to VRAM. Leave empty for 100% offload.', style: TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark)),
              const SizedBox(height: 8),
              TextField(
                controller: _gpuLayersController,
                onChanged: (_) => _markChanged(),
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                decoration: const InputDecoration(
                  hintText: 'e.g. 33 (leave empty for all layers)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrecedenceInspectorTab() {
    final effective = widget.modelConfigService.resolveEffectiveParameters(modelId: widget.modelId);
    return ListView(
      children: [
        _buildSectionHeader('4-Tier Precedence Hierarchy Inspector'),
        const Text(
          'Ollivo resolves runtime parameters using strict precedence:\n'
          'Conversation Override → Model-Specific Profile → Global Settings Default → Backend Default\n\n'
          'The table below displays currently resolved effective parameters for this model and their exact origin source.',
          style: TextStyle(fontSize: 12, color: OllivoTheme.textSecondaryDark, height: 1.4),
        ),
        const SizedBox(height: 16),
        _buildPrecedenceRow('Temperature', effective.temperature.toStringAsFixed(2), effective.parameterSources['temperature'] ?? 'unknown'),
        _buildPrecedenceRow('Top-P', effective.topP.toStringAsFixed(2), effective.parameterSources['topP'] ?? 'unknown'),
        _buildPrecedenceRow('Top-K', effective.topK.toString(), effective.parameterSources['topK'] ?? 'unknown'),
        _buildPrecedenceRow('Min-P', effective.minP.toStringAsFixed(2), effective.parameterSources['minP'] ?? 'unknown'),
        _buildPrecedenceRow('Repeat Penalty', effective.repeatPenalty.toStringAsFixed(2), effective.parameterSources['repeatPenalty'] ?? 'unknown'),
        _buildPrecedenceRow('Max Tokens', effective.maxTokens.toString(), effective.parameterSources['maxTokens'] ?? 'unknown'),
        _buildPrecedenceRow('Context Length', '${effective.contextLength} tokens', effective.parameterSources['contextLength'] ?? 'unknown'),
        _buildPrecedenceRow('RAG Enabled', effective.ragEnabled ? 'YES' : 'NO', effective.parameterSources['ragEnabled'] ?? 'unknown'),
        _buildPrecedenceRow('Keep-Alive', effective.keepAlive, effective.parameterSources['keepAlive'] ?? 'unknown'),
      ],
    );
  }

  Widget _buildPrecedenceRow(String param, String value, String source) {
    Color badgeColor = OllivoTheme.textSecondaryDark;
    String badgeText = source;
    if (source == ParameterSource.modelOverride) {
      badgeColor = OllivoTheme.mintPrimary;
      badgeText = 'MODEL OVERRIDE';
    } else if (source == ParameterSource.conversation) {
      badgeColor = Colors.cyanAccent;
      badgeText = 'CONVERSATION';
    } else if (source == ParameterSource.globalDefault) {
      badgeColor = Colors.amberAccent;
      badgeText = 'GLOBAL DEFAULT';
    } else if (source == ParameterSource.backendDefault) {
      badgeColor = Colors.grey;
      badgeText = 'BACKEND DEFAULT';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: OllivoTheme.cardDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: OllivoTheme.borderDark),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(param, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
          Row(
            children: [
              Text(value, style: const TextStyle(fontSize: 13, fontFamily: 'monospace', color: Colors.white70)),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSliderTile({
    required String label,
    required String description,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String displayValue,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: OllivoTheme.cardDark,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: OllivoTheme.borderDark),
                ),
                child: Text(displayValue, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: OllivoTheme.mintPrimary, fontFamily: 'monospace')),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(description, style: const TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark)),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            activeColor: OllivoTheme.mintPrimary,
            inactiveColor: OllivoTheme.borderDark,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 12.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: OllivoTheme.mintPrimary,
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      children: [
        OllivoSecondaryButton(
          label: 'Export JSON',
          icon: Icons.upload_file_rounded,
          onPressed: _exportConfig,
        ),
        const SizedBox(width: 8),
        OllivoSecondaryButton(
          label: 'Import JSON',
          icon: Icons.download_rounded,
          onPressed: _importConfig,
        ),
        const SizedBox(width: 8),
        OllivoSecondaryButton(
          label: 'Reset to Defaults',
          icon: Icons.restore_rounded,
          onPressed: _resetToDefaults,
        ),
        const Spacer(),
        OllivoSecondaryButton(
          label: 'Close',
          onPressed: () => Navigator.pop(context),
        ),
        const SizedBox(width: 10),
        OllivoPrimaryButton(
          label: 'Save Configuration',
          icon: Icons.save_rounded,
          onPressed: _saveConfig,
        ),
      ],
    );
  }
}
