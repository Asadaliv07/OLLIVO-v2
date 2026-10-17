import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../components/markdown_view.dart';
import '../../components/ollivo_components.dart';
import '../../controllers/chat_controller.dart';
import '../../controllers/model_controller.dart';
import '../../models/mock_data.dart';
import '../../models/prompt_template.dart';
import '../../services/task_service.dart';
import '../../theme.dart';
import '../settings/model_config_dialog.dart';

class ChatView extends StatefulWidget {
  final ChatController chatController;
  final ModelController modelController;
  final TaskService? taskService;

  const ChatView({
    super.key,
    required this.chatController,
    required this.modelController,
    this.taskService,
  });

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  bool _isPinnedToBottom = true;
  bool _showScrollToBottomButton = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    widget.chatController.addListener(_onChatControllerUpdate);
  }

  @override
  void didUpdateWidget(ChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chatController != widget.chatController) {
      oldWidget.chatController.removeListener(_onChatControllerUpdate);
      widget.chatController.addListener(_onChatControllerUpdate);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    widget.chatController.removeListener(_onChatControllerUpdate);
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    final distanceFromBottom = maxScroll - currentScroll;

    // Pin threshold: user within 40px of bottom extent is pinned
    final isAtBottom = distanceFromBottom <= 40;

    if (isAtBottom != _isPinnedToBottom || (!isAtBottom) != _showScrollToBottomButton) {
      setState(() {
        _isPinnedToBottom = isAtBottom;
        _showScrollToBottomButton = !isAtBottom;
      });
    }
  }

  void _onChatControllerUpdate() {
    if (!mounted) return;
    if (_isPinnedToBottom && _scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients || !_isPinnedToBottom) return;
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      });
    }
  }

  void _scrollToBottom() {
    setState(() {
      _isPinnedToBottom = true;
      _showScrollToBottomButton = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _sendMessage([String? customText]) {
    final text = customText ?? _inputController.text.trim();
    if (text.isEmpty || widget.chatController.isGenerating) return;

    _inputController.clear();
    widget.chatController.sendUserPrompt(text);
    _scrollToBottom();
  }

  Future<void> _attachAndImportDocument() async {
    try {
      FilePickerResult? result;
      try {
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: [
            'txt', 'md', 'markdown', 'dart', 'json', 'csv', 'py', 'js',
            'ts', 'tsx', 'jsx', 'html', 'css', 'pdf', 'yaml', 'yml',
            'sh', 'sql', 'c', 'cpp', 'h', 'swift', 'kt', 'java', 'go',
            'rs', 'log', 'xml', 'rst'
          ],
          allowMultiple: true,
          withData: true,
          dialogTitle: 'Attach Documents for Ollivo Local RAG',
        );
      } catch (_) {
        result = await FilePicker.platform.pickFiles(
          type: FileType.any,
          allowMultiple: true,
          withData: true,
          dialogTitle: 'Attach Documents for Ollivo Local RAG',
        );
      }

      if (result != null && result.files.isNotEmpty) {
        final docService = widget.chatController.documentService;
        final docPath = widget.chatController.settingsService.documentsPath;
        final importedNames = <String>[];

        for (final file in result.files) {
          try {
            if (file.path != null && file.path!.isNotEmpty) {
              await docService.importAndIndexDocument(file.path!, docPath);
              importedNames.add(file.name);
            } else if (file.bytes != null && file.bytes!.isNotEmpty) {
              await docService.importAndIndexDocumentFromBytes(file.name, file.bytes!, docPath);
              importedNames.add(file.name);
            }
          } catch (err) {
            debugPrint('Failed to attach ${file.name}: $err');
          }
        }

        if (mounted && importedNames.isNotEmpty) {
          final joinedNames = importedNames.join(', ');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Attached & indexed "$joinedNames" into Local RAG!'),
              backgroundColor: OllivoTheme.oliveEmerald,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
          if (_inputController.text.trim().isEmpty) {
            _inputController.text = 'Summarize key points from ${importedNames.first}';
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to attach document: $e'),
            backgroundColor: OllivoTheme.statusError,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _showPromptTemplatesDialog() async {
    PromptTemplate selectedTemplate = PromptTemplate.defaultTemplates.first;
    final Map<String, TextEditingController> variableControllers = {};

    void initControllers(PromptTemplate t) {
      variableControllers.forEach((_, c) => c.dispose());
      variableControllers.clear();
      for (final v in t.variables) {
        variableControllers[v] = TextEditingController();
      }
    }

    initControllers(selectedTemplate);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: OllivoTheme.surfaceDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(OllivoTheme.radiusMd),
              side: const BorderSide(color: OllivoTheme.borderDark),
            ),
            title: const Row(
              children: [
                Icon(Icons.auto_stories, color: OllivoTheme.oliveEmerald, size: 22),
                SizedBox(width: 8),
                Text('Quick Prompt Templates'),
              ],
            ),
            content: SizedBox(
              width: 540,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select a structured template and populate dynamic slot variables:',
                      style: TextStyle(fontSize: 13, color: OllivoTheme.textSecondaryDark),
                    ),
                    const SizedBox(height: 12),
                    // Template selection chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: PromptTemplate.defaultTemplates.map((t) {
                          final isSel = selectedTemplate.id == t.id;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Text(t.title),
                              selected: isSel,
                              selectedColor: OllivoTheme.oliveEmerald,
                              backgroundColor: OllivoTheme.cardDark,
                              labelStyle: TextStyle(
                                color: isSel ? OllivoTheme.onyxDark : Colors.white,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                fontSize: 12,
                              ),
                              side: BorderSide(color: isSel ? OllivoTheme.oliveEmerald : OllivoTheme.borderDark),
                              onSelected: (val) {
                                if (val) {
                                  setDialogState(() {
                                    selectedTemplate = t;
                                    initControllers(t);
                                  });
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: OllivoTheme.cardDark,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: OllivoTheme.borderDark),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 16, color: OllivoTheme.oliveEmerald),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              selectedTemplate.description,
                              style: const TextStyle(fontSize: 12, color: OllivoTheme.textSecondaryDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Slot Variables:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: OllivoTheme.oliveEmerald)),
                    const SizedBox(height: 8),
                    // Variable inputs
                    ...selectedTemplate.variables.map((variable) {
                      final isMultiLine = variable == 'code' || variable == 'context' || variable == 'document_text';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: TextField(
                          controller: variableControllers[variable],
                          maxLines: isMultiLine ? 3 : 1,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            labelText: variable.replaceAll('_', ' ').toUpperCase(),
                            hintText: 'Enter $variable...',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            actions: [
              OllivoSecondaryButton(label: 'Cancel', onPressed: () => Navigator.pop(ctx)),
              OllivoSecondaryButton(
                label: 'Insert into Input',
                icon: Icons.input,
                onPressed: () {
                  final values = <String, String>{};
                  for (final entry in variableControllers.entries) {
                    values[entry.key] = entry.value.text.trim();
                  }
                  final prompt = selectedTemplate.interpolate(values);
                  Navigator.pop(ctx);
                  setState(() {
                    _inputController.text = prompt;
                  });
                },
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: OllivoTheme.oliveEmerald,
                  foregroundColor: OllivoTheme.onyxDark,
                ),
                icon: const Icon(Icons.send, size: 16),
                label: const Text('Send Prompt'),
                onPressed: () {
                  final values = <String, String>{};
                  for (final entry in variableControllers.entries) {
                    values[entry.key] = entry.value.text.trim();
                  }
                  final prompt = selectedTemplate.interpolate(values);
                  Navigator.pop(ctx);
                  _sendMessage(prompt);
                },
              ),
            ],
          );
        },
      ),
    );

    variableControllers.forEach((_, c) => c.dispose());
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.chatController, widget.modelController]),
      builder: (context, child) {
        final isOnline = widget.modelController.isOllamaOnline;
        final activeModel = widget.modelController.activeModel;
        final messages = widget.chatController.messages;
        final isGenerating = widget.chatController.isGenerating;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Connection Error Alert Banner (if disconnected)
            if (!isOnline) ...[
              OllivoBanner(
                title: 'Local Ollama Service Offline',
                message: widget.modelController.errorMessage ?? 'Cannot connect to Ollama at 127.0.0.1:11434. Make sure Ollama daemon is running.',
                icon: Icons.warning_amber_rounded,
                color: OllivoTheme.statusError,
                action: OllivoPrimaryButton(
                  label: widget.modelController.isRecoveringDaemon ? 'Starting...' : 'Start Ollama',
                  icon: Icons.play_arrow_rounded,
                  isLoading: widget.modelController.isRecoveringDaemon,
                  onPressed: widget.modelController.isRecoveringDaemon
                      ? null
                      : () async {
                          final res = await widget.modelController.launchOrRecoverOllama();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(res.message),
                              backgroundColor: res.success ? OllivoTheme.oliveEmerald : OllivoTheme.statusError,
                            ),
                          );
                        },
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Fact Memory Notification Banner
            if (widget.chatController.recentSavedMemory != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: OllivoTheme.oliveEmerald.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(OllivoTheme.radiusMd),
                  border: Border.all(color: OllivoTheme.oliveEmerald.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.psychology, color: OllivoTheme.oliveEmerald, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.chatController.recentSavedMemory!,
                        style: const TextStyle(
                          color: OllivoTheme.oliveEmerald,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16, color: OllivoTheme.oliveEmerald),
                      onPressed: widget.chatController.clearSavedMemoryBanner,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Header Row (Session & Active Model Indicator)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline, color: OllivoTheme.oliveEmerald, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      widget.chatController.activeConversationTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: OllivoTheme.textPrimaryDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    TactileBounce(
                      onTap: () {
                        if (activeModel.isNotEmpty) {
                          ModelConfigDialog.show(
                            context,
                            modelId: activeModel,
                            modelConfigService: widget.chatController.modelConfigService,
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: OllivoTheme.cardDark,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: OllivoTheme.borderDark),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.memory, size: 12, color: OllivoTheme.oliveEmerald),
                            const SizedBox(width: 6),
                            Text(
                              activeModel.isEmpty ? 'No Model Selected' : activeModel,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: OllivoTheme.oliveEmerald),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.tune_rounded, size: 12, color: OllivoTheme.mintPrimary),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OllivoSecondaryButton(
                      label: 'Templates',
                      icon: Icons.auto_stories,
                      onPressed: _showPromptTemplatesDialog,
                    ),
                    const SizedBox(width: 8),
                    if (isGenerating)
                      OllivoSecondaryButton(
                        label: 'Stop Generation',
                        icon: Icons.stop_circle_outlined,
                        onPressed: widget.chatController.stopGeneration,
                      )
                    else
                      OllivoSecondaryButton(
                        label: 'New Session',
                        icon: Icons.refresh,
                        onPressed: widget.chatController.clearSession,
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Messages Stream Container
            Expanded(
              child: OllivoCard(
                padding: const EdgeInsets.all(OllivoTheme.spaceMd),
                child: messages.isEmpty
                    ? OllivoEmptyState(
                        icon: Icons.chat_bubble_outline,
                        title: 'How can Ollivo help you today?',
                        description: 'Ask questions, save decisions to local vector memory, or interrogate project notes.',
                        actionLabel: 'New Session',
                        onAction: widget.chatController.clearSession,
                      )
                    : Stack(
                        children: [
                          ListView.builder(
                        controller: _scrollController,
                        itemCount: messages.length + (isGenerating ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == messages.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12.0),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(OllivoTheme.oliveEmerald),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Ollivo AI is thinking locally...',
                                    style: TextStyle(
                                      color: OllivoTheme.textSecondaryDark,
                                      fontSize: 13,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          final msg = messages[index];
                          final bool isUser = msg['role'] == 'user';

                          return Align(
                            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 650),
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isUser ? OllivoTheme.cardDark : OllivoTheme.surfaceDark,
                                borderRadius: BorderRadius.circular(OllivoTheme.radiusMd),
                                border: Border.all(
                                  color: isUser
                                      ? OllivoTheme.oliveEmerald.withValues(alpha: 0.3)
                                      : OllivoTheme.borderDark,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isUser ? Icons.person_outline : Icons.auto_awesome,
                                        size: 14,
                                        color: OllivoTheme.oliveEmerald,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        isUser ? 'You' : 'Ollivo AI ($activeModel)',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: OllivoTheme.textSecondaryDark,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        msg['timestamp'] ?? '',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: OllivoTheme.textSecondaryDark,
                                        ),
                                      ),
                                      if (msg['isMemorySaved'] == true) ...[
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: OllivoTheme.oliveEmerald.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.psychology, size: 10, color: OllivoTheme.oliveEmerald),
                                              SizedBox(width: 4),
                                              Text(
                                                'MEMORY SAVED',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: OllivoTheme.oliveEmerald,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  RichMarkdownView(
                                    markdown: msg['content'] ?? '',
                                    isUser: isUser,
                                  ),
                                  if (!isUser && msg['citations'] != null && (msg['citations'] as List).isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    _buildCitationsSection(context, msg['citations'] as List),
                                  ],
                                  if (!isUser) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        if (msg['metrics'] != null)
                                          Builder(builder: (context) {
                                            final metrics = msg['metrics'] as Map<String, dynamic>;
                                            final tps = metrics['tokensPerSecond'] ?? 0.0;
                                            final tokens = metrics['totalTokens'] ?? 0;
                                            final durationSec = ((metrics['durationMs'] as int? ?? 0) / 1000.0).toStringAsFixed(1);
                                            final ttft = metrics['firstTokenMs'] ?? 0;
                                            final isStreaming = metrics['isStreaming'] == true;

                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: OllivoTheme.cardDark,
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: OllivoTheme.borderDark),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    isStreaming ? Icons.bolt : Icons.speed_rounded,
                                                    size: 13,
                                                    color: OllivoTheme.oliveEmerald,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '$tps tok/s • $tokens tokens • ${durationSec}s • TTFT: ${ttft}ms',
                                                    style: const TextStyle(
                                                      fontSize: 10.5,
                                                      fontFamily: 'monospace',
                                                      color: OllivoTheme.textSecondaryDark,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          })
                                        else
                                          const SizedBox.shrink(),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Builder(builder: (ctx) {
                                              final parsedTasks = TaskService.parseTasksFromText(msg['content'] ?? '');
                                              if (parsedTasks.isEmpty) return const SizedBox.shrink();
                                              return IconButton(
                                                icon: const Icon(Icons.playlist_add_check_rounded, size: 16, color: OllivoTheme.oliveEmerald),
                                                tooltip: 'Add ${parsedTasks.length} action items to Tasks',
                                                onPressed: () async {
                                                  final taskService = widget.taskService ?? TaskService();
                                                  await taskService.batchCreateTasks(parsedTasks);
                                                  if (!context.mounted) return;
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text('Added ${parsedTasks.length} action items to your Task Manager!'),
                                                      backgroundColor: OllivoTheme.oliveEmerald,
                                                      duration: const Duration(seconds: 2),
                                                    ),
                                                  );
                                                },
                                              );
                                            }),
                                            IconButton(
                                              icon: const Icon(Icons.copy, size: 14, color: OllivoTheme.textSecondaryDark),
                                              tooltip: 'Copy text',
                                              onPressed: () {
                                                Clipboard.setData(ClipboardData(text: msg['content'] ?? ''));
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text('Copied to clipboard'),
                                                    duration: Duration(seconds: 1),
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      if (_showScrollToBottomButton)
                        Positioned(
                          right: 16,
                          bottom: 12,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              key: const Key('scrollToBottomButton'),
                              onTap: _scrollToBottom,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: OllivoTheme.cardDark,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: OllivoTheme.oliveEmerald.withValues(alpha: 0.6), width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.arrow_downward, size: 14, color: OllivoTheme.oliveEmerald),
                                    SizedBox(width: 6),
                                    Text(
                                      'Scroll to latest',
                                      style: TextStyle(
                                        color: OllivoTheme.oliveEmerald,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
              ),
            ),
            const SizedBox(height: 16),

            // Starter Chips (show if <= 1 message)
            if (messages.length <= 1) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: OllivoMockData.starterPrompts.map((starter) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ActionChip(
                        avatar: const Icon(Icons.lightbulb_outline, size: 14, color: OllivoTheme.oliveEmerald),
                        label: Text(starter['title']!),
                        backgroundColor: OllivoTheme.cardDark,
                        side: const BorderSide(color: OllivoTheme.borderDark),
                        onPressed: () => _sendMessage(starter['prompt']),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Input Row
            Row(
              children: [
                Expanded(
                  child: CallbackShortcuts(
                    bindings: <ShortcutActivator, VoidCallback>{
                      const SingleActivator(LogicalKeyboardKey.enter): () {
                        if (!HardwareKeyboard.instance.isShiftPressed) {
                          _sendMessage();
                        }
                      },
                    },
                    child: OllivoTextField(
                      controller: _inputController,
                      hintText: isOnline
                          ? 'Ask Ollivo or type a preference to remember... (Enter to send, Shift+Enter for newline)'
                          : 'Ollama is offline. Reconnect Ollama to chat.',
                      onSubmitted: (_) => _sendMessage(),
                      prefixIcon: IconButton(
                        icon: const Icon(Icons.attach_file, color: OllivoTheme.textSecondaryDark, size: 20),
                        tooltip: 'Import & Attach Document for Local RAG',
                        onPressed: _attachAndImportDocument,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.send, color: OllivoTheme.oliveEmerald),
                        onPressed: isOnline ? () => _sendMessage() : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OllivoPrimaryButton(
                  label: 'Send',
                  icon: Icons.send,
                  isLoading: isGenerating,
                  onPressed: isOnline ? () => _sendMessage() : null,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildCitationsSection(BuildContext context, List citations) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: OllivoTheme.cardDark,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: OllivoTheme.oliveEmerald.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.menu_book_rounded, size: 13, color: OllivoTheme.oliveEmerald),
              const SizedBox(width: 6),
              const Text(
                'Sources & Citations',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: OllivoTheme.oliveEmerald,
                ),
              ),
              const Spacer(),
              Text(
                '${citations.length} document references',
                style: const TextStyle(fontSize: 10, color: OllivoTheme.textSecondaryDark),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: citations.map((c) {
              final map = c as Map<String, dynamic>;
              final filename = map['filename'] ?? 'Document';
              final score = map['formattedScore'] ?? '';
              final chunkIdx = (map['chunkIndex'] as int? ?? 0) + 1;

              return InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: () => _showCitationDetailsDialog(context, map),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: OllivoTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: OllivoTheme.borderDark),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.description_outlined, size: 11, color: OllivoTheme.textSecondaryDark),
                      const SizedBox(width: 4),
                      Text(
                        '$filename #$chunkIdx',
                        style: const TextStyle(fontSize: 11, color: OllivoTheme.textPrimaryDark),
                      ),
                      if (score.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Text(
                          '($score)',
                          style: const TextStyle(fontSize: 10, color: OllivoTheme.oliveEmerald, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _showCitationDetailsDialog(BuildContext context, Map<String, dynamic> citation) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OllivoTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OllivoTheme.radiusMd),
          side: const BorderSide(color: OllivoTheme.borderDark),
        ),
        title: Row(
          children: [
            const Icon(Icons.source_rounded, color: OllivoTheme.oliveEmerald, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${citation['filename']} (Chunk #${(citation['chunkIndex'] as int? ?? 0) + 1})',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (citation['formattedScore'] != null) ...[
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: OllivoTheme.oliveEmerald.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Relevance: ${citation['formattedScore']}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: OllivoTheme.oliveEmerald,
                        ),
                      ),
                    ),
                    if (citation['vectorSimilarity'] != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        'Cosine: ${(citation['vectorSimilarity'] as double).toStringAsFixed(3)}',
                        style: const TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark, fontFamily: 'monospace'),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
              ],
              const Text(
                'Retrieved Excerpt:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: OllivoTheme.textSecondaryDark),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                constraints: const BoxConstraints(maxHeight: 250),
                decoration: BoxDecoration(
                  color: OllivoTheme.cardDark,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: OllivoTheme.borderDark),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    citation['text'] ?? '',
                    style: const TextStyle(fontSize: 13, height: 1.4, color: OllivoTheme.textPrimaryDark),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          OllivoPrimaryButton(
            label: 'Close',
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }
}
