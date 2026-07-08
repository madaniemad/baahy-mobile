import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/models/product.dart';
import '../../core/utils/l10n.dart';
import 'baahy_plus_badge.dart';

/// Promo badges a product can carry.
/// [baahyPlus] renders the brand logo on its own; the rest are bare
/// icon + coloured text (no pill). When a product has more than one, they
/// roll upward in the card like a small vertical ticker.
///
/// Split:
///   • auto (derived, threshold-driven): baahyPlus, trending, fastMoving,
///     bigDeal, isNew
///   • manual (admin-toggled per product): original, warranty
enum ProductBadgeKind {
  baahyPlus,
  original,
  warranty,
  trending,
  fastMoving,
  bigDeal,
  isNew,
}

/// Thresholds + on/off switches that decide when the auto badges appear.
/// Defaults live here; the backend can override them (via app-config /
/// site-settings) so the rules are tunable without shipping an app update.
class BadgeConfig {
  final int bigDealMinDiscount; // % off to earn the big-deal badge
  final int fastMovingMinSold;
  final int trendingMinSold;
  final int newMaxDays;
  final Set<ProductBadgeKind> enabled;

  const BadgeConfig({
    this.bigDealMinDiscount = 40,
    this.fastMovingMinSold = 15,
    this.trendingMinSold = 40,
    this.newMaxDays = 14,
    this.enabled = const {
      ProductBadgeKind.baahyPlus,
      ProductBadgeKind.original,
      ProductBadgeKind.warranty,
      ProductBadgeKind.trending,
      ProductBadgeKind.fastMoving,
      ProductBadgeKind.bigDeal,
      ProductBadgeKind.isNew,
    },
  });

  static const BadgeConfig defaults = BadgeConfig();

  bool on(ProductBadgeKind k) => enabled.contains(k);
}

class _BadgeStyle {
  final String label; // English PascalCase, shown as-is in every locale
  final IconData icon;
  final Color color;
  final String? asset; // colored image icon (overrides [icon] when set)
  const _BadgeStyle(this.label, this.icon, this.color, {this.asset});
}

const Map<ProductBadgeKind, _BadgeStyle> _styles = {
  ProductBadgeKind.original: _BadgeStyle('Original',
      Icons.verified_rounded, Color(0xFFF97316),
      asset: 'assets/images/badge_original.png'),
  ProductBadgeKind.warranty: _BadgeStyle('Warranty',
      Icons.verified_user_rounded, Color(0xFF2563EB),
      asset: 'assets/images/badge_warranty.png'),
  ProductBadgeKind.trending: _BadgeStyle('Trending',
      Icons.local_fire_department_rounded, Color(0xFFF97316),
      asset: 'assets/images/badge_trending.png'),
  ProductBadgeKind.bigDeal: _BadgeStyle('BigSale',
      Icons.sell_rounded, Color(0xFF2563EB),
      asset: 'assets/images/badge_bigdeal.png'),
  ProductBadgeKind.fastMoving: _BadgeStyle('FastMoving',
      Icons.bolt_rounded, Color(0xFFF97316)),
  ProductBadgeKind.isNew: _BadgeStyle('New',
      Icons.auto_awesome_rounded, Color(0xFF14B8A6)),
};

/// Maps backend badge-key strings → kinds (tolerant of a few aliases).
ProductBadgeKind? kindFromKey(String key) {
  switch (key) {
    case 'baahy+':
    case 'baahy_plus':
    case 'baahyplus':
      return ProductBadgeKind.baahyPlus;
    case 'original':
    case 'genuine':
    case 'authentic':
      return ProductBadgeKind.original;
    case 'warranty':
    case 'guarantee':
      return ProductBadgeKind.warranty;
    case 'trending':
      return ProductBadgeKind.trending;
    case 'fastmoving':
    case 'fast_moving':
    case 'bestseller':
      return ProductBadgeKind.fastMoving;
    case 'bigdeal':
    case 'big_deal':
    case 'bigdiscount':
    case 'big_discount':
    case 'deal':
    case 'flashsale':
    case 'flash_sale':
      return ProductBadgeKind.bigDeal;
    case 'new':
      return ProductBadgeKind.isNew;
  }
  return null;
}

