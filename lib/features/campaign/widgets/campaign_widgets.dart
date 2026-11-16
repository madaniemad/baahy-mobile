import 'dart:async';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/campaign.dart';
import '../../../core/providers/campaign_provider.dart';
import '../../../core/utils/l10n.dart';
import '../../../core/utils/navigation.dart';
import '../../../shared/theme/app_theme.dart';

const _font = 'Manrope';
const _fallback = ['Tajawal'];

/// The campaign logo from the API; falls back to the campaign name when it has none or it fails.
class CampaignLogo extends StatelessWidget {
  final Campaign campaign;
  final double height;
  const CampaignLogo({super.key, required this.campaign, required this.height});

  @override
  Widget build(BuildContext context) {
    final name = Text(campaign.name(context.isAr),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
            fontFamily: _font,
            fontFamilyFallback: _fallback,
            fontSize: height * 0.28,
            fontWeight: FontWeight.w800,
            color: campaign.fg));
    final logo = campaign.logo;
    if (logo == null) return SizedBox(height: height, child: Center(child: name));
    return SizedBox(
      height: height,
      child: CachedNetworkImage(
        imageUrl: logo,
        fit: BoxFit.contain,
        memCacheWidth: (height * 4).round(),
        fadeInDuration: const Duration(milliseconds: 150),
        placeholder: (_, __) => SizedBox(width: height * 1.2),
        errorWidget: (_, __, ___) => Center(child: name),
      ),
    );
  }
}

/// Live countdown to the campaign's end: day / hour / minute / second boxes in the campaign colours.
/// Renders nothing when the campaign has no end time or hides the countdown.
class CampaignCountdown extends StatefulWidget {
  final Campaign campaign;
  final bool compact;
  const CampaignCountdown({super.key, required this.campaign, this.compact = false});

  @override
  State<CampaignCountdown> createState() => _CampaignCountdownState();
}

class _CampaignCountdownState extends State<CampaignCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.campaign;
    final end = c.endsAt;
    if (!c.showCountdown || end == null) return const SizedBox.shrink();
    var left = end.difference(DateTime.now());
    if (left.isNegative) left = Duration.zero;
    final s = context.s;
    final parts = [
      (left.inDays, s.campaignDays),
      (left.inHours % 24, s.campaignHours),
      (left.inMinutes % 60, s.campaignMinutes),
      (left.inSeconds % 60, s.campaignSeconds),
    ];
    if (widget.compact) return _compact(context, c, left);
    const box = 40.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(s.campaignEndsIn,
            style: TextStyle(
                fontFamily: _font,
                fontFamilyFallback: _fallback,
                fontSize: widget.compact ? 11 : 12.5,
                fontWeight: FontWeight.w700,
                color: c.fg)),
        SizedBox(width: widget.compact ? 6 : 8),
        // The row follows the reading direction, so days come first in both languages.
        for (var i = 0; i < parts.length; i++) ...[
          if (i > 0) SizedBox(width: widget.compact ? 3 : 5),
          Container(
            width: box,
            padding: EdgeInsets.symmetric(vertical: widget.compact ? 3 : 4),
            decoration: BoxDecoration(
              color: c.fg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(parts[i].$1.toString().padLeft(2, '0'),
                  style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: widget.compact ? 12.5 : 15,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                      color: c.accent)),
              if (!widget.compact)
                Text(parts[i].$2,
                    maxLines: 1,
                    style: TextStyle(
                        fontFamily: _font,
                        fontFamilyFallback: _fallback,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                        color: c.bg)),
            ]),
          ),
        ],
      ],
    );
  }
}

