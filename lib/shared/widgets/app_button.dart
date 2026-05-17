import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum AppButtonVariant { primary, outline, ghost, danger }

class AppButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final isPrimary = variant == AppButtonVariant.primary;
    final isDanger = variant == AppButtonVariant.danger;
    final isOutline = variant == AppButtonVariant.outline;

    final bg = isPrimary ? AppColors.primary
        : isDanger ? AppColors.danger
        : Colors.transparent;
    final fg = (isPrimary || isDanger) ? Colors.white
        : isOutline ? AppColors.primary
        : AppColors.ink1;
    final border = isOutline ? Border.all(color: AppColors.primary, width: 1.5) : null;

    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: width ?? double.infinity,
        height: height,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: border,
        ),
        child: Center(
          child: loading
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
                    if (icon != null) ...[icon!, const SizedBox(width: 8)],
                    Text(
                      label,
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
