import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../components/ollivo_components.dart';
import '../../controllers/model_controller.dart';
import '../../services/ai_service.dart';
import '../../services/audit_service.dart';
import '../../services/backup_service.dart';
import '../../services/database_service.dart';
import '../../services/model_config_service.dart';
import '../../services/settings_service.dart';
import '../../theme.dart';
import 'model_config_dialog.dart';

/// Item descriptor for navigation sidebar in the Settings Center
class _SettingsSectionItem {
  final int index;
  final String title;
  final String description;
  final IconData icon;

  const _SettingsSectionItem({
    required this.index,
    required this.title,
    required this.description,
    required this.icon,
  });
}

/// Comprehensive native macOS Settings Center for Ollivo
class SettingsView extends StatefulWidget {
  final SettingsService settingsService;
  final ModelController modelController;
  final AIService aiService;
  final DatabaseService databaseService;
  final ModelConfigService? modelConfigService;
  final int? initialDbSizeBytes;
  final Map<String, int>? initialTableCounts;
  final int initialTabIndex;

  const SettingsView({
    super.key,
    required this.settingsService,
    required this.modelController,
    required this.aiService,
    required this.databaseService,
    this.modelConfigService,
    this.initialDbSizeBytes,
    this.initialTableCounts,
    this.initialTabIndex = 0,
  });

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  int _selectedSection = 0;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _systemPromptController = TextEditingController();
  final TextEditingController _airllmHostController = TextEditingController();
  final TextEditingController _airllmModelController = TextEditingController();
  final TextEditingController _airllmShardsController = TextEditingController();

  late final BackupService _backupService;
  Map<String, dynamic>? _connectionDiagnostic;
  bool _isTestingConnection = false;
  Map<String, dynamic>? _airllmConnectionDiagnostic;
  bool _isTestingAirLLMConnection = false;
  bool _isManagingAirLLMDaemon = false;
  bool _isLoadingAirLLMModel = false;
  bool _isBackingUp = false;
  bool _isRestoring = false;
  String? _statusMessage;
  bool _isSuccess = true;

  int? _dbSizeBytes;
  Map<String, int>? _tableCounts;
  bool _isLoadingDbStats = false;
  bool _isVacuuming = false;
  String? _integrityCheckResult;

  static const List<_SettingsSectionItem> _sections = [
    _SettingsSectionItem(
      index: 0,
      title: 'General',
      description: 'Startup behavior, session restore, title generation, and safety prompts.',
      icon: Icons.settings_suggest_rounded,
    ),
    _SettingsSectionItem(
      index: 1,
      title: 'Appearance & UI',
      description: 'Theme modes, accent palette, interface density, typography, and statistics.',
      icon: Icons.palette_outlined,
    ),
    _SettingsSectionItem(
      index: 2,
      title: 'Chat & Response',
      description: 'Global generation defaults, sampling sliders, and auto-scroll behavior.',
      icon: Icons.chat_bubble_outline_rounded,
    ),
    _SettingsSectionItem(
      index: 3,
      title: 'Runtime & Engine',
      description: 'Ollama local server connectivity, keep-alive policies, and timeout bounds.',
      icon: Icons.tune_rounded,
    ),
    _SettingsSectionItem(
      index: 4,
      title: 'Performance & Hardware',
      description: 'Apple Silicon Metal telemetry, memory pressure relief, and profiling.',
      icon: Icons.speed_rounded,
    ),
    _SettingsSectionItem(
      index: 5,
      title: 'Storage & Downloads',
      description: 'Local directory locations, SQLite database maintenance, and backups.',
      icon: Icons.folder_open_rounded,
    ),
    _SettingsSectionItem(
      index: 6,
      title: 'Knowledge & RAG',
      description: 'Local vector store indexing, chunking parameters, and citation injection.',
      icon: Icons.auto_stories_outlined,
    ),
    _SettingsSectionItem(
      index: 7,
      title: 'Multimodal Processing',
      description: 'Image understanding, Apple Vision OCR, and media file retention policies.',
      icon: Icons.photo_library_outlined,
    ),
    _SettingsSectionItem(
      index: 8,
      title: 'Privacy & Security',
      description: 'Local-only air-gapped guarantees, log secret scrubbing, and data retention.',
      icon: Icons.shield_outlined,
    ),
    _SettingsSectionItem(
      index: 9,
      title: 'Advanced & Developer',
      description: 'Raw request inspection, database integrity checks, and configuration import/export.',
      icon: Icons.code_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedSection = widget.initialTabIndex.clamp(0, _sections.length - 1);
    _hostController.text = widget.settingsService.ollamaHost;
    _systemPromptController.text = widget.settingsService.systemPrompt;
    _airllmHostController.text = widget.settingsService.airllmHost;
    _airllmModelController.text = widget.settingsService.airllmModel;
    _airllmShardsController.text = widget.settingsService.airllmShardsPath;
    _backupService = BackupService(
      dbService: widget.databaseService,
      settingsService: widget.settingsService,
    );
    _dbSizeBytes = widget.initialDbSizeBytes;
    _tableCounts = widget.initialTableCounts;
    if (_dbSizeBytes == null) {
      _loadDbStats();
    }
    if (widget.settingsService.airllmEnabled) {
      _testAirLLMConnection();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _hostController.dispose();
    _systemPromptController.dispose();
    _airllmHostController.dispose();
    _airllmModelController.dispose();
    _airllmShardsController.dispose();
    super.dispose();
  }

  Future<void> _loadDbStats() async {
    setState(() => _isLoadingDbStats = true);
    try {
      final size = await widget.databaseService.getDatabaseSizeBytes();
      final counts = await widget.databaseService.getTableCounts();
      if (!mounted) return;
      setState(() {
        _dbSizeBytes = size;
        _tableCounts = counts;
        _isLoadingDbStats = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingDbStats = false);
    }
  }

  Future<void> _vacuumDatabase() async {
    setState(() => _isVacuuming = true);
    try {
      await widget.databaseService.vacuum();
      await _loadDbStats();
      if (!mounted) return;
      setState(() {
        _isVacuuming = false;
        _statusMessage = 'Database vacuumed and unused pages successfully reclaimed.';
        _isSuccess = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isVacuuming = false;
        _statusMessage = 'Vacuum error: $e';
        _isSuccess = false;
      });
    }
  }

  Future<void> _checkDatabaseIntegrity() async {
    try {
      final result = await widget.databaseService.checkIntegrity();
      if (!mounted) return;
      setState(() {
        _integrityCheckResult = result.join(', ');
        _statusMessage = 'PRAGMA integrity_check result: ${result.join(', ')}';
        _isSuccess = result.length == 1 && result.first.toLowerCase() == 'ok';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Integrity check error: $e';
        _isSuccess = false;
      });
    }
  }

  Future<void> _testOllamaConnection() async {
    setState(() {
      _isTestingConnection = true;
      _connectionDiagnostic = null;
    });

    final res = await widget.aiService.checkHealthDetails(customHost: _hostController.text);

    if (!mounted) return;
    setState(() {
      _isTestingConnection = false;
      _connectionDiagnostic = res;
      _isSuccess = res['isOnline'] == true;
      _statusMessage = res['isOnline'] == true
          ? 'Ollama is online (v${res['version']}, ping: ${res['latencyMs']}ms)'
          : 'Failed to connect: ${res['error'] ?? 'Connection refused'}';
    });
  }

  Future<void> _testAirLLMConnection() async {
    setState(() {
      _isTestingAirLLMConnection = true;
      _airllmConnectionDiagnostic = null;
    });

    final res = await widget.aiService.checkAirLLMHealthDetails(
      customHost: _airllmHostController.text,
    );

    if (!mounted) return;
    setState(() {
      _isTestingAirLLMConnection = false;
      _airllmConnectionDiagnostic = res;
      _isSuccess = res['isOnline'] == true;
      _statusMessage = res['isOnline'] == true
          ? 'AirLLM is online (Model: ${res['activeModel'] ?? 'None'}, ping: ${res['latencyMs']}ms)'
          : 'Failed to connect to AirLLM: ${res['error'] ?? 'Connection refused'}';
    });
  }

  Future<void> _startAirLLMDaemon() async {
    setState(() => _isManagingAirLLMDaemon = true);
    final res = await widget.modelController.launchAirLLMDaemon();
    await _testAirLLMConnection();
    if (!mounted) return;
    setState(() {
      _isManagingAirLLMDaemon = false;
      _isSuccess = res.success;
      _statusMessage = res.message;
    });
  }

  Future<void> _stopAirLLMDaemon() async {
    setState(() => _isManagingAirLLMDaemon = true);
    final res = await widget.modelController.stopAirLLMDaemon();
    await _testAirLLMConnection();
    if (!mounted) return;
    setState(() {
      _isManagingAirLLMDaemon = false;
      _isSuccess = res.success;
      _statusMessage = res.message;
    });
  }

  Future<void> _loadAirLLMSelectedModel() async {
    final modelId = _airllmModelController.text.trim();
    if (modelId.isEmpty) return;
    setState(() => _isLoadingAirLLMModel = true);
    final success = await widget.aiService.loadAirLLMModel(modelId);
    await _testAirLLMConnection();
    if (!mounted) return;
    setState(() {
      _isLoadingAirLLMModel = false;
      _isSuccess = success;
      _statusMessage = success
          ? 'Successfully loaded $modelId into AirLLM.'
          : 'Failed to load $modelId into AirLLM.';
    });
  }

  Future<void> _pickAirLLMShardsFolder() async {
    final String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select AirLLM Layer Shards Directory',
    );
    if (selectedDirectory != null && selectedDirectory.isNotEmpty) {
      await widget.settingsService.setAirllmShardsPath(selectedDirectory);
      if (!mounted) return;
      setState(() {
        _airllmShardsController.text = selectedDirectory;
        _statusMessage = 'Updated AirLLM shards path.';
        _isSuccess = true;
      });
    }
  }

  Future<void> _pickFolder(String type) async {
    final String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Custom Storage Folder for $type',
    );

    if (selectedDirectory != null && selectedDirectory.isNotEmpty) {
      bool success = false;
      switch (type) {
        case 'Documents':
          success = await widget.settingsService.setDocumentsPath(selectedDirectory);
          break;
        case 'Embeddings':
          success = await widget.settingsService.setEmbeddingsPath(selectedDirectory);
          break;
        case 'Backups':
          success = await widget.settingsService.setBackupsPath(selectedDirectory);
          break;
        case 'Database':
          success = await widget.settingsService.setDatabasePath(selectedDirectory);
          break;
      }

      setState(() {
        _statusMessage = success
            ? 'Successfully updated $type folder location.'
            : 'Failed to access or set permissions for selected folder.';
        _isSuccess = success;
      });
    }
  }

  Future<void> _openFolderInFinder(String folderPath) async {
    try {
      final dir = Directory(folderPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      if (Platform.isMacOS) {
        await Process.run('open', [folderPath]);
      } else {
        await launchUrl(Uri.file(folderPath));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open folder: ${e.toString()}')),
      );
    }
  }

  void _exportAllSettingsJson() {
    final jsonStr = widget.settingsService.exportSettingsJson();
    Clipboard.setData(ClipboardData(text: jsonStr));
    setState(() {
      _statusMessage = 'Application configuration copied to clipboard (JSON format).';
      _isSuccess = true;
    });
  }

  Future<void> _importAllSettingsJson() async {
    final textController = TextEditingController();
    final jsonText = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OllivoTheme.cardDark,
        title: const Text('Import Application Settings (JSON)'),
        content: SizedBox(
          width: 500,
          child: TextField(
            controller: textController,
            maxLines: 10,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            decoration: const InputDecoration(
              hintText: 'Paste application settings JSON here...',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          OllivoSecondaryButton(label: 'Cancel', onPressed: () => Navigator.pop(ctx)),
          OllivoPrimaryButton(label: 'Import Settings', onPressed: () => Navigator.pop(ctx, textController.text)),
        ],
      ),
    );

    if (jsonText != null && jsonText.trim().isNotEmpty) {
      final success = await widget.settingsService.importSettingsJson(jsonText.trim());
      if (!mounted) return;
      setState(() {
        _isSuccess = success;
        _statusMessage = success
            ? 'Application settings successfully imported and applied!'
            : 'Failed to import settings: Invalid JSON schema or version mismatch.';
      });
    }
  }

  Future<void> _confirmResetAllPreferences() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OllivoTheme.cardDark,
        title: const Text('Restore All Application Defaults?'),
        content: const Text(
          'This will reset ALL application settings, preferences, appearance choices, and chat defaults to their factory values. Your conversations and stored documents will not be deleted.',
        ),
        actions: [
          OllivoSecondaryButton(label: 'Cancel', onPressed: () => Navigator.pop(ctx, false)),
          OllivoDangerButton(label: 'Restore Factory Defaults', onPressed: () => Navigator.pop(ctx, true)),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.settingsService.resetAllPreferences();
      if (!mounted) return;
      setState(() {
        _hostController.text = widget.settingsService.ollamaHost;
        _systemPromptController.text = widget.settingsService.systemPrompt;
        _statusMessage = 'All application preferences restored to factory defaults.';
        _isSuccess = true;
      });
    }
  }

  Future<void> _confirmResetSection(int sectionIndex) async {
    final section = _sections[sectionIndex];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OllivoTheme.cardDark,
        title: Text('Reset ${section.title} Settings?'),
        content: Text('Are you sure you want to reset all settings in "${section.title}" back to default values?'),
        actions: [
          OllivoSecondaryButton(label: 'Cancel', onPressed: () => Navigator.pop(ctx, false)),
          OllivoDangerButton(label: 'Reset Section', onPressed: () => Navigator.pop(ctx, true)),
        ],
      ),
    );

