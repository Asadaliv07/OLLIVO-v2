import 'package:flutter/material.dart';
import '../theme.dart';

/// Tactile Bounce Physics Widget (`Curves.easeOutCubic`, 120ms, scale: 0.975)
/// Delivers snappy tactile feedback on press and smooth 150ms surface transitions on hover.
class TactileBounce extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleFactor;
  final Duration duration;
  final bool enableHoverGlow;
  final Color? hoverBorderColor;
  final BorderRadius? borderRadius;

  const TactileBounce({
    super.key,
    required this.child,
    this.onTap,
    this.scaleFactor = 0.975,
    this.duration = const Duration(milliseconds: 120),
    this.enableHoverGlow = false,
    this.hoverBorderColor,
    this.borderRadius,
  });

  @override
  State<TactileBounce> createState() => _TactileBounceState();
}

class _TactileBounceState extends State<TactileBounce> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleFactor,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap != null) {
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onTap != null) {
      _controller.reverse();
    }
  }

  void _onTapCancel() {
    if (widget.onTap != null) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isInteractive = widget.onTap != null;

    Widget content = MouseRegion(
      cursor: isInteractive ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) {
        if (mounted && isInteractive) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (mounted && isInteractive) setState(() => _isHovered = false);
      },
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _scaleAnimation.value,
          duration: widget.duration,
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            decoration: widget.enableHoverGlow && _isHovered
                ? BoxDecoration(
                    borderRadius: widget.borderRadius ?? BorderRadius.circular(OllivoTheme.radiusMd),
                    border: Border.all(
                      color: widget.hoverBorderColor ?? OllivoTheme.borderGlass,
                      width: 1,
                    ),
                    boxShadow: OllivoTheme.ambientShadow,
                  )
                : null,
            child: widget.child,
          ),
        ),
      ),
    );

    return RepaintBoundary(child: content);
  }
}

/// Shimmer Progress Track Widget for Model Library and Local RAG Indexing
/// Fluid 60–120 FPS progress bar with interpolated value and looping light sweep.
class ShimmerProgressTrack extends StatefulWidget {
  final double? progress; // null for indeterminate
  final double height;
  final Color baseColor;
  final Color progressColor;
  final BorderRadius? borderRadius;

  const ShimmerProgressTrack({
    super.key,
    double? progress,
    double? value,
    this.height = 6.0,
    this.baseColor = OllivoTheme.cardElevatedDark,
    this.progressColor = OllivoTheme.mintPrimary,
    this.borderRadius,
  }) : progress = progress ?? value;

  @override
  State<ShimmerProgressTrack> createState() => _ShimmerProgressTrackState();
}

