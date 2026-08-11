import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/app_config.dart';
import '../../../core/models/tier_status.dart';
import '../../../core/providers/app_config_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/tier_provider.dart';
import '../../../core/utils/l10n.dart';
import '../../../core/utils/navigation.dart';
import '../../../shared/theme/app_theme.dart';

final _hubReferralProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  try {
    final res = await ApiClient.instance.dio.get('/referrals');
    final data = res.data['data'] as Map<String, dynamic>? ?? {};
    return {
      'code':          data['referral_code'] as String? ?? '',
      'invited_count': (data['total_referrals'] as num?)?.toInt() ?? 0,
      'used_count':    (data['completed'] as num?)?.toInt() ?? 0,
      'earned_amount': (data['total_earned'] as num?)?.toDouble() ?? 0.0,
    };
  } catch (_) {
    return {'code': '', 'invited_count': 0, 'used_count': 0, 'earned_amount': 0.0};
  }
});

// ── Tier colour palette ───────────────────────────────────────────────────────
class _TierPalette {
  final String nameAr;
  final Color gradA;   // card background gradient — the tier's own metal colour
  final Color gradB;
  final Color fg;      // text / icon colour ON the card (contrasts the metal bg)
  final Color accent;  // saturated colour for white backgrounds (values, borders, inactive header)
  final bool darkBg;   // dark card → icon needs a light halo; light card → a dark drop shadow
  const _TierPalette({required this.nameAr, required this.gradA, required this.gradB,
    required this.fg, required this.accent, required this.darkBg});
}

const _kTiers       = ['bronze', 'silver', 'gold', 'platinum'];
const _kTierNamesAr = ['Silver', 'Gold', 'Platinum', 'Black'];
const _kTierNamesEn = ['Silver', 'Gold', 'Platinum', 'Black'];

// Shows "1.5" for fractional rates, "2" for whole numbers
String _fmtRate(double r) {
  final i = r.toInt();
  return r == i.toDouble() ? '$i' : r.toStringAsFixed(1);
}

// Card bg = the tier's own metal colour; fg = readable text on it; accent = for white bg.
const _palettes = <String, _TierPalette>{
  // gradA/gradB/fg = the metal hero card; accent = the tier's text/number colour (per reference)
  'bronze':   _TierPalette(nameAr: 'Silver',   gradA: Color(0xFFEAEFF3), gradB: Color(0xFFB6C1CC), fg: Color(0xFF33404D), accent: Color(0xFF7C8894), darkBg: false),  // Silver → grey
  'silver':   _TierPalette(nameAr: 'Gold',     gradA: Color(0xFFF4D06A), gradB: Color(0xFFCF9714), fg: Color(0xFF4A3608), accent: Color(0xFFC69320), darkBg: false),  // Gold → amber
  'gold':     _TierPalette(nameAr: 'Platinum', gradA: Color(0xFFEDF3F8), gradB: Color(0xFFA6C0D2), fg: Color(0xFF2B4256), accent: Color(0xFF3B82C4), darkBg: false),  // Platinum → blue
  'platinum': _TierPalette(nameAr: 'Black',    gradA: Color(0xFF40404C), gradB: Color(0xFF0E0E16), fg: Color(0xFFFFFFFF), accent: Color(0xFF1C1C22), darkBg: true),   // Black → near-black
};
const _bronzePalette = _TierPalette(nameAr: 'Silver', gradA: Color(0xFFEAEFF3), gradB: Color(0xFFB6C1CC), fg: Color(0xFF33404D), accent: Color(0xFF7C8894), darkBg: false);
_TierPalette _pal(String? t) => _palettes[t?.toLowerCase()] ?? _bronzePalette;

