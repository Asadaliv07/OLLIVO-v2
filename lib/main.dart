import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'components/ollama_dashboard_dialog.dart';
import 'components/ollivo_components.dart';
import 'components/privacy_seal_dialog.dart';
import 'components/quick_ask_dialog.dart';
import 'components/shortcuts_sheet_dialog.dart';
import 'controllers/chat_controller.dart';
import 'controllers/model_controller.dart';
import 'services/ai_service.dart';
import 'services/database_service.dart';
import 'services/document_service.dart';
import 'services/memory_service.dart';
import 'services/model_config_service.dart';
import 'services/settings_service.dart';
import 'services/task_service.dart';
import 'theme.dart';
import 'views/chat/chat_view.dart';
import 'views/documents/documents_view.dart';
import 'views/memories/memory_center_view.dart';
import 'views/models/model_library_view.dart';
import 'views/settings/settings_view.dart';
import 'views/tasks/tasks_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settingsService = SettingsService();
  await settingsService.init();

  final dbService = DatabaseService();
  try {
    await dbService.init();
  } catch (_) {
    // Graceful fallback for environments without write permission
  }

  final modelConfigService = ModelConfigService(
    dbService: dbService,
    settingsService: settingsService,
  );
  try {
    await modelConfigService.init();
  } catch (_) {}

  final aiService = AIService(
    ollamaHost: settingsService.ollamaHost,
    modelName: settingsService.activeModel,
  );
  final memoryService = MemoryService(dbService: dbService);
  final documentService = DocumentService(dbService: dbService);
  final taskService = TaskService(dbService: dbService);

  final chatController = ChatController(
    aiService: aiService,
    dbService: dbService,
    memoryService: memoryService,
    documentService: documentService,
    settingsService: settingsService,
    modelConfigService: modelConfigService,
  );

  final modelController = ModelController(
    aiService: aiService,
    settingsService: settingsService,
  );

  // Preload conversations & indexed document RAG chunks
  try {
    await chatController.loadConversations(switchActive: true);
    await documentService.loadPersistedDocuments(
      embeddingModel: settingsService.activeModel,
      customHost: settingsService.ollamaHost,
    );
  } catch (_) {}

  runApp(OllivoApp(
    settingsService: settingsService,
    dbService: dbService,
    aiService: aiService,
    memoryService: memoryService,
    documentService: documentService,
    taskService: taskService,
    chatController: chatController,
    modelController: modelController,
    modelConfigService: modelConfigService,
  ));
}

class OllivoApp extends StatelessWidget {
  final SettingsService settingsService;
  final DatabaseService dbService;
  final AIService aiService;
  final MemoryService memoryService;
  final DocumentService documentService;
  final TaskService taskService;
  final ChatController chatController;
  final ModelController modelController;
  final ModelConfigService? modelConfigService;

  const OllivoApp({
    super.key,
    required this.settingsService,
    required this.dbService,
    required this.aiService,
    required this.memoryService,
    required this.documentService,
    required this.taskService,
    required this.chatController,
    required this.modelController,
    this.modelConfigService,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settingsService,
      builder: (context, child) {
        ThemeMode mode = ThemeMode.dark;
        if (settingsService.themeMode == 'light') mode = ThemeMode.light;
        if (settingsService.themeMode == 'system') mode = ThemeMode.system;

        return MaterialApp(
          title: 'OLLIVO v1 - Local macOS AI Assistant',
          debugShowCheckedModeBanner: false,
          theme: OllivoTheme.lightTheme,
          darkTheme: OllivoTheme.darkTheme,
          themeMode: mode,
          home: OllivoHomeScreen(
            settingsService: settingsService,
            dbService: dbService,
            aiService: aiService,
            memoryService: memoryService,
            documentService: documentService,
            taskService: taskService,
            chatController: chatController,
            modelController: modelController,
            modelConfigService: modelConfigService,
          ),
        );
      },
    );
  }
}

class OllivoHomeScreen extends StatefulWidget {
  final SettingsService settingsService;
  final DatabaseService dbService;
  final AIService aiService;
  final MemoryService memoryService;
  final DocumentService documentService;
  final TaskService taskService;
  final ChatController chatController;
  final ModelController modelController;
  final ModelConfigService? modelConfigService;

