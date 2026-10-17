import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../components/ollivo_components.dart';
import '../../services/document_service.dart';
import '../../services/settings_service.dart';
import '../../theme.dart';

class DocumentsView extends StatefulWidget {
  final DocumentService documentService;
  final SettingsService settingsService;
  final List<DocumentItem>? initialDocuments;

  const DocumentsView({
    super.key,
    required this.documentService,
    required this.settingsService,
    this.initialDocuments,
  });

  @override
  State<DocumentsView> createState() => DocumentsViewState();
}

class DocumentsViewState extends State<DocumentsView> {
  List<DocumentItem> _documents = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialDocuments != null) {
      _documents = List.from(widget.initialDocuments!);
      _isLoading = false;
    } else {
      _loadDocuments();
    }
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);
    try {
      final docs = await widget.documentService.getDocuments();
      setState(() {
        _documents = docs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load documents: ${e.toString()}';
      });
    }
  }

  List<DocumentItem> get documents => List.unmodifiable(_documents);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Pick and import single or multiple documents for local RAG indexing
  Future<void> pickAndImportFile() async {
    setState(() {
      _errorMessage = null;
    });

    try {
      FilePickerResult? result;

      // 1. Attempt multi-extension custom file picking with both path & in-memory bytes
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
          dialogTitle: 'Select Documents for Ollivo Local RAG Indexing',
        );
      } catch (_) {
        // Fallback to FileType.any if custom types are restricted on OS
        result = await FilePicker.platform.pickFiles(
          type: FileType.any,
          allowMultiple: true,
          withData: true,
          dialogTitle: 'Select Documents for Ollivo Local RAG Indexing',
        );
      }

      if (result != null && result.files.isNotEmpty) {
        setState(() => _isLoading = true);
        int successCount = 0;

        for (final file in result.files) {
          try {
            if (file.path != null && file.path!.isNotEmpty) {
              await widget.documentService.importAndIndexDocument(
                file.path!,
                widget.settingsService.documentsPath,
              );
              successCount++;
            } else if (file.bytes != null && file.bytes!.isNotEmpty) {
              await widget.documentService.importAndIndexDocumentFromBytes(
                file.name,
                file.bytes!,
                widget.settingsService.documentsPath,
              );
              successCount++;
            }
          } catch (fileError) {
            // Continue processing remaining files if one fails
            debugPrint('Failed to import ${file.name}: $fileError');
          }
        }

        await _loadDocuments();

        if (mounted) {
          if (successCount > 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Successfully imported and indexed $successCount document(s) for local RAG!'),
                backgroundColor: OllivoTheme.oliveEmerald,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 3),
              ),
            );
          } else {
            setState(() {
              _errorMessage = 'Could not read chosen file(s). Please check permissions or try manual import.';
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error importing file: ${e.toString()}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import error: ${e.toString()}'),
            backgroundColor: OllivoTheme.statusError,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Manual Document Import modal allowing pasting text or typing a local path
  Future<void> _showManualImportModal() async {
    final titleController = TextEditingController(text: 'quick_notes.md');
    final contentController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => AlertDialog(
          backgroundColor: OllivoTheme.surfaceDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(OllivoTheme.radiusMd),
            side: const BorderSide(color: OllivoTheme.borderDark),
          ),
          title: const Row(
            children: [
              Icon(Icons.edit_note, color: OllivoTheme.oliveEmerald, size: 22),
              SizedBox(width: 8),
              Text('Create / Paste Document to Index'),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Paste text or Markdown notes directly into Ollivo to chunk and index for local AI search.',
                  style: TextStyle(fontSize: 12, color: OllivoTheme.textSecondaryDark),
                ),
                const SizedBox(height: 12),
                OllivoTextField(
                  controller: titleController,
                  labelText: 'DOCUMENT FILENAME',
                  hintText: 'e.g. project_spec.md, notes.txt',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentController,
                  maxLines: 8,
                  style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                  decoration: const InputDecoration(
                    labelText: 'DOCUMENT TEXT CONTENT',
                    hintText: 'Paste notes, code, documentation or requirements here...',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            OllivoSecondaryButton(label: 'Cancel', onPressed: () => Navigator.pop(dialogCtx)),
            OllivoPrimaryButton(
              label: 'Index Document',
              icon: Icons.check,
              onPressed: () async {
                final filename = titleController.text.trim().isEmpty ? 'imported_notes.md' : titleController.text.trim();
                final text = contentController.text.trim();
                if (text.isEmpty) return;

                Navigator.pop(dialogCtx);
                setState(() => _isLoading = true);
                try {
                  await widget.documentService.importAndIndexDocumentFromBytes(
                    filename,
                    utf8.encode(text),
                    widget.settingsService.documentsPath,
                  );
                  await _loadDocuments();
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Successfully indexed "$filename" into local RAG!'),
                        backgroundColor: OllivoTheme.oliveEmerald,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (err) {
                  if (mounted) {
                    setState(() {
                      _isLoading = false;
                      _errorMessage = 'Manual index error: $err';
                    });
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Quick 1-click Sample Document loader for instant RAG verification
  Future<void> _loadSampleDocument() async {
    setState(() => _isLoading = true);
    try {
      const sampleContent = '''
# Ollivo Local AI Workspace Architecture

## Overview
Ollivo is a 100% local-first macOS private AI workspace powered by Ollama and local SQLite.
All user conversations, long-term memory facts, and indexed documents remain exclusively on the user's physical machine.

## Key Subsystems
1. **Local LLM Inference Engine**: Communicates with Ollama daemon via localhost HTTP REST API (port 11434).
2. **Hybrid RAG Index**: Semantic sliding-window chunking (400 chars, 80 char overlap) with cosine similarity and keyword matching.
3. **Hardware Acceleration**: Optimized for Apple Silicon unified memory with Metal acceleration and zero telemetry.
4. **Offline Resilience**: Automatic graceful recovery when the local Ollama process is sleeping or terminated.
''';

      await widget.documentService.importAndIndexDocumentFromBytes(
        'Ollivo_Architecture_Spec.md',
        utf8.encode(sampleContent),
        widget.settingsService.documentsPath,
      );
      await _loadDocuments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Loaded sample architecture document into local RAG index!'),
            backgroundColor: OllivoTheme.oliveEmerald,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading sample document: $e';
      });
    }
  }

  Future<void> _deleteDocument(String id, String filename) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: OllivoTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OllivoTheme.radiusMd),
          side: const BorderSide(color: OllivoTheme.borderDark),
        ),
        title: const Text('Remove Document'),
        content: Text('Are you sure you want to remove "$filename" from Ollivo local index?'),
        actions: [
          OllivoSecondaryButton(label: 'Cancel', onPressed: () => Navigator.pop(context, false)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: OllivoTheme.statusError, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await widget.documentService.deleteDocument(id);
      await _loadDocuments();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_errorMessage != null) ...[
          OllivoBanner(
            title: 'Document Error',
            message: _errorMessage!,
            icon: Icons.error_outline,
            color: OllivoTheme.statusError,
          ),
          const SizedBox(height: 16),
        ],

        // RAG Workspace Configuration Bar (Section 8: Multi-KB & Embeddings)
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: OllivoTheme.surfaceDark,
            borderRadius: BorderRadius.circular(OllivoTheme.radiusSm),
            border: Border.all(color: OllivoTheme.borderDark),
          ),
          child: Row(
            children: [
              const Icon(Icons.dataset_outlined, color: OllivoTheme.mintPrimary, size: 20),
              const SizedBox(width: 10),
              const Text(
                'Knowledge Base:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: OllivoTheme.textSecondaryDark),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: OllivoTheme.cardDark,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: OllivoTheme.mintPrimary.withValues(alpha: 0.3)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: widget.settingsService.activeKnowledgeBase,
                    dropdownColor: OllivoTheme.surfaceDark,
                    style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600),
                    icon: const Icon(Icons.keyboard_arrow_down, color: OllivoTheme.mintPrimary, size: 18),
                    isDense: true,
                    items: const [
                      DropdownMenuItem(value: 'default', child: Text('General Workspace (Default)')),
                      DropdownMenuItem(value: 'research', child: Text('Research & Papers')),
                      DropdownMenuItem(value: 'codebase', child: Text('Codebase & API Specs')),
                      DropdownMenuItem(value: 'operations', child: Text('Operations & Logs')),
                    ],
                    onChanged: (newKb) {
                      if (newKb != null) {
                        widget.settingsService.setActiveKnowledgeBase(newKb);
                        setState(() {});
                      }
                    },
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: OllivoTheme.mintAccent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: OllivoTheme.mintPrimary.withValues(alpha: 0.2)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.hub_outlined, color: OllivoTheme.mintPrimary, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'Embedding Model: nomic-embed-text (768-dim)',
                      style: TextStyle(fontSize: 11.5, color: OllivoTheme.mintPrimary, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Header Action Bar
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 850;
            return isNarrow
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.folder_open_outlined, color: OllivoTheme.oliveEmerald, size: 22),
                          const SizedBox(width: 10),
                          Text(
                            'Indexed Documents (${_documents.length})',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            OllivoSecondaryButton(
                              label: 'Paste / Write Note',
                              icon: Icons.edit_note,
                              onPressed: _showManualImportModal,
                            ),
                            const SizedBox(width: 8),
                            OllivoSecondaryButton(
                              label: 'Add Sample Doc',
                              icon: Icons.auto_awesome,
                              onPressed: _loadSampleDocument,
                            ),
                            const SizedBox(width: 8),
                            OllivoPrimaryButton(
                              label: 'Import Document',
                              icon: Icons.add_to_photos_outlined,
                              onPressed: pickAndImportFile,
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.folder_open_outlined, color: OllivoTheme.oliveEmerald, size: 22),
                          const SizedBox(width: 10),
                          Text(
                            'Indexed Documents (${_documents.length})',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Flexible(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              OllivoSecondaryButton(
                                label: 'Paste / Write Note',
                                icon: Icons.edit_note,
                                onPressed: _showManualImportModal,
                              ),
                              const SizedBox(width: 8),
                              OllivoSecondaryButton(
                                label: 'Add Sample Doc',
                                icon: Icons.auto_awesome,
                                onPressed: _loadSampleDocument,
                              ),
                              const SizedBox(width: 8),
                              OllivoPrimaryButton(
                                label: 'Import Document',
                                icon: Icons.add_to_photos_outlined,
                                onPressed: pickAndImportFile,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
          },
        ),
        const SizedBox(height: 16),

        // Main Document Table / List
        Expanded(
          child: _isLoading
              ? const OllivoLoadingIndicator(label: 'Indexing documents...')
              : _documents.isEmpty
                  ? OllivoCard(
                      child: OllivoEmptyState(
                        icon: Icons.folder_open_outlined,
                        title: 'No documents imported yet',
                        description: 'Select Markdown (.md), PDF (.pdf), Text (.txt), or Code files to index for offline AI Q&A.',
                        actionLabel: 'Select & Import File',
                        onAction: pickAndImportFile,
                      ),
                    )
                  : ListView.builder(
                      itemCount: _documents.length,
                      itemBuilder: (context, index) {
                        final doc = _documents[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: OllivoCard(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: OllivoTheme.oliveEmerald.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.description, color: OllivoTheme.oliveEmerald),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        doc.filename,
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Path: ${doc.filePath}',
                                        style: const TextStyle(fontSize: 12, color: OllivoTheme.textSecondaryDark, fontFamily: 'monospace'),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: OllivoTheme.borderDark,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '${doc.chunkCount} Chunks',
                                              style: const TextStyle(fontSize: 11, color: OllivoTheme.oliveEmerald),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            doc.formattedSize,
                                            style: const TextStyle(fontSize: 12, color: OllivoTheme.textSecondaryDark),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.layers_outlined, color: OllivoTheme.oliveEmerald),
                                  tooltip: 'Inspect Chunks',
                                  onPressed: () => _showChunkVisualizer(doc),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: OllivoTheme.statusError),
                                  tooltip: 'Delete Document',
                                  onPressed: () => _deleteDocument(doc.id, doc.filename),
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

  void _showChunkVisualizer(DocumentItem doc) {
    final chunks = widget.documentService.getChunksForDocument(doc.id);
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
            const Icon(Icons.layers_outlined, color: OllivoTheme.oliveEmerald, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Chunk Visualizer: ${doc.filename}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 550,
          height: 400,
          child: chunks.isEmpty
              ? const Center(
                  child: Text(
                    'No chunks indexed for this document in active session.',
                    style: TextStyle(color: OllivoTheme.textSecondaryDark),
                  ),
                )
              : ListView.builder(
                  itemCount: chunks.length,
                  itemBuilder: (cContext, idx) {
                    final chunk = chunks[idx];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: OllivoTheme.cardDark,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: OllivoTheme.borderDark),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: OllivoTheme.oliveEmerald.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Chunk #${chunk.chunkIndex + 1}',
                                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: OllivoTheme.oliveEmerald),
                                    ),
                                  ),
                                  if (chunk.embedding != null) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: OllivoTheme.mintAccent.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Dense Vector (${chunk.embedding!.length}-dim)',
                                        style: const TextStyle(fontSize: 9.5, color: OllivoTheme.mintPrimary),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              Text(
                                '${chunk.text.length} chars • ~${(chunk.text.length / 4).round()} tokens',
                                style: const TextStyle(fontSize: 10.5, color: OllivoTheme.textSecondaryDark),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            chunk.text,
                            style: const TextStyle(fontSize: 12, height: 1.4, color: OllivoTheme.textPrimaryDark),
                            maxLines: 6,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  },
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
