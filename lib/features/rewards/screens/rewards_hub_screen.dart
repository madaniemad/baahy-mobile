import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/app_config.dart';
import '../../../core/models/tier_status.dart';
import '../../../core/providers/app_config_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/tier_provider.dart';
import '../../../core/utils/l10n.dart';
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
  final Color gradA;
  final Color gradB;
  final Color accent;
  const _TierPalette({required this.nameAr, required this.gradA,
    required this.gradB, required this.accent});
}

const _kTiers       = ['bronze', 'silver', 'gold', 'platinum'];
const _kTierNamesAr = ['برونزي', 'فضي', 'ذهبي', 'بلاتيني'];
const _kTierNamesEn = ['Bronze', 'Silver', 'Gold', 'Platinum'];

// Shows "1.5" for fractional rates, "2" for whole numbers
String _fmtRate(double r) {
  final i = r.toInt();
  return r == i.toDouble() ? '$i' : r.toStringAsFixed(1);
}

const _palettes = <String, _TierPalette>{
  'bronze':   _TierPalette(nameAr: 'برونزي',  gradA: Color(0xFFD4913A), gradB: Color(0xFF3B1A07), accent: Color(0xFFE8B464)),
  'silver':   _TierPalette(nameAr: 'فضي',     gradA: Color(0xFF9E9E9E), gradB: Color(0xFF616161), accent: Color(0xFFBDBDBD)),
  'gold':     _TierPalette(nameAr: 'ذهبي',    gradA: Color(0xFFD4A82E), gradB: Color(0xFFA07010), accent: Color(0xFFFFD54F)),
  'platinum': _TierPalette(nameAr: 'بلاتيني', gradA: Color(0xFF26C5F3), gradB: Color(0xFF0A8EC0), accent: Color(0xFFB3E5FC)),
};
const _bronzePalette = _TierPalette(nameAr: 'برونزي', gradA: Color(0xFFD4913A), gradB: Color(0xFF3B1A07), accent: Color(0xFFE8B464));
_TierPalette _pal(String? t) => _palettes[t?.toLowerCase()] ?? _bronzePalette;

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
              style: TextStyle(fontFamily: 'Cairo',
                fontWeight: FontWeight.w800, color: context.col.ink0),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.info_outline_rounded, color: context.col.ink2),
                onPressed: () => context.push('/faq'),
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
    final nameAr = _palettes[tier.tier?.toLowerCase()]?.nameAr ?? 'برونزي';
    final nameEn = tier.tier != null
        ? '${tier.tier![0].toUpperCase()}${tier.tier!.substring(1)}'
        : 'Bronze';
    final cashback = _fmtRate(tier.cashbackRate);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color.lerp(palette.gradA, Colors.white, 0.28)!,
            palette.gradA,
            palette.gradB,
          ],
          stops: const [0.0, 0.38, 1.0],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: palette.gradB.withValues(alpha: 0.45),
            blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: Stack(children: [
        // Subtle metallic sheen at top edge
        Positioned(
          top: 0, left: 0, right: 0, height: 60,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.14),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Padding(
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
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.65)),
                    ),
                    const SizedBox(height: 8),
                    // Tier name + مميز chip inline
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          isAr ? nameAr : nameEn,
                          style: const TextStyle(fontFamily: 'Cairo',
                            fontSize: 36, fontWeight: FontWeight.w900,
                            color: Colors.white, height: 1),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            isAr ? 'مميز' : 'Member',
                            style: const TextStyle(fontFamily: 'Cairo', fontSize: 12,
                              fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    if (tier.nextTier != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        isAr ? 'استمر وارتقِ للمستوى التالي'
                             : 'Keep going to reach the next tier',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.70)),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Medal icon (left in RTL = last child)
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.15),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.30), width: 1.5),
                ),
                child: const Icon(Icons.military_tech_rounded,
                  size: 46, color: Colors.white),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Divider
          Container(height: 1,
            color: Colors.white.withValues(alpha: 0.20)),

          const SizedBox(height: 18),

          // Stats row
          IntrinsicHeight(
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _HeroStat(
                  value: '$cashback%',
                  label: isAr ? 'كاش باك' : 'Cashback',
                ),
                Container(width: 1,
                  color: Colors.white.withValues(alpha: 0.25)),
                _HeroStat(
                  value: walletBalance.round().toString(),
                  label: isAr ? 'رصيد المكافآت' : 'Rewards',
                  suffix: isAr ? ' د.ل' : ' LYD',
                  icon: Icons.lock_outline_rounded,
                ),
                Container(width: 1,
                  color: Colors.white.withValues(alpha: 0.25)),
                _HeroStat(
                  value: '${tier.returnDays}',
                  label: isAr ? 'أيام إرجاع' : 'Returns',
                  suffix: isAr ? '' : ' days',
                ),
              ],
            ),
          ),
        ]),
        ),
      ]),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String value;
  final String label;
  final String? suffix;
  final IconData? icon;
  const _HeroStat({required this.value, required this.label,
    this.suffix, this.icon});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: Colors.white.withValues(alpha: 0.75)),
          const SizedBox(width: 3),
        ],
        Text(value,
          style: const TextStyle(fontFamily: 'PlusJakartaSans',
            fontSize: 20, fontWeight: FontWeight.w800,
            color: Colors.white, height: 1)),
        if (suffix != null && suffix!.isNotEmpty)
          Text(suffix!,
            style: TextStyle(fontFamily: 'Cairo', fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.80))),
      ]),
      const SizedBox(height: 5),
      Text(label,
        textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'Cairo', fontSize: 11,
          color: Colors.white.withValues(alpha: 0.70))),
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
      case 'silver':   return 'الفضي';
      case 'gold':     return 'الذهبي';
      case 'platinum': return 'البلاتيني';
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
                style: TextStyle(fontFamily: 'Cairo', fontSize: 15,
                  fontWeight: FontWeight.w800, color: context.col.ink0),
              ),
              const SizedBox(height: 2),
              Text(
                isAr ? 'استمر للتقدّم للمستوى التالي' : 'Keep going to reach the next tier',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 12,
                  color: context.col.ink3),
              ),
            ]),
          ),
          const SizedBox(width: 12),
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: nextPal.gradA.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: nextPal.gradA.withValues(alpha: 0.25)),
            ),
            child: Icon(Icons.military_tech_rounded, color: nextPal.gradA, size: 24),
          ),
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
          color: nextPal.gradA,
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
          color: nextPal.gradA,
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
          style: TextStyle(fontFamily: 'Cairo', fontSize: 13,
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
            style: TextStyle(fontFamily: 'Cairo', fontSize: 16,
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
            style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5,
              color: context.col.ink3),
          ),
        ]),
      ),
    ]);
  }
}