/// Tier badge PNG with a soft drop shadow so it never blends into a same-colour
/// card: a dark shadow on light metals, a light halo on the dark onyx card.
class _TierBadge extends StatelessWidget {
  final String tierKey;
  final double size;
  final bool darkBg;
  const _TierBadge({required this.tierKey, required this.size, required this.darkBg});
  @override
  Widget build(BuildContext context) {
    final asset  = 'assets/images/tier_$tierKey.png';
    final shadow = darkBg ? Colors.white.withValues(alpha: 0.40) : Colors.black.withValues(alpha: 0.32);
    return SizedBox(
      width: size, height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.translate(
            offset: darkBg ? Offset.zero : const Offset(1.2, 1.8),
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 4.5, sigmaY: 4.5),
              child: Image.asset(asset, color: shadow, colorBlendMode: BlendMode.srcIn,
                width: size, height: size, fit: BoxFit.contain),
            ),
          ),
          Image.asset(asset, width: size, height: size, fit: BoxFit.contain),
        ],
      ),
    );
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────
class RewardsHubScreen extends ConsumerWidget {
  const RewardsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tierAsync = ref.watch(tierProvider);
    final refAsync  = ref.watch(_hubReferralProvider);
    final config    = ref.watch(appConfigProvider);
    final user      = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: context.col.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: AppBar(
            backgroundColor: context.col.surface,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: context.col.ink0),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              'برنامج الولاء',
              textDirection: TextDirection.rtl,
              style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
                fontWeight: FontWeight.w800, color: context.col.ink0),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.info_outline_rounded, color: context.col.ink2),
                onPressed: () => safePush(context, '/faq'),
              ),
            ],
          ),
        ),
      ),
      body: tierAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(
          color: AppColors.primary, strokeWidth: 2)),
        error: (_, __) => const SizedBox.shrink(),
        data: (tier) {
          final palette = _pal(tier.tier);
          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 40),
            child: Column(children: [

              // ── 0. Pending rewards banner ──────────────────────────────
              if (tier.pendingTotal > 0)
                _PendingRewardsBanner(tier: tier),

              // ── 1. Hero card ───────────────────────────────────────────
              _HeroCard(tier: tier, palette: palette,
                walletBalance: user?.walletBalance ?? 0),

              const SizedBox(height: 16),

              // ── 2. Progress ────────────────────────────────────────────
              if (tier.nextTier != null)
                _ProgressCard(tier: tier, palette: palette),

              if (tier.nextTier != null) const SizedBox(height: 16),

              // ── 3. Benefits (4 separate cards) ─────────────────────────
              _BenefitsSection(currentTier: tier.tier, config: config),

              const SizedBox(height: 16),

              // ── 4. Referral ────────────────────────────────────────────
              _ReferralCard(
                refAsync: refAsync,
                user: user,
                giverAmount: config.referralGiverAmount,
                receiverAmount: config.referralReceiverAmount,
              ),

              const SizedBox(height: 16),

              // ── 5. Milestones ──────────────────────────────────────────
              _MilestonesSection(tier: tier, config: config),

              const SizedBox(height: 16),

              // ── 6. FAQ ─────────────────────────────────────────────────
              _FaqSection(),
            ]),
          );
        },
      ),
    );
  }
}

