import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Default logo for a store that has none: a brand-tiffany storefront mark on white.
/// Fills whatever box it is given (square card or round badge).
class StoreLogoPlaceholder extends StatelessWidget {
  const StoreLogoPlaceholder({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (_, c) {
          final side = c.biggest.shortestSide.isFinite ? c.biggest.shortestSide : 60.0;
          return ColoredBox(
            color: Colors.white,
            child: Center(
              child: Icon(Icons.storefront_rounded,
                  size: side * 0.46, color: AppColors.primary),
            ),
          );
        },
      );
}