extension on _CampaignCountdownState {
  /// One line for strips: «ينتهي خلال [13 يوم] [20:35:40]».
  Widget _compact(BuildContext context, Campaign c, Duration left) {
    String two(int n) => n.toString().padLeft(2, '0');
    Widget pill(String text, {TextDirection? dir}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(color: c.fg, borderRadius: BorderRadius.circular(8)),
          child: Text(text,
              textDirection: dir,
              style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontFamilyFallback: _fallback,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  color: c.accent)),
        );
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(context.s.campaignEndsIn,
          style: TextStyle(
              fontFamily: _font,
              fontFamilyFallback: _fallback,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: c.fg)),
      const SizedBox(width: 6),
      if (left.inDays > 0) ...[
        pill(context.s.campaignDaysN(left.inDays)),
        const SizedBox(width: 4),
      ],
      // Clock digits always read left to right.
      pill('${two(left.inHours % 24)}:${two(left.inMinutes % 60)}:${two(left.inSeconds % 60)}',
          dir: TextDirection.ltr),
    ]);
  }
}

/// Home: the campaign strip at the top of the content. Hidden while no campaign is running.
class CampaignHomeStrip extends ConsumerWidget {
  const CampaignHomeStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(currentCampaignProvider);
    if (c == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: CampaignPromoCard(campaign: c),
    );
  }
}

/// Categories (browse) screen: the first row, opening the campaign page.
class CampaignBrowseTile extends ConsumerWidget {
  const CampaignBrowseTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(currentCampaignProvider);
    if (c == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: CampaignPromoCard(campaign: c, compact: true),
    );
  }
}

/// The campaign's entry card (Home strip, Categories first row). Emad, 2026-11-16: "more exciting,
/// add discount and sale/offer badges": the real top discount on a starburst sticker, a «عروض» tag on
/// the logo, faint sale icons behind, and a light sweep of shine every few seconds (off when the
/// phone asks for reduced motion). The discount is the server's `max_discount`, never a made-up one;
/// without it the sticker shows a % sign.
class CampaignPromoCard extends StatefulWidget {
  final Campaign campaign;
  /// Categories row: one line, no countdown or button.
  final bool compact;
  const CampaignPromoCard({super.key, required this.campaign, this.compact = false});

  @override
  State<CampaignPromoCard> createState() => _CampaignPromoCardState();
}