// ── 1. Hero card ──────────────────────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  final TierStatus tier;
  final _TierPalette palette;
  final double walletBalance;
  const _HeroCard({required this.tier, required this.palette,
    required this.walletBalance});

  @override
  Widget build(BuildContext context) {
    final isAr   = context.isAr;
    final nameAr = _palettes[tier.tier?.toLowerCase()]?.nameAr ?? 'Silver';
    final nameEn = nameAr; // brand tier names are identical in both languages
    final cashback = _fmtRate(tier.cashbackRate);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [palette.gradA, palette.gradB],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: palette.gradB.withValues(alpha: 0.40),
            blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
        child: Column(children: [

          // Top row: text (right) + medal icon (left)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Text section (right in RTL = first child)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAr ? 'مستواك الحالي' : 'Current Tier',
                      style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal'], fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: palette.fg.withValues(alpha: 0.65)),
                    ),
                    const SizedBox(height: 8),
                    // Tier name + مميز chip inline
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '⁦${isAr ? nameAr : nameEn}⁩',
                          textDirection: TextDirection.ltr,
                          style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal'],
                            fontSize: 36, fontWeight: FontWeight.w900,
                            color: palette.fg, height: 1),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: palette.fg.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            isAr ? 'مميز' : 'Member',
                            style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal'], fontSize: 12,
                              fontWeight: FontWeight.w700, color: palette.fg),
                          ),
                        ),
                      ],
                    ),
                    if (tier.nextTier != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        isAr ? 'استمر وارتقِ للمستوى التالي'
                             : 'Keep going to reach the next tier',
                        style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal'], fontSize: 12,
                          color: palette.fg.withValues(alpha: 0.72)),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Medal icon (left in RTL = last child) — drop shadow so it stays visible on same-colour bg
              _TierBadge(tierKey: tier.tier?.toLowerCase() ?? 'bronze', size: 90, darkBg: palette.darkBg),
            ],
          ),

          const SizedBox(height: 20),

          // Divider
          Container(height: 1,
            color: palette.fg.withValues(alpha: 0.18)),

          const SizedBox(height: 18),

          // Stats row
          IntrinsicHeight(
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _HeroStat(fg: palette.fg,
                  value: '$cashback%',
                  label: isAr ? 'كاش باك' : 'Cashback',
                ),
                Container(width: 1,
                  color: palette.fg.withValues(alpha: 0.22)),
                _HeroStat(fg: palette.fg,
                  value: walletBalance.round().toString(),
                  label: isAr ? 'رصيد المكافآت' : 'Rewards',
                  suffix: isAr ? ' د.ل' : ' LYD',
                  icon: Icons.lock_outline_rounded,
                ),
                Container(width: 1,
                  color: palette.fg.withValues(alpha: 0.22)),
                _HeroStat(fg: palette.fg,
                  value: '${tier.returnDays}',
                  label: isAr ? 'أيام إرجاع' : 'Returns',
                  suffix: isAr ? '' : ' days',
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String value;
  final String label;
  final String? suffix;
  final IconData? icon;
  final Color fg;
  const _HeroStat({required this.value, required this.label, required this.fg,
    this.suffix, this.icon});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: fg.withValues(alpha: 0.75)),
          const SizedBox(width: 3),
        ],
        Text(value,
          style: TextStyle(fontFamily: 'PlusJakartaSans',
            fontSize: 20, fontWeight: FontWeight.w800,
            color: fg, height: 1)),
        if (suffix != null && suffix!.isNotEmpty)
          Text(suffix!,
            style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal'], fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg.withValues(alpha: 0.80))),
      ]),
      const SizedBox(height: 5),
      Text(label,
        textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal'], fontSize: 11,
          color: fg.withValues(alpha: 0.72))),
    ]),
  );
}

// ── 2. Progress card ──────────────────────────────────────────────────────────
class _ProgressCard extends StatelessWidget {
  final TierStatus tier;
  final _TierPalette palette;
  const _ProgressCard({required this.tier, required this.palette});