/// Resolves the ordered list of badges a product should show.
/// baahy+ first (brand), then manual admin badges, then the threshold-driven
/// auto badges. Deduplicated and capped so the ticker stays readable.
List<ProductBadgeKind> resolveProductBadges(Product p) {
  final out = <ProductBadgeKind>[];
  void add(ProductBadgeKind k) {
    if (!out.contains(k)) out.add(k);
  }

  // baahy+ is client-side (fulfilment + per-city express). Everything else —
  // manual (original/warranty) and the threshold-driven auto badges (big_deal,
  // trending, fast_moving, new) — is computed by the backend and delivered in
  // `p.badges`, so the rules stay tunable from admin without an app update.
  if (p.fulfilledByBaahy) add(ProductBadgeKind.baahyPlus);
  for (final key in p.badges) {
    final k = kindFromKey(key);
    if (k != null) add(k);
  }
  return out.take(4).toList();
}

/// Renders a single badge — the bare baahy+ mark for [baahyPlus], otherwise
/// icon + coloured text (no pill).
class ProductBadgeChip extends StatelessWidget {
  final ProductBadgeKind kind;
  final double scale; // 1.0 = card size, ~1.15 = detail
  const ProductBadgeChip({super.key, required this.kind, this.scale = 1.0});

  @override
  Widget build(BuildContext context) {
    if (kind == ProductBadgeKind.baahyPlus) {
      return BaahyPlusBadge(height: 12 * scale);
    }
    final s = _styles[kind]!;
    final iconSize = (s.asset != null ? 14.0 : 12.0) * scale;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        s.asset != null
            ? Image.asset(s.asset!, height: iconSize, width: iconSize,
                fit: BoxFit.contain, filterQuality: FilterQuality.high)
            : Icon(s.icon, size: iconSize, color: s.color),
        SizedBox(width: 3 * scale),
        Text(
          s.label,
          style: TextStyle(
            fontSize: 10.5 * scale,
            fontWeight: FontWeight.w800,
            color: context.col.ink0, // black text, coloured icon
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

/// Rolls through [badges] one at a time when there is more than one:
/// the current badge slides up and out while the next rolls up into its place
/// (a small vertical ticker). A single badge renders statically. Fixed height
/// so card layout never jumps.
class RotatingProductBadges extends StatefulWidget {
  final List<ProductBadgeKind> badges;
  final double scale;
  final Duration interval;
  const RotatingProductBadges({
    super.key,
    required this.badges,
    this.scale = 1.0,
    this.interval = const Duration(milliseconds: 2600),
  });

  @override
  State<RotatingProductBadges> createState() => _RotatingProductBadgesState();
}

class _RotatingProductBadgesState extends State<RotatingProductBadges>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  int _i = 0;
  Timer? _timer;

  double get _rowH => 22 * widget.scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 480));
    _ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() => _i = (_i + 1) % widget.badges.length);
        _ctrl.value = 0; // snap back with the next badge now on top
      }
    });
    _maybeStart();
  }

  @override
  void didUpdateWidget(RotatingProductBadges old) {
    super.didUpdateWidget(old);
    if (old.badges.length != widget.badges.length) {
      _timer?.cancel();
      _i = 0;
      _ctrl.value = 0;
      _maybeStart();
    }
  }

  void _maybeStart() {
    if (widget.badges.length <= 1) return;
    _timer = Timer.periodic(widget.interval, (_) {
      if (!mounted || _ctrl.isAnimating) return;
      _ctrl.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.badges.isEmpty) return const SizedBox.shrink();
    final len = widget.badges.length;
    final current = widget.badges[_i % len];
    if (len == 1) {
      return SizedBox(
        height: _rowH,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: ProductBadgeChip(kind: current, scale: widget.scale),
        ),
      );
    }
    final next = widget.badges[(_i + 1) % len];
    return SizedBox(
      height: _rowH,
      child: ClipRect(
        // The two-row column is twice as tall as the viewport; OverflowBox
        // lets it lay out at its natural height (no overflow error) while the
        // ClipRect above hides everything outside the single-row window.
        child: OverflowBox(
          alignment: Alignment.topCenter,
          minHeight: 0,
          maxHeight: _rowH * 2,
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              final t = Curves.easeInOut.transform(_ctrl.value);
              return Transform.translate(
                offset: Offset(0, -_rowH * t),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _row(current),
                    _row(next),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _row(ProductBadgeKind kind) => SizedBox(
        height: _rowH,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: ProductBadgeChip(kind: kind, scale: widget.scale),
        ),
      );
}