  const OllivoHomeScreen({
    super.key,
    required this.settingsService,
    required this.dbService,
    required this.aiService,
    required this.memoryService,
    required this.documentService,
    required this.taskService,
    required this.chatController,
    required this.modelController,
    this.modelConfigService,
  });

  @override
  State<OllivoHomeScreen> createState() => _OllivoHomeScreenState();
}

class _OllivoHomeScreenState extends State<OllivoHomeScreen> {
  int _selectedIndex = 0;
  bool _isSidebarVisible = true;
  final GlobalKey<DocumentsViewState> _documentsViewKey = GlobalKey<DocumentsViewState>();
  late final ModelConfigService _modelConfigService = widget.modelConfigService ??
      ModelConfigService(
        dbService: widget.dbService,
        settingsService: widget.settingsService,
      );

  final List<String> _navTitles = [
    'AI Assistant Chat',
    'Local Memory Center',
    'Documents & Local RAG',
    'Task Workspace',
    'Model Library',
    'Settings & Storage Locations',
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.settingsService.lastSelectedTab.clamp(0, _navTitles.length - 1);
    _isSidebarVisible = widget.settingsService.sidebarVisible;
  }

  void _selectTab(int index) {
    if (index >= 0 && index < _navTitles.length) {
      setState(() => _selectedIndex = index);
      widget.settingsService.setLastSelectedTab(index);
    }
  }

  void _toggleSidebar() {
    setState(() => _isSidebarVisible = !_isSidebarVisible);
    widget.settingsService.setSidebarVisible(_isSidebarVisible);
  }