class _CampaignPromoCardState extends State<CampaignPromoCard> with SingleTickerProviderStateMixin {
  late final AnimationController _anim =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _anim.stop();
      _anim.value = 0.6; // shine out of view, sticker at rest
    } else if (!_anim.isAnimating) {
      _anim.repeat();
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.campaign;
    final compact = widget.compact;
    final isAr = context.isAr;
    final s = context.s;
    final dark = Color.lerp(c.bg, Colors.black, 0.16)!;
    final sticker = compact ? 60.0 : 78.0;

    final pillText = c.maxDiscount > 0
        ? s.campaignUpToOff(c.maxDiscount)
        : (c.headline(isAr).isNotEmpty ? c.headline(isAr) : s.campaignShopDeals);

    final texts = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(c.name(isAr),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontFamily: _font,
              fontFamilyFallback: _fallback,
              fontSize: compact ? 16 : 19,
              fontWeight: FontWeight.w900,
              height: 1.2,
              color: c.fg)),
      SizedBox(height: compact ? 4 : 6),
      // The discount line: dark pill, the badge colour for the words.
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: c.fg, borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.local_fire_department_rounded, size: compact ? 13 : 15, color: c.accent),
          const SizedBox(width: 3),
          Flexible(
            child: Text(pillText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontFamily: _font,
                    fontFamilyFallback: _fallback,
                    fontSize: compact ? 12 : 13.5,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                    color: c.accent)),
          ),
        ]),
      ),
      if (!compact && c.maxDiscount > 0 && c.headline(isAr).isNotEmpty) ...[
        const SizedBox(height: 5),
        Text(c.headline(isAr),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontFamily: _font,
                fontFamilyFallback: _fallback,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: c.fg.withValues(alpha: 0.85))),
      ],
    ]);

    final topRow = Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      _LogoWithTag(campaign: c, height: compact ? 54 : 66),
      const SizedBox(width: 10),
      Expanded(child: texts),
      const SizedBox(width: 6),
      _DiscountSticker(campaign: c, size: sticker, anim: _anim),
    ]);

    final content = compact
        ? topRow
        : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            topRow,
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FittedBox(fit: BoxFit.scaleDown, child: CampaignCountdown(campaign: c, compact: true)),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: c.fg, borderRadius: BorderRadius.circular(12)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(s.campaignShopDeals,
                      style: TextStyle(
                          fontFamily: _font,
                          fontFamilyFallback: _fallback,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: c.accent)),
                  const SizedBox(width: 4),
                  // chevron_right mirrors in RTL: "forward" in both languages.
                  Icon(Icons.chevron_right_rounded, size: 18, color: c.accent),
                ]),
              ),
            ]),
          ]);

    return Semantics(
      button: true,
      label: c.name(isAr),
      child: GestureDetector(
        onTap: () => safePush(context, c.route()),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [c.bg, dark],
              ),
            ),
            child: Stack(children: [
              Positioned.fill(child: _SaleBackdrop(color: c.fg)),
              Positioned.fill(child: IgnorePointer(child: _Shine(anim: _anim))),
              Padding(
                padding: EdgeInsets.fromLTRB(12, compact ? 10 : 12, 12, compact ? 10 : 12),
                child: content,
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// The campaign logo with a small tilted «عروض» tag on its bottom corner (the top carries the
/// sticker's own «تخفيضات» label).
class _LogoWithTag extends StatelessWidget {
  final Campaign campaign;
  final double height;
  const _LogoWithTag({required this.campaign, required this.height});

  @override
  Widget build(BuildContext context) {
    final c = campaign;
    return SizedBox(
      height: height + 8,
      child: Stack(clipBehavior: Clip.none, alignment: Alignment.bottomCenter, children: [
        CampaignLogo(campaign: c, height: height),
        PositionedDirectional(
          bottom: 0,
          start: -6,
          child: Transform.rotate(
            angle: -0.2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(6),
                boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 3, offset: Offset(0, 1))],
              ),
              child: Text(context.s.campaignDealsBadge,
                  style: const TextStyle(
                      fontFamily: _font,
                      fontFamilyFallback: _fallback,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      color: Colors.white)),
            ),
          ),
        ),
      ]),
    );
  }
}

/// The starburst sticker: «حتى / 81%» on the badge colour, with a gentle wobble.
class _DiscountSticker extends StatelessWidget {
  final Campaign campaign;
  final double size;
  final Animation<double> anim;
  const _DiscountSticker({required this.campaign, required this.size, required this.anim});

  @override
  Widget build(BuildContext context) {
    final c = campaign;
    final hasPct = c.maxDiscount > 0;
    final face = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _StarburstPainter(fill: c.accent, stroke: c.fg),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(size * 0.2),
            child: FittedBox(
              child: hasPct
                  ? Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(context.s.campaignUpTo,
                          style: TextStyle(
                              fontFamily: _font,
                              fontFamilyFallback: _fallback,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              height: 1.0,
                              color: c.fg)),
                      Text('${c.maxDiscount}%',
                          textDirection: TextDirection.ltr,
                          style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              height: 1.05,
                              color: c.fg)),
                    ])
                  : Icon(Icons.percent_rounded, size: 30, color: c.fg),
            ),
          ),
        ),
      ),
    );
    return AnimatedBuilder(
      animation: anim,
      builder: (_, child) {
        final t = anim.value * 2 * math.pi;
        return Transform.rotate(
          angle: math.sin(t) * 0.07,
          child: Transform.scale(scale: 1 + 0.04 * math.sin(t * 2).abs(), child: child),
        );
      },
      child: face,
    );
  }
}

class _StarburstPainter extends CustomPainter {
  final Color fill;
  final Color stroke;
  _StarburstPainter({required this.fill, required this.stroke});

