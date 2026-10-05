import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Default logo for a store that has none: a soft Baahy-teal tile with a storefront mark.
/// Fills whatever box it is given (square card or round badge).
class StoreLogoPlaceholder extends StatelessWidget {
  const StoreLogoPlaceholder({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (_, c) {
          final side = c.biggest.shortestSide.isFinite ? c.biggest.shortestSide : 60.0;
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withValues(alpha: 0.28),
                  AppColors.teal600.withValues(alpha: 0.16),
                ],
              ),
            ),
            child: Center(
              child: Icon(Icons.storefront_rounded,
                  size: side * 0.46, color: AppColors.teal600),
            ),
          );
        },
      );
}
