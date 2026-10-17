import 'package:flutter/material.dart';
import '../controllers/model_controller.dart';
import '../theme.dart';
import 'ollivo_components.dart';

/// Quick Server Control & Status Dialog (MOD-DASH-001)
class OllamaDashboardDialog extends StatelessWidget {
  final ModelController controller;
  final VoidCallback? onOpenModelLibrary;

  const OllamaDashboardDialog({
    super.key,
    required this.controller,
    this.onOpenModelLibrary,
  });

  static Future<void> show(
    BuildContext context, {
    required ModelController controller,
    VoidCallback? onOpenModelLibrary,
  }) {
    return showDialog(
      context: context,
      builder: (context) => OllamaDashboardDialog(
        controller: controller,
        onOpenModelLibrary: onOpenModelLibrary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final isOnline = controller.isOllamaOnline;
        final isRecovering = controller.isRecoveringDaemon;
        final latency = controller.daemonLatencyMs;
        final version = controller.ollamaVersion;
        final hardware = controller.hardwareProfile;

        return AlertDialog(
          backgroundColor: OllivoTheme.surfaceDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(OllivoTheme.radiusMd),
            side: const BorderSide(color: OllivoTheme.borderDark),
          ),
          title: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOnline ? OllivoTheme.mintPrimary : OllivoTheme.statusError,
                  boxShadow: [
                    BoxShadow(
                      color: (isOnline ? OllivoTheme.mintPrimary : OllivoTheme.statusError)
                          .withValues(alpha: 0.6),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Ollama Engine Server',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const Spacer(),
              if (version != null && version.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: OllivoTheme.cardDark,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: OllivoTheme.borderDark),
                  ),
                  child: Text(
                    version,
                    style: const TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark),
                  ),
                ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Server Status & Metrics Box
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: OllivoTheme.cardDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isOnline
                          ? OllivoTheme.mintPrimary.withValues(alpha: 0.3)
                          : OllivoTheme.statusError.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Server Status', style: TextStyle(color: OllivoTheme.textSecondaryDark, fontSize: 12)),
                          Text(
                            isRecovering
                                ? 'Starting Daemon...'
                                : (isOnline ? 'Online · Running' : 'Offline · Stopped'),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isOnline ? OllivoTheme.mintPrimary : OllivoTheme.statusError,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Endpoint URL', style: TextStyle(color: OllivoTheme.textSecondaryDark, fontSize: 12)),
                          Text(controller.ollamaHost, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Health Latency', style: TextStyle(color: OllivoTheme.textSecondaryDark, fontSize: 12)),
                          Text(latency != null ? '${latency}ms' : 'N/A', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Installed Models', style: TextStyle(color: OllivoTheme.textSecondaryDark, fontSize: 12)),
                          Text('${controller.installedModels.length} models', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Loaded in VRAM', style: TextStyle(color: OllivoTheme.textSecondaryDark, fontSize: 12)),
                          Text('${controller.loadedModels.length} models', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: OllivoTheme.mintPrimary)),
                        ],
                      ),
                      if (hardware != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('System Memory', style: TextStyle(color: OllivoTheme.textSecondaryDark, fontSize: 12)),
                            Text('${hardware.totalRamGb.toStringAsFixed(0)} GB (${hardware.tierLabel})', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Primary Daemon Controls Row
                Row(
                  children: [
                    if (!isOnline) ...[
                      Expanded(
                        child: OllivoPrimaryButton(
                          label: isRecovering ? 'Starting...' : 'Start Ollama Server',
                          icon: Icons.play_arrow_rounded,
                          isLoading: isRecovering,
                          onPressed: isRecovering
                              ? null
                              : () async {
                                  final res = await controller.startOllama();
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(res.message),
                                      backgroundColor: res.success ? OllivoTheme.mintPrimary : OllivoTheme.statusError,
                                    ),
                                  );
                                },
                        ),
                      ),
                    ] else ...[
                      Expanded(
                        child: OllivoSecondaryButton(
                          label: 'Stop Ollama',
                          icon: Icons.stop_rounded,
                          onPressed: isRecovering
                              ? null
                              : () async {
                                  final res = await controller.stopOllama();
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(res.message),
                                      backgroundColor: res.success ? OllivoTheme.mintPrimary : OllivoTheme.statusWarning,
                                    ),
                                  );
                                },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OllivoSecondaryButton(
                          label: 'Restart',
                          icon: Icons.restart_alt_rounded,
                          onPressed: isRecovering
                              ? null
                              : () async {
                                  final res = await controller.restartOllama();
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(res.message),
                                      backgroundColor: res.success ? OllivoTheme.mintPrimary : OllivoTheme.statusError,
                                    ),
                                  );
                                },
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.sync_rounded),
                      tooltip: 'Check Connection',
                      onPressed: controller.checkConnection,
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            if (onOpenModelLibrary != null)
              TextButton.icon(
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: const Text('Open Model Library (110 Models)'),
                onPressed: () {
                  Navigator.pop(context);
                  onOpenModelLibrary?.call();
                },
              ),
            OllivoSecondaryButton(
              label: 'Done',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        );
      },
    );
  }
}
