import 'package:flutter/material.dart';
import '../../core/models/cart.dart';
import '../../core/utils/l10n.dart';
import '../theme/app_theme.dart';

/// Personal items (makeup, skincare, perfume, underwear…) are returned only when damaged, expired or
/// wrong, and never exchanged (2026-11-19, backend ReturnPolicy). A product carries `return_rule` only
/// while the server switch is on, so with it off every check here is false and nothing shows.
bool cartHasPersonalItems(Iterable<CartItem> items) =>
    items.any((i) => i.product.returnRule != null);

/// One small outlined note: lock icon (tiffany accent) + text. Used on the product page, the cart and
/// checkout so the rule reads the same everywhere.
class ReturnRuleNote extends StatelessWidget {
  final String text;
  final EdgeInsetsGeometry margin;
  const ReturnRuleNote({required this.text, this.margin = EdgeInsets.zero, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.col.border),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              textAlign: TextAlign.start,
              style: TextStyle(
                  fontFamily: 'Manrope',
                  fontFamilyFallback: const ['Tajawal'],
                  fontSize: 12,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                  color: context.col.ink1)),
        ),
      ]),
    );
  }
}

/// The cart / checkout note, shown only when at least one line is a personal item.
class PersonalItemsNote extends StatelessWidget {
  final Iterable<CartItem> items;
  final EdgeInsetsGeometry margin;
  const PersonalItemsNote({required this.items, this.margin = EdgeInsets.zero, super.key});

  @override
  Widget build(BuildContext context) {
    if (!cartHasPersonalItems(items)) return const SizedBox.shrink();
    return ReturnRuleNote(text: context.s.personalItemsCartNote, margin: margin);
  }
}
