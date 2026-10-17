import 'package:flutter/material.dart';
import '../../components/ollivo_components.dart';
import '../../controllers/model_controller.dart';
import '../../models/model_catalog_item.dart';
import '../../models/rag_pipeline_recommendation.dart';
import '../../services/hardware_service.dart';
import '../../services/model_catalog_service.dart';
import '../../services/model_config_service.dart';
import '../../theme.dart';
import '../settings/model_config_dialog.dart';

class ModelLibraryView extends StatefulWidget {
  final ModelController controller;
  final void Function(String modelId)? onOpenChat;
  final ModelConfigService? modelConfigService;

  const ModelLibraryView({
    super.key,
    required this.controller,
    this.onOpenChat,
    this.modelConfigService,
  });

  @override
  State<ModelLibraryView> createState() => _ModelLibraryViewState();
}

class _ModelLibraryViewState extends State<ModelLibraryView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  ModelCatalogItem? _selectedModelForComparisonA;
  ModelCatalogItem? _selectedModelForComparisonB;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. One-Click Ollama Daemon Control & Status Bar
            _buildOllamaServerBar(context),
            const SizedBox(height: 12),

            // 2. Active Download Banner (if downloading a model)
            if (widget.controller.activeDownloadingModel != null) ...[
              _buildActiveDownloadBanner(),
              const SizedBox(height: 12),
            ],

            // 3. Main Navigation Tab Bar
            _buildTopNavigationRow(context),
            const SizedBox(height: 14),

            // 4. Tab Views: Model Catalog | RAG Stacks | Installed & Memory | Engine & Hardware Dashboard
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildCatalogTab(context),
                  _buildRagToolkitTab(context),
                  _buildInstalledAndMemoryTab(context),
                  _buildEngineDashboardTab(context),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// One-Click Ollama Server Bar with Status, Latency, and Quick Actions
  Widget _buildOllamaServerBar(BuildContext context) {
    final isOnline = widget.controller.isOllamaOnline;
    final isRecovering = widget.controller.isRecoveringDaemon;
    final latency = widget.controller.daemonLatencyMs;
    final version = widget.controller.ollamaVersion;
    final loadedCount = widget.controller.loadedModels.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: OllivoTheme.cardDark,
        borderRadius: BorderRadius.circular(OllivoTheme.radiusMd),
        border: Border.all(
          color: isOnline
              ? OllivoTheme.oliveEmerald.withValues(alpha: 0.3)
              : OllivoTheme.statusWarning.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          // Live Status Dot & Label
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOnline ? OllivoTheme.oliveEmerald : OllivoTheme.statusWarning,
              boxShadow: [
                BoxShadow(
                  color: (isOnline ? OllivoTheme.oliveEmerald : OllivoTheme.statusWarning)
                      .withValues(alpha: 0.6),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    isRecovering
                        ? 'OLLAMA STARTING...'
                        : (isOnline ? 'OLLAMA ONLINE' : 'OLLAMA STOPPED'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: isOnline ? OllivoTheme.oliveEmerald : OllivoTheme.statusWarning,
                    ),
                  ),
                  if (version != null && version.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: OllivoTheme.borderDark,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        version,
                        style: const TextStyle(fontSize: 10, color: OllivoTheme.textSecondaryDark),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    widget.controller.ollamaHost,
                    style: const TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark),
                  ),
                  if (latency != null) ...[
                    Text(
                      ' · ${latency}ms latency',
                      style: const TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark),
                    ),
                  ],
                ],
              ),
            ],
          ),

          const Spacer(),

          // Memory loaded badge
          if (isOnline && loadedCount > 0) ...[
            InkWell(
              onTap: () => _tabController.animateTo(1),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: OllivoTheme.oliveEmerald.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: OllivoTheme.oliveEmerald.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.memory, size: 14, color: OllivoTheme.oliveEmerald),
                    const SizedBox(width: 6),
                    Text(
                      '$loadedCount in VRAM',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: OllivoTheme.oliveEmerald,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],

          // Action buttons: Start / Stop / Restart / Check Connection
          if (!isOnline) ...[
            OllivoPrimaryButton(
              label: isRecovering ? 'Starting...' : 'Start Ollama',
              icon: Icons.play_arrow_rounded,
              isLoading: isRecovering,
              onPressed: isRecovering
                  ? null
                  : () async {
                      final res = await widget.controller.startOllama();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(res.message),
                          backgroundColor:
                              res.success ? OllivoTheme.oliveEmerald : OllivoTheme.statusError,
                        ),
                      );
                    },
            ),
          ] else ...[
            OllivoSecondaryButton(
              label: 'Stop',
              icon: Icons.stop_rounded,
              onPressed: isRecovering
                  ? null
                  : () async {
                      final res = await widget.controller.stopOllama();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(res.message),
                          backgroundColor:
                              res.success ? OllivoTheme.oliveEmerald : OllivoTheme.statusWarning,
                        ),
                      );
                    },
            ),
            const SizedBox(width: 8),
            OllivoSecondaryButton(
              label: 'Restart',
              icon: Icons.restart_alt_rounded,
              onPressed: isRecovering
                  ? null
                  : () async {
                      final res = await widget.controller.restartOllama();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(res.message),
                          backgroundColor:
                              res.success ? OllivoTheme.oliveEmerald : OllivoTheme.statusError,
                        ),
                      );
                    },
            ),
          ],
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.sync_rounded, size: 18),
            color: OllivoTheme.textSecondaryDark,
            tooltip: 'Check Connection & Refresh Inventory',
            onPressed: () async {
              await widget.controller.checkConnection();
            },
          ),
        ],
      ),
    );
  }

  /// Top Navigation Bar with Tabs & Header Actions
  Widget _buildTopNavigationRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          width: 630,
          decoration: BoxDecoration(
            color: OllivoTheme.surfaceDark,
            borderRadius: BorderRadius.circular(OllivoTheme.radiusSm),
            border: Border.all(color: OllivoTheme.borderDark),
          ),
          child: TabBar(
            controller: _tabController,
            indicatorColor: OllivoTheme.oliveEmerald,
            labelColor: Colors.white,
            unselectedLabelColor: OllivoTheme.textSecondaryDark,
            tabs: [
              Tab(text: 'Catalog (${widget.controller.filteredCatalogModels.length})'),
              Tab(text: 'RAG Stacks (${ModelCatalogService.getRagPipelineRecommendations().length})'),
              const Tab(text: 'Installed & Memory'),
              const Tab(text: 'Engine Dashboard'),
            ],
          ),
        ),
        Row(
          children: [
            OllivoSecondaryButton(
              label: widget.controller.isDiscovering ? 'Syncing...' : 'Sync Hub',
              icon: Icons.travel_explore_rounded,
              onPressed: widget.controller.isDiscovering
                  ? null
                  : () async {
                      await widget.controller.refreshDiscovery();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            widget.controller.discoveryMessage ??
                                'Catalog discovery synced (${widget.controller.catalogModels.length} models available)',
                          ),
                          backgroundColor: OllivoTheme.oliveEmerald,
                        ),
                      );
                    },
            ),
            const SizedBox(width: 8),
            OllivoPrimaryButton(
              label: 'Pull Custom Tag',
              icon: Icons.cloud_download_outlined,
              onPressed: () => _showPullCustomModelDialog(context),
            ),
            const SizedBox(width: 8),
            OllivoSecondaryButton(
              label: 'Compare',
              icon: Icons.compare_arrows_rounded,
              onPressed: () => _showComparisonDialog(context),
            ),
          ],
        ),
      ],
    );
  }

  /// Active Download Banner
  Widget _buildActiveDownloadBanner() {
    final progress = widget.controller.downloadProgress;
    final modelId = widget.controller.activeDownloadingModel ?? '';
    final pct = progress?.progressPercentage ?? 0.0;
    final statusText = progress?.formattedProgress ?? 'Downloading...';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OllivoTheme.oliveEmerald.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(OllivoTheme.radiusMd),
        border: Border.all(color: OllivoTheme.oliveEmerald.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(OllivoTheme.oliveEmerald),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Downloading $modelId...',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              OllivoSecondaryButton(
                label: 'Cancel Download',
                icon: Icons.close,
                onPressed: widget.controller.cancelDownload,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ShimmerProgressTrack(
            value: pct > 0 ? pct : null,
            height: 6,
          ),
          const SizedBox(height: 8),
          Text(
            statusText,
            style: const TextStyle(fontSize: 12, color: OllivoTheme.textSecondaryDark),
          ),
        ],
      ),
    );
  }

  /// TAB 1: Massive Searchable Model Catalog (160+ models)
  Widget _buildCatalogTab(BuildContext context) {
    final filtered = widget.controller.filteredCatalogModels;
    final categories = [
      'All',
      'AirLLM (70B+)',
      'Lightweight',
      'Medium',
      'Coding',
      'Reasoning',
      'Vision',
      'Embeddings',
      'Reranking',
      'Speech / Audio',
      'Structured Data',
      'OCR & Document',
      'Multilingual Translation',
      'Image Generation',
      'Video',
    ];
    final sizeTiers = [
      'All',
      'Ultra-light',
      'Lightweight',
      'Medium',
      'Advanced',
      'Large',
      'Extra-large',
    ];
    final ragRoles = [
      'All',
      'generator',
      'embedding',
      'reranker',
      'document_parser',
      'vision_rag',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Search Bar & Status Filters
        Row(
          children: [
            Expanded(
              child: OllivoTextField(
                controller: _searchController,
                hintText: 'Search 160+ models by name, tag, family, provider, capability, or task...',
                prefixIcon: const Icon(Icons.search, color: OllivoTheme.textSecondaryDark),
                onChanged: (val) => widget.controller.setCatalogSearchQuery(val),
              ),
            ),
            const SizedBox(width: 12),
            // Hardware Compatibility Toggle
            FilterChip(
              avatar: Icon(
                Icons.memory,
                size: 14,
                color: widget.controller.hardwareCompatibleOnly
                    ? OllivoTheme.oliveEmerald
                    : OllivoTheme.textSecondaryDark,
              ),
              label: Text(
                'Compatible (${widget.controller.hardwareProfile?.totalRamGb.toStringAsFixed(0) ?? "16"}GB RAM)',
                style: const TextStyle(fontSize: 12),
              ),
              selected: widget.controller.hardwareCompatibleOnly,
              selectedColor: OllivoTheme.oliveEmerald.withValues(alpha: 0.2),
              checkmarkColor: OllivoTheme.oliveEmerald,
              backgroundColor: OllivoTheme.cardDark,
              side: BorderSide(
                color: widget.controller.hardwareCompatibleOnly
                    ? OllivoTheme.oliveEmerald
                    : OllivoTheme.borderDark,
              ),
              onSelected: (val) => widget.controller.setHardwareCompatibleOnly(val),
            ),
            const SizedBox(width: 8),
            // Status Filter Dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: OllivoTheme.cardDark,
                borderRadius: BorderRadius.circular(OllivoTheme.radiusSm),
                border: Border.all(color: OllivoTheme.borderDark),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: widget.controller.selectedStatus,
                  dropdownColor: OllivoTheme.surfaceDark,
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                  items: ['All', 'Installed', 'Not Installed', 'Favorites'].map((status) {
                    return DropdownMenuItem(value: status, child: Text(status));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) widget.controller.setSelectedStatus(val);
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Sort Dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: OllivoTheme.cardDark,
                borderRadius: BorderRadius.circular(OllivoTheme.radiusSm),
                border: Border.all(color: OllivoTheme.borderDark),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: widget.controller.selectedSortBy,
                  dropdownColor: OllivoTheme.surfaceDark,
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                  items: ['Popularity', 'Name', 'Size', 'Context'].map((sort) {
                    return DropdownMenuItem(value: sort, child: Text('Sort: $sort'));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) widget.controller.setSelectedSortBy(val);
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 2. Category Filter Pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: categories.map((cat) {
              final isSel = widget.controller.selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: FilterChip(
                  label: Text(cat),
                  selected: isSel,
                  selectedColor: OllivoTheme.oliveEmerald.withValues(alpha: 0.2),
                  checkmarkColor: OllivoTheme.oliveEmerald,
                  backgroundColor: OllivoTheme.cardDark,
                  side: BorderSide(
                    color: isSel ? OllivoTheme.oliveEmerald : OllivoTheme.borderDark,
                  ),
                  onSelected: (_) => widget.controller.setSelectedCategory(cat),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),

        // 3. Multi-Dimensional Size Tier & RAG Role Pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              const Padding(
                padding: EdgeInsets.only(right: 6.0),
                child: Text('Size Tier:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: OllivoTheme.textSecondaryDark)),
              ),
              ...sizeTiers.map((tier) {
                final isSel = widget.controller.selectedSizeTier == tier;
                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: FilterChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(tier, style: const TextStyle(fontSize: 11)),
                    selected: isSel,
                    selectedColor: OllivoTheme.oliveEmerald.withValues(alpha: 0.2),
                    checkmarkColor: OllivoTheme.oliveEmerald,
                    backgroundColor: OllivoTheme.cardDark,
                    side: BorderSide(
                      color: isSel ? OllivoTheme.oliveEmerald : OllivoTheme.borderDark,
                    ),
                    onSelected: (_) => widget.controller.setSelectedSizeTier(tier),
                  ),
                );
              }),
              const SizedBox(width: 8),
              Container(width: 1, height: 16, color: OllivoTheme.borderDark),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(right: 6.0),
                child: Text('RAG Role:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: OllivoTheme.textSecondaryDark)),
              ),
              ...ragRoles.map((role) {
                final isSel = widget.controller.selectedRagRole == role;
                final displayLabel = role == 'All' ? 'All Roles' : role.replaceAll('_', ' ');
                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: FilterChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(displayLabel, style: const TextStyle(fontSize: 11)),
                    selected: isSel,
                    selectedColor: OllivoTheme.oliveEmerald.withValues(alpha: 0.2),
                    checkmarkColor: OllivoTheme.oliveEmerald,
                    backgroundColor: OllivoTheme.cardDark,
                    side: BorderSide(
                      color: isSel ? OllivoTheme.oliveEmerald : OllivoTheme.borderDark,
                    ),
                    onSelected: (_) => widget.controller.setSelectedRagRole(role),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 4. Results Count Bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Showing ${filtered.length} verified models',
              style: const TextStyle(fontSize: 12, color: OllivoTheme.textSecondaryDark),
            ),
            if (widget.controller.catalogSearchQuery.isNotEmpty ||
                widget.controller.selectedCategory != 'All' ||
                widget.controller.selectedSizeTier != 'All' ||
                widget.controller.selectedRagRole != 'All' ||
                widget.controller.selectedStatus != 'All' ||
                widget.controller.hardwareCompatibleOnly) ...[
              TextButton(
                onPressed: () {
                  _searchController.clear();
                  widget.controller.resetAllFilters();
                },
                child: const Text('Reset All Filters', style: TextStyle(fontSize: 12, color: OllivoTheme.oliveEmerald)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),

        // 4. Model Cards Grid/List
        Expanded(
          child: filtered.isEmpty
              ? const OllivoEmptyState(
                  icon: Icons.search_off,
                  title: 'No models match the filter',
                  description: 'Try adjusting your search criteria, category pill, or compatibility toggle.',
                )
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return _buildCatalogModelCard(context, item);
                  },
                ),
        ),
      ],
    );
  }

  /// Individual Model Card in Catalog
  Widget _buildCatalogModelCard(BuildContext context, ModelCatalogItem item) {
    final isInstalled = widget.controller.isInstalled(item.id);
    final isActive = widget.controller.activeModel == item.id ||
        widget.controller.activeModel.startsWith('${item.id}:');
    final isDownloading = widget.controller.activeDownloadingModel == item.id;
    final isLoaded = widget.controller.isModelLoaded(item.id);
    final isFav = widget.controller.isFavorite(item.id);

    final hardware = widget.controller.hardwareProfile;
    final suitability = hardware?.assessModelSuitability(estimatedRamGb: item.estimatedMemoryGb);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: OllivoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header: Name, Provider, Badges, Actions
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon Avatar
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(item.category).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_getCategoryIcon(item.category), color: _getCategoryColor(item.category), size: 22),
                ),
                const SizedBox(width: 14),

                // Name & Metadata Chips
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.name,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Category pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: OllivoTheme.borderDark,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.category,
                              style: const TextStyle(fontSize: 10, color: OllivoTheme.textSecondaryDark),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Size Tier pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: OllivoTheme.borderDark,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.sizeTier,
                              style: const TextStyle(fontSize: 10, color: Colors.white70),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Parameter Count pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: OllivoTheme.borderDark,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.parameterCount,
                              style: const TextStyle(fontSize: 10, color: OllivoTheme.oliveEmerald),
                            ),
                          ),
                          if (item.isMoE) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: OllivoTheme.oliveEmerald.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: OllivoTheme.oliveEmerald.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                'MoE (${item.activeParameterCount ?? "Active"})',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: OllivoTheme.oliveEmerald),
                              ),
                            ),
                          ],
                          const SizedBox(width: 6),
                          // Context pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: OllivoTheme.borderDark,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.formattedContext,
                              style: const TextStyle(fontSize: 10, color: OllivoTheme.textSecondaryDark),
                            ),
                          ),
                          if (item.ragRole != 'none') ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.tealAccent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                'RAG: ${item.ragRole.replaceAll('_', ' ')}',
                                style: const TextStyle(fontSize: 10, color: Colors.tealAccent),
                              ),
                            ),
                          ],
                          if (item.isAppleSiliconOptimized) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: OllivoTheme.borderDark,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.apple, size: 11, color: Colors.white70),
                                  SizedBox(width: 2),
                                  Text('Metal', style: TextStyle(fontSize: 10, color: Colors.white70)),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.provider} · ${item.family} · ${item.quantization}',
                        style: const TextStyle(fontSize: 12, color: OllivoTheme.textSecondaryDark),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.description,
                        style: const TextStyle(fontSize: 13, color: Colors.white70),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 14),

                // Favorite Star Button
                IconButton(
                  icon: Icon(
                    isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: isFav ? Colors.amber : OllivoTheme.textSecondaryDark,
                    size: 20,
                  ),
                  tooltip: isFav ? 'Remove from Favorites' : 'Add to Favorites',
                  onPressed: () => widget.controller.toggleFavorite(item.id),
                ),

                // Action CTA
                if (isActive) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: OllivoTheme.oliveEmerald.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: OllivoTheme.oliveEmerald),
                    ),
                    child: const Text('ACTIVE', style: TextStyle(color: OllivoTheme.oliveEmerald, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ] else if (isInstalled) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isLoaded) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: OllivoTheme.oliveEmerald.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('In VRAM', style: TextStyle(color: OllivoTheme.oliveEmerald, fontSize: 11)),
                        ),
                        const SizedBox(width: 6),
                        OllivoSecondaryButton(
                          label: 'Unload',
                          icon: Icons.eject_rounded,
                          onPressed: () => widget.controller.unloadModel(item.id),
                        ),
                      ] else ...[
                        OllivoSecondaryButton(
                          label: 'Preload',
                          icon: Icons.memory,
                          onPressed: () => widget.controller.preloadModel(item.id),
                        ),
                      ],
                      const SizedBox(width: 8),
                      OllivoPrimaryButton(
                        label: 'Chat',
                        icon: Icons.chat_bubble_outline_rounded,
                        onPressed: () {
                          widget.controller.selectActiveModel(item.id);
                          widget.onOpenChat?.call(item.id);
                        },
                      ),
                    ],
                  ),
                ] else if (item.isOllamaNative) ...[
                  OllivoSecondaryButton(
                    label: isDownloading ? 'Downloading...' : 'Download (${item.estimatedDiskSize})',
                    icon: Icons.download_rounded,
                    onPressed: isDownloading ? null : () => widget.controller.downloadModel(item.id),
                  ),
                ] else ...[
                  OllivoSecondaryButton(
                    label: 'External Engine',
                    icon: Icons.extension_outlined,
                    onPressed: () => _showExternalEngineInfo(context, item),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 12),

            // Bottom Badges: Memory Guidance, Hardware Suitability, Capabilities, Details link
            Row(
              children: [
                // Memory Badge
                Builder(
                  builder: (context) {
                    final mem = ModelController.getMemoryGuidance(
                      sizeString: item.estimatedDiskSize,
                      modelId: item.id,
                    );
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: mem.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: mem.color.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.speed_rounded, size: 12, color: mem.color),
                          const SizedBox(width: 5),
                          Text(
                            mem.label,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: mem.color),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(width: 8),

                // Hardware Suitability Badge
                if (suitability != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _getSuitabilityColor(suitability.level).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _getSuitabilityColor(suitability.level).withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      suitability.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _getSuitabilityColor(suitability.level),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // Capabilities Chips
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: item.capabilities.map((cap) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: OllivoTheme.cardDark,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: OllivoTheme.borderDark),
                            ),
                            child: Text(
                              '#$cap',
                              style: const TextStyle(fontSize: 10, color: OllivoTheme.textSecondaryDark),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                // Inspect Details action
                TextButton.icon(
                  icon: const Icon(Icons.info_outline, size: 14),
                  label: const Text('Details', style: TextStyle(fontSize: 12)),
                  onPressed: () => _showModelDetailsDialog(context, item),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// TAB 2: Installed Models on Disk & Live Loaded Models in Memory
  Widget _buildInstalledAndMemoryTab(BuildContext context) {
    final installed = widget.controller.installedModels;
    final loaded = widget.controller.loadedModels;

    if (!widget.controller.isOllamaOnline) {
      return OllivoEmptyState(
        icon: Icons.cloud_off,
        title: 'Ollama is Offline',
        description: 'Cannot query installed models or VRAM allocations because the local Ollama daemon is unreachable.',
        actionLabel: 'Start Ollama',
        onAction: widget.controller.startOllama,
      );
    }

    return ListView(
      children: [
        // Section A: Models Loaded in VRAM / RAM
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: OllivoTheme.cardDark,
            borderRadius: BorderRadius.circular(OllivoTheme.radiusMd),
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
                      const Icon(Icons.memory, color: OllivoTheme.oliveEmerald, size: 20),
                      const SizedBox(width: 10),
                      const Text(
                        'Active Models in Memory / VRAM',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: loaded.isNotEmpty
                              ? OllivoTheme.oliveEmerald.withValues(alpha: 0.2)
                              : OllivoTheme.borderDark,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${loaded.length} Loaded',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: loaded.isNotEmpty
                                ? OllivoTheme.oliveEmerald
                                : OllivoTheme.textSecondaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (loaded.isNotEmpty) ...[
                    OllivoSecondaryButton(
                      label: 'Unload All',
                      icon: Icons.eject_rounded,
                      onPressed: () async {
                        for (final m in loaded) {
                          await widget.controller.unloadModel(m.name);
                        }
                      },
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              if (loaded.isEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'No models currently loaded in memory. Models are loaded on-demand during chat or preloaded for instant responses.',
                    style: TextStyle(fontSize: 13, color: OllivoTheme.textSecondaryDark),
                  ),
                ),
              ] else ...[
                ...loaded.map((m) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: OllivoTheme.surfaceDark,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: OllivoTheme.oliveEmerald.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.bolt, color: OllivoTheme.oliveEmerald, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'VRAM: ${m.formattedVram}  •  Expires: ${m.expiresAt.length > 16 ? m.expiresAt.substring(11, 16) : m.expiresAt}  •  ${m.parameterSize}',
                                  style: const TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark),
                                ),
                              ],
                            ),
                          ),
                          OllivoSecondaryButton(
                            label: 'Unload',
                            icon: Icons.eject_rounded,
                            onPressed: () => widget.controller.unloadModel(m.name),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Section B: Models Installed on Disk
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Installed Models on Disk (${installed.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            OllivoSecondaryButton(
              label: 'Refresh Inventory',
              icon: Icons.refresh,
              onPressed: widget.controller.refreshModels,
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (installed.isEmpty) ...[
          OllivoEmptyState(
            icon: Icons.folder_open,
            title: 'No Local Models Installed',
            description: 'Download a model from the Model Catalog tab to start chatting offline.',
            actionLabel: 'Open Model Catalog',
            onAction: () => _tabController.animateTo(0),
          ),
        ] else ...[
          ...installed.map((item) {
            final isActive = widget.controller.activeModel == item.name ||
                widget.controller.activeModel.startsWith('${item.name}:');
            final isLoaded = widget.controller.isModelLoaded(item.name);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: OllivoCard(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isActive
                            ? OllivoTheme.oliveEmerald.withValues(alpha: 0.2)
                            : OllivoTheme.borderDark,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.memory,
                        color: isActive ? OllivoTheme.oliveEmerald : OllivoTheme.textSecondaryDark,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              if (isActive) ...[
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: OllivoTheme.oliveEmerald.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text('ACTIVE', style: TextStyle(color: OllivoTheme.oliveEmerald, fontWeight: FontWeight.bold, fontSize: 11)),
                                ),
                              ],
                              if (isLoaded) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: OllivoTheme.borderDark,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text('IN VRAM', style: TextStyle(color: OllivoTheme.oliveEmerald, fontSize: 10)),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Size: ${item.formattedSize}  •  Digest: ${item.digest.substring(0, item.digest.length > 12 ? 12 : item.digest.length)}...',
                            style: const TextStyle(fontSize: 12, color: OllivoTheme.textSecondaryDark),
                          ),
                        ],
                      ),
                    ),
                    if (isLoaded) ...[
                      OllivoSecondaryButton(
                        label: 'Unload',
                        icon: Icons.eject_rounded,
                        onPressed: () => widget.controller.unloadModel(item.name),
                      ),
                      const SizedBox(width: 8),
                    ] else ...[
                      OllivoSecondaryButton(
                        label: 'Preload',
                        icon: Icons.memory,
                        onPressed: () => widget.controller.preloadModel(item.name),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (!isActive) ...[
                      OllivoPrimaryButton(
                        label: 'Use Model',
                        icon: Icons.check_circle_outline,
                        onPressed: () => widget.controller.selectActiveModel(item.name),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (widget.modelConfigService != null) ...[
                      IconButton(
                        icon: const Icon(Icons.tune_rounded, color: OllivoTheme.mintPrimary),
                        tooltip: 'Configure Model Parameters (${item.name})',
                        onPressed: () {
                          ModelConfigDialog.show(
                            context,
                            modelId: item.name,
                            modelConfigService: widget.modelConfigService!,
                          );
                        },
                      ),
                      const SizedBox(width: 4),
                    ],
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: OllivoTheme.statusError),
                      tooltip: 'Delete Model',
                      onPressed: () => _confirmDeleteModel(context, item.name),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  /// TAB 3: Engine Dashboard & Hardware Telemetry
  Widget _buildEngineDashboardTab(BuildContext context) {
    final hardware = widget.controller.hardwareProfile;
    final providers = widget.controller.providerRegistry.providers;

    return ListView(
      children: [
        // 1. Hardware Profile Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: OllivoTheme.cardDark,
            borderRadius: BorderRadius.circular(OllivoTheme.radiusMd),
            border: Border.all(color: OllivoTheme.borderDark),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.laptop_mac_rounded, color: OllivoTheme.oliveEmerald),
                  SizedBox(width: 10),
                  Text('System Hardware Telemetry', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 20,
                runSpacing: 14,
                children: [
                  _buildHardwareStatItem('System RAM', '${hardware?.totalRamGb.toStringAsFixed(0) ?? "16"} GB Unified Memory', Icons.memory),
                  _buildHardwareStatItem('Processor', '${hardware?.cpuArch ?? "ARM64"} (${hardware?.cpuCores ?? 8} Cores)', Icons.developer_board),
                  _buildHardwareStatItem('Graphics Engine', hardware?.gpuName ?? 'Apple Silicon GPU', Icons.videogame_asset_outlined),
                  _buildHardwareStatItem('Platform', hardware?.osName.toUpperCase() ?? 'MACOS', Icons.computer),
                  _buildHardwareStatItem('Hardware Tier', hardware?.tierLabel ?? 'Balanced Tier', Icons.verified_user_outlined),
                  _buildHardwareStatItem('Disk Space', hardware?.diskSummary ?? 'Verified Local Storage', Icons.storage_rounded),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // 2. Ollama Daemon Runtime Diagnostics
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: OllivoTheme.cardDark,
            borderRadius: BorderRadius.circular(OllivoTheme.radiusMd),
            border: Border.all(color: OllivoTheme.borderDark),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.terminal_rounded, color: OllivoTheme.oliveEmerald),
                  SizedBox(width: 10),
                  Text('Ollama Daemon Diagnostics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 20,
                runSpacing: 10,
                children: [
                  _buildDiagnosticLine('Endpoint URL', widget.controller.ollamaHost),
                  _buildDiagnosticLine('Server Status', widget.controller.isOllamaOnline ? 'Healthy & Connected' : 'Offline / Unreachable'),
                  _buildDiagnosticLine('API Version', widget.controller.ollamaVersion ?? 'Unknown'),
                  _buildDiagnosticLine('Latency', '${widget.controller.daemonLatencyMs ?? "--"} ms'),
                  _buildDiagnosticLine('Installed Models', '${widget.controller.installedModels.length} models'),
                  _buildDiagnosticLine('Loaded in Memory', '${widget.controller.loadedModels.length} models'),
                ],
              ),
              if (widget.controller.recoveryStatusMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: OllivoTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: OllivoTheme.borderDark),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: OllivoTheme.oliveEmerald),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Last daemon action: ${widget.controller.recoveryStatusMessage}',
                          style: const TextStyle(fontSize: 12, color: OllivoTheme.textSecondaryDark),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 18),

        // 3. AirLLM Layer-Streaming Daemon Runtime Diagnostics
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: OllivoTheme.cardDark,
            borderRadius: BorderRadius.circular(OllivoTheme.radiusMd),
            border: Border.all(color: OllivoTheme.borderDark),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.layers_outlined, color: OllivoTheme.mintPrimary),
                  const SizedBox(width: 10),
                  const Text('AirLLM Layer-Streaming Diagnostics (70B+ Local)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: widget.controller.isAirLLMOnline
                          ? OllivoTheme.mintPrimary.withValues(alpha: 0.2)
                          : OllivoTheme.borderDark,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      widget.controller.isAirLLMOnline ? 'ONLINE & READY' : 'OFFLINE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: widget.controller.isAirLLMOnline ? OllivoTheme.mintPrimary : OllivoTheme.textSecondaryDark,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 20,
                runSpacing: 10,
                children: [
                  _buildDiagnosticLine('Endpoint URL', widget.controller.airllmHost),
                  _buildDiagnosticLine('Engine Status', widget.controller.isAirLLMOnline ? 'Ready for Streaming' : 'Stopped / Offline'),
                  _buildDiagnosticLine('Active Model', widget.controller.airllmActiveModel ?? 'None Loaded'),
                  _buildDiagnosticLine('Latency', '${widget.controller.airllmLatencyMs ?? "--"} ms'),
                  _buildDiagnosticLine('Quantization', widget.controller.airllmCompression.toUpperCase()),
                  _buildDiagnosticLine('Compute Device', widget.controller.airllmDevice.toUpperCase()),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  if (!widget.controller.isAirLLMOnline)
                    OllivoPrimaryButton(
                      label: widget.controller.isAirLLMBusy ? 'Starting...' : 'Start AirLLM Daemon',
                      icon: Icons.play_arrow_rounded,
                      isLoading: widget.controller.isAirLLMBusy,
                      onPressed: widget.controller.isAirLLMBusy
                          ? null
                          : () async {
                              final res = await widget.controller.startAirLLMDaemon();
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(res.message),
                                  backgroundColor: res.success ? OllivoTheme.oliveEmerald : OllivoTheme.statusError,
                                ),
                              );
                            },
                    )
                  else ...[
                    OllivoSecondaryButton(
                      label: 'Stop Daemon',
                      icon: Icons.stop_rounded,
                      onPressed: () async {
                        final res = await widget.controller.stopAirLLMDaemon();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(res.message),
                            backgroundColor: res.success ? OllivoTheme.oliveEmerald : OllivoTheme.statusError,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    OllivoSecondaryButton(
                      label: 'Restart',
                      icon: Icons.refresh_rounded,
                      onPressed: () async {
                        final res = await widget.controller.restartAirLLMDaemon();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(res.message),
                            backgroundColor: res.success ? OllivoTheme.oliveEmerald : OllivoTheme.statusError,
                          ),
                        );
                      },
                    ),
                  ],
                  const SizedBox(width: 8),
                  OllivoSecondaryButton(
                    label: 'Check Status',
                    icon: Icons.network_check_rounded,
                    onPressed: () => widget.controller.checkAirLLMStatus(),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // 4. Multi-Backend Provider Architecture Cards
        const Text('Modular Inference Providers', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),

        for (final p in providers)
          Padding(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: OllivoTheme.cardDark,
                borderRadius: BorderRadius.circular(OllivoTheme.radiusSm),
                border: Border.all(color: OllivoTheme.borderDark),
              ),
              child: Row(
                children: [
                  Icon(
                    p.id == 'ollama' ? Icons.smart_toy_outlined : Icons.extension_outlined,
                    color: p.id == 'ollama' ? OllivoTheme.oliveEmerald : OllivoTheme.textSecondaryDark,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: (p.id == 'ollama' && widget.controller.isOllamaOnline)
                                    ? OllivoTheme.oliveEmerald.withValues(alpha: 0.2)
                                    : OllivoTheme.borderDark,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                (p.id == 'ollama' && widget.controller.isOllamaOnline) ? 'ONLINE' : 'OPTIONAL ENGINE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: (p.id == 'ollama' && widget.controller.isOllamaOnline)
                                      ? OllivoTheme.oliveEmerald
                                      : OllivoTheme.textSecondaryDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${p.description}  •  ${p.endpointUrl}',
                          style: const TextStyle(fontSize: 12, color: OllivoTheme.textSecondaryDark),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHardwareStatItem(String label, String value, IconData icon) {
    return SizedBox(
      width: 220,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: OllivoTheme.textSecondaryDark),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticLine(String label, String value) {
    return SizedBox(
      width: 280,
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 12, color: OllivoTheme.textSecondaryDark)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String cat) {
    switch (cat) {
      case 'Lightweight':
        return OllivoTheme.oliveEmerald;
      case 'Medium':
        return Colors.blueAccent;
      case 'Coding':
        return Colors.cyanAccent;
      case 'Reasoning':
        return Colors.purpleAccent;
      case 'Vision':
        return Colors.orangeAccent;
      case 'Embeddings':
        return Colors.tealAccent;
      case 'Reranking':
        return Colors.deepPurpleAccent;
      case 'Speech / Audio':
      case 'Audio':
        return Colors.amberAccent;
      case 'Structured Data':
        return Colors.tealAccent;
      case 'OCR & Document':
        return Colors.limeAccent;
      case 'Multilingual Translation':
        return Colors.lightBlueAccent;
      case 'Image Generation':
        return Colors.pinkAccent;
      case 'Video':
        return Colors.indigoAccent;
      default:
        return OllivoTheme.oliveEmerald;
    }
  }

  IconData _getCategoryIcon(String cat) {
    switch (cat) {
      case 'Lightweight':
        return Icons.bolt_rounded;
      case 'Medium':
        return Icons.auto_awesome;
      case 'Coding':
        return Icons.code_rounded;
      case 'Reasoning':
        return Icons.psychology_rounded;
      case 'Vision':
        return Icons.remove_red_eye_rounded;
      case 'Embeddings':
        return Icons.hub_rounded;
      case 'Reranking':
        return Icons.sort_rounded;
      case 'Speech / Audio':
      case 'Audio':
        return Icons.mic_rounded;
      case 'Structured Data':
        return Icons.table_chart_rounded;
      case 'OCR & Document':
        return Icons.document_scanner_rounded;
      case 'Multilingual Translation':
        return Icons.translate_rounded;
      case 'Image Generation':
        return Icons.palette_rounded;
      case 'Video':
        return Icons.movie_rounded;
      default:
        return Icons.auto_awesome;
    }
  }

  Color _getSuitabilityColor(SuitabilityLevel level) {
    switch (level) {
      case SuitabilityLevel.optimal:
        return OllivoTheme.oliveEmerald;
      case SuitabilityLevel.compatible:
        return OllivoTheme.oliveEmerald;
      case SuitabilityLevel.tight:
        return OllivoTheme.statusWarning;
      case SuitabilityLevel.insufficient:
        return OllivoTheme.statusError;
    }
  }

  /// TAB 2: Pre-Engineered Local RAG Stacks & Pipeline Recommendations
  Widget _buildRagToolkitTab(BuildContext context) {
    final recommendations = ModelCatalogService.getRagPipelineRecommendations();

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // Hero / Architecture Banner
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: OllivoTheme.cardDark,
            borderRadius: BorderRadius.circular(OllivoTheme.radiusMd),
            border: Border.all(color: OllivoTheme.oliveEmerald.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: OllivoTheme.oliveEmerald.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.account_tree_rounded, color: OllivoTheme.oliveEmerald, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pre-Engineered Local RAG Pipelines & Recommendation Stacks',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Complete Retrieval-Augmented Generation stacks configured for local Apple Silicon & desktop execution. Combines generator, embedding, reranker, and document parser models with zero external cloud API latency.',
                          style: TextStyle(fontSize: 13, color: OllivoTheme.textSecondaryDark),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: OllivoTheme.borderDark),
              const SizedBox(height: 12),
              // Highlights / Badges Row
              Row(
                children: [
                  _buildRagStatBadge(Icons.hub_rounded, '6 Tuned Stacks', 'From 8GB to 64GB RAM'),
                  const SizedBox(width: 12),
                  _buildRagStatBadge(Icons.security_rounded, '100% Offline', 'Private SQLite vector storage'),
                  const SizedBox(width: 12),
                  _buildRagStatBadge(Icons.speed_rounded, 'Apple Silicon Optimized', 'Metal & Unified Memory acceleration'),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        Text(
          'Selectable Hardware & Domain Stacks (${recommendations.length})',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        ...recommendations.map((rec) => _buildRagRecommendationCard(context, rec)),
      ],
    );
  }

  Widget _buildRagStatBadge(IconData icon, String title, String subtitle) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: OllivoTheme.surfaceDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: OllivoTheme.borderDark),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: OllivoTheme.oliveEmerald),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRagRecommendationCard(BuildContext context, RagPipelineRecommendation rec) {
    final genInstalled = widget.controller.isInstalled(rec.generatorModelId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: OllivoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Title, Subtitle, Hardware badge, Quick Use
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            rec.title,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: OllivoTheme.oliveEmerald.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: OllivoTheme.oliveEmerald.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              '~${rec.estimatedTotalMemoryGb} GB RAM',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: OllivoTheme.oliveEmerald),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        rec.subtitle,
                        style: const TextStyle(fontSize: 13, color: OllivoTheme.textSecondaryDark),
                      ),
                    ],
                  ),
                ),
                // Action: Use as Active Stack
                OllivoPrimaryButton(
                  label: genInstalled ? 'Activate Generator' : 'Download Stack Models',
                  icon: genInstalled ? Icons.check_circle_outline : Icons.download_rounded,
                  onPressed: () {
                    if (genInstalled) {
                      widget.controller.selectActiveModel(rec.generatorModelId);
                      widget.onOpenChat?.call(rec.generatorModelId);
                    } else {
                      widget.controller.downloadModel(rec.generatorModelId);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              rec.description,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
            const SizedBox(height: 12),
            // Hardware Requirements Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: OllivoTheme.surfaceDark,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: OllivoTheme.borderDark),
              ),
              child: Row(
                children: [
                  const Icon(Icons.memory, size: 14, color: OllivoTheme.textSecondaryDark),
                  const SizedBox(width: 8),
                  Text(
                    'Hardware: ${rec.targetHardware}  •  Quantization: ${rec.recommendedQuantization}',
                    style: const TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 4 Component Columns
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPipelineComponentBox(
                  context,
                  role: 'GENERATOR',
                  modelId: rec.generatorModelId,
                  icon: Icons.chat_bubble_outline_rounded,
                  color: OllivoTheme.oliveEmerald,
                ),
                const SizedBox(width: 8),
                _buildPipelineComponentBox(
                  context,
                  role: 'EMBEDDING',
                  modelId: rec.embeddingModelId,
                  icon: Icons.hub_rounded,
                  color: Colors.tealAccent,
                ),
                const SizedBox(width: 8),
                _buildPipelineComponentBox(
                  context,
                  role: 'RERANKER',
                  modelId: rec.rerankerModelId ?? 'Cosine Similarity Top-K',
                  icon: Icons.sort_rounded,
                  color: Colors.deepPurpleAccent,
                  isOptional: rec.rerankerModelId == null,
                ),
                const SizedBox(width: 8),
                _buildPipelineComponentBox(
                  context,
                  role: 'DOC PARSER / OCR',
                  modelId: rec.documentParserModelId ?? 'PDF/DOCX Text Extractor',
                  icon: Icons.document_scanner_rounded,
                  color: Colors.limeAccent,
                  isOptional: rec.documentParserModelId == null,
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Supported document types & Key strengths
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Supported Document Types:', style: TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: rec.supportedDocumentTypes.map((docType) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: OllivoTheme.surfaceDark,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: OllivoTheme.borderDark),
                            ),
                            child: Text(docType, style: const TextStyle(fontSize: 10, color: Colors.white70)),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Stack Strengths:', style: TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark)),
                      const SizedBox(height: 4),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: rec.keyStrengths.map((str) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.check_circle_outline, size: 12, color: OllivoTheme.oliveEmerald),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(str, style: const TextStyle(fontSize: 11, color: Colors.white70)),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPipelineComponentBox(
    BuildContext context, {
    required String role,
    required String modelId,
    required IconData icon,
    required Color color,
    bool isOptional = false,
  }) {
    final item = ModelCatalogService.getModelById(modelId);
    final isInstalled = widget.controller.isInstalled(modelId);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: OllivoTheme.surfaceDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: OllivoTheme.borderDark),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                Text(
                  role,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              item?.name ?? modelId,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              item?.parameterCount ?? (isOptional ? 'Built-in Engine' : 'Specialized'),
              style: const TextStyle(fontSize: 10, color: OllivoTheme.textSecondaryDark),
            ),
            const SizedBox(height: 8),
            if (item != null) ...[
              if (isInstalled) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: OllivoTheme.oliveEmerald.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('Installed', style: TextStyle(fontSize: 10, color: OllivoTheme.oliveEmerald, fontWeight: FontWeight.bold)),
                ),
              ] else if (item.isOllamaNative) ...[
                InkWell(
                  onTap: () => widget.controller.downloadModel(item.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: OllivoTheme.cardDark,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: OllivoTheme.borderDark),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.download, size: 10, color: OllivoTheme.oliveEmerald),
                        const SizedBox(width: 3),
                        Text('Get (${item.estimatedDiskSize})', style: const TextStyle(fontSize: 10, color: OllivoTheme.oliveEmerald)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  /// Model Details Modal Dialog with 25+ Schema Fields & Quantizations
  void _showModelDetailsDialog(BuildContext context, ModelCatalogItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: OllivoTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OllivoTheme.radiusMd),
          side: const BorderSide(color: OllivoTheme.borderDark),
        ),
        title: Row(
          children: [
            Icon(_getCategoryIcon(item.category), color: _getCategoryColor(item.category)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${item.name} (${item.id})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 640,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.description, style: const TextStyle(fontSize: 13, color: Colors.white70)),
                const SizedBox(height: 16),
                const Divider(color: OllivoTheme.borderDark),
                const SizedBox(height: 10),
                _buildDetailRow('Provider', item.provider),
                _buildDetailRow('Family', item.family),
                _buildDetailRow('Category', item.category),
                _buildDetailRow('Size Tier', item.sizeTier),
                _buildDetailRow('Architecture', item.architecture),
                if (item.isMoE)
                  _buildDetailRow('MoE Active Params', '${item.activeParameterCount ?? "Sparse"} active (Total: ${item.parameterCount})'),
                _buildDetailRow('Inference Backend', item.backend),
                _buildDetailRow('Parameter Count', item.parameterCount),
                _buildDetailRow('Default Quantization', item.quantization),
                _buildDetailRow('Estimated Disk Size', item.estimatedDiskSize),
                _buildDetailRow('Estimated RAM Needed', item.estimatedMemory),
                _buildDetailRow('Context Window', '${item.contextLength} tokens (${item.formattedContext})'),
                _buildDetailRow('RAG Role', item.ragRole != 'none' ? item.ragRole.replaceAll('_', ' ').toUpperCase() : 'General Purpose / Chat'),
                if (item.embeddingDimensions != null)
                  _buildDetailRow('Embedding Dimensions', '${item.embeddingDimensions} dims'),
                _buildDetailRow('Apple Silicon Optimized', item.isAppleSiliconOptimized ? 'Yes (Metal & Apple Neural Engine)' : 'Standard CPU/GPU'),
                _buildDetailRow('CPU Execution', item.isCpuPractical ? 'Practical on Modern CPUs' : 'High Memory / GPU Recommended'),
                _buildDetailRow('Supported Modalities', item.supportedModalities.join(', ')),
                _buildDetailRow('Supported Tasks', item.supportedTasks.join(', ')),
                _buildDetailRow('License', item.license),
                _buildDetailRow('Compatibility Status', item.compatibilityStatus),
                _buildDetailRow('Verification Status', item.verificationStatus),
                _buildDetailRow('Last Verified', item.lastVerified),
                _buildDetailRow('Download Identifier', item.downloadIdentifier),
                _buildDetailRow('Hardware Requirements', item.hardwareRequirements),

                // Quantization Variants
                if (item.quantizationVariants.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Available Quantization Variants:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: OllivoTheme.cardDark,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: OllivoTheme.borderDark),
                    ),
                    child: Column(
                      children: item.quantizationVariants.map((qv) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: OllivoTheme.borderDark)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: OllivoTheme.surfaceDark,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(qv.tag, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: OllivoTheme.oliveEmerald)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(qv.description.isNotEmpty ? qv.description : qv.tag, style: const TextStyle(fontSize: 11, color: Colors.white70)),
                              ),
                              Text('Disk: ${qv.diskSize}', style: const TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark)),
                              const SizedBox(width: 12),
                              Text('RAM: ${qv.memoryRequiredGb} GB', style: const TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],

                // Strengths & Limitations
                if (item.strengths.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text('Key Strengths:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle_outline, size: 13, color: OllivoTheme.oliveEmerald),
                      const SizedBox(width: 6),
                      Expanded(child: Text(item.strengths, style: const TextStyle(fontSize: 11, color: Colors.white70))),
                    ],
                  ),
                ],

                if (item.limitations.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text('Known Limitations & Resource Constraints:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, size: 13, color: OllivoTheme.statusWarning),
                      const SizedBox(width: 6),
                      Expanded(child: Text(item.limitations, style: const TextStyle(fontSize: 11, color: Colors.white70))),
                    ],
                  ),
                ],

                if (item.recommendedUseCases.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Recommended Use Cases:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: item.recommendedUseCases.map((uc) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: OllivoTheme.cardDark,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: OllivoTheme.borderDark),
                        ),
                        child: Text(uc, style: const TextStyle(fontSize: 10, color: Colors.white70)),
                      );
                    }).toList(),
                  ),
                ],

                const SizedBox(height: 12),
                const Text('Verified Model Tags:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: item.verifiedTags.map((t) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: OllivoTheme.cardDark,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: OllivoTheme.borderDark),
                      ),
                      child: Text(t, style: const TextStyle(fontSize: 11, color: OllivoTheme.oliveEmerald)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                const Text('Source Reference URL:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(item.sourceUrl, style: const TextStyle(fontSize: 12, color: Colors.blueAccent)),
              ],
            ),
          ),
        ),
        actions: [
          OllivoSecondaryButton(
            label: 'Close',
            onPressed: () => Navigator.pop(context),
          ),
          if (item.isOllamaNative && !widget.controller.isInstalled(item.id)) ...[
            OllivoPrimaryButton(
              label: 'Download Now',
              icon: Icons.download_rounded,
              onPressed: () {
                Navigator.pop(context);
                widget.controller.downloadModel(item.id);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(label, style: const TextStyle(fontSize: 12, color: OllivoTheme.textSecondaryDark)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  /// Model Comparison Dialog
  void _showComparisonDialog(BuildContext context) {
    final catalog = ModelCatalogService.catalog;
    _selectedModelForComparisonA ??= catalog.first;
    _selectedModelForComparisonB ??= catalog.length > 1 ? catalog[1] : catalog.first;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final a = _selectedModelForComparisonA!;
          final b = _selectedModelForComparisonB!;

          return AlertDialog(
            backgroundColor: OllivoTheme.surfaceDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(OllivoTheme.radiusMd),
              side: const BorderSide(color: OllivoTheme.borderDark),
            ),
            title: const Row(
              children: [
                Icon(Icons.compare_arrows_rounded, color: OllivoTheme.oliveEmerald),
                SizedBox(width: 10),
                Text('Compare AI Models Side-by-Side', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 700,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      // Model A Selector
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: OllivoTheme.cardDark,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: OllivoTheme.borderDark),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<ModelCatalogItem>(
                              value: a,
                              isExpanded: true,
                              dropdownColor: OllivoTheme.surfaceDark,
                              items: catalog.map((item) {
                                return DropdownMenuItem(value: item, child: Text(item.name));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setDialogState(() => _selectedModelForComparisonA = val);
                              },
                            ),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12.0),
                        child: Text('VS', style: TextStyle(fontWeight: FontWeight.bold, color: OllivoTheme.textSecondaryDark)),
                      ),
                      // Model B Selector
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: OllivoTheme.cardDark,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: OllivoTheme.borderDark),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<ModelCatalogItem>(
                              value: b,
                              isExpanded: true,
                              dropdownColor: OllivoTheme.surfaceDark,
                              items: catalog.map((item) {
                                return DropdownMenuItem(value: item, child: Text(item.name));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setDialogState(() => _selectedModelForComparisonB = val);
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: OllivoTheme.borderDark),
                  const SizedBox(height: 10),
                  _buildComparisonRow('Category', a.category, b.category),
                  _buildComparisonRow('Parameters', a.parameterCount, b.parameterCount),
                  _buildComparisonRow('Context Length', '${a.contextLength} tok', '${b.contextLength} tok'),
                  _buildComparisonRow('Estimated Disk Size', a.estimatedDiskSize, b.estimatedDiskSize),
                  _buildComparisonRow('RAM Requirement', a.estimatedMemory, b.estimatedMemory),
                  _buildComparisonRow('Quantization', a.quantization, b.quantization),
                  _buildComparisonRow('License', a.license, b.license),
                ],
              ),
            ),
            actions: [
              OllivoSecondaryButton(
                label: 'Close',
                onPressed: () => Navigator.pop(dialogCtx),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildComparisonRow(String metric, String valA, String valB) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Expanded(child: Text(valA, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
          SizedBox(
            width: 140,
            child: Center(
              child: Text(metric, style: const TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark)),
            ),
          ),
          Expanded(child: Text(valB, textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  void _showExternalEngineInfo(BuildContext context, ModelCatalogItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: OllivoTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OllivoTheme.radiusMd),
          side: const BorderSide(color: OllivoTheme.borderDark),
        ),
        title: Row(
          children: [
            const Icon(Icons.extension_outlined, color: Colors.amber),
            const SizedBox(width: 10),
            Text('${item.backend.toUpperCase()} Engine Integration'),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Model "${item.name}" runs via ${item.backend}. Ollama is specialized for LLMs, Vision-Language, and Vector Embeddings.',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              Text(
                'Requirements: ${item.hardwareRequirements}',
                style: const TextStyle(fontSize: 12, color: OllivoTheme.textSecondaryDark),
              ),
              const SizedBox(height: 12),
              Text(
                'Source & Weights: ${item.sourceUrl}',
                style: const TextStyle(fontSize: 12, color: Colors.blueAccent),
              ),
            ],
          ),
        ),
        actions: [
          OllivoSecondaryButton(
            label: 'Got it',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showPullCustomModelDialog(BuildContext context) {
    final textController = TextEditingController();
    String? validationError;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: OllivoTheme.surfaceDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(OllivoTheme.radiusMd),
              side: const BorderSide(color: OllivoTheme.borderDark),
            ),
            title: const Row(
              children: [
                Icon(Icons.cloud_download_outlined, color: OllivoTheme.oliveEmerald, size: 24),
                SizedBox(width: 10),
                Text('Pull Custom Ollama Model', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter any model identifier from the official Ollama Library or HuggingFace GGUF repository.',
                    style: TextStyle(fontSize: 13, color: OllivoTheme.textSecondaryDark),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: textController,
                    autofocus: true,
                    style: const TextStyle(fontSize: 14, color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Model Tag or Identifier',
                      hintText: 'e.g. deepseek-r1:1.5b, llama3.2:1b, mistral:7b',
                      errorText: validationError,
                      prefixIcon: const Icon(Icons.tag, size: 18, color: OllivoTheme.textSecondaryDark),
                      filled: true,
                      fillColor: OllivoTheme.cardDark,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(OllivoTheme.radiusSm),
                        borderSide: const BorderSide(color: OllivoTheme.borderDark),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(OllivoTheme.radiusSm),
                        borderSide: const BorderSide(color: OllivoTheme.oliveEmerald),
                      ),
                    ),
                    onChanged: (_) {
                      if (validationError != null) {
                        setDialogState(() => validationError = null);
                      }
                    },
                    onSubmitted: (val) {
                      final err = ModelController.validateCustomTag(val);
                      if (err != null) {
                        setDialogState(() => validationError = err);
                      } else {
                        Navigator.of(dialogCtx).pop();
                        widget.controller.downloadModel(val.trim());
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Popular suggestions:',
                    style: TextStyle(fontSize: 12, color: OllivoTheme.textSecondaryDark, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      'deepseek-r1:1.5b',
                      'llama3.2:1b',
                      'qwen2.5-coder:1.5b',
                      'mistral:7b',
                      'phi3:mini',
                      'nomic-embed-text',
                    ].map((tag) {
                      return InkWell(
                        onTap: () {
                          textController.text = tag;
                          setDialogState(() => validationError = null);
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: OllivoTheme.cardDark,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: OllivoTheme.borderDark),
                          ),
                          child: Text(
                            tag,
                            style: const TextStyle(fontSize: 11, color: OllivoTheme.oliveEmerald),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              OllivoSecondaryButton(
                label: 'Cancel',
                onPressed: () => Navigator.of(dialogCtx).pop(),
              ),
              OllivoPrimaryButton(
                label: 'Start Download',
                icon: Icons.download_rounded,
                onPressed: () {
                  final tag = textController.text.trim();
                  final err = ModelController.validateCustomTag(tag);
                  if (err != null) {
                    setDialogState(() => validationError = err);
                  } else {
                    Navigator.of(dialogCtx).pop();
                    widget.controller.downloadModel(tag);
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteModel(BuildContext context, String modelName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: OllivoTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OllivoTheme.radiusMd),
          side: const BorderSide(color: OllivoTheme.borderDark),
        ),
        title: const Text('Confirm Model Deletion'),
        content: Text('Are you sure you want to delete model "$modelName" from local storage? This action cannot be undone.'),
        actions: [
          OllivoSecondaryButton(
            label: 'Cancel',
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: OllivoTheme.statusError,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              await widget.controller.deleteModel(modelName);
            },
            child: const Text('Delete Model'),
          ),
        ],
      ),
    );
  }
}