  String _nextTierAr(String? t) {
    switch (t?.toLowerCase()) {
      case 'silver':   return 'Gold';
      case 'gold':     return 'Platinum';
      case 'platinum': return 'Black';
      default:         return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr   = context.isAr;
    final nextPal = _palettes[tier.nextTier?.toLowerCase()] ?? _bronzePalette;
    final nextName = isAr ? _nextTierAr(tier.nextTier)
        : (tier.nextTier != null
            ? '${tier.nextTier![0].toUpperCase()}${tier.nextTier!.substring(1)}'
            : '');

    final ordersDone = tier.ordersNeeded - tier.ordersRemaining;
    final ordersPct  = tier.ordersNeeded > 0
        ? (ordersDone / tier.ordersNeeded).clamp(0.0, 1.0) : 0.0;
    final spendDone  = tier.spendNeeded - tier.spendRemaining;
    final spendPct   = tier.spendNeeded > 0
        ? (spendDone / tier.spendNeeded).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: context.col.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.col.border),
        boxShadow: AppShadows.shadowLifted,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Header row: title + next tier icon
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                isAr ? 'للوصول إلى مستوى $nextName' : 'Progress to $nextName',
                style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 15,
                  fontWeight: FontWeight.w800, color: context.col.ink0),
              ),
              const SizedBox(height: 2),
              Text(
                isAr ? 'استمر للتقدّم للمستوى التالي' : 'Keep going to reach the next tier',
                style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 12,
                  color: context.col.ink3),
              ),
            ]),
          ),
          const SizedBox(width: 12),
          _TierBadge(tierKey: tier.nextTier?.toLowerCase() ?? 'bronze', size: 44, darkBg: false),
        ]),

        const SizedBox(height: 18),

        // Orders progress bar
        _ProgressRow(
          icon: Icons.receipt_long_outlined,
          labelAr: 'الطلبات',
          labelEn: 'Orders',
          current: ordersDone,
          total: tier.ordersNeeded,
          suffixAr: 'طلب',
          suffixEn: 'orders',
          pct: ordersPct,
          color: AppColors.teal,
          isAr: isAr,
          context: context,
        ),

        const SizedBox(height: 14),

        // Spend progress bar
        _ProgressRow(
          icon: Icons.account_balance_wallet_outlined,
          labelAr: 'المبلغ',
          labelEn: 'Amount',
          current: spendDone.toInt(),
          total: tier.spendNeeded.toInt(),
          suffixAr: 'د.ل',
          suffixEn: 'LYD',
          pct: spendPct,
          color: AppColors.teal,
          isAr: isAr,
          context: context,
        ),
      ]),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final IconData icon;
  final String labelAr, labelEn;
  final int current, total;
  final String suffixAr, suffixEn;
  final double pct;
  final Color color;
  final bool isAr;
  final BuildContext context;

  const _ProgressRow({
    required this.icon, required this.labelAr, required this.labelEn,
    required this.current, required this.total,
    required this.suffixAr, required this.suffixEn,
    required this.pct, required this.color,
    required this.isAr, required this.context,
  });

  @override
  Widget build(BuildContext ctx) {
    final suffix = isAr ? suffixAr : suffixEn;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Text(isAr ? labelAr : labelEn,
          style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 13,
            fontWeight: FontWeight.w600, color: ctx.col.ink1)),
        const Spacer(),
        Text('$current / $total $suffix',
          style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12,
            fontWeight: FontWeight.w700, color: ctx.col.ink2)),
      ]),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(
          value: pct,
          minHeight: 7,
          backgroundColor: ctx.col.surfaceSoft,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
    ]);
  }
}

// ── 3. Benefits — 4 separate tier cards ──────────────────────────────────────
class _BenefitsSection extends StatelessWidget {
  final String? currentTier;
  final AppConfig config;
  const _BenefitsSection({this.currentTier, required this.config});

  @override
  Widget build(BuildContext context) {
    final isAr  = context.isAr;
    final curIdx = _kTiers.indexOf(currentTier?.toLowerCase() ?? 'bronze')
        .clamp(0, 3);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // Section header
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          const Icon(Icons.diamond_outlined, size: 17, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            isAr ? 'مزايا كل مستوى' : 'Tier Benefits',
            style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 16,
              fontWeight: FontWeight.w800, color: context.col.ink0),
          ),
        ]),
      ),

      const SizedBox(height: 14),

      // 4-column fixed layout — all tiers visible simultaneously
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < _kTiers.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _TierCard(
                  tierKey: _kTiers[i],
                  nameAr: _kTierNamesAr[i],
                  nameEn: _kTierNamesEn[i],
                  cashback: '${_fmtRate(config.tierCashbacks[i])}%',
                  shipping: config.tierShippingThresholds[i].toInt().toString(),
                  returns:  config.tierReturnDays[i].toString(),
                  palette: _palettes[_kTiers[i]] ?? _bronzePalette,
                  isActive: i == curIdx,
                  isAr: isAr,
                ),
              ),
            ],
          ],
        ),
      ),

      const SizedBox(height: 10),

      // Footnote
      Center(
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.auto_awesome, size: 12, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            isAr ? 'كلما ارتقيت في المستوى، زادت مزاياك'
                : 'More perks as you level up',
            style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 11.5,
              color: context.col.ink3),
          ),
        ]),
      ),
    ]);
  }
}