class _ShimmerProgressTrackState extends State<ShimmerProgressTrack> with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.borderRadius ?? BorderRadius.circular(widget.height / 2);

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final pct = widget.progress?.clamp(0.0, 1.0) ?? 1.0;
          final activeWidth = widget.progress != null ? totalWidth * pct : totalWidth;

          return Container(
            height: widget.height,
            width: totalWidth,
            decoration: BoxDecoration(
              color: widget.baseColor,
              borderRadius: r,
              border: Border.all(color: OllivoTheme.borderMuted, width: 0.5),
            ),
            child: Stack(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  width: activeWidth,
                  height: widget.height,
                  decoration: BoxDecoration(
                    color: widget.progressColor,
                    borderRadius: r,
                  ),
                ),
                // Shimmer sweep
                AnimatedBuilder(
                  animation: _shimmerController,
                  builder: (context, child) {
                    final shimmerOffset = _shimmerController.value;
                    return Positioned(
                      left: (totalWidth + 100) * shimmerOffset - 100,
                      top: 0,
                      bottom: 0,
                      width: 80,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.0),
                              Colors.white.withValues(alpha: 0.35),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Reusable Brand Logo Header Component
class OllivoLogoHeader extends StatelessWidget {
  final double height;
  final bool showWordmark;

  const OllivoLogoHeader({
    super.key,
    this.height = 32.0,
    this.showWordmark = true,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Ollivo Logo',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/logo.png',
            height: height,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: height,
                height: height,
                decoration: BoxDecoration(
                  color: OllivoTheme.mintSubtle,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: OllivoTheme.mintPrimary.withValues(alpha: 0.3)),
                ),
                child: Icon(
                  Icons.auto_awesome,
                  color: OllivoTheme.mintPrimary,
                  size: height * 0.6,
                ),
              );
            },
          ),
          if (showWordmark) ...[
            const SizedBox(width: 12),
            const Text(
              'Ollivo',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Consolidated Status Indicator Pill (Top Navigation / Header)
class OllivoStatusPill extends StatelessWidget {
  final bool isConnected;
  final String statusText;
  final VoidCallback? onTap;

  const OllivoStatusPill({
    super.key,
    required this.isConnected,
    this.statusText = 'Local Engine',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = isConnected ? OllivoTheme.statusSuccess : OllivoTheme.statusError;
    final label = isConnected ? '$statusText: Active' : '$statusText: Offline';

    return TactileBounce(
      onTap: onTap,
      scaleFactor: 0.98,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: OllivoTheme.cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isConnected ? OllivoTheme.borderDark : OllivoTheme.statusError.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withValues(alpha: 0.4),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: isConnected ? Colors.white : OllivoTheme.statusError,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Primary Emerald Action Button with Tactile Springs & Subtle Sheen
class OllivoPrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;

  const OllivoPrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return TactileBounce(
      onTap: isLoading ? null : onPressed,
      scaleFactor: 0.97,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: OllivoTheme.mintPrimary,
          borderRadius: BorderRadius.circular(OllivoTheme.radiusSm),
          boxShadow: [
            BoxShadow(
              color: OllivoTheme.mintPrimary.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(OllivoTheme.onyxDark),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: OllivoTheme.onyxDark),
                    const SizedBox(width: 7),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                      color: OllivoTheme.onyxDark,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Destructive Danger Action Button with Crimson/Error Palette
class OllivoDangerButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;

  const OllivoDangerButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return TactileBounce(
      onTap: isLoading ? null : onPressed,
      scaleFactor: 0.97,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: OllivoTheme.statusError,
          borderRadius: BorderRadius.circular(OllivoTheme.radiusSm),
          boxShadow: [
            BoxShadow(
              color: OllivoTheme.statusError.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: Colors.white),
                    const SizedBox(width: 7),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Secondary Action Button with Smooth Hover Surface Transitions
class OllivoSecondaryButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  const OllivoSecondaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
  });

  @override
  State<OllivoSecondaryButton> createState() => _OllivoSecondaryButtonState();
}

class _OllivoSecondaryButtonState extends State<OllivoSecondaryButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onPressed != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: TactileBounce(
        onTap: widget.onPressed,
        scaleFactor: 0.975,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: _isHovered ? OllivoTheme.cardElevatedDark : OllivoTheme.cardDark,
            borderRadius: BorderRadius.circular(OllivoTheme.radiusSm),
            border: Border.all(
              color: _isHovered ? OllivoTheme.borderGlass : OllivoTheme.borderDark,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: 15,
                  color: _isHovered ? Colors.white : OllivoTheme.textSecondaryDark,
                ),
                const SizedBox(width: 7),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: _isHovered ? Colors.white : OllivoTheme.textSecondaryDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Accessible Reusable Form Text Field
class OllivoTextField extends StatelessWidget {
  final String hintText;
  final String? labelText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? prefixIcon;
  final Widget? suffixIcon;

  const OllivoTextField({
    super.key,
    required this.hintText,
    this.labelText,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.prefixIcon,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: const TextStyle(fontSize: 13.5, color: Colors.white),
      decoration: InputDecoration(
        hintText: hintText,
        labelText: labelText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
      ),
    );
  }
}

/// Reusable Elevated Container Card with Subtle Gradient Borders & Soft Shadows
class OllivoCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const OllivoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(OllivoTheme.spaceMd),
    this.onTap,
  });

  @override
  State<OllivoCard> createState() => _OllivoCardState();
}

class _OllivoCardState extends State<OllivoCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isClickable = widget.onTap != null;

    Widget cardBody = MouseRegion(
      onEnter: (_) {
        if (mounted && isClickable) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (mounted && isClickable) setState(() => _isHovered = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: widget.padding,
        decoration: BoxDecoration(
          color: _isHovered && isClickable ? OllivoTheme.cardElevatedDark : OllivoTheme.cardDark,
          borderRadius: BorderRadius.circular(OllivoTheme.radiusMd),
          border: Border.all(
            color: _isHovered && isClickable ? OllivoTheme.borderGlass : OllivoTheme.borderDark,
            width: 1,
          ),
          boxShadow: OllivoTheme.ambientShadow,
        ),
        child: widget.child,
      ),
    );

    if (isClickable) {
      return TactileBounce(
        onTap: widget.onTap,
        scaleFactor: 0.985,
        child: cardBody,
      );
    }

    return cardBody;
  }
}

/// Human-First Error & Warning Banner with Diagnostics Trace Disclosure
class OllivoBanner extends StatefulWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color color;
  final Widget? action;

  const OllivoBanner({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.info_outline,
    this.color = OllivoTheme.mintPrimary,
    this.action,
  });

  @override
  State<OllivoBanner> createState() => _OllivoBannerState();
}

class _OllivoBannerState extends State<OllivoBanner> {
  bool _showTrace = false;

  String get _friendlyMessage {
    final raw = widget.message;
    if (raw.contains('errno = 61') || raw.contains('Connection refused') || raw.contains('ClientException')) {
      return 'The local Ollama background daemon is offline or starting up at 127.0.0.1:11434. Launch the daemon to start local inference.';
    }
    return raw;
  }

  bool get _hasRawDiagnostics {
    return widget.message.contains('errno') || widget.message.contains('Exception') || widget.message.length > 80;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(OllivoTheme.spaceMd),
      decoration: BoxDecoration(
        color: widget.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(OllivoTheme.radiusMd),
        border: Border.all(color: widget.color.withValues(alpha: 0.25), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(widget.icon, color: widget.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        color: widget.color,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _friendlyMessage,
                      style: const TextStyle(
                        color: OllivoTheme.textSecondaryDark,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.action != null) ...[
                const SizedBox(width: 14),
                widget.action!,
              ],
            ],
          ),
          if (_hasRawDiagnostics) ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: () => setState(() => _showTrace = !_showTrace),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 4.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showTrace ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      size: 14,
                      color: OllivoTheme.textSecondaryDark,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _showTrace ? 'Hide Trace' : 'View Trace',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: OllivoTheme.textSecondaryDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_showTrace) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: OllivoTheme.onyxDark,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: OllivoTheme.borderMuted),
                ),
                child: SelectableText(
                  widget.message,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: OllivoTheme.textSecondaryDark,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Accessible Loading State Indicator Component
class OllivoLoadingIndicator extends StatelessWidget {
  final String label;

  const OllivoLoadingIndicator({
    super.key,
    this.label = 'Loading workspace data...',
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(OllivoTheme.mintPrimary),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              label,
              style: const TextStyle(
                color: OllivoTheme.textSecondaryDark,
                fontSize: 13,
                letterSpacing: -0.1,
              ),
            ),
            const SizedBox(height: 12),
            const SizedBox(
              width: 140,
              child: ShimmerProgressTrack(value: null, height: 4),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared Reusable Empty State Component
class OllivoEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const OllivoEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(OllivoTheme.spaceXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: OllivoTheme.mintSubtle,
                shape: BoxShape.circle,
                border: Border.all(color: OllivoTheme.mintPrimary.withValues(alpha: 0.2)),
              ),
              child: Icon(icon, size: 40, color: OllivoTheme.mintPrimary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: OllivoTheme.h2Style,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: OllivoTheme.captionStyle,
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              OllivoPrimaryButton(
                label: actionLabel!,
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tactile, Ergonomic macOS Slider with Min/Max Tags and Real-Time Editable Numeric Field
class ErgonomicSlider extends StatefulWidget {
  final String title;
  final String? subtitle;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String? minTag;
  final String? maxTag;
  final int decimalPlaces;
  final ValueChanged<double> onChanged;

  const ErgonomicSlider({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    this.minTag,
    this.maxTag,
    this.decimalPlaces = 1,
    required this.onChanged,
  });

  @override
  State<ErgonomicSlider> createState() => _ErgonomicSliderState();
}

class _ErgonomicSliderState extends State<ErgonomicSlider> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.value.toStringAsFixed(widget.decimalPlaces),
    );
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        _syncControllerWithWidgetValue();
      }
    });
  }

  @override
  void didUpdateWidget(covariant ErgonomicSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && (oldWidget.value != widget.value)) {
      _syncControllerWithWidgetValue();
    }
  }

  void _syncControllerWithWidgetValue() {
    final textVal = widget.value.toStringAsFixed(widget.decimalPlaces);
    if (_controller.text != textVal) {
      _controller.text = textVal;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleTextSubmitted(String text) {
    final parsed = double.tryParse(text);
    if (parsed != null) {
      final clamped = parsed.clamp(widget.min, widget.max);
      widget.onChanged(clamped);
      _controller.text = clamped.toStringAsFixed(widget.decimalPlaces);
    } else {
      _syncControllerWithWidgetValue();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle!,
                      style: const TextStyle(
                        color: OllivoTheme.textSecondaryDark,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Inline editable numeric field
            Container(
              width: 58,
              height: 28,
              decoration: BoxDecoration(
                color: OllivoTheme.surfaceDark,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: OllivoTheme.borderDark),
              ),
              child: Center(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: OllivoTheme.mintPrimary,
                    fontFamily: 'monospace',
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                  ),
                  onSubmitted: _handleTextSubmitted,
                  onChanged: (text) {
                    final parsed = double.tryParse(text);
                    if (parsed != null) {
                      final clamped = parsed.clamp(widget.min, widget.max);
                      widget.onChanged(clamped);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            if (widget.minTag != null) ...[
              Text(
                widget.minTag!,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: OllivoTheme.textSecondaryDark,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: OllivoTheme.mintPrimary,
                  inactiveTrackColor: OllivoTheme.borderDark,
                  thumbColor: OllivoTheme.mintPrimary,
                  overlayColor: OllivoTheme.mintPrimary.withValues(alpha: 0.15),
                  trackHeight: 3.5,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                ),
                child: Slider(
                  value: widget.value.clamp(widget.min, widget.max),
                  min: widget.min,
                  max: widget.max,
                  divisions: widget.divisions,
                  onChanged: (newVal) {
                    widget.onChanged(newVal);
                    _controller.text = newVal.toStringAsFixed(widget.decimalPlaces);
                  },
                ),
              ),
            ),
            if (widget.maxTag != null) ...[
              const SizedBox(width: 8),
              Text(
                widget.maxTag!,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: OllivoTheme.textSecondaryDark,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
