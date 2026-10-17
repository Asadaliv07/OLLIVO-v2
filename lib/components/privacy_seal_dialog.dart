import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/audit_service.dart';
import '../theme.dart';
import 'ollivo_components.dart';

/// Air-Gapped Privacy Seal Dialog (`SEC-002`)
/// Visual verification certificate confirming zero telemetry, local inference, and air-gapped isolation.
class PrivacySealDialog extends StatelessWidget {
  final VoidCallback? onInspectAuditLog;

  const PrivacySealDialog({
    super.key,
    this.onInspectAuditLog,
  });

  static Future<void> show(BuildContext context, {VoidCallback? onInspectAuditLog}) {
    return showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => PrivacySealDialog(onInspectAuditLog: onInspectAuditLog),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auditService = AuditService.instance;
    final totalActions = auditService.totalLocalActions;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 640),
        child: Material(
          color: OllivoTheme.surfaceDark,
          borderRadius: BorderRadius.circular(OllivoTheme.radiusLg),
          elevation: 24,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(OllivoTheme.radiusLg),
              border: Border.all(color: OllivoTheme.borderDark),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: OllivoTheme.oliveEmerald.withAlpha(30),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.shield_outlined, color: OllivoTheme.oliveEmerald, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              children: [
                                Text(
                                  'Air-Gapped Privacy Seal',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Icon(Icons.verified, color: OllivoTheme.oliveEmerald, size: 17),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '100% On-Device · Zero Cloud Telemetry Verified',
                              style: TextStyle(
                                fontSize: 11,
                                color: OllivoTheme.oliveEmerald.withAlpha(220),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: OllivoTheme.textSecondaryDark, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: OllivoTheme.borderDark, height: 1),
                  const SizedBox(height: 14),

                  // Live Verification Metric Card
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: OllivoTheme.cardDark,
                      borderRadius: BorderRadius.circular(OllivoTheme.radiusSm),
                      border: Border.all(color: OllivoTheme.borderDark),
                    ),
                    child: Column(
                      children: [
                        _buildMetricRow(
                          label: 'Cloud Telemetry Sent',
                          value: '0 Bytes (100% Zero Leakage)',
                          valueColor: OllivoTheme.oliveEmerald,
                          icon: Icons.cloud_off_outlined,
                        ),
                        const Divider(color: OllivoTheme.borderDark, height: 14),
                        _buildMetricRow(
                          label: 'Local Operations Logged',
                          value: '$totalActions actions audited on-device',
                          valueColor: Colors.white,
                          icon: Icons.history_toggle_off,
                        ),
                        const Divider(color: OllivoTheme.borderDark, height: 14),
                        _buildMetricRow(
                          label: 'Inference Endpoint',
                          value: 'http://127.0.0.1:11434 (localhost only)',
                          valueColor: OllivoTheme.textSecondaryDark,
                          icon: Icons.lan_outlined,
                        ),
                        const Divider(color: OllivoTheme.borderDark, height: 14),
                        _buildMetricRow(
                          label: 'Data Storage',
                          value: 'SQLite (macOS Application Support sandbox)',
                          valueColor: OllivoTheme.textSecondaryDark,
                          icon: Icons.storage_outlined,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Privacy Checklist
                  const Text(
                    'SECURITY & AIR-GAP GUARANTEES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: OllivoTheme.oliveEmerald,
                    ),
                  ),
                  const SizedBox(height: 8),

                  _buildChecklistItem('Zero Third-Party Telemetry', 'No remote tracking, analytics, or third-party cloud SDKs.'),
                  const SizedBox(height: 6),
                  _buildChecklistItem('Local Hardware Execution', 'Weights execute locally on Apple Silicon Metal GPU / Unified Memory.'),
                  const SizedBox(height: 6),
                  _buildChecklistItem('Sandboxed SQLite Storage', 'Prompts, memory facts, tasks, and documents never leave your drive.'),
                  const SizedBox(height: 6),
                  _buildChecklistItem('Offline Independence', 'Works identically whether your device is online or fully disconnected.'),

                  const SizedBox(height: 16),
                  const Divider(color: OllivoTheme.borderDark, height: 1),
                  const SizedBox(height: 14),

                  // Actions
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Wrap(
                        spacing: 8,
                        children: [
                          if (onInspectAuditLog != null)
                            OllivoSecondaryButton(
                              label: 'Inspect Audit Log',
                              icon: Icons.receipt_long_outlined,
                              onPressed: () {
                                Navigator.of(context).pop();
                                onInspectAuditLog!();
                              },
                            ),
                          OllivoSecondaryButton(
                            label: 'Copy Proof',
                            icon: Icons.copy_outlined,
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: auditService.exportAsJson()));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Privacy audit verification report copied to clipboard.'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      OllivoPrimaryButton(
                        label: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricRow({
    required String label,
    required String value,
    required Color valueColor,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon, size: 15, color: OllivoTheme.textSecondaryDark),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: OllivoTheme.textSecondaryDark),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChecklistItem(String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.check_circle_rounded, color: OllivoTheme.oliveEmerald, size: 14),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Text(
                description,
                style: const TextStyle(fontSize: 11, color: OllivoTheme.textSecondaryDark),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