class _TierCard extends StatelessWidget {
  final String tierKey;
  final String nameAr, nameEn;
  final String cashback, shipping, returns;
  final _TierPalette palette;
  final bool isActive, isAr;
  const _TierCard({required this.tierKey, required this.nameAr, required this.nameEn,
    required this.cashback, required this.shipping, required this.returns,
    required this.palette, required this.isActive, required this.isAr});

  @override
  Widget build(BuildContext context) {
    // Number/name colour per tier (Black adapts to theme so it stays visible in dark mode).
    final tierColor = palette.darkBg ? context.col.ink0 : palette.accent;
    final name = isAr ? nameAr : nameEn;
    return Container(
      decoration: BoxDecoration(
        color: context.col.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? AppColors.primary : context.col.border,
          width: isActive ? 2 : 1,
        ),
        boxShadow: isActive
            ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.28), blurRadius: 16, spreadRadius: 1, offset: const Offset(0, 4))]
            : AppShadows.shadowCard,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isActive ? 14 : 15),
        child: Column(children: [
          // Header — icon + "Baahy <Tier>" on a faint tint
          Container(
            width: double.infinity,
            color: context.col.surfaceSoft,
            padding: const EdgeInsets.fromLTRB(4, 14, 4, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TierBadge(tierKey: tierKey, size: 46, darkBg: palette.darkBg),
                const SizedBox(height: 9),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(name,
                    textDirection: TextDirection.ltr,
                    style: TextStyle(fontFamily: 'Manrope', fontSize: 13,
                      fontWeight: FontWeight.w800, color: tierColor)),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: context.col.border),
          // Benefit rows — big colored value + grey label
          _cardBenefit(cashback, isAr ? 'كاش باك' : 'Cash', tierColor, context),
          Divider(height: 1, color: context.col.border, indent: 14, endIndent: 14),
          _cardBenefit('$returns ${isAr ? 'أيام' : 'd'}',
            isAr ? 'إرجاع' : 'Return', tierColor, context),
        ]),
      ),
    );
  }

  Widget _cardBenefit(String value, String label, Color color, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
      child: Column(children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: TextStyle(fontFamily: 'PlusJakartaSans',
              fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        ),
        const SizedBox(height: 3),
        Text(label,
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal'], fontSize: 10.5,
            color: context.col.ink3)),
      ]),
    );
  }
}

// ── 4. Referral card ──────────────────────────────────────────────────────────
class _ReferralCard extends ConsumerStatefulWidget {
  final AsyncValue<Map<String, dynamic>> refAsync;
  final dynamic user;
  final int giverAmount;
  final int receiverAmount;
  const _ReferralCard({required this.refAsync, required this.user,
    required this.giverAmount, required this.receiverAmount});

  @override
  ConsumerState<_ReferralCard> createState() => _ReferralCardState();
}

class _ReferralCardState extends ConsumerState<_ReferralCard> {
  bool _copied = false;

  String get _code {
    final d = widget.refAsync.value;
    if (d != null && (d['code'] as String).isNotEmpty) return d['code'] as String;
    return widget.user?.referralCode ?? '';
  }