  void _openDocumentImport() {
    _selectTab(2);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _documentsViewKey.currentState?.pickAndImportFile();
    });
  }

  void _openQuickAsk() {
    QuickAskDialog.show(
      context,
      aiService: widget.aiService,
      settingsService: widget.settingsService,
      onOpenInChat: (prompt, response) {
        _selectTab(0);
        widget.chatController.addCompletedExchange(prompt, response);
      },
    );
  }

  List<PlatformMenuItem> _buildPlatformMenus(BuildContext context) {
    return <PlatformMenuItem>[
      PlatformMenu(
        label: 'Ollivo',
        menus: <PlatformMenuItem>[
          PlatformMenuItem(
            label: 'About Ollivo',
            onSelected: () => _showAboutDialog(context),
          ),
          PlatformMenuItemGroup(
            members: <PlatformMenuItem>[
              PlatformMenuItem(
                label: 'Preferences...',
                shortcut: const SingleActivator(LogicalKeyboardKey.comma, meta: true),
                onSelected: () => _selectTab(5),
              ),
            ],
          ),
          if (PlatformProvidedMenuItem.hasMenu(PlatformProvidedMenuItemType.servicesSubmenu))
            const PlatformMenuItemGroup(
              members: <PlatformMenuItem>[
                PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.servicesSubmenu),
              ],
            ),
          if (PlatformProvidedMenuItem.hasMenu(PlatformProvidedMenuItemType.hide))
            PlatformMenuItemGroup(
              members: <PlatformMenuItem>[
                const PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.hide),
                if (PlatformProvidedMenuItem.hasMenu(PlatformProvidedMenuItemType.hideOtherApplications))
                  const PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.hideOtherApplications),
                if (PlatformProvidedMenuItem.hasMenu(PlatformProvidedMenuItemType.showAllApplications))
                  const PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.showAllApplications),
              ],
            ),
          if (PlatformProvidedMenuItem.hasMenu(PlatformProvidedMenuItemType.quit))
            const PlatformMenuItemGroup(
              members: <PlatformMenuItem>[
                PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.quit),
              ],
            ),
        ],
      ),
      PlatformMenu(
        label: 'File',
        menus: <PlatformMenuItem>[
          PlatformMenuItem(
            label: 'Quick Ask...',
            shortcut: const SingleActivator(LogicalKeyboardKey.keyK, meta: true),
            onSelected: _openQuickAsk,
          ),
          PlatformMenuItem(
            label: 'New Conversation',
            shortcut: const SingleActivator(LogicalKeyboardKey.keyN, meta: true),
            onSelected: () {
              _selectTab(0);
              widget.chatController.clearSession();
            },
          ),
          PlatformMenuItem(
            label: 'Clear Chat Session',
            shortcut: const SingleActivator(LogicalKeyboardKey.keyL, meta: true),
            onSelected: () {
              widget.chatController.clearSession();
            },
          ),
          PlatformMenuItem(
            label: 'Import Documents...',
            shortcut: const SingleActivator(LogicalKeyboardKey.keyO, meta: true),
            onSelected: _openDocumentImport,
          ),
        ],
      ),
      const PlatformMenu(
        label: 'Edit',
        menus: <PlatformMenuItem>[
          PlatformMenuItem(
            label: 'Undo',
            shortcut: SingleActivator(LogicalKeyboardKey.keyZ, meta: true),
          ),
          PlatformMenuItem(
            label: 'Redo',
            shortcut: SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true),
          ),
          PlatformMenuItemGroup(
            members: <PlatformMenuItem>[
              PlatformMenuItem(
                label: 'Cut',
                shortcut: SingleActivator(LogicalKeyboardKey.keyX, meta: true),
              ),
              PlatformMenuItem(
                label: 'Copy',
                shortcut: SingleActivator(LogicalKeyboardKey.keyC, meta: true),
              ),
              PlatformMenuItem(
                label: 'Paste',
                shortcut: SingleActivator(LogicalKeyboardKey.keyV, meta: true),
              ),
              PlatformMenuItem(
                label: 'Select All',
                shortcut: SingleActivator(LogicalKeyboardKey.keyA, meta: true),
              ),
            ],
          ),
        ],
      ),
      PlatformMenu(
        label: 'View',
        menus: <PlatformMenuItem>[
          PlatformMenuItem(
            label: 'Toggle Sidebar',
            shortcut: const SingleActivator(LogicalKeyboardKey.backslash, meta: true),
            onSelected: _toggleSidebar,
          ),
          PlatformMenuItemGroup(
            members: <PlatformMenuItem>[
              PlatformMenuItem(
                label: 'AI Chat',
                shortcut: const SingleActivator(LogicalKeyboardKey.digit1, meta: true),
                onSelected: () => _selectTab(0),
              ),
              PlatformMenuItem(
                label: 'Memory Center',
                shortcut: const SingleActivator(LogicalKeyboardKey.digit2, meta: true),
                onSelected: () => _selectTab(1),
              ),
              PlatformMenuItem(
                label: 'Documents & RAG',
                shortcut: const SingleActivator(LogicalKeyboardKey.digit3, meta: true),
                onSelected: () => _selectTab(2),
              ),
              PlatformMenuItem(
                label: 'Task Workspace',
                shortcut: const SingleActivator(LogicalKeyboardKey.digit4, meta: true),
                onSelected: () => _selectTab(3),
              ),
              PlatformMenuItem(
                label: 'Model Library',
                shortcut: const SingleActivator(LogicalKeyboardKey.digit5, meta: true),
                onSelected: () => _selectTab(4),
              ),
              PlatformMenuItem(
                label: 'Settings & Storage',
                shortcut: const SingleActivator(LogicalKeyboardKey.digit6, meta: true),
                onSelected: () => _selectTab(5),
              ),
            ],
          ),
        ],
      ),
      if (PlatformProvidedMenuItem.hasMenu(PlatformProvidedMenuItemType.minimizeWindow) ||
          PlatformProvidedMenuItem.hasMenu(PlatformProvidedMenuItemType.zoomWindow))
        PlatformMenu(
          label: 'Window',
          menus: <PlatformMenuItem>[
            if (PlatformProvidedMenuItem.hasMenu(PlatformProvidedMenuItemType.minimizeWindow))
              const PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.minimizeWindow),
            if (PlatformProvidedMenuItem.hasMenu(PlatformProvidedMenuItemType.zoomWindow))
              const PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.zoomWindow),
          ],
        ),
      PlatformMenu(
        label: 'Help',
        menus: <PlatformMenuItem>[
          PlatformMenuItem(
            label: 'Keyboard Shortcuts (⌘/)',
            shortcut: const SingleActivator(LogicalKeyboardKey.slash, meta: true),
            onSelected: () => _openShortcutsSheet(),
          ),
          PlatformMenuItem(
            label: '100% Local Privacy Seal',
            onSelected: () => _openPrivacySealDialog(),
          ),
          PlatformMenuItem(
            label: 'Security & Privacy Audit Log',
            onSelected: () => _selectTab(5),
          ),
          PlatformMenuItem(
            label: 'Check Ollama Daemon Status',
            onSelected: () => widget.modelController.refreshModels(),
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return PlatformMenuBar(
      menus: _buildPlatformMenus(context),
      child: Shortcuts(
        shortcuts: <LogicalKeySet, Intent>{
          LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyN): const _NewChatIntent(),
          LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyK): const _QuickAskIntent(),
          LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.shift, LogicalKeyboardKey.space): const _QuickAskIntent(),
          LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyL): const _ClearSessionIntent(),
          LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.comma): const _SettingsIntent(),
          LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.slash): const _ShortcutsSheetIntent(),
          LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyO): const _ImportDocumentsIntent(),
          LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.backslash): const _ToggleSidebarIntent(),
          LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.digit1): const _SelectTabIntent(0),
          LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.digit2): const _SelectTabIntent(1),
          LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.digit3): const _SelectTabIntent(2),
          LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.digit4): const _SelectTabIntent(3),
          LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.digit5): const _SelectTabIntent(4),
          LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.digit6): const _SelectTabIntent(5),
          LogicalKeySet(LogicalKeyboardKey.escape): const _EscapeIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            _NewChatIntent: CallbackAction<_NewChatIntent>(
              onInvoke: (_) {
                _selectTab(0);
                widget.chatController.clearSession();
                return null;
              },
            ),
            _QuickAskIntent: CallbackAction<_QuickAskIntent>(
              onInvoke: (_) {
                _openQuickAsk();
                return null;
              },
            ),
            _ClearSessionIntent: CallbackAction<_ClearSessionIntent>(
              onInvoke: (_) {
                widget.chatController.clearSession();
                return null;
              },
            ),
            _SettingsIntent: CallbackAction<_SettingsIntent>(
              onInvoke: (_) {
                _selectTab(5);
                return null;
              },
            ),
            _ShortcutsSheetIntent: CallbackAction<_ShortcutsSheetIntent>(
              onInvoke: (_) {
                _openShortcutsSheet();
                return null;
              },
            ),
            _ImportDocumentsIntent: CallbackAction<_ImportDocumentsIntent>(
              onInvoke: (_) {
                _openDocumentImport();
                return null;
              },
            ),
            _ToggleSidebarIntent: CallbackAction<_ToggleSidebarIntent>(
              onInvoke: (_) {
                _toggleSidebar();
                return null;
              },
            ),
            _SelectTabIntent: CallbackAction<_SelectTabIntent>(
              onInvoke: (intent) {
                _selectTab(intent.index);
                return null;
              },
            ),
            _EscapeIntent: CallbackAction<_EscapeIntent>(
              onInvoke: (_) {
                FocusManager.instance.primaryFocus?.unfocus();
                return null;
              },
            ),
          },
          child: Focus(
            autofocus: true,
            child: Scaffold(
              body: Row(
                children: [
                  if (_isSidebarVisible) _buildSidebar(),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          _buildDesktopTopBar(),
                          const SizedBox(height: 18),
                          Expanded(child: _buildSelectedView()),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopTopBar() {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.modelController, widget.settingsService]),
      builder: (context, child) {
        final isOnline = widget.modelController.isOllamaOnline;
        final activeModel = widget.settingsService.activeModel;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left: Breadcrumb Navigation & View Title
            Expanded(
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(_isSidebarVisible ? Icons.menu_open_rounded : Icons.menu_rounded, color: OllivoTheme.textSecondaryDark),
                    tooltip: _isSidebarVisible ? 'Hide Sidebar (⌘\\)' : 'Show Sidebar (⌘\\)',
                    onPressed: _toggleSidebar,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Ollivo',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.8,
                                color: OllivoTheme.textSecondaryDark.withValues(alpha: 0.7),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              '/',
                              style: TextStyle(
                                fontSize: 11,
                                color: OllivoTheme.borderDark,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _navTitles[_selectedIndex],
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.4,
                                color: OllivoTheme.mintPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _navTitles[_selectedIndex],
                          style: OllivoTheme.h1Style,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Center / Right Controls
            Flexible(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Spotlight-style Quick Ask ⌘K Trigger
                    TactileBounce(
                      onTap: _openQuickAsk,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 170, maxWidth: 220),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: OllivoTheme.cardDark,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: OllivoTheme.borderDark),
                          boxShadow: const [
                            BoxShadow(color: Color(0x22000000), blurRadius: 8, offset: Offset(0, 2)),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.search_rounded, size: 15, color: OllivoTheme.mintPrimary),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Quick Ask...',
                                style: TextStyle(fontSize: 12, color: OllivoTheme.textSecondaryDark, fontWeight: FontWeight.w400),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: OllivoTheme.cardElevatedDark,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: OllivoTheme.borderSubtle),
                              ),
                              child: const Text(
                                '⌘K',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: OllivoTheme.textSecondaryDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Active Model Quick-Switcher Dropdown (MOD-005)
                    PopupMenuButton<String>(
                      tooltip: 'Switch Active Model (MOD-005)',
                      color: OllivoTheme.surfaceDark,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: OllivoTheme.borderDark),
                      ),
                      offset: const Offset(0, 36),
                      onSelected: (modelName) async {
                        if (modelName == '__manage_models__') {
                          _selectTab(4); // Open Model Library
                        } else {
                          await widget.modelController.selectActiveModel(modelName);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Switched active model to $modelName'),
                                backgroundColor: OllivoTheme.mintPrimary,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        }
                      },
                      itemBuilder: (context) {
                        final installed = widget.modelController.installedModels;
                        final items = <PopupMenuEntry<String>>[];

                        items.add(
                          const PopupMenuItem<String>(
                            enabled: false,
                            child: Text(
                              'SWITCH ACTIVE AI MODEL',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                color: OllivoTheme.textSecondaryDark,
                              ),
                            ),
                          ),
                        );

                        if (installed.isEmpty) {
                          items.add(
                            const PopupMenuItem<String>(
                              enabled: false,
                              child: Text(
                                'No models installed yet',
                                style: TextStyle(fontSize: 13, color: OllivoTheme.textSecondaryDark),
                              ),
                            ),
                          );
                        } else {
                          for (final m in installed) {
                            final isCurrent = m.name == activeModel || activeModel.startsWith('${m.name}:');
                            final mem = ModelController.getMemoryGuidance(sizeBytes: m.size, modelId: m.name);

                            items.add(
                              PopupMenuItem<String>(
                                value: m.name,
                                child: Row(
                                  children: [
                                    Icon(
                                      isCurrent ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                                      size: 16,
                                      color: isCurrent ? OllivoTheme.mintPrimary : OllivoTheme.textSecondaryDark,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            m.name,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                              color: isCurrent ? Colors.white : OllivoTheme.textPrimaryDark,
                                            ),
                                          ),
                                          Text(
                                            '${m.formattedSize} • ${mem.label}',
                                            style: TextStyle(fontSize: 11, color: mem.color),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                        }

                        items.add(const PopupMenuDivider(height: 10));
                        items.add(
                          const PopupMenuItem<String>(
                            value: '__manage_models__',
                            child: Row(
                              children: [
                                Icon(Icons.extension_outlined, size: 16, color: OllivoTheme.mintPrimary),
                                SizedBox(width: 10),
                                Text(
                                  'Manage Models in Library...',
                                  style: TextStyle(fontSize: 12, color: OllivoTheme.mintPrimary, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        );

                        return items;
                      },
                      child: TactileBounce(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                          decoration: BoxDecoration(
                            color: OllivoTheme.cardDark,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: OllivoTheme.borderDark),
                            boxShadow: const [
                              BoxShadow(color: Color(0x22000000), blurRadius: 8, offset: Offset(0, 2)),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.memory_rounded, size: 14, color: OllivoTheme.mintPrimary),
                              const SizedBox(width: 6),
                              Text(
                                activeModel.isEmpty ? 'No Model Selected' : activeModel,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: OllivoTheme.mintPrimary),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: OllivoTheme.textSecondaryDark),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Consolidated Status Chip with Soft Glowing Indicator Dot
                    TactileBounce(
                      onTap: () {
                        OllamaDashboardDialog.show(
                          context,
                          controller: widget.modelController,
                          onOpenModelLibrary: () => _selectTab(4),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                        decoration: BoxDecoration(
                          color: OllivoTheme.cardDark,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isOnline
                                ? OllivoTheme.mintPrimary.withValues(alpha: 0.3)
                                : OllivoTheme.statusError.withValues(alpha: 0.3),
                          ),
                          boxShadow: const [
                            BoxShadow(color: Color(0x22000000), blurRadius: 8, offset: Offset(0, 2)),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: isOnline ? OllivoTheme.mintPrimary : OllivoTheme.statusError,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: (isOnline ? OllivoTheme.mintPrimary : OllivoTheme.statusError)
                                        .withValues(alpha: 0.6),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isOnline
                                  ? (widget.modelController.daemonLatencyMs != null
                                      ? 'Local Engine Active · ${widget.modelController.daemonLatencyMs}ms'
                                      : 'Local Engine Active')
                                  : 'Daemon Offline',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.1,
                                color: isOnline ? Colors.white : OllivoTheme.statusError,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Keyboard Shortcuts Sheet Button
                    TactileBounce(
                      onTap: _openShortcutsSheet,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: OllivoTheme.cardDark,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: OllivoTheme.borderDark),
                        ),
                        child: const Icon(Icons.keyboard_command_key_rounded, size: 16, color: OllivoTheme.textSecondaryDark),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 250,
      color: OllivoTheme.surfaceDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 16.0, right: 16.0, top: 20.0, bottom: 16.0),
            child: OllivoLogoHeader(height: 32, showWordmark: true),
          ),
          const Divider(color: OllivoTheme.borderDark, height: 1),
          const SizedBox(height: 12),
          _buildSidebarNavItem(0, Icons.chat_bubble_outline_rounded, 'AI Chat'),
          _buildSidebarNavItem(1, Icons.psychology_outlined, 'Memory Center'),
          _buildSidebarNavItem(2, Icons.folder_open_rounded, 'Documents & RAG'),
          _buildSidebarNavItem(3, Icons.task_alt_rounded, 'Task Workspace'),
          _buildSidebarNavItem(4, Icons.extension_outlined, 'Model Library'),
          _buildSidebarNavItem(5, Icons.tune_rounded, 'Settings & Storage'),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TactileBounce(
              onTap: () => _selectTab(5),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: OllivoTheme.cardDark,
                  borderRadius: BorderRadius.circular(OllivoTheme.radiusSm),
                  border: Border.all(color: OllivoTheme.borderDark),
                  boxShadow: const [
                    BoxShadow(color: Color(0x22000000), blurRadius: 8, offset: Offset(0, 2)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: OllivoTheme.mintPrimary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: OllivoTheme.mintPrimary.withValues(alpha: 0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Privacy & Engine Health',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '100% Offline · Zero Telemetry',
                            style: TextStyle(
                              fontSize: 10,
                              color: OllivoTheme.textSecondaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: OllivoTheme.textSecondaryDark,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarNavItem(int index, IconData icon, String label) {
    final bool isSelected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: TactileBounce(
        onTap: () => setState(() => _selectedIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? OllivoTheme.mintAccent.withValues(alpha: 0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(OllivoTheme.radiusSm),
            border: isSelected ? Border.all(color: OllivoTheme.mintAccent.withValues(alpha: 0.15)) : null,
          ),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 18,
                decoration: BoxDecoration(
                  color: isSelected ? OllivoTheme.mintPrimary : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: OllivoTheme.mintPrimary.withValues(alpha: 0.5),
                            blurRadius: 4,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                icon,
                color: isSelected ? OllivoTheme.mintPrimary : OllivoTheme.textSecondaryDark,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    letterSpacing: -0.1,
                    color: isSelected ? Colors.white : OllivoTheme.textSecondaryDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedView() {
    Widget view;
    switch (_selectedIndex) {
      case 0:
        view = ChatView(
          key: const ValueKey('view_chat'),
          chatController: widget.chatController,
          modelController: widget.modelController,
          taskService: widget.taskService,
        );
        break;
      case 1:
        view = MemoryCenterView(
          key: const ValueKey('view_memory'),
          memoryService: widget.memoryService,
        );
        break;
      case 2:
        view = DocumentsView(
          key: _documentsViewKey,
          documentService: widget.documentService,
          settingsService: widget.settingsService,
        );
        break;
      case 3:
        view = TasksView(
          key: const ValueKey('view_tasks'),
          taskService: widget.taskService,
          onAskOllivo: (prompt) {
            setState(() => _selectedIndex = 0);
            widget.chatController.sendUserPrompt(prompt);
          },
        );
        break;
      case 4:
        view = ModelLibraryView(
          key: const ValueKey('view_models'),
          controller: widget.modelController,
          modelConfigService: _modelConfigService,
          onOpenChat: (modelId) {
            setState(() => _selectedIndex = 0);
          },
        );
        break;
      case 5:
        view = SettingsView(
          key: const ValueKey('view_settings'),
          settingsService: widget.settingsService,
          modelController: widget.modelController,
          aiService: widget.aiService,
          databaseService: widget.dbService,
          modelConfigService: _modelConfigService,
        );
        break;
      default:
        view = ChatView(
          key: const ValueKey('view_default'),
          chatController: widget.chatController,
          modelController: widget.modelController,
          taskService: widget.taskService,
        );
    }

    return RepaintBoundary(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        switchInCurve: Curves.easeOutQuart,
        switchOutCurve: Curves.easeInQuart,
        transitionBuilder: (child, animation) {
          final slide = Tween<Offset>(
            begin: const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutQuart,
          ));
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: slide,
              child: child,
            ),
          );
        },
        child: view,
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: OllivoTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OllivoTheme.radiusMd),
          side: const BorderSide(color: OllivoTheme.borderDark),
        ),
        title: const Row(
          children: [
            OllivoLogoHeader(height: 28, showWordmark: true),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('OLLIVO v1 (v1.0.0)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            SizedBox(height: 8),
            Text(
              'A 100% private, local-first macOS desktop AI assistant powered by Ollama and on-device SQLite.',
              style: TextStyle(color: OllivoTheme.textSecondaryDark, fontSize: 13),
            ),
            SizedBox(height: 8),
            Text(
              'Architected for Apple Silicon and macOS desktop ergonomics.',
              style: TextStyle(color: OllivoTheme.textSecondaryDark, fontSize: 12),
            ),
          ],
        ),
        actions: [
          OllivoSecondaryButton(
            label: 'Close',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _openShortcutsSheet() {
    ShortcutsSheetDialog.show(context);
  }

  void _openPrivacySealDialog() {
    PrivacySealDialog.show(
      context,
      onInspectAuditLog: () => _selectTab(5),
    );
  }
}

class _NewChatIntent extends Intent {
  const _NewChatIntent();
}

class _QuickAskIntent extends Intent {
  const _QuickAskIntent();
}

class _ClearSessionIntent extends Intent {
  const _ClearSessionIntent();
}

class _SettingsIntent extends Intent {
  const _SettingsIntent();
}

class _ShortcutsSheetIntent extends Intent {
  const _ShortcutsSheetIntent();
}

class _ToggleSidebarIntent extends Intent {
  const _ToggleSidebarIntent();
}

class _SelectTabIntent extends Intent {
  final int index;
  const _SelectTabIntent(this.index);
}

class _EscapeIntent extends Intent {
  const _EscapeIntent();
}

class _ImportDocumentsIntent extends Intent {
  const _ImportDocumentsIntent();
}