class _TierCard extends StatelessWidget {
  final String nameAr, nameEn;
  final String cashback, shipping, returns;
  final _TierPalette palette;
  final bool isActive, isAr;
  const _TierCard({required this.nameAr, required this.nameEn,
    required this.cashback, required this.shipping, required this.returns,
    required this.palette, required this.isActive, required this.isAr});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.col.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isActive ? palette.gradA : context.col.border,
          width: isActive ? 2 : 1,
        ),
        boxShadow: isActive ? AppShadows.shadowLifted : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isActive ? 8 : 9),
        child: Column(children: [
          // Colored header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            color: isActive
                ? palette.gradA
                : palette.gradA.withValues(alpha: 0.10),
            child: Text(
              isAr ? nameAr : nameEn,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo', fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isActive ? Colors.white : palette.gradA,
              ),
            ),
          ),
          // Benefit rows
          _cardBenefit(cashback, isAr ? 'كاش باك' : 'Cash',
            palette.gradA, context),
          Divider(height: 1, color: context.col.border),
          _cardBenefit(isAr ? '$shipping د.ل' : 'LYD $shipping',
            isAr ? 'شحن مجاني' : 'Ship.',
            palette.gradA, context),
          Divider(height: 1, color: context.col.border),
          _cardBenefit('$returns ${isAr ? 'أيام' : 'd'}',
            isAr ? 'إرجاع' : 'Return',
            palette.gradA, context),
        ]),
      ),
    );
  }

  Widget _cardBenefit(String value, String label, Color color, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
      child: Column(children: [
        Text(value,
          textAlign: TextAlign.center,
          maxLines: 1,
          style: TextStyle(fontFamily: 'PlusJakartaSans',
            fontSize: 13, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label,
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Cairo', fontSize: 10,
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
    final inviteLink = 'https://baahy-web.vercel.app/invite/$_code'
        '?from=$firstName&reward=${widget.receiverAmount}';
    final text = context.isAr
        ? '$firstName دعاك للانضمام لباهي!\n'
          'ستُضاف ${widget.receiverAmount} د.ل لمحفظتك فور التسجيل 🎁\n'
          '$inviteLink'
        : 'Join Baahy with my invite!\n'
          'Get ${widget.receiverAmount} LYD added to your wallet on signup 🎁\n'
          '$inviteLink';
    try {
      await Share.share(text);
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم نسخ رابط الدعوة',
            style: TextStyle(fontFamily: 'Cairo'))));
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
                style: TextStyle(fontFamily: 'Cairo', fontSize: 16,
                  fontWeight: FontWeight.w800, color: context.col.ink0),
              ),
              const SizedBox(height: 6),
              Text(
                isAr
                    ? 'احصل على ${widget.giverAmount} د.ل لكل صديق\nبمجرد إتمام أول طلب له'
                    : 'Get ${widget.giverAmount} LYD per friend\nafter their first order',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 12,
                  color: context.col.ink2, height: 1.65),
              ),
            ]),
          ),
          const SizedBox(width: 12),
          // Gift icon box
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F9FB),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Icon(Icons.card_giftcard_rounded,
                size: 32, color: AppColors.primary),
            ),
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
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 14,
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
      style: TextStyle(fontFamily: 'Cairo', fontSize: 11,
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
            style: TextStyle(fontFamily: 'Cairo', fontSize: 16,
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
            style: TextStyle(fontFamily: 'Cairo', fontSize: 10,
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
  static const _faqs = [
    (q: 'متى أستلم الكاش باك؟',
     a: 'يُضاف الكاش باك إلى محفظتك تلقائياً بمجرد توصيل طلبك وتأكيد الاستلام.'),
    (q: 'هل يمكنني استخدام رصيد المكافآت مع العروض؟',
     a: 'نعم، يمكنك استخدام رصيد محفظتك مع أي طلب بصرف النظر عن العروض المطبّقة.'),
    (q: 'هل يوجد حد أقصى لاستخدام المكافآت؟',
     a: 'لا يوجد حد أقصى. يمكنك تجميع الرصيد واستخدامه متى شئت على أي طلب.'),
    (q: 'كيف أرتقي في مستوى الولاء؟',
     a: 'يجب تحقيق شرطي الطلبات والإنفاق معاً خلال آخر 12 شهراً. تتم المراجعة تلقائياً عند كل توصيل.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.help_outline_rounded, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text('الأسئلة الشائعة',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 16,
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
            children: List.generate(_faqs.length, (i) {
              final faq    = _faqs[i];
              final isLast = i == _faqs.length - 1;
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
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: context.col.ink0)),
                    trailing: Icon(Icons.keyboard_arrow_down_rounded,
                      color: context.col.ink3, size: 22),
                    children: [
                      Text(faq.a,
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 13,
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
          onTap: () => context.push('/contact'),
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
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.headset_mic_rounded,
                  size: 22, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('تحتاج مساعدة؟',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 14,
                      fontWeight: FontWeight.w800, color: context.col.ink0)),
                  Text('تواصل معنا وسنساعدك بكل سرور',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 12,
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