  void _copy() {
    if (_code.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _code));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _share() async {
    if (_code.isEmpty) return;
    final firstName = ((widget.user?.name ?? '') as String).split(' ').first;
    final inviteLink = 'https://baahy.com/invite/$_code'
        '?from=$firstName&reward=${widget.receiverAmount}';
    final text = context.isAr
        ? '$firstName دعاك للانضمام لباهي!\n'
          'ستُضاف ${widget.receiverAmount} د.ل لمحفظتك فور التسجيل 🎁\n'
          '$inviteLink'
        : 'Join Baahy with my invite!\n'
          'Get ${widget.receiverAmount} LYD added to your wallet on signup 🎁\n'
          '$inviteLink';
    try {
      await SharePlus.instance.share(ShareParams(text: text));
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم نسخ رابط الدعوة',
            style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal']))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr  = context.isAr;
    final data  = widget.refAsync.value;
    final earned  = (data?['earned_amount'] as double?) ?? 0.0;
    final invited = (data?['invited_count'] as int?) ?? 0;
    final joined  = (data?['used_count'] as int?) ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.col.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.col.border),
        boxShadow: AppShadows.shadowLifted,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Top row: text + icon
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                isAr ? 'ادعُ أصدقاءك واربح مكافآت'
                    : 'Invite Friends, Earn Rewards',
                style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 16,
                  fontWeight: FontWeight.w800, color: context.col.ink0),
              ),
              const SizedBox(height: 6),
              Text(
                isAr
                    ? 'احصل على ${widget.giverAmount} د.ل لكل صديق\nبمجرد إتمام أول طلب له'
                    : 'Get ${widget.giverAmount} LYD per friend\nafter their first order',
                style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 12,
                  color: context.col.ink2, height: 1.65),
              ),
            ]),
          ),
          const SizedBox(width: 12),
          // Gift icon
          Image.asset(
            'assets/images/referral_gift.png',
            width: 80, height: 80, fit: BoxFit.contain,
          ),
        ]),

        const SizedBox(height: 18),

        // Code box
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: context.col.surfaceSoft,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: context.col.borderStrong),
          ),
          child: Row(children: [
            Expanded(
              child: Text(
                _code.isNotEmpty ? _code : '——————',
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'PlusJakartaSans',
                  fontSize: 20, fontWeight: FontWeight.w800,
                  letterSpacing: 2.0),
              ),
            ),
            GestureDetector(
              onTap: _copy,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  _copied ? Icons.check_rounded : Icons.copy_rounded,
                  key: ValueKey(_copied),
                  size: 20,
                  color: _copied ? AppColors.primary : context.col.ink2,
                ),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 12),

        // Share button — tiffany
        GestureDetector(
          onTap: _share,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.share_rounded, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                isAr ? 'شارك رابط الدعوة' : 'Share invite link',
                style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 14,
                  fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ]),
          ),
        ),

        // Earned stats (show only when non-zero)
        if (invited > 0 || earned > 0) ...[
          const SizedBox(height: 16),
          Divider(color: context.col.border, height: 1),
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _RefStat('$invited', isAr ? 'تمت دعوتهم' : 'Invited'),
            _RefStat('$joined',  isAr ? 'انضموا' : 'Joined'),
            _RefStat(earned.toStringAsFixed(0),
              isAr ? 'د.ل ربحت' : 'LYD earned', isMoney: true),
          ]),
        ],
      ]),
    );
  }
}

class _RefStat extends StatelessWidget {
  final String value;
  final String label;
  final bool isMoney;
  const _RefStat(this.value, this.label, {this.isMoney = false});
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value,
      style: TextStyle(fontFamily: 'PlusJakartaSans',
        fontSize: 20, fontWeight: FontWeight.w800,
        color: context.col.ink0, height: 1)),
    const SizedBox(height: 3),
    Text(label,
      style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 11,
        color: context.col.ink3)),
  ]);
}

// ── 5. Milestones — horizontal progress steps ─────────────────────────────────
class _MilestonesSection extends StatelessWidget {
  final TierStatus tier;
  final AppConfig config;
  const _MilestonesSection({required this.tier, required this.config});

  static const _arOrdinals = ['الأول', 'الثاني', 'الثالث', 'الرابع', 'الخامس',
    'السادس', 'السابع', 'الثامن', 'التاسع', 'العاشر'];

  String _orderLabelAr(int n) {
    if (n <= 10) return _arOrdinals[n - 1];
    return 'الـ$n';
  }

  String _orderLabelEn(int n) {
    if (n == 1) return '1st';
    if (n == 2) return '2nd';
    if (n == 3) return '3rd';
    return '${n}th';
  }

  @override
  Widget build(BuildContext context) {
    final isAr  = context.isAr;
    final done  = tier.totalDelivered;
    final nextN = tier.nextMilestoneOrder;
    final orders  = config.milestoneOrders;
    final amounts = config.milestoneRewards;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Header
        Row(children: [
          const Icon(Icons.auto_awesome, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            isAr ? 'مكافآت الرحلة' : 'Journey Rewards',
            style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 16,
              fontWeight: FontWeight.w800, color: context.col.ink0),
          ),
        ]),