    if (confirmed == true) {
      switch (sectionIndex) {
        case 0:
          await widget.settingsService.resetGeneralSettings();
          break;
        case 1:
          await widget.settingsService.resetAppearanceSettings();
          break;
        case 2:
          await widget.settingsService.resetChatSettings();
          _systemPromptController.text = widget.settingsService.systemPrompt;
          break;
        case 3:
          await widget.settingsService.resetRuntimeSettings();
          _hostController.text = widget.settingsService.ollamaHost;
          break;
        case 4:
          await widget.settingsService.resetPerformanceSettings();
          break;
        case 5:
          await widget.settingsService.resetStorageSettings();
          break;
        case 6:
          await widget.settingsService.resetRagSettings();
          break;
        case 7:
          await widget.settingsService.resetMultimodalSettings();
          break;
        case 8:
          await widget.settingsService.resetPrivacySettings();
          break;
      }
      if (!mounted) return;
      setState(() {
        _statusMessage = '${section.title} settings reset to defaults.';
        _isSuccess = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.settingsService,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: OllivoTheme.surfaceDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: OllivoTheme.borderDark),
          ),
          child: Row(
            children: [
              // Left Navigation Sidebar (260px)
              _buildSettingsSidebar(),
              const VerticalDivider(width: 1, color: OllivoTheme.borderDark),
              // Right Content Panel
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeaderBar(),
                      const SizedBox(height: 12),
                      if (_statusMessage != null) ...[
                        _buildStatusBanner(),
                        const SizedBox(height: 12),
                      ],
                      Expanded(
                        child: _buildSelectedSectionContent(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettingsSidebar() {
    final query = _searchQuery.trim().toLowerCase();
    final filtered = _sections.where((s) {
      if (query.isEmpty) return true;
      return s.title.toLowerCase().contains(query) || s.description.toLowerCase().contains(query);
    }).toList();

    return Container(
      width: 270,
      color: OllivoTheme.cardDark.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Box across all Settings
          Container(
            height: 36,
            decoration: BoxDecoration(
              color: OllivoTheme.surfaceDark,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: OllivoTheme.borderDark),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, size: 16, color: OllivoTheme.textSecondaryDark),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(
                      hintText: 'Search settings...',
                      hintStyle: TextStyle(fontSize: 12, color: OllivoTheme.textSecondaryDark),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: const Icon(Icons.close_rounded, size: 14, color: OllivoTheme.textSecondaryDark),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6.0),
            child: Text(
              'SETTINGS SECTIONS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: OllivoTheme.textSecondaryDark,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (ctx, idx) {
                final item = filtered[idx];
                final isSelected = _selectedSection == item.index;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2.0),
                  child: TactileBounce(
                    onTap: () => setState(() => _selectedSection = item.index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? OllivoTheme.mintAccent.withValues(alpha: 0.12) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected ? Border.all(color: OllivoTheme.mintAccent.withValues(alpha: 0.25)) : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item.icon,
                            size: 16,
                            color: isSelected ? OllivoTheme.mintPrimary : OllivoTheme.textSecondaryDark,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              item.title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                color: isSelected ? Colors.white : OllivoTheme.textSecondaryDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(color: OllivoTheme.borderDark, height: 16),
          // Sidebar bottom actions
          Row(
            children: [
              Expanded(
                child: OllivoSecondaryButton(
                  label: 'Export',
                  icon: Icons.upload_file_rounded,
                  onPressed: _exportAllSettingsJson,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OllivoSecondaryButton(
                  label: 'Import',
                  icon: Icons.download_rounded,
                  onPressed: _importAllSettingsJson,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeaderBar() {
    final current = _sections[_selectedSection];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Icon(current.icon, color: OllivoTheme.mintPrimary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      current.title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      current.description,
                      style: const TextStyle(fontSize: 12, color: OllivoTheme.textSecondaryDark),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        OllivoSecondaryButton(
          label: 'Reset Section',
          icon: Icons.restore_rounded,
          onPressed: () => _confirmResetSection(_selectedSection),
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
          Expanded(
            child: Text(
              _statusMessage!,
              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
            ),
          ),
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

  Widget _buildSelectedSectionContent() {
    Widget content;
    switch (_selectedSection) {
      case 0:
        content = _buildGeneralSection();
        break;
      case 1:
        content = _buildAppearanceSection();
        break;
      case 2:
        content = _buildChatSection();
        break;
      case 3:
        content = _buildRuntimeSection();
        break;
      case 4:
        content = _buildPerformanceSection();
        break;
      case 5:
        content = _buildStorageSection();
        break;
      case 6:
        content = _buildRagSection();
        break;
      case 7:
        content = _buildMultimodalSection();
        break;
      case 8:
        content = _buildPrivacySection();
        break;
      case 9:
        content = _buildAdvancedSection();
        break;
      default:
        content = _buildGeneralSection();
    }
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 768),
        child: content,
      ),
    );
  }

  // ==========================================
  // SECTION 0: GENERAL SETTINGS
  // ==========================================
  Widget _buildGeneralSection() {
    final s = widget.settingsService;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        _buildGroupCard(
          title: 'Appearance',
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Theme Mode', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              subtitle: const Text('Select visual theme. Onyx Dark is the signature Ollivo theme.', style: TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark)),
              trailing: DropdownButton<String>(
                value: s.themeMode,
                dropdownColor: OllivoTheme.cardDark,
                items: const [
                  DropdownMenuItem(value: 'dark', child: Text('Onyx Dark (Default)')),
                  DropdownMenuItem(value: 'light', child: Text('Emerald Light')),
                  DropdownMenuItem(value: 'system', child: Text('Match macOS System')),
                ],
                onChanged: (v) => v != null ? s.setThemeMode(v) : null,
              ),
            ),
            const Divider(color: OllivoTheme.borderDark, height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Accent Color Palette', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              subtitle: const Text('Primary highlights, action buttons, and active indicators.', style: TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark)),
              trailing: DropdownButton<String>(
                value: s.accentColor,
                dropdownColor: OllivoTheme.cardDark,
                items: const [
                  DropdownMenuItem(value: 'emerald', child: Text('Mint Emerald (Default)')),
                  DropdownMenuItem(value: 'cyan', child: Text('Electric Cyan')),
                  DropdownMenuItem(value: 'indigo', child: Text('Deep Indigo')),
                  DropdownMenuItem(value: 'amber', child: Text('Warm Amber')),
                ],
                onChanged: (v) => v != null ? s.setAccentColor(v) : null,
              ),
            ),
            const Divider(color: OllivoTheme.borderDark, height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Interface Density', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              subtitle: const Text('Controls padding, list tile heights, and component margins.', style: TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark)),
              trailing: DropdownButton<String>(
                value: s.interfaceDensity,
                dropdownColor: OllivoTheme.cardDark,
                items: const [
                  DropdownMenuItem(value: 'comfortable', child: Text('Comfortable (Default)')),
                  DropdownMenuItem(value: 'compact', child: Text('Compact Density')),
                  DropdownMenuItem(value: 'spacious', child: Text('Spacious')),
                ],
                onChanged: (v) => v != null ? s.setInterfaceDensity(v) : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildGroupCard(
          title: 'Generation Engine',
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Automatic Conversation Title Generation', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              subtitle: const Text('Synthesizes a short contextual title from the first prompt using local AI heuristics.', style: TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark)),
              value: s.autoTitleGeneration,
              activeThumbColor: OllivoTheme.mintPrimary,
              onChanged: (v) => s.setAutoTitleGeneration(v),
            ),
            const Divider(color: OllivoTheme.borderDark, height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Default Active Model', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              subtitle: const Text('Base language model initialized for new chat conversations.', style: TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark)),
              trailing: DropdownButton<String>(
                value: widget.modelController.installedModels.any((m) => m.name == s.activeModel)
                    ? s.activeModel
                    : (widget.modelController.installedModels.isNotEmpty ? widget.modelController.installedModels.first.name : null),
                dropdownColor: OllivoTheme.cardDark,
                hint: const Text('Select Model'),
                items: widget.modelController.installedModels.map((m) {
                  return DropdownMenuItem(value: m.name, child: Text(m.name));
                }).toList(),
                onChanged: (v) {
                  if (v != null) s.setActiveModel(v);
                },
              ),
            ),
            const Divider(color: OllivoTheme.borderDark, height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Confirm Before Removing Models', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              subtitle: const Text('Requires explicit confirmation before issuing DELETE request to Ollama storage.', style: TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark)),
              value: s.confirmRemoveModel,
              activeThumbColor: OllivoTheme.mintPrimary,
              onChanged: (v) => s.setConfirmRemoveModel(v),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildGroupCard(
          title: 'System Integration',
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Restore Previous Session on Launch', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              subtitle: const Text('Automatically switch to the last open conversation and selected tab upon restarting Ollivo.', style: TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark)),
              value: s.restorePreviousSession,
              activeThumbColor: OllivoTheme.mintPrimary,
              onChanged: (v) => s.setRestorePreviousSession(v),
            ),
            const Divider(color: OllivoTheme.borderDark, height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Remember Window Size and Position', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              subtitle: const Text('Preserves exact desktop window bounds and split-pane layout.', style: TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark)),
              value: s.rememberWindowPosition,
              activeThumbColor: OllivoTheme.mintPrimary,
              onChanged: (v) => s.setRememberWindowPosition(v),
            ),
            const Divider(color: OllivoTheme.borderDark, height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Default Startup Tab View', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              subtitle: const Text('Initial screen displayed when opening Ollivo if session restore is disabled.', style: TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark)),
              trailing: DropdownButton<int>(
                value: s.lastSelectedTab.clamp(0, 5),
                dropdownColor: OllivoTheme.cardDark,
                items: const [
                  DropdownMenuItem(value: 0, child: Text('AI Chat')),
                  DropdownMenuItem(value: 1, child: Text('Memory Center')),
                  DropdownMenuItem(value: 2, child: Text('Documents & RAG')),
                  DropdownMenuItem(value: 3, child: Text('Task Workspace')),
                  DropdownMenuItem(value: 4, child: Text('Model Library')),
                  DropdownMenuItem(value: 5, child: Text('Settings')),
                ],
                onChanged: (v) => v != null ? s.setLastSelectedTab(v) : null,
              ),
            ),
            const Divider(color: OllivoTheme.borderDark, height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Confirm Before Deleting Conversations', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              subtitle: const Text('Prompts with an alert dialog before removing a chat thread permanently.', style: TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark)),
              value: s.confirmDeleteConversation,
              activeThumbColor: OllivoTheme.mintPrimary,
              onChanged: (v) => s.setConfirmDeleteConversation(v),
            ),
            const Divider(color: OllivoTheme.borderDark, height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Application Locale & Language', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              subtitle: const Text('Language formatting for system strings, dates, and number formats.', style: TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark)),
              trailing: DropdownButton<String>(
                value: s.appLocale,
                dropdownColor: OllivoTheme.cardDark,
                items: const [
                  DropdownMenuItem(value: 'en', child: Text('English (US)')),
                  DropdownMenuItem(value: 'en_GB', child: Text('English (UK)')),
                  DropdownMenuItem(value: 'de', child: Text('Deutsch')),
                  DropdownMenuItem(value: 'fr', child: Text('Français')),
                  DropdownMenuItem(value: 'ja', child: Text('日本語')),
                ],
                onChanged: (v) => v != null ? s.setAppLocale(v) : null,
              ),
            ),
            const Divider(color: OllivoTheme.borderDark, height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Check for Updates on Startup', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              subtitle: const Text('Polls local release manifest for new Ollivo features.', style: TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark)),
              value: s.checkForUpdates,
              activeThumbColor: OllivoTheme.mintPrimary,
              onChanged: (v) => s.setCheckForUpdates(v),
            ),
          ],
        ),
      ],
    ),
  );
  }

  // ==========================================
  // SECTION 1: APPEARANCE & INTERFACE
  // ==========================================
  Widget _buildAppearanceSection() {
    final s = widget.settingsService;
    return ListView(
      children: [
        _buildGroupCard(
          title: 'Theme & Appearance',
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Theme Mode', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              subtitle: const Text('Select visual theme. Onyx Dark is the signature Ollivo theme.', style: TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark)),
              trailing: DropdownButton<String>(
                value: s.themeMode,
                dropdownColor: OllivoTheme.cardDark,
                items: const [
                  DropdownMenuItem(value: 'dark', child: Text('Onyx Dark (Default)')),
                  DropdownMenuItem(value: 'light', child: Text('Emerald Light')),
                  DropdownMenuItem(value: 'system', child: Text('Match macOS System')),
                ],
                onChanged: (v) => v != null ? s.setThemeMode(v) : null,
              ),
            ),
            const Divider(color: OllivoTheme.borderDark, height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Accent Color Palette', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              subtitle: const Text('Primary highlights, action buttons, and active indicators.', style: TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark)),
              trailing: DropdownButton<String>(
                value: s.accentColor,
                dropdownColor: OllivoTheme.cardDark,
                items: const [
                  DropdownMenuItem(value: 'emerald', child: Text('Mint Emerald (Default)')),
                  DropdownMenuItem(value: 'cyan', child: Text('Electric Cyan')),
                  DropdownMenuItem(value: 'indigo', child: Text('Deep Indigo')),
                  DropdownMenuItem(value: 'amber', child: Text('Warm Amber')),
                ],
                onChanged: (v) => v != null ? s.setAccentColor(v) : null,
              ),
            ),
            const Divider(color: OllivoTheme.borderDark, height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Interface Density', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              subtitle: const Text('Controls padding, list tile heights, and component margins.', style: TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark)),
              trailing: DropdownButton<String>(
                value: s.interfaceDensity,
                dropdownColor: OllivoTheme.cardDark,
                items: const [
                  DropdownMenuItem(value: 'compact', child: Text('Compact (Dense)')),
                  DropdownMenuItem(value: 'comfortable', child: Text('Comfortable (Default)')),
                  DropdownMenuItem(value: 'spacious', child: Text('Spacious')),
                ],
                onChanged: (v) => v != null ? s.setInterfaceDensity(v) : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildGroupCard(
          title: 'Typography & Code Highlighting',
          children: [
            _buildSliderRow(
              label: 'Chat Message Font Size',
              value: s.chatFontSize,
              min: 12.0,
              max: 20.0,
              divisions: 8,
              unit: 'pt',
              onChanged: (v) => s.setChatFontSize(v),
            ),
            const Divider(color: OllivoTheme.borderDark, height: 16),
            _buildSliderRow(
              label: 'General UI Font Size',
              value: s.uiFontSize,
              min: 11.0,
              max: 18.0,
              divisions: 7,
              unit: 'pt',
              onChanged: (v) => s.setUiFontSize(v),
            ),
            const Divider(color: OllivoTheme.borderDark, height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Code Block Font Family', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              subtitle: const Text('Monospaced font used for code blocks and JSON snippets.', style: TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark)),
              trailing: DropdownButton<String>(
                value: s.codeFontFamily,
                dropdownColor: OllivoTheme.cardDark,
                items: const [
                  DropdownMenuItem(value: 'SF Mono', child: Text('SF Mono (macOS Native)')),
                  DropdownMenuItem(value: 'JetBrains Mono', child: Text('JetBrains Mono')),
                  DropdownMenuItem(value: 'Fira Code', child: Text('Fira Code')),
                  DropdownMenuItem(value: 'Menlo', child: Text('Menlo')),
                ],
                onChanged: (v) => v != null ? s.setCodeFontFamily(v) : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildGroupCard(
          title: 'Chat Layout & Performance Badges',
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show Generation Statistics (TPS, Latency)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              subtitle: const Text('Displays live tokens/sec, time-to-first-token, and total duration under assistant responses.', style: TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark)),
              value: s.showPerformanceMetrics,
              activeThumbColor: OllivoTheme.mintPrimary,
              onChanged: (v) => s.setShowPerformanceMetrics(v),
            ),
            const Divider(color: OllivoTheme.borderDark, height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show User & Assistant Avatars', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              subtitle: const Text('Displays identity icons beside chat message bubbles.', style: TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark)),
              value: s.showAvatars,
              activeThumbColor: OllivoTheme.mintPrimary,
              onChanged: (v) => s.setShowAvatars(v),
            ),
            const Divider(color: OllivoTheme.borderDark, height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Reduced Motion Transitions', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              subtitle: const Text('Disables bounce animations and replaces transitions with subtle fades for accessibility.', style: TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark)),
              value: s.reducedMotion,
              activeThumbColor: OllivoTheme.mintPrimary,
              onChanged: (v) => s.setReducedMotion(v),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // SECTION 2: CHAT & RESPONSE DEFAULTS
  // ==========================================
  Widget _buildChatSection() {
    final s = widget.settingsService;
    return ListView(
      children: [
        _buildGroupCard(
          title: 'Default System Persona',
          children: [
            const Text(
              'Global system prompt injected when a model or conversation does not provide a specific override.',
              style: TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _systemPromptController,
              onChanged: (val) => s.setSystemPrompt(val),
              maxLines: 4,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                hintText: 'Enter global system instructions...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildGroupCard(
          title: 'Global Sampling Defaults (Precedence Level 3)',
          children: [
            _buildSliderRow(
              label: 'Default Temperature',
              value: s.chatTemperature,
              min: 0.0,
              max: 2.0,
              divisions: 40,
              displayOverride: s.chatTemperature.toStringAsFixed(2),
              onChanged: (v) => s.setChatTemperature(v),
            ),
            const Divider(color: OllivoTheme.borderDark, height: 16),
            _buildSliderRow(
              label: 'Default Top-P (Nucleus Sampling)',
              value: s.topP,
              min: 0.0,
              max: 1.0,
              divisions: 20,
              displayOverride: s.topP.toStringAsFixed(2),
              onChanged: (v) => s.setTopP(v),
            ),
            const Divider(color: OllivoTheme.borderDark, height: 16),
            _buildSliderRow(
              label: 'Default Top-K Sampling',
              value: s.topK.toDouble(),
              min: 0,
              max: 100,
              divisions: 100,
              displayOverride: s.topK == 0 ? 'Disabled' : s.topK.toString(),
              onChanged: (v) => s.setTopK(v.toInt()),
            ),
            const Divider(color: OllivoTheme.borderDark, height: 16),
            _buildSliderRow(
              label: 'Default Repeat Penalty',
              value: s.repeatPenalty,
              min: 0.5,
              max: 2.0,
              divisions: 30,
              displayOverride: s.repeatPenalty.toStringAsFixed(2),
              onChanged: (v) => s.setRepeatPenalty(v),
            ),
            const Divider(color: OllivoTheme.borderDark, height: 16),
            _buildSliderRow(
              label: 'Default Context Window Length (num_ctx)',
              value: s.contextWindow.toDouble(),
              min: 1024,
              max: 32768,
              divisions: 31,
              unit: 'tokens',
              onChanged: (v) => s.setContextWindow(v.toInt()),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildGroupCard(
          title: 'Interaction & Streaming Behavior',
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto-Scroll During Token Streaming', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              subtitle: const Text('Keeps viewport pinned to the bottom while Ollama generates tokens.', style: TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark)),
              value: s.autoScrollDuringGeneration,
              activeThumbColor: OllivoTheme.mintPrimary,
              onChanged: (v) => s.setAutoScrollDuringGeneration(v),
            ),
            const Divider(color: OllivoTheme.borderDark, height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show Copy Button on Message Bubbles', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              subtitle: const Text('Quick clipboard copy action on assistant responses.', style: TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark)),
              value: s.showCopyButton,
              activeThumbColor: OllivoTheme.mintPrimary,
              onChanged: (v) => s.setShowCopyButton(v),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // SECTION 3: RUNTIME & ENGINE SETTINGS
  // ==========================================
  Widget _buildRuntimeSection() {
    final s = widget.settingsService;
    return ListView(
      children: [
        _buildGroupCard(
          title: 'Ollama Server Endpoint',
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _hostController,
                    onChanged: (val) => s.setOllamaHost(val),
                    style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                    decoration: const InputDecoration(
                      labelText: 'Server URL',
                      hintText: 'http://localhost:11434',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OllivoPrimaryButton(
                  label: _isTestingConnection ? 'Testing...' : 'Test Connection',
                  icon: Icons.network_check_rounded,
                  onPressed: _isTestingConnection ? null : _testOllamaConnection,
                ),
              ],
            ),
            if (_connectionDiagnostic != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: OllivoTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _connectionDiagnostic!['isOnline'] == true
                        ? OllivoTheme.mintPrimary
                        : OllivoTheme.statusError,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _connectionDiagnostic!['isOnline'] == true ? Icons.check_circle : Icons.error,
                      color: _connectionDiagnostic!['isOnline'] == true ? OllivoTheme.mintPrimary : OllivoTheme.statusError,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Status: ${_connectionDiagnostic!['status']} • Latency: ${_connectionDiagnostic!['latencyMs']}ms • Version: ${_connectionDiagnostic!['version'] ?? 'N/A'}',
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        _buildGroupCard(
          title: 'Timeout & Keep-Alive Policy',
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Default Model Keep-Alive Duration', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              subtitle: const Text('How long models stay resident in VRAM after the last prompt.', style: TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark)),
              trailing: DropdownButton<String>(
                value: s.defaultKeepAlive,
                dropdownColor: OllivoTheme.cardDark,
                items: const [
                  DropdownMenuItem(value: '0', child: Text('Unload Immediately (0)')),
                  DropdownMenuItem(value: '5m', child: Text('5 minutes (Default)')),
                  DropdownMenuItem(value: '15m', child: Text('15 minutes')),
                  DropdownMenuItem(value: '30m', child: Text('30 minutes')),
                  DropdownMenuItem(value: '1h', child: Text('1 hour')),
                  DropdownMenuItem(value: '-1', child: Text('Keep Loaded Forever (-1)')),
                ],
                onChanged: (v) => v != null ? s.setDefaultKeepAlive(v) : null,
              ),
            ),
            const Divider(color: OllivoTheme.borderDark, height: 16),
            _buildSliderRow(
              label: 'Connection Timeout',
              value: s.connectionTimeoutSeconds.toDouble(),
              min: 5,
              max: 60,
              divisions: 11,
              unit: 'seconds',
              onChanged: (v) => s.setConnectionTimeoutSeconds(v.toInt()),
            ),
            const Divider(color: OllivoTheme.borderDark, height: 16),
            _buildSliderRow(
              label: 'Inference Request Timeout',
              value: s.requestTimeoutSeconds.toDouble(),
              min: 30,
              max: 300,
              divisions: 9,
              unit: 'seconds',
              onChanged: (v) => s.setRequestTimeoutSeconds(v.toInt()),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildGroupCard(
          title: 'AirLLM Layer-Streaming Engine (70B+ Local)',
          children: [
            const Text(
              'AirLLM enables running 70B+ parameter models on consumer hardware by streaming model layers sequentially from NVMe/SSD storage into 4-8GB RAM without full weight residency.',
              style: TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Use AIRLLM for inference',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              subtitle: const Text(
                'When enabled, new AI requests use the AIRLLM layer-streaming engine. When disabled, Ollivo uses its existing inference backend.',
                style: TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark),
              ),
              value: s.airllmEnabled,
              activeThumbColor: OllivoTheme.mintPrimary,
              onChanged: (v) async {
                await s.setAirllmEnabled(v);
                if (v) {
                  await _testAirLLMConnection();
                } else {
                  setState(() {});
                }
              },
            ),
            const SizedBox(height: 10),
            _buildEngineRoutingStatusBanner(s),
            const Divider(color: OllivoTheme.borderDark, height: 24),
            // Daemon Control Row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Local Python Service Daemon',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _airllmConnectionDiagnostic?['isOnline'] == true
                            ? 'Service running on ${_airllmHostController.text} (PID active)'
                            : 'Service stopped or waiting for launch',
                        style: const TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark),
                      ),
                    ],
                  ),
                ),
                OllivoSecondaryButton(
                  label: _isManagingAirLLMDaemon ? 'Working...' : 'Start Daemon',
                  icon: Icons.play_arrow_rounded,
                  onPressed: _isManagingAirLLMDaemon ? null : _startAirLLMDaemon,
                ),
                const SizedBox(width: 8),
                OllivoSecondaryButton(
                  label: 'Stop',
                  icon: Icons.stop_rounded,
                  onPressed: _isManagingAirLLMDaemon ? null : _stopAirLLMDaemon,
                ),
              ],
            ),
            const Divider(color: OllivoTheme.borderDark, height: 20),
            // Host URL & Test Connection
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _airllmHostController,
                    onChanged: (val) => s.setAirllmHost(val),
                    style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                    decoration: const InputDecoration(
                      labelText: 'AirLLM Service URL',
                      hintText: 'http://127.0.0.1:8765',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OllivoPrimaryButton(
                  label: _isTestingAirLLMConnection ? 'Testing...' : 'Test AirLLM',
                  icon: Icons.network_check_rounded,
                  onPressed: _isTestingAirLLMConnection ? null : _testAirLLMConnection,
                ),
              ],
            ),
            if (_airllmConnectionDiagnostic != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: OllivoTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _airllmConnectionDiagnostic!['isOnline'] == true
                        ? OllivoTheme.mintPrimary
                        : OllivoTheme.statusError,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _airllmConnectionDiagnostic!['isOnline'] == true ? Icons.check_circle : Icons.error,
                      color: _airllmConnectionDiagnostic!['isOnline'] == true ? OllivoTheme.mintPrimary : OllivoTheme.statusError,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Status: ${_airllmConnectionDiagnostic!['status']} • Engine: ${_airllmConnectionDiagnostic!['engine'] ?? 'airllm'} • Model: ${_airllmConnectionDiagnostic!['activeModel'] ?? 'None'} • Latency: ${_airllmConnectionDiagnostic!['latencyMs']}ms',
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Divider(color: OllivoTheme.borderDark, height: 20),
            // Model Selection & Load
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _airllmModelController,
                    onChanged: (val) => s.setAirllmModel(val),
                    style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                    decoration: const InputDecoration(
                      labelText: 'Active Model Identifier',
                      hintText: 'meta-llama/Meta-Llama-3-70B-Instruct',
                      border: OutlineInputBorder(),
                      helperText: 'Allowlisted: Meta-Llama-3-70B-Instruct, DeepSeek-R1-Distill-Llama-70B, Qwen2.5-72B-Instruct',
                      helperStyle: TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OllivoSecondaryButton(
                  label: _isLoadingAirLLMModel ? 'Loading...' : 'Load Model',
                  icon: Icons.system_update_alt_rounded,
                  onPressed: _isLoadingAirLLMModel ? null : _loadAirLLMSelectedModel,
                ),
              ],
            ),
            const Divider(color: OllivoTheme.borderDark, height: 20),
            // Compression & Hardware Device Options
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Quantization / Compression', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                    subtitle: const Text('Layer compression mode', style: TextStyle(fontSize: 10, color: OllivoTheme.textSecondaryDark)),
                    trailing: DropdownButton<String>(
                      value: s.airllmCompression,
                      dropdownColor: OllivoTheme.cardDark,
                      items: const [
                        DropdownMenuItem(value: '4bit', child: Text('4-bit (Optimal SSD/RAM)')),
                        DropdownMenuItem(value: '8bit', child: Text('8-bit (Higher Quality)')),
                        DropdownMenuItem(value: 'none', child: Text('None (FP16 full precision)')),
                      ],
                      onChanged: (v) => v != null ? s.setAirllmCompression(v) : null,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Compute Device Target', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                    subtitle: const Text('Apple Metal / CUDA / CPU', style: TextStyle(fontSize: 10, color: OllivoTheme.textSecondaryDark)),
                    trailing: DropdownButton<String>(
                      value: s.airllmDevice,
                      dropdownColor: OllivoTheme.cardDark,
                      items: const [
                        DropdownMenuItem(value: 'auto', child: Text('Auto (Metal on Mac)')),
                        DropdownMenuItem(value: 'cuda', child: Text('CUDA (NVIDIA GPU)')),
                        DropdownMenuItem(value: 'cpu', child: Text('CPU Fallback')),
                      ],
                      onChanged: (v) => v != null ? s.setAirllmDevice(v) : null,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(color: OllivoTheme.borderDark, height: 20),
            // Shards Path & Auto Launch
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _airllmShardsController,
                    readOnly: true,
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    decoration: const InputDecoration(
                      labelText: 'Layer Shards Cache Directory',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OllivoSecondaryButton(
                  label: 'Browse...',
                  icon: Icons.folder_open_rounded,
                  onPressed: _pickAirLLMShardsFolder,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto-Launch AirLLM Daemon on Startup', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              subtitle: const Text('Automatically boot the local Python service when Ollivo starts.', style: TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark)),
              value: s.airllmAutoLaunch,
              activeThumbColor: OllivoTheme.mintPrimary,
              onChanged: (v) => s.setAirllmAutoLaunch(v),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (widget.modelConfigService != null) ...[
          _buildGroupCard(
            title: 'Per-Model Configuration Center',
            children: [
              const Text(
                'Open dedicated parameter configuration for any installed model to customize sampling, context length, or offload settings.',
                style: TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: widget.modelController.installedModels.any((m) => m.name == s.activeModel)
                          ? s.activeModel
                          : (widget.modelController.installedModels.isNotEmpty ? widget.modelController.installedModels.first.name : null),
                      dropdownColor: OllivoTheme.cardDark,
                      hint: const Text('Select Model to Configure...'),
                      items: widget.modelController.installedModels.map((m) {
                        return DropdownMenuItem(value: m.name, child: Text(m.name));
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) s.setActiveModel(v);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  OllivoPrimaryButton(
                    label: 'Configure Model',
                    icon: Icons.tune_rounded,
                    onPressed: () {
                      final model = s.activeModel;
                      if (model.isNotEmpty) {
                        ModelConfigDialog.show(
                          context,
                          modelId: model,
                          modelConfigService: widget.modelConfigService!,
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ==========================================
  // SECTION 4: HARDWARE & PERFORMANCE
  // ==========================================
  Widget _buildPerformanceSection() {
    final s = widget.settingsService;
    final hardware = widget.modelController.hardwareProfile;

    return ListView(
      children: [
        _buildGroupCard(
          title: 'macOS Hardware Telemetry',
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildTelemetryStat(
                    title: 'Architecture',
                    value: (hardware?.chipFamily.isNotEmpty ?? false) ? hardware!.chipFamily : 'Apple Silicon',
                    subtitle: 'Metal Acceleration Active',
                  ),
                ),
                Expanded(
                  child: _buildTelemetryStat(
                    title: 'Total Unified Memory',
                    value: hardware?.formattedTotalRam ?? 'Unknown RAM',
                    subtitle: 'Shared CPU / GPU VRAM',
                  ),
                ),
                Expanded(
                  child: _buildTelemetryStat(
                    title: 'Available RAM',
                    value: hardware?.formattedAvailableRam ?? 'Unknown RAM',
                    subtitle: 'Dynamic Headroom',
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildGroupCard(
          title: 'Memory Management & Preloading',
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto-Unload Model on System Memory Pressure', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              subtitle: const Text('Ejects resident models if available unified memory drops below critical threshold.', style: TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark)),
              value: s.autoUnloadOnMemoryPressure,
              activeThumbColor: OllivoTheme.mintPrimary,
              onChanged: (v) => s.setAutoUnloadOnMemoryPressure(v),
            ),
            const Divider(color: OllivoTheme.borderDark, height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Preload Active Model on Launch', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              subtitle: const Text('Warms up model weights into memory during launch for zero first-token delay.', style: TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark)),
              value: s.preloadActiveModelOnLaunch,
              activeThumbColor: OllivoTheme.mintPrimary,
              onChanged: (v) => s.setPreloadActiveModelOnLaunch(v),
            ),
            const Divider(color: OllivoTheme.borderDark, height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Collect Performance Telemetry', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              subtitle: const Text('Records per-request duration and prompt token processing throughput.', style: TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark)),
              value: s.collectPerformanceTelemetry,
              activeThumbColor: OllivoTheme.mintPrimary,
              onChanged: (v) => s.setCollectPerformanceTelemetry(v),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildAuditLogCard(),
      ],
    );
  }

  // ==========================================
  // SECTION 5: STORAGE & DOWNLOADS
  // ==========================================
  Widget _buildStorageSection() {
    final s = widget.settingsService;
    return ListView(
      children: [
        _buildGroupCard(
          title: 'Local File System Storage Paths',
          children: [
            _buildFolderRow('Documents', s.documentsPath),
            const Divider(color: OllivoTheme.borderDark, height: 16),
            _buildFolderRow('Embeddings', s.embeddingsPath),
            const Divider(color: OllivoTheme.borderDark, height: 16),
            _buildFolderRow('Database', s.databasePath),
            const Divider(color: OllivoTheme.borderDark, height: 16),
            _buildFolderRow('Backups', s.backupsPath),
          ],
        ),
        const SizedBox(height: 16),
        _buildGroupCard(
          title: 'Database Statistics & Vacuum Maintenance',
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'SQLite Database Size: ${_isLoadingDbStats ? 'Calculating...' : (_dbSizeBytes != null ? '${(_dbSizeBytes! / 1024).toStringAsFixed(1)} KB' : 'Unavailable')}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                OllivoSecondaryButton(
                  label: _isVacuuming ? 'Reclaiming...' : 'Vacuum Database',
                  icon: Icons.cleaning_services_rounded,
                  onPressed: _isVacuuming ? null : _vacuumDatabase,
                ),
              ],
            ),
            if (_tableCounts != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _tableCounts!.entries.map((e) {
                  return Chip(
                    label: Text('${e.key}: ${e.value} records', style: const TextStyle(fontSize: 11)),
                    backgroundColor: OllivoTheme.surfaceDark,
                    side: const BorderSide(color: OllivoTheme.borderDark),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        _buildGroupCard(
          title: 'System Backups & Restoration',
          children: [
            const Text(
              'Back up all conversations, memory nodes, task states, and model configurations into a portable zip archive.',
              style: TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OllivoPrimaryButton(
                  label: _isBackingUp ? 'Creating Backup...' : 'Create Backup Archive',
                  icon: Icons.archive_rounded,
                  onPressed: _isBackingUp
                      ? null
                      : () async {
                          setState(() => _isBackingUp = true);
                          final res = await _backupService.createBackup();
                          if (!mounted) return;
                          setState(() {
                            _isBackingUp = false;
                            _statusMessage = res.message;
                            _isSuccess = res.success;
                          });
                        },
                ),
                const SizedBox(width: 10),
                OllivoSecondaryButton(
                  label: _isRestoring ? 'Restoring...' : 'Restore from Backup...',
                  icon: Icons.unarchive_rounded,
                  onPressed: _isRestoring
                      ? null
                      : () async {
                          final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['zip']);
                          if (result != null && result.files.single.path != null) {
                            setState(() => _isRestoring = true);
                            final res = await _backupService.restoreBackup(File(result.files.single.path!));
                            if (!mounted) return;
                            setState(() {
                              _isRestoring = false;
                              _statusMessage = res.message;
                              _isSuccess = res.success;
                            });
                          }
                        },
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // SECTION 6: KNOWLEDGE & RAG SETTINGS
  // ==========================================
  Widget _buildRagSection() {
    final s = widget.settingsService;
    return ListView(
      children: [
        _buildGroupCard(
          title: 'Retrieval Augmented Generation (RAG)',
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable Local Document RAG Globally', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              subtitle: const Text('Automatically queries local vector embeddings and augments prompts with relevant document context.', style: TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark)),
              value: s.ragEnabled,
              activeThumbColor: OllivoTheme.mintPrimary,
              onChanged: (v) => s.setRagEnabled(v),
            ),
            const Divider(color: OllivoTheme.borderDark, height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show Document Citations in Responses', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              subtitle: const Text('Displays filename and chunk index pills for all retrieved passages.', style: TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark)),
              value: s.showCitations,
              activeThumbColor: OllivoTheme.mintPrimary,
              onChanged: (v) => s.setShowCitations(v),
            ),
            const Divider(color: OllivoTheme.borderDark, height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Hybrid Retrieval (Keyword + Vector Search)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              subtitle: const Text('Combines dense cosine similarity with BM25 keyword matching for superior retrieval accuracy.', style: TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark)),
              value: s.ragHybridSearch,
              activeThumbColor: OllivoTheme.mintPrimary,
              onChanged: (v) => s.setRagHybridSearch(v),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildGroupCard(
          title: 'Chunking & Retrieval Calibration',
          children: [
            _buildSliderRow(
              label: 'Document Chunk Size',
              value: s.ragChunkSize.toDouble(),
              min: 100,
              max: 1000,
              divisions: 18,
              unit: 'tokens',
              onChanged: (v) => s.setRagChunkSize(v.toInt()),
            ),
            const Divider(color: OllivoTheme.borderDark, height: 16),
            _buildSliderRow(
              label: 'Chunk Overlap Window',
              value: s.ragChunkOverlap.toDouble(),
              min: 10,
              max: 200,
              divisions: 19,
              unit: 'tokens',
              onChanged: (v) => s.setRagChunkOverlap(v.toInt()),
            ),
            const Divider(color: OllivoTheme.borderDark, height: 16),
            _buildSliderRow(
              label: 'Default Retrieval Top-K Passages',
              value: s.ragTopK.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              unit: 'passages',
              onChanged: (v) => s.setRagTopK(v.toInt()),
            ),
            const Divider(color: OllivoTheme.borderDark, height: 16),
            _buildSliderRow(
              label: 'Cosine Similarity Threshold',
              value: s.ragSimilarityThreshold,
              min: 0.1,
              max: 0.9,
              divisions: 16,
              displayOverride: s.ragSimilarityThreshold.toStringAsFixed(2),
              onChanged: (v) => s.setRagSimilarityThreshold(v),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // SECTION 7: MULTIMODAL & DOCUMENT PROCESSING
  // ==========================================
  Widget _buildMultimodalSection() {
    final s = widget.settingsService;
    return ListView(
      children: [
        _buildGroupCard(
          title: 'Vision & OCR Pipeline',
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('OCR Engine', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              subtitle: const Text('Native macOS Apple Vision text recognition framework runs offline with zero network latency.', style: TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark)),
              trailing: DropdownButton<String>(
                value: s.ocrEngine,
                dropdownColor: OllivoTheme.cardDark,
                items: const [
                  DropdownMenuItem(value: 'apple_vision', child: Text('Apple Vision Framework (Native macOS)')),
                ],
                onChanged: (v) => v != null ? s.setOcrEngine(v) : null,
              ),
            ),
            const Divider(color: OllivoTheme.borderDark, height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Default Vision Model', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              subtitle: const Text('Preferred local multimodal model for image understanding prompts.', style: TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark)),
              trailing: DropdownButton<String>(
                value: s.visionModel.isEmpty ? 'llava:7b' : s.visionModel,
                dropdownColor: OllivoTheme.cardDark,
                items: const [
                  DropdownMenuItem(value: 'llava:7b', child: Text('LLaVA 7B')),
                  DropdownMenuItem(value: 'llava:13b', child: Text('LLaVA 13B')),
                  DropdownMenuItem(value: 'bakllava:latest', child: Text('BakLLaVA')),
                  DropdownMenuItem(value: 'minicpm-v:latest', child: Text('MiniCPM-V')),
                ],
                onChanged: (v) => v != null ? s.setVisionModel(v) : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildGroupCard(
          title: 'Media Limits & Retention',
          children: [
            _buildSliderRow(
              label: 'Maximum Images Per Request',
              value: s.maxImagesPerPrompt.toDouble(),
              min: 1,
              max: 8,
              divisions: 7,
              unit: 'images',
              onChanged: (v) => s.setMaxImagesPerPrompt(v.toInt()),
            ),
            const Divider(color: OllivoTheme.borderDark, height: 16),
            _buildSliderRow(
              label: 'Maximum Scanned PDF Pages',
              value: s.maxPdfPageCount.toDouble(),
              min: 10,
              max: 100,
              divisions: 9,
              unit: 'pages',
              onChanged: (v) => s.setMaxPdfPageCount(v.toInt()),
            ),
            const Divider(color: OllivoTheme.borderDark, height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto-Cleanup Temporary Media on Exit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              subtitle: const Text('Deletes cached cropped frames and temporary PDF image pages when closing Ollivo.', style: TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark)),
              value: s.autoCleanupMediaOnExit,
              activeThumbColor: OllivoTheme.mintPrimary,
              onChanged: (v) => s.setAutoCleanupMediaOnExit(v),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // SECTION 8: PRIVACY & SECURITY
  // ==========================================
  Widget _buildPrivacySection() {
    final s = widget.settingsService;
    return ListView(
      children: [
        _buildGroupCard(
          title: 'Air-Gapped Privacy Guarantees',
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enforce Local-Only Air-Gapped Mode', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              subtitle: const Text('Prohibits all outgoing network requests. All prompts, documents, and weights stay strictly local on device.', style: TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark)),
              value: s.localOnlyMode,
              activeThumbColor: OllivoTheme.mintPrimary,
              onChanged: (v) => s.setLocalOnlyMode(v),
            ),
            const Divider(color: OllivoTheme.borderDark, height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Warn When Connecting to Non-Local Hosts', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              subtitle: const Text('Displays a security warning if Ollama host is changed from localhost / 127.0.0.1.', style: TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark)),
              value: s.warnOnRemoteEndpoint,
              activeThumbColor: OllivoTheme.mintPrimary,
              onChanged: (v) => s.setWarnOnRemoteEndpoint(v),
            ),
            const Divider(color: OllivoTheme.borderDark, height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Scrub Sensitive Tokens in System Logs', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              subtitle: const Text('Automatically masks API keys, authorization tokens, and personal identifiers in SQLite audit logs.', style: TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark)),
              value: s.redactSecretsInLogs,
              activeThumbColor: OllivoTheme.mintPrimary,
              onChanged: (v) => s.setRedactSecretsInLogs(v),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildGroupCard(
          title: 'Conversation Retention Policy',
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto-Prune Inactive Conversations', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              subtitle: const Text('Automatically deletes conversations older than the retention threshold.', style: TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark)),
              trailing: DropdownButton<int>(
                value: s.conversationRetentionDays,
                dropdownColor: OllivoTheme.cardDark,
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Never (Keep Indefinitely)')),
                  DropdownMenuItem(value: 30, child: Text('30 Days')),
                  DropdownMenuItem(value: 90, child: Text('90 Days')),
                  DropdownMenuItem(value: 365, child: Text('1 Year')),
                ],
                onChanged: (v) => v != null ? s.setConversationRetentionDays(v) : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildAuditLogCard(),
      ],
    );
  }

  // ==========================================
  // SECTION 9: ADVANCED & DEVELOPER
  // ==========================================
  Widget _buildAdvancedSection() {
    final s = widget.settingsService;
    return ListView(
      children: [
        _buildGroupCard(
          title: 'Developer Diagnostics & Inspection',
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show Advanced Controls Globally', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              subtitle: const Text('Unlocks raw parameter steppers, sampling seeds, and offload controls by default across all screens.', style: TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark)),
              value: s.showAdvancedControls,
              activeThumbColor: OllivoTheme.mintPrimary,
              onChanged: (v) => s.setShowAdvancedControls(v),
            ),
            const Divider(color: OllivoTheme.borderDark, height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Verbose Logging & Diagnostics', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              subtitle: const Text('Emits detailed debug records for token streaming chunks and RAG cosine rankings.', style: TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark)),
              value: s.verboseLogging,
              activeThumbColor: OllivoTheme.mintPrimary,
              onChanged: (v) => s.setVerboseLogging(v),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildGroupCard(
          title: 'Database Integrity Check (PRAGMA integrity_check)',
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _integrityCheckResult != null
                        ? 'Integrity Result: $_integrityCheckResult'
                        : 'Verify database B-trees, indices, and page allocations.',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: _integrityCheckResult != null ? 'monospace' : null,
                      color: _integrityCheckResult == 'ok' ? OllivoTheme.mintPrimary : Colors.white,
                    ),
                  ),
                ),
                OllivoSecondaryButton(
                  label: 'Run Integrity Check',
                  icon: Icons.verified_user_rounded,
                  onPressed: _checkDatabaseIntegrity,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildGroupCard(
          title: 'Danger Zone & Factory Reset',
          children: [
            const Text(
              'Reset all application preferences, UI state, and model defaults back to initial installation values.',
              style: TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark),
            ),
            const SizedBox(height: 12),
            OllivoDangerButton(
              label: 'Restore All Factory Defaults...',
              icon: Icons.restore_page_rounded,
              onPressed: _confirmResetAllPreferences,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildAuditLogCard(),
      ],
    );
  }

  Widget _buildAuditLogCard() {
    final audit = AuditService.instance;
    return ListenableBuilder(
      listenable: audit,
      builder: (context, _) {
        return Material(
          color: OllivoTheme.cardDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: OllivoTheme.borderDark),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Local Privacy & Security Audit Log',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Zero cloud telemetry verification · 100% on-device ledger',
                          style: TextStyle(
                            fontSize: 12,
                            color: OllivoTheme.textSecondaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: OllivoTheme.mintPrimary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: OllivoTheme.mintPrimary.withValues(alpha: 0.4)),
                        ),
                        child: const Text(
                          '100% Air-Gapped',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: OllivoTheme.mintPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: OllivoTheme.mintPrimary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: OllivoTheme.mintPrimary.withValues(alpha: 0.4)),
                        ),
                        child: const Text(
                          '0 Bytes Outbound Telemetry',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: OllivoTheme.mintPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  OllivoSecondaryButton(
                    label: 'Copy JSON Report',
                    icon: Icons.copy_rounded,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: audit.exportAsJson()));
                      setState(() {
                        _statusMessage = 'Audit log JSON report copied to clipboard.';
                        _isSuccess = true;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  OllivoSecondaryButton(
                    label: 'Clear Log',
                    icon: Icons.delete_outline_rounded,
                    onPressed: () {
                      audit.clearLogs();
                      setState(() {
                        _statusMessage = 'Audit log entries cleared.';
                        _isSuccess = true;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                decoration: BoxDecoration(
                  color: OllivoTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: OllivoTheme.borderDark),
                ),
                child: audit.entries.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'No audit events recorded yet.',
                            style: TextStyle(fontSize: 12, color: OllivoTheme.textSecondaryDark),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: audit.entries.length,
                        separatorBuilder: (context, index) => const Divider(color: OllivoTheme.borderDark, height: 1),
                        itemBuilder: (context, index) {
                          final entry = audit.entries[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                Text(
                                  entry.action.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: OllivoTheme.mintPrimary,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    entry.details,
                                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  entry.endpoint,
                                  style: const TextStyle(fontSize: 10, color: OllivoTheme.textSecondaryDark, fontFamily: 'monospace'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
      },
    );
  }

  String _getBackendDisplayName(String backendId) {
    switch (backendId.toLowerCase()) {
      case 'ollama':
        return 'Ollama';
      case 'airllm':
        return 'AirLLM Layer-Streaming';
      case 'lmstudio':
        return 'LM Studio';
      case 'localai':
        return 'LocalAI';
      default:
        return backendId.isNotEmpty
            ? backendId[0].toUpperCase() + backendId.substring(1)
            : 'Ollama';
    }
  }

  Widget _buildEngineRoutingStatusBanner(SettingsService s) {
    if (!s.airllmEnabled) {
      final backendName = _getBackendDisplayName(s.activeBackend);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: OllivoTheme.surfaceDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: OllivoTheme.borderDark),
        ),
        child: Row(
          children: [
            const Icon(Icons.swap_horiz_rounded, color: OllivoTheme.textSecondaryDark, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AIRLLM disabled — using $backendName',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Inference requests will use the configured $backendName backend at ${s.ollamaHost}. Toggle ON to switch to AirLLM.',
                    style: const TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final diag = _airllmConnectionDiagnostic;
    final bool isTesting = _isTestingAirLLMConnection;
    final bool isOnline = diag != null && diag['isOnline'] == true;
    final String state = (diag != null ? (diag['status'] as String? ?? 'offline') : 'offline').toLowerCase();
    final bool modelReady = isOnline && (state == 'ready' || (diag['modelId'] != null && diag['modelId'] != 'None loaded'));

    Color borderColor;
    Color iconColor;
    IconData iconData;
    String title;
    String subtitle;
    Widget? actionWidget;

    if (isTesting && diag == null) {
      borderColor = OllivoTheme.borderDark;
      iconColor = OllivoTheme.mintPrimary;
      iconData = Icons.sync_rounded;
      title = 'AIRLLM enabled — checking service...';
      subtitle = 'Verifying daemon connectivity at ${s.airllmHost}...';
    } else if (!isOnline) {
      borderColor = OllivoTheme.statusError;
      iconColor = OllivoTheme.statusError;
      iconData = Icons.cloud_off_rounded;
      title = 'AIRLLM enabled — service not running';
      subtitle = 'The local Python daemon is not responding at ${s.airllmHost}. Start the service to enable inference.';
      actionWidget = OllivoSecondaryButton(
        label: _isManagingAirLLMDaemon ? 'Starting...' : 'Start Daemon',
        icon: Icons.play_arrow_rounded,
        onPressed: _isManagingAirLLMDaemon ? null : _startAirLLMDaemon,
      );
    } else if (!modelReady) {
      borderColor = Colors.amber;
      iconColor = Colors.amber;
      iconData = Icons.warning_amber_rounded;
      title = 'AIRLLM enabled — model not loaded';
      subtitle = 'Service is online, but "${s.airllmModel}" is not loaded in memory. Load the model to begin streaming.';
      actionWidget = OllivoSecondaryButton(
        label: _isLoadingAirLLMModel ? 'Loading...' : 'Load Model',
        icon: Icons.system_update_alt_rounded,
        onPressed: _isLoadingAirLLMModel ? null : _loadAirLLMSelectedModel,
      );
    } else {
      borderColor = OllivoTheme.mintPrimary;
      iconColor = OllivoTheme.mintPrimary;
      iconData = Icons.check_circle_rounded;
      final activeModelName = diag['modelId'] ?? s.airllmModel;
      title = 'AIRLLM enabled — model ready';
      subtitle = 'Active model $activeModelName ready for layer-streaming inference on ${s.airllmDevice.toUpperCase()}.';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: OllivoTheme.surfaceDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Row(
        children: [
          Icon(iconData, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark),
                ),
              ],
            ),
          ),
          if (actionWidget != null) ...[
            const SizedBox(width: 12),
            actionWidget,
          ],
        ],
      ),
    );
  }

  // ==========================================
  // SHARED UI HELPER BUILDERS
  // ==========================================
  Widget _buildGroupCard({required String title, required List<Widget> children}) {
    return Material(
      color: OllivoTheme.cardDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: OllivoTheme.borderDark),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: OllivoTheme.mintPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    String? unit,
    String? displayOverride,
    required ValueChanged<double> onChanged,
  }) {
    final display = displayOverride ?? (unit != null ? '${value.toInt()} $unit' : value.toStringAsFixed(1));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: OllivoTheme.surfaceDark,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: OllivoTheme.borderDark),
              ),
              child: Text(
                display,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: OllivoTheme.mintPrimary),
              ),
            ),
          ],
        ),
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
    );
  }

  Widget _buildFolderRow(String type, String currentPath) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$type Folder',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
              ),
              const SizedBox(height: 2),
              Text(
                currentPath.isEmpty ? 'Default App Directory' : currentPath,
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: OllivoTheme.textSecondaryDark),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        OllivoSecondaryButton(
          label: 'Change...',
          icon: Icons.drive_file_rename_outline_rounded,
          onPressed: () => _pickFolder(type),
        ),
        const SizedBox(width: 6),
        IconButton(
          icon: const Icon(Icons.folder_open_rounded, size: 18, color: OllivoTheme.textSecondaryDark),
          tooltip: 'Open in Finder',
          onPressed: () => _openFolderInFinder(currentPath),
        ),
      ],
    );
  }

  Widget _buildTelemetryStat({
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: OllivoTheme.surfaceDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: OllivoTheme.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: OllivoTheme.mintPrimary)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 10, color: OllivoTheme.textSecondaryDark)),
        ],
      ),
    );
  }
}
