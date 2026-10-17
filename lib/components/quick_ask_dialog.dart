import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/ai_service.dart';
import '../services/settings_service.dart';
import '../theme.dart';
import 'markdown_view.dart';

/// Global Spotlight-Style Quick Ask Modal (MAC-001)
class QuickAskDialog extends StatefulWidget {
  final AIService aiService;
  final SettingsService settingsService;
  final void Function(String prompt, String response)? onOpenInChat;
  final bool autofocus;

  const QuickAskDialog({
    super.key,
    required this.aiService,
    required this.settingsService,
    this.onOpenInChat,
    this.autofocus = true,
  });

  static Future<void> show(
    BuildContext context, {
    required AIService aiService,
    required SettingsService settingsService,
    void Function(String prompt, String response)? onOpenInChat,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (context) => QuickAskDialog(
        aiService: aiService,
        settingsService: settingsService,
        onOpenInChat: onOpenInChat,
      ),
    );
  }

  @override
  State<QuickAskDialog> createState() => _QuickAskDialogState();
}

class _QuickAskDialogState extends State<QuickAskDialog> {
  final TextEditingController _promptController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _responseScrollController = ScrollController();

  StreamSubscription<String>? _streamSub;
  String _currentResponse = '';
  String _lastPrompt = '';
  bool _isGenerating = false;
  String? _errorMessage;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _promptController.dispose();
    _focusNode.dispose();
    _responseScrollController.dispose();
    super.dispose();
  }

  void _sendQuery() {
    final query = _promptController.text.trim();
    if (query.isEmpty || _isGenerating) return;

    setState(() {
      _lastPrompt = query;
      _currentResponse = '';
      _isGenerating = true;
      _errorMessage = null;
      _copied = false;
    });

    final targetHost = widget.settingsService.effectiveInferenceHost;
    final targetModel = widget.settingsService.effectiveInferenceModel;
    final targetBackend = widget.settingsService.effectiveInferenceBackend;

    _streamSub?.cancel();
    _streamSub = widget.aiService
        .generateStream(
          query,
          customHost: targetHost,
          customModel: targetModel,
          backendId: targetBackend,
          temperature: widget.settingsService.chatTemperature,
          contextWindow: widget.settingsService.contextWindow,
          topP: widget.settingsService.topP,
          topK: widget.settingsService.topK,
          repeatPenalty: widget.settingsService.repeatPenalty,
          systemPrompt: widget.settingsService.systemPrompt,
        )
        .listen(
          (chunk) {
            setState(() {
              _currentResponse += chunk;
            });
            // Auto scroll preview to bottom
            if (_responseScrollController.hasClients) {
              _responseScrollController.jumpTo(
                _responseScrollController.position.maxScrollExtent,
              );
            }
          },
          onError: (e) {
            setState(() {
              _isGenerating = false;
              _errorMessage = 'Error: ${e.toString()}';
            });
          },
          onDone: () {
            setState(() {
              _isGenerating = false;
            });
          },
        );
  }

  void _cancelQuery() {
    _streamSub?.cancel();
    _streamSub = null;
    setState(() {
      _isGenerating = false;
    });
  }

  void _copyResponse() {
    if (_currentResponse.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _currentResponse));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeModel = widget.settingsService.activeModel;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
      child: Container(
        width: 640,
        constraints: const BoxConstraints(maxHeight: 580),
        decoration: BoxDecoration(
          color: OllivoTheme.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: OllivoTheme.oliveEmerald.withValues(alpha: 0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: OllivoTheme.oliveEmerald.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.bolt_rounded, size: 18, color: OllivoTheme.oliveEmerald),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Quick Ask',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: OllivoTheme.cardDark,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: OllivoTheme.borderDark),
                    ),
                    child: Text(
                      activeModel.isEmpty ? 'No Model' : activeModel,
                      style: const TextStyle(fontSize: 11, color: OllivoTheme.oliveEmerald, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: OllivoTheme.cardDark,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: OllivoTheme.borderDark),
                    ),
                    child: const Text('ESC', style: TextStyle(fontSize: 10, color: OllivoTheme.textSecondaryDark, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: OllivoTheme.textSecondaryDark),
                    splashRadius: 18,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(color: OllivoTheme.borderDark, height: 1),

            // Prompt Input Field
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _promptController,
                      focusNode: _focusNode,
                      autofocus: widget.autofocus,
                      style: const TextStyle(fontSize: 15, color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Quick question or command... (Enter to ask)',
                        hintStyle: TextStyle(color: OllivoTheme.textSecondaryDark, fontSize: 14),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: (_) => _sendQuery(),
                    ),
                  ),
                  if (_isGenerating) ...[
                    IconButton(
                      icon: const Icon(Icons.stop_circle_outlined, color: OllivoTheme.statusError, size: 22),
                      tooltip: 'Stop Generation',
                      onPressed: _cancelQuery,
                    ),
                  ] else ...[
                    IconButton(
                      icon: const Icon(Icons.arrow_upward_rounded, color: OllivoTheme.oliveEmerald, size: 22),
                      tooltip: 'Ask Ollivo',
                      onPressed: _sendQuery,
                    ),
                  ],
                ],
              ),
            ),

            // Preview Area or Placeholder
            if (_currentResponse.isNotEmpty || _errorMessage != null || _isGenerating) ...[
              const Divider(color: OllivoTheme.borderDark, height: 1),
              Flexible(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 320),
                  padding: const EdgeInsets.all(16),
                  color: OllivoTheme.cardDark.withValues(alpha: 0.5),
                  child: SingleChildScrollView(
                    controller: _responseScrollController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_errorMessage != null)
                          Text(
                            _errorMessage!,
                            style: const TextStyle(color: OllivoTheme.statusError, fontSize: 13),
                          )
                        else if (_currentResponse.isEmpty && _isGenerating)
                          const Row(
                            children: [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(OllivoTheme.oliveEmerald),
                                ),
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Thinking...',
                                style: TextStyle(fontSize: 13, color: OllivoTheme.textSecondaryDark, fontStyle: FontStyle.italic),
                              ),
                            ],
                          )
                        else
                          RichMarkdownView(markdown: _currentResponse),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom Actions Row
              const Divider(color: OllivoTheme.borderDark, height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        TextButton.icon(
                          icon: Icon(
                            _copied ? Icons.check : Icons.copy_rounded,
                            size: 14,
                            color: _copied ? OllivoTheme.oliveEmerald : OllivoTheme.textSecondaryDark,
                          ),
                          label: Text(
                            _copied ? 'Copied!' : 'Copy Answer',
                            style: TextStyle(
                              fontSize: 12,
                              color: _copied ? OllivoTheme.oliveEmerald : OllivoTheme.textSecondaryDark,
                            ),
                          ),
                          onPressed: _currentResponse.isEmpty ? null : _copyResponse,
                        ),
                        const SizedBox(width: 8),
                        if (widget.onOpenInChat != null)
                          TextButton.icon(
                            icon: const Icon(Icons.chat_outlined, size: 14, color: OllivoTheme.oliveEmerald),
                            label: const Text(
                              'Open in Full Chat',
                              style: TextStyle(fontSize: 12, color: OllivoTheme.oliveEmerald),
                            ),
                            onPressed: () {
                              final p = _lastPrompt;
                              final r = _currentResponse;
                              Navigator.of(context).pop();
                              widget.onOpenInChat!(p, r);
                            },
                          ),
                      ],
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _promptController.clear();
                          _currentResponse = '';
                          _errorMessage = null;
                        });
                        _focusNode.requestFocus();
                      },
                      child: const Text('Clear', style: TextStyle(fontSize: 12, color: OllivoTheme.textSecondaryDark)),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Idle Tips
              const Divider(color: OllivoTheme.borderDark, height: 1),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_outline, size: 16, color: OllivoTheme.textSecondaryDark),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Press ⌘K anywhere to open Quick Ask. Instant answers without switching your current view.',
                        style: TextStyle(fontSize: 12, color: OllivoTheme.textSecondaryDark),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