        const SizedBox(height: 18),

        // Horizontal progress steps
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Directionality(
            textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < orders.length; i++) ...[
                  if (i > 0)
                    _StepConnector(completed: done >= orders[i - 1]),
                  _StepNode(
                    labelAr: 'الطلب\n${_orderLabelAr(orders[i])}',
                    labelEn: 'Order\n${_orderLabelEn(orders[i])}',
                    amount: amounts[i],
                    completed: done >= orders[i],
                    isCurrent: orders[i] == nextN,
                    isAr: isAr,
                  ),
                ],
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

class _StepConnector extends StatelessWidget {
  final bool completed;
  const _StepConnector({required this.completed});

  @override
  Widget build(BuildContext context) => Container(
    width: 36, height: 2,
    margin: const EdgeInsets.only(top: 19),
    decoration: BoxDecoration(
      color: completed ? AppColors.primary : context.col.border,
      borderRadius: BorderRadius.circular(1),
    ),
  );
}

class _StepNode extends StatelessWidget {
  final String labelAr, labelEn;
  final double amount;
  final bool completed, isCurrent, isAr;
  const _StepNode({required this.labelAr, required this.labelEn,
    required this.amount, required this.completed,
    required this.isCurrent, required this.isAr});

  @override
  Widget build(BuildContext context) {
    final Color circleBg = completed
        ? AppColors.primary
        : isCurrent
            ? AppColors.primary.withValues(alpha: 0.08)
            : context.col.surfaceSoft;
    final Color circleBorder = completed || isCurrent
        ? AppColors.primary
        : context.col.border;
    final Color textColor = completed || isCurrent
        ? context.col.ink0
        : context.col.ink3;
    final Color amountColor = completed || isCurrent
        ? AppColors.primary
        : context.col.ink4;

    return SizedBox(
      width: 68,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: circleBg,
              border: Border.all(
                color: circleBorder,
                width: isCurrent ? 2.0 : 1.0),
            ),
            child: Center(
              child: completed
                  ? const Icon(Icons.check_rounded, size: 20, color: Colors.white)
                  : Icon(Icons.card_giftcard_outlined, size: 20,
                      color: isCurrent
                          ? AppColors.primary
                          : context.col.ink4),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isAr ? labelAr : labelEn,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 10,
              fontWeight: FontWeight.w600, height: 1.3,
              color: textColor),
          ),
          const SizedBox(height: 4),
          Text(
            '+${amount.toStringAsFixed(0)} ${isAr ? 'د.ل' : 'LYD'}',
            style: TextStyle(fontFamily: 'PlusJakartaSans',
              fontSize: 11, fontWeight: FontWeight.w800,
              color: amountColor),
          ),
        ],
      ),
    );
  }
}

// ── 6. FAQ ────────────────────────────────────────────────────────────────────
class _FaqSection extends StatelessWidget {
  static List<({String q, String a})> _getFaqs(bool isAr) => [
    (q: isAr ? 'متى أستلم الكاش باك؟' : 'When do I receive my cashback?',
     a: isAr ? 'يُضاف الكاش باك إلى محفظتك تلقائياً بمجرد توصيل طلبك وتأكيد الاستلام.'
              : 'Cashback is added to your wallet automatically once your order is delivered and confirmed.'),
    (q: isAr ? 'هل يمكنني استخدام رصيد المكافآت مع العروض؟' : 'Can I use rewards balance with promotions?',
     a: isAr ? 'نعم، مع استثناء واحد: طلبك الأول يحصل على خصم 15% تلقائياً، ولا يُستخدم رصيد المحفظة معه — يبقى رصيدك كما هو لطلبك القادم.'
              : 'Yes, with one exception: your first order gets an automatic 15% discount and your wallet balance is not used with it — it stays untouched for your next order.'),
    (q: isAr ? 'هل يوجد حد أقصى لاستخدام المكافآت؟' : 'Is there a maximum on rewards usage?',
     a: isAr ? 'لا يوجد حد أقصى على المبلغ — تجمع الرصيد وتستخدمه متى شئت. الاستثناء الوحيد هو طلبك الأول، حيث يُطبَّق خصم 15% بدلاً من الرصيد.'
              : 'No maximum on the amount — accumulate it and use it whenever you like. The only exception is your first order, where the 15% discount applies instead of the balance.'),
    (q: isAr ? 'كيف أرتقي في مستوى الولاء؟' : 'How do I level up my loyalty tier?',
     a: isAr ? 'يجب تحقيق شرطي الطلبات والإنفاق معاً خلال آخر 12 شهراً. تتم المراجعة تلقائياً عند كل توصيل.'
              : 'You must meet both orders and spend conditions within the last 12 months. Your tier is reviewed automatically at each delivery.'),
  ];

