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

/// Home: the campaign strip at the top of the content (logo, name, headline, countdown, button).
/// Hidden while no campaign is running.
class CampaignHomeStrip extends ConsumerWidget {
  const CampaignHomeStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(currentCampaignProvider);
    if (c == null) return const SizedBox.shrink();
    final isAr = context.isAr;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GestureDetector(
        onTap: () => safePush(context, c.route()),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: c.bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                CampaignLogo(campaign: c, height: 64),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name(isAr),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontFamily: _font,
                              fontFamilyFallback: _fallback,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: c.fg)),
                      if (c.headline(isAr).isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(c.headline(isAr),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontFamily: _font,
                                fontFamilyFallback: _fallback,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: c.fg.withValues(alpha: 0.85))),
                      ],
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: CampaignCountdown(campaign: c, compact: true),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: c.fg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(context.s.campaignShopDeals,
                        style: TextStyle(
                            fontFamily: _font,
                            fontFamilyFallback: _fallback,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: c.bg)),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios_rounded, size: 11, color: c.bg),
                  ]),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

/// Categories (browse) screen: a full-width tile, the first row, opening the campaign page.
class CampaignBrowseTile extends ConsumerWidget {
  const CampaignBrowseTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(currentCampaignProvider);
    if (c == null) return const SizedBox.shrink();
    final isAr = context.isAr;
    return GestureDetector(
      onTap: () => safePush(context, c.route()),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: c.bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          CampaignLogo(campaign: c, height: 56),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.name(isAr),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: _font,
                        fontFamilyFallback: _fallback,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: c.fg)),
                const SizedBox(height: 2),
                Text(
                    c.headline(isAr).isNotEmpty
                        ? c.headline(isAr)
                        : context.s.campaignShopDeals,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: _font,
                        fontFamilyFallback: _fallback,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: c.fg.withValues(alpha: 0.85))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: c.fg, shape: BoxShape.circle),
            // chevron_right mirrors in RTL: "forward" in both languages.
            child: Icon(Icons.chevron_right_rounded, size: 20, color: c.bg),
          ),
        ]),
      ),
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