  @override
  void paint(Canvas canvas, Size size) {
    const spikes = 16;
    final c = size.center(Offset.zero);
    final outer = size.shortestSide / 2 - 2;
    final inner = outer * 0.8;
    final path = Path();
    for (var i = 0; i < spikes * 2; i++) {
      final r = i.isEven ? outer : inner;
      final a = -math.pi / 2 + i * math.pi / spikes;
      final p = c + Offset(math.cos(a) * r, math.sin(a) * r);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawShadow(path, const Color(0x66000000), 3, false);
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
        path,
        Paint()
          ..color = stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(_StarburstPainter old) => old.fill != fill || old.stroke != stroke;
}

/// Faint sale icons scattered behind the content.
class _SaleBackdrop extends StatelessWidget {
  final Color color;
  const _SaleBackdrop({required this.color});

  static const _icons = [
    (Icons.percent_rounded, 0.30, 0.10, 26.0, -0.3),
    (Icons.local_offer_rounded, 0.55, 0.62, 30.0, 0.4),
    (Icons.sell_outlined, 0.04, 0.70, 24.0, -0.5),
    (Icons.percent_rounded, 0.72, 0.05, 20.0, 0.3),
    (Icons.shopping_bag_outlined, 0.42, 0.85, 22.0, 0.15),
    (Icons.auto_awesome_rounded, 0.62, 0.30, 16.0, 0.0),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, box) {
      return Stack(children: [
        for (final (icon, x, y, size, turn) in _icons)
          PositionedDirectional(
            start: box.maxWidth * x,
            top: box.maxHeight * y - size / 2,
            child: Transform.rotate(
              angle: turn,
              child: Icon(icon, size: size, color: color.withValues(alpha: 0.08)),
            ),
          ),
      ]);
    });
  }
}

/// A soft diagonal light that sweeps across once per cycle, then rests.
class _Shine extends StatelessWidget {
  final Animation<double> anim;
  const _Shine({required this.anim});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) {
        final t = (anim.value / 0.45).clamp(0.0, 1.0); // sweep in the first 45%, then rest
        if (t <= 0 || t >= 1) return const SizedBox.shrink();
        return FractionalTranslation(
          translation: Offset(-1.2 + t * 2.4, 0),
          child: Transform(
            transform: Matrix4.skewX(-0.35),
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Color(0x00FFFFFF),
                  Color(0x55FFFFFF),
                  Color(0x00FFFFFF),
                ], stops: [0.35, 0.5, 0.65]),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Search screen: «عروض <name>», the first trending chip.
class CampaignSearchChip extends StatelessWidget {
  final Campaign campaign;
  const CampaignSearchChip({super.key, required this.campaign});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => safePush(context, campaign.route()),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: campaign.bg,
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.local_offer_rounded, size: 14, color: campaign.fg),
          const SizedBox(width: 5),
          Text(context.s.campaignOffersChip(campaign.name(context.isAr)),
              style: TextStyle(
                  fontFamily: _font,
                  fontFamilyFallback: _fallback,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: campaign.fg)),
        ]),
      ),
    );
  }
}

/// Store page: «مشارك في <name>» when the store has products in the campaign; opens the campaign
/// page filtered to this store. Nothing while loading, on failure or when it has none.
class CampaignStoreStrip extends ConsumerWidget {
  final int vendorId;
  const CampaignStoreStrip({super.key, required this.vendorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(currentCampaignProvider);
    if (c == null) return const SizedBox.shrink();
    final inIt = ref.watch(vendorInCampaignProvider((c.slug, vendorId))).valueOrNull ?? false;
    if (!inIt) return const SizedBox.shrink();
    final isAr = context.isAr;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: GestureDetector(
        onTap: () => safePush(context, c.route(vendorId: vendorId)),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          decoration: BoxDecoration(
            color: c.bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            CampaignLogo(campaign: c, height: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.s.campaignTakingPart(c.name(isAr)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: _font,
                          fontFamilyFallback: _fallback,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: c.fg)),
                  Text(context.s.campaignSeeStoreDeals,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: _font,
                          fontFamilyFallback: _fallback,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: c.fg.withValues(alpha: 0.85))),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 22, color: c.fg),
          ]),
        ),
      ),
    );
  }
}