  @override
  Widget build(BuildContext context) {
    final faqs = _getFaqs(context.isAr);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.help_outline_rounded, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(context.s.faqTitle,
            style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 16,
              fontWeight: FontWeight.w800, color: context.col.ink0)),
        ]),

        const SizedBox(height: 12),

        Container(
          decoration: BoxDecoration(
            color: context.col.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: context.col.border),
            boxShadow: AppShadows.shadowLifted,
          ),
          child: Column(
            children: List.generate(faqs.length, (i) {
              final faq    = faqs[i];
              final isLast = i == faqs.length - 1;
              return Column(children: [
                Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 2),
                    childrenPadding:
                        const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    title: Text(faq.q,
                      style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: context.col.ink0)),
                    trailing: Icon(Icons.keyboard_arrow_down_rounded,
                      color: context.col.ink3, size: 22),
                    children: [
                      Text(faq.a,
                        style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 13,
                          color: context.col.ink2, height: 1.65)),
                    ],
                  ),
                ),
                if (!isLast)
                  Divider(height: 1, indent: 16, endIndent: 16,
                    color: context.col.border),
              ]);
            }),
          ),
        ),

        const SizedBox(height: 14),

        // Support card
        GestureDetector(
          onTap: () => safePush(context, '/contact'),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.18)),
            ),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.headset_mic_rounded,
                  size: 22, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('تحتاج مساعدة؟',
                    style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 14,
                      fontWeight: FontWeight.w800, color: context.col.ink0)),
                  Text('تواصل معنا وسنساعدك بكل سرور',
                    style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 12,
                      color: context.col.ink3)),
                ],
              )),
              Icon(Icons.arrow_back_ios_new_rounded,
                size: 14, color: context.col.ink3),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ── Pending rewards banner ─────────────────────────────────────────────────────
class _PendingRewardsBanner extends StatelessWidget {
  final TierStatus tier;
  const _PendingRewardsBanner({required this.tier});

  @override
  Widget build(BuildContext context) {
    final lines = <String>[];
    for (final m in tier.pendingMilestones) {
      final n = m['order_number'];
      final a = (m['amount'] as num).toStringAsFixed(0);
      lines.add('مكافأة الطلب رقم $n: $a د.ل');
    }
    if (tier.pendingReferralCount > 0) {
      lines.add('${tier.pendingReferralCount} دعوة بانتظار التسليم');
    }
    if (tier.pendingReceiverReward) {
      lines.add('مكافأة ترحيب بانتظار تسليم طلبك');
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD54F)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 40, height: 40,
          decoration: const BoxDecoration(
            color: Color(0xFFFFEE58),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.hourglass_top_rounded,
              size: 20, color: Color(0xFFF57F17)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(
                '${tier.pendingTotal.toStringAsFixed(0)} د.ل بانتظار التسليم',
                style: const TextStyle(
                  fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 14,
                  fontWeight: FontWeight.w800, color: Color(0xFFF57F17)),
              ),
            ]),
            const SizedBox(height: 4),
            ...lines.map((l) => Text('• $l',
              style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 12,
                color: context.col.ink2))),
            const SizedBox(height: 4),
            Text('ستُضاف تلقائياً لمحفظتك عند استلام طلبك',
              style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 11,
                color: context.col.ink3)),
          ],
        )),
      ]),
    );
  }
}
