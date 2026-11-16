import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/campaign.dart';
import '../../../core/providers/campaign_provider.dart';
import '../../../core/utils/l10n.dart';
import '../../../core/utils/navigation.dart';

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

/// The campaign's entry card (Home strip, Categories first row). After Emad's 2026-11-16 review:
/// no discount badge; the campaign colour carries a faint printed pattern of sale motifs
/// ([CampaignSalePattern]) and the name is in the campaign's yellow with a dark outline
/// ([CampaignTitleText]). A light sweep of shine every few seconds (still when the phone asks for
/// reduced motion).
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
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _anim.stop();
      _anim.value = 0.6; // shine out of view
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
    // The logo already says the campaign's name (Emad, 2026-11-16): the yellow line is the headline
    // (Marketing → Campaigns), and under it the campaign's dates, which are always true.
    final headline = c.headline(isAr).isNotEmpty ? c.headline(isAr) : s.campaignShopDeals;
    final dates = campaignDateLine(c, isAr);

    final texts = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      CampaignTitleText(campaign: c, text: headline, fontSize: compact ? 16 : 19, maxLines: 2),
      if (dates.isNotEmpty) ...[
        const SizedBox(height: 3),
        Text(dates,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontFamily: _font,
              fontFamilyFallback: _fallback,
              fontSize: compact ? 12 : 13,
              fontWeight: FontWeight.w700,
              color: c.fg)),
      ],
    ]);

    final topRow = Row(children: [
      CampaignLogo(campaign: c, height: compact ? 56 : 68),
      const SizedBox(width: 12),
      Expanded(child: texts),
      if (compact) ...[
        const SizedBox(width: 8),
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(color: c.fg, shape: BoxShape.circle),
          // chevron_right mirrors in RTL: "forward" in both languages.
          child: Icon(Icons.chevron_right_rounded, size: 20, color: c.accent),
        ),
      ],
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
          child: ColoredBox(
            color: c.bg,
            child: Stack(children: [
              Positioned.fill(child: CampaignSalePattern(campaign: c)),
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

/// A line in the campaign's badge colour (yellow for Baahy Friday) with a thin dark outline and a
/// soft shadow, so it reads on the light campaign colour. [text] defaults to the campaign name.
class CampaignTitleText extends StatelessWidget {
  final Campaign campaign;
  final String? text;
  final double fontSize;
  final int maxLines;
  final TextAlign textAlign;
  const CampaignTitleText({
    super.key,
    required this.campaign,
    this.text,
    required this.fontSize,
    this.maxLines = 1,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    final c = campaign;
    final name = text ?? c.name(context.isAr);
    TextStyle base() => TextStyle(
          fontFamily: _font,
          fontFamilyFallback: _fallback,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          height: 1.25,
        );
    Text t(TextStyle st) => Text(name, maxLines: maxLines, overflow: TextOverflow.ellipsis, textAlign: textAlign, style: st);
    return Stack(children: [
      // Outline: the same text stroked in the dark text colour underneath.
      t(base().copyWith(
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = fontSize * 0.16
          ..strokeJoin = StrokeJoin.round
          ..color = c.fg,
        shadows: const [Shadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 2))],
      )),
      t(base().copyWith(color: c.accent)),
    ]);
  }
}

/// A few faint sale motifs (%, a price tag, «تخفيض», a bag) at the edges of the campaign colour,
/// kept clear of the text (Emad, 2026-11-16: the dense print was distracting; calm wins).
class CampaignSalePattern extends StatelessWidget {
  final Campaign campaign;
  final double opacity;
  const CampaignSalePattern({super.key, required this.campaign, this.opacity = 0.06});

  // (motif, x as a fraction of the width from the start edge, y as a fraction of the height, size, turn)
  static const _spots = [
    (Icons.percent_rounded, 0.02, 0.10, 26.0, -0.25),
    (Icons.local_offer_outlined, 0.30, 0.70, 26.0, 0.30),
    (null, 0.52, 0.04, 14.0, -0.12),
    (Icons.shopping_bag_outlined, 0.72, 0.72, 24.0, 0.15),
    (Icons.percent_rounded, 0.93, 0.36, 22.0, 0.30),
  ];

  @override
  Widget build(BuildContext context) {
    final color = campaign.fg.withValues(alpha: opacity);
    final word = context.isAr ? 'تخفيض' : 'SALE';
    return IgnorePointer(
      child: LayoutBuilder(builder: (_, box) {
        return ClipRect(
          child: Stack(children: [
            for (final (icon, x, y, size, turn) in _spots)
              PositionedDirectional(
                end: box.maxWidth * x,
                top: box.maxHeight * y,
                child: Transform.rotate(
                  angle: turn,
                  child: icon == null
                      ? Text(word,
                          style: TextStyle(
                              fontFamily: _font,
                              fontFamilyFallback: _fallback,
                              fontSize: size,
                              fontWeight: FontWeight.w900,
                              color: color))
                      : Icon(icon, size: size, color: color),
                ),
              ),
          ]),
        );
      }),
    );
  }
}

/// The campaign's dates, true for any campaign: «من السبت 21 إلى الجمعة 27 نوفمبر» /
/// "Sat 21 – Fri 27 November". Read from the API's own date (Tripoli), not the phone's time zone.
String campaignDateLine(Campaign c, bool isAr) {
  DateTime? d(String key) {
    final raw = c.json[key]?.toString() ?? '';
    return raw.length >= 10 ? DateTime.tryParse(raw.substring(0, 10)) : null;
  }
  final a = d('starts_at'), b = d('ends_at');
  if (a == null || b == null) return '';
  const daysAr = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
  const daysEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const monthsAr = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
  const monthsEn = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  final sameMonth = a.month == b.month && a.year == b.year;
  if (isAr) {
    final from = '${daysAr[a.weekday - 1]} ${a.day}${sameMonth ? '' : ' ${monthsAr[a.month - 1]}'}';
    return 'من $from إلى ${daysAr[b.weekday - 1]} ${b.day} ${monthsAr[b.month - 1]}';
  }
  final from = '${daysEn[a.weekday - 1]} ${a.day}${sameMonth ? '' : ' ${monthsEn[a.month - 1]}'}';
  return '$from – ${daysEn[b.weekday - 1]} ${b.day} ${monthsEn[b.month - 1]}';
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
        final t = (anim.value / 0.4).clamp(0.0, 1.0); // sweep in the first 40%, then rest
        if (t <= 0 || t >= 1) return const SizedBox.shrink();
        return FractionalTranslation(
          translation: Offset(-1.2 + t * 2.4, 0),
          child: Transform(
            transform: Matrix4.skewX(-0.35),
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Color(0x00FFFFFF),
                  Color(0x44FFFFFF),
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
