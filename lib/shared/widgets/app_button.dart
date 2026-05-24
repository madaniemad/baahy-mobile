import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum AppButtonVariant { primary, outline, ghost, danger }

class AppButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final AppButtonVariant variant;
  final bool loading;
  final Widget? icon;
  final double? width;
  final double height;

  const AppButton({
    required this.label,
    this.onTap,
    this.variant = AppButtonVariant.primary,
    this.loading = false,
    this.icon,
    this.width,
    this.height = 50,
    super.key,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  static DateTime? _lastTap; // static — survives widget rebuilds during navigation

  void _handleTap() {
    if (widget.onTap == null || widget.loading) return;
    final now = DateTime.now();
    if (_lastTap != null && now.difference(_lastTap!) < const Duration(milliseconds: 600)) return;
    _lastTap = now;
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    final isPrimary = widget.variant == AppButtonVariant.primary;
    final isDanger = widget.variant == AppButtonVariant.danger;
    final isOutline = widget.variant == AppButtonVariant.outline;

    final bg = isPrimary ? AppColors.primary
        : isDanger ? AppColors.danger
        : Colors.transparent;
    final fg = (isPrimary || isDanger) ? Colors.white
        : isOutline ? AppColors.primary
        : AppColors.ink1;
    final border = isOutline ? Border.all(color: AppColors.primary, width: 1.5) : null;

    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: widget.width ?? double.infinity,
        height: widget.height,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: border,
        ),
        child: Center(
          child: widget.loading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: fg,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[widget.icon!, const SizedBox(width: 8)],
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: fg,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
