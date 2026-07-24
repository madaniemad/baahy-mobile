import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers/app_config_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/tier_provider.dart';
import '../../../core/models/tier_status.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/l10n.dart';
import '../../../core/utils/navigation.dart';
import '../../../shared/theme/app_theme.dart';
import '../../checkout/screens/payment_webview_screen.dart';

final _walletProvider = FutureProvider<List<dynamic>>((ref) async {
  final res = await ApiClient.instance.dio.get('/wallet/transactions');
  return (res.data['data'] as List?) ?? [];
});

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onResume: () => ref.invalidate(_walletProvider),
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final walletAsync = ref.watch(_walletProvider);
    final tierAsync = ref.watch(tierProvider);
    final balance = user?.walletBalance ?? 0.0;

    return Scaffold(
      backgroundColor: context.col.bg,
      appBar: AppBar(
        backgroundColor: context.col.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => context.canPop() ? context.pop() : context.go('/account'),
        ),
        title: Text(context.s.myWallet,
          style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontWeight: FontWeight.w800, fontSize: 17)),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF1FD7E2),
        onRefresh: () async {
          ref.invalidate(_walletProvider);
          ref.invalidate(tierProvider);
          await ref.read(authProvider.notifier).refreshProfile();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: _HeroBalanceCard(
                balance: balance,
                user: user,
                onTopUp: () => _showTopUpSheet(context, ref),
                onSend: () => _showTransferSheet(context, ref),
                onQr: () => _showQrSheet(context, user),
              ),
            ),
            const SizedBox(height: 16),

            walletAsync.when(
              loading: () => const SizedBox(height: 80),
              error: (_, __) => const SizedBox.shrink(),
              data: (txns) => _StatsRow(txns: txns, balance: balance),
            ),
            const SizedBox(height: 16),

            tierAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (tier) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _TierProgressCard(tier: tier),
              ),
            ),
            const SizedBox(height: 16),

            _EarnMoreSection(
              onShop: () => context.go('/home'),
              onInvite: () => safePush(context, '/referral'),
              onDeals: () => safePush(context, '/browse'),
            ),
            const SizedBox(height: 16),

            walletAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: Color(0xFF1FD7E2)))),
              error: (_, __) => const SizedBox.shrink(),
              data: (txns) => _TransactionsSection(txns: txns),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 36),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.shield_outlined, size: 13, color: context.col.ink3),
                const SizedBox(width: 6),
                Text(context.tr('رصيدك آمن 100٪ ويمكنك استخدامه في أي وقت', 'Your balance is 100% secure — use it anytime'),
                  style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 11.5, color: context.col.ink2)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  void _showTopUpSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TopUpSheet(onSuccess: () {
        ref.invalidate(_walletProvider);
        ref.read(authProvider.notifier).refreshProfile();
      }),
    );
  }

  void _showTransferSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TransferSheet(onSuccess: () {
        ref.invalidate(_walletProvider);
        ref.read(authProvider.notifier).refreshProfile();
      }),
    );
  }

  void _showQrSheet(BuildContext context, dynamic user) {
    if (user == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _WalletQrSheet(phone: user.phone, name: user.name),
    );
  }
}

// ── Hero balance card ─────────────────────────────────────────────────────────

class _HeroBalanceCard extends StatelessWidget {
  final double balance;
  final dynamic user;
  final VoidCallback onTopUp;
  final VoidCallback onSend;
  final VoidCallback onQr;
  const _HeroBalanceCard({required this.balance, required this.user, required this.onTopUp, required this.onSend, required this.onQr});

  static const _tiffany = Color(0xFF1FD7E2);
  static const _tiffanyDeep = Color(0xFF12AEBA);
  static const _tiffanyMid = Color(0xFF28CAD2);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [_tiffany, _tiffanyMid, _tiffanyDeep],
          stops: [0.0, 0.55, 1.0],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        boxShadow: [
          BoxShadow(
            color: _tiffany.withValues(alpha: 0.38),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(children: [
          // Pattern
          Positioned.fill(
            child: Opacity(
              opacity: 0.09,
              child: Image.asset('assets/images/onb-pattern.png', fit: BoxFit.cover),
            ),
          ),
          // Subtle diagonal shine stripe
          Positioned(
            top: -30, right: -20,
            child: Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
          ),
          // Wallet icon — top left
          Positioned(
            top: 12, left: 12,
            child: ColorFiltered(
              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              child: Image.asset('assets/images/wallet_icon.png',
                width: 28, height: 28, fit: BoxFit.contain),
            ),
          ),
          // QR code button
          Positioned(
            top: 12, right: 12,
            child: GestureDetector(
              onTap: onQr,
              child: Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(Icons.qr_code_2_rounded, size: 16, color: Colors.white),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
              const SizedBox(height: 18),
              Text(context.tr('رصيدك المتاح', 'Your Balance'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 13, fontWeight: FontWeight.w500,
                  color: Colors.white)),
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic, children: [
                Text(fmtPrice(balance),
                  style: const TextStyle(fontFamily: 'PlusJakartaSans',
                    fontSize: 40, fontWeight: FontWeight.w800, color: Colors.white,
                    letterSpacing: -1, height: 1)),
                const SizedBox(width: 7),
                const Text('د.ل',
                  style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 16, fontWeight: FontWeight.w600,
                    color: Colors.white)),
              ]),
              const SizedBox(height: 5),
              Text(context.tr('✦  أنت تكسب مع كل طلب', '✦  You earn on every order'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 12, color: Colors.white,
                  fontWeight: FontWeight.w500)),
              const SizedBox(height: 14),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _CardButton(
                  label: context.s.topUpWallet, icon: Icons.add_rounded,
                  outlined: true, onTap: onTopUp),
                const SizedBox(width: 10),
                _CardButton(
                  label: context.s.sendMoney, icon: Icons.upload_outlined,
                  outlined: false, onTap: onSend),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _CardButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool outlined;
  final VoidCallback onTap;
  const _CardButton({required this.label, required this.icon,
    required this.outlined, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const tiffanyDeep = Color(0xFF18B8C0);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : Colors.white,
          borderRadius: BorderRadius.circular(9),
          border: outlined
              ? Border.all(color: Colors.white.withValues(alpha: 0.80), width: 1.5)
              : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: outlined ? Colors.white : tiffanyDeep),
          const SizedBox(width: 5),
          Text(label,
            style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 13,
              fontWeight: FontWeight.w800,
              color: outlined ? Colors.white : tiffanyDeep)),
        ]),
      ),
    );
  }
}

// ── 4-stat row ────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final List<dynamic> txns;
  final double balance;
  const _StatsRow({required this.txns, required this.balance});

  @override
  Widget build(BuildContext context) {
    double cashbackEarned = 0;
    double pendingRefunds = 0;
    double referralRewards = 0;
    for (final tx in txns) {
      final type = (tx['type'] as String? ?? '').toLowerCase();
      final rawAmt = tx['amount'];
      final amt = (rawAmt is num
          ? rawAmt.toDouble()
          : double.tryParse(rawAmt?.toString() ?? '') ?? 0.0).abs();
      if (type == 'cashback') cashbackEarned += amt;
      if (type == 'refund') pendingRefunds += amt;
      if (type == 'referral') referralRewards += amt;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: context.col.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.col.border),
        ),
        child: Row(children: [
          _StatItem(
            label: context.tr('كاش باك مكتسب', 'Cashback Earned'),
            amount: cashbackEarned,
            iconBg: const Color(0xFFE0F9F9),
            iconColor: const Color(0xFF08AAAC),
            icon: Icons.attach_money_rounded,
          ),
          _StatDivider(),
          _StatItem(
            label: context.tr('استرداد معلق', 'Pending Refunds'),
            amount: pendingRefunds,
            iconBg: const Color(0xFFFFF3E0),
            iconColor: const Color(0xFFE65100),
            icon: Icons.schedule_rounded,
          ),
          _StatDivider(),
          _StatItem(
            label: context.tr('مكافآت الدعوات', 'Referral Rewards'),
            amount: referralRewards,
            iconBg: const Color(0xFFEFF6FF),
            iconColor: AppColors.info,
            icon: Icons.card_giftcard_outlined,
          ),
          _StatDivider(),
          _StatItem(
            label: context.s.availableBalance,
            amount: balance,
            iconBg: AppColors.teal50,
            iconColor: AppColors.primary,
            iconAsset: 'assets/images/wallet_icon.png',
          ),
        ]),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final double amount;
  final Color iconBg;
  final Color iconColor;
  final IconData? icon;
  final String? iconAsset;
  const _StatItem({required this.label, required this.amount,
    required this.iconBg, required this.iconColor, this.icon, this.iconAsset});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? Colors.transparent : iconBg,
            border: isDark ? Border.all(color: Colors.white.withValues(alpha: 0.55)) : null,
          ),
          child: iconAsset != null
            ? Center(child: ColorFiltered(
                colorFilter: ColorFilter.mode(
                  isDark ? Colors.white : iconColor, BlendMode.srcIn),
                child: Image.asset(iconAsset!, width: 20, height: 20, fit: BoxFit.contain),
              ))
            : Icon(icon!, size: 17, color: isDark ? Colors.white : iconColor),
        ),
        const SizedBox(height: 7),
        Text(label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
            fontSize: 9.5, color: context.col.ink2, height: 1.3)),
        const SizedBox(height: 3),
        Text('${fmtPrice(amount)} د.ل',
          style: TextStyle(fontFamily: 'PlusJakartaSans',
            fontSize: 12.5, fontWeight: FontWeight.w800, color: context.col.ink0)),
      ]),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 50, color: context.col.border);
  }
}

// ── Tier progress card ────────────────────────────────────────────────────────

class _TierProgressCard extends StatelessWidget {
  final TierStatus tier;
  const _TierProgressCard({required this.tier});

  static const _tiers = ['bronze', 'silver', 'gold', 'platinum'];
  static const _tierLabels = ['Silver', 'Gold', 'Platinum', 'Black'];
  static const _tierColors = [
    Color(0xFF8AA0B4), Color(0xFFE0B44A), Color(0xFF5AA8CC), Color(0xFFA99FD6),
  ];

  @override
  Widget build(BuildContext context) {
    final currentTier = tier.tier ?? 'bronze';
    final currentIndex = _tiers.indexOf(currentTier).clamp(0, 3);
    final nextTier = tier.nextTier;
    final nextIndex = nextTier != null ? _tiers.indexOf(nextTier).clamp(0, 3) : null;

    final totalSpendNeeded = tier.spendAmount + tier.spendRemaining;
    final spendProgress = totalSpendNeeded > 0
        ? (tier.spendAmount / totalSpendNeeded).clamp(0.0, 1.0) : 0.0;

    final totalOrdersNeeded = tier.ordersCount + tier.ordersRemaining;
    final ordersProgress = totalOrdersNeeded > 0
        ? (tier.ordersCount / totalOrdersNeeded).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.col.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.col.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Top row: medal | tier info | tier dots
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Image.asset(
            'assets/images/tier_$currentTier.png',
            width: 54, height: 54, fit: BoxFit.contain,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.tr('المستوى الحالي', 'Current Tier'),
                style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 11, color: context.col.ink2)),
              const SizedBox(height: 2),
              Text('⁦${_tierLabels[currentIndex]}⁩',
                style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 20, fontWeight: FontWeight.w800,
                  color: _tierColors[currentIndex], height: 1.1)),
              if (nextIndex != null)
                Text(context.isAr ? 'استمر للتقدم للمستوى ⁦${_tierLabels[nextIndex]}⁩' : 'Keep going to reach ⁦${_tierLabels[nextIndex]}⁩',
                  style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 11, color: context.col.ink2)),
            ]),
          ),
        ]),

        if (nextIndex != null) ...[
          const SizedBox(height: 14),

          // Orders progress
          _DualProgressRow(
            icon: Icons.receipt_long_outlined,
            label: context.s.hubOrders,
            current: tier.ordersCount,
            needed: tier.ordersNeeded,
            remaining: tier.ordersRemaining,
            unit: context.isAr ? 'طلب' : 'orders',
            progress: ordersProgress,
            color: AppColors.primary,
          ),
          const SizedBox(height: 10),

          // Spend progress
          _DualProgressRow(
            icon: Icons.payments_outlined,
            label: context.tr('المبلغ', 'Spend'),
            current: tier.spendAmount.toInt(),
            needed: tier.spendNeeded.toInt(),
            remaining: tier.spendRemaining.toInt(),
            unit: context.s.lydUnit,
            progress: spendProgress,
            color: const Color(0xFF0AABB3),
          ),
        ],

        const SizedBox(height: 12),

        GestureDetector(
          onTap: () => safePush(context, '/rewards-hub'),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.chevron_left_rounded, size: 16, color: AppColors.primary),
            Text(context.tr('عرض جميع المزايا', 'View all benefits'),
              style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 12, color: AppColors.primary,
                fontWeight: FontWeight.w600)),
          ]),
        ),
      ]),
    );
  }
}

// ── Dual progress row ─────────────────────────────────────────────────────────

class _DualProgressRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int current;
  final int needed;
  final int remaining;
  final String unit;
  final double progress;
  final Color color;
  const _DualProgressRow({required this.icon, required this.label,
    required this.current, required this.needed, required this.remaining,
    required this.unit, required this.progress, required this.color});

  @override
  Widget build(BuildContext context) {
    final done = remaining <= 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(label,
          style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 11.5,
            fontWeight: FontWeight.w600, color: context.col.ink1)),
        const Spacer(),
        if (done)
          Row(children: [
            const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success),
            const SizedBox(width: 3),
            Text(context.tr('مكتمل', 'Done'),
              style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 11,
                color: AppColors.success, fontWeight: FontWeight.w700)),
          ])
        else
          Text('$current / $needed $unit',
            style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11,
              color: context.col.ink2, fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 5),
      ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: progress,
          minHeight: 6,
          backgroundColor: context.col.surfaceSoft,
          valueColor: AlwaysStoppedAnimation<Color>(done ? AppColors.success : color),
        ),
      ),
    ]);
  }
}

// ── Earn more section ─────────────────────────────────────────────────────────

class _EarnMoreSection extends StatelessWidget {
  final VoidCallback onShop;
  final VoidCallback onInvite;
  final VoidCallback onDeals;
  const _EarnMoreSection({required this.onShop, required this.onInvite, required this.onDeals});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Text(context.tr('اكسب أكثر', 'Earn More'),
          style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 16, fontWeight: FontWeight.w800,
            color: context.col.ink0)),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: _EarnCard(
            onTap: onShop,
            icon: Icons.shopping_bag_outlined,
            iconColor: const Color(0xFF08AAAC),
            cardBg: const Color(0xFFE2F9FA),
            title: context.tr('تسوق لتحصل على كاش باك', 'Shop for cashback'),
            subtitle: context.tr('اكسب كاش باك على كل طلب تقوم به', 'Earn cashback on every order'),
            actionLabel: context.tr('تسوق الآن', 'Shop Now'),
          )),
          const SizedBox(width: 8),
          Expanded(child: _EarnCard(
            onTap: onInvite,
            iconAsset: 'assets/images/referral_gift.png',
            iconColor: AppColors.info,
            cardBg: const Color(0xFFEFF6FF),
            title: context.tr('دعوة الأصدقاء', 'Invite Friends'),
            subtitle: context.tr('ادع أصدقائك واكسب مكافآت عند كل دعوة', 'Invite friends and earn rewards'),
            actionLabel: context.tr('دعوة الآن', 'Invite Now'),
          )),
          const SizedBox(width: 8),
          Expanded(child: _EarnCard(
            onTap: onDeals,
            icon: Icons.local_offer_outlined,
            iconColor: AppColors.gold,
            cardBg: const Color(0xFFFFF8E1),
            title: context.tr('عروض حصرية', 'Exclusive Deals'),
            subtitle: context.tr('اكتشف عروض ومكافآت خاصة للأعضاء', 'Discover member-only deals & rewards'),
            actionLabel: context.tr('اكتشف', 'Explore'),
          )),
        ])),
      ),
    ]);
  }
}

class _EarnCard extends StatelessWidget {
  final VoidCallback onTap;
  final IconData? icon;
  final String? iconAsset;
  final Color iconColor;
  final Color cardBg;
  final String title;
  final String subtitle;
  final String actionLabel;
  const _EarnCard({required this.onTap, this.icon, this.iconAsset, required this.iconColor,
    required this.cardBg, required this.title, required this.subtitle,
    required this.actionLabel});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? context.col.surface : cardBg;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: isDark ? Border.all(color: context.col.border) : null,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor.withValues(alpha: isDark ? 0.15 : 0.18),
            ),
            child: iconAsset != null
              ? Image.asset(iconAsset!, width: 20, height: 20, fit: BoxFit.contain)
              : Icon(icon!, size: 17, color: iconColor),
          ),
          const SizedBox(height: 8),
          Text(title,
            style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 11.5, fontWeight: FontWeight.w800,
              color: context.col.ink0, height: 1.3)),
          const SizedBox(height: 3),
          Text(subtitle,
            style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 9.5, color: context.col.ink2,
              height: 1.35)),
          const SizedBox(height: 8),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.chevron_left_rounded, size: 13, color: iconColor),
            Text(actionLabel,
              style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 10.5,
                fontWeight: FontWeight.w700, color: iconColor)),
          ]),
        ]),
      ),
    );
  }
}

// ── Transactions section ──────────────────────────────────────────────────────

class _TransactionsSection extends StatelessWidget {
  final List<dynamic> txns;
  const _TransactionsSection({required this.txns});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(context.tr('آخر المعاملات', 'Recent Transactions'),
            style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 16, fontWeight: FontWeight.w800,
              color: context.col.ink0)),
          const Spacer(),
          if (txns.isNotEmpty)
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.chevron_left_rounded, size: 15, color: AppColors.primary),
              Text(context.s.seeAll,
                style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 12, color: AppColors.primary,
                  fontWeight: FontWeight.w600)),
            ]),
        ]),
        const SizedBox(height: 12),
        if (txns.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Column(children: [
                Icon(Icons.receipt_long_outlined, size: 60, color: context.col.ink4),
                const SizedBox(height: 12),
                Text(context.s.noTransactions,
                  style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 15, color: context.col.ink2)),
              ]),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: context.col.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.col.border),
            ),
            child: Column(
              children: List.generate(txns.length > 5 ? 5 : txns.length, (i) {
                final limit = txns.length > 5 ? 5 : txns.length;
                return _TransactionRow(
                  tx: Map<String, dynamic>.from(txns[i]),
                  hasBorder: i < limit - 1,
                );
              }),
            ),
          ),
      ]),
    );
  }
}

// ── Top-up sheet ──────────────────────────────────────────────────────────────

class _TopUpSheet extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;
  const _TopUpSheet({required this.onSuccess});

  @override
  ConsumerState<_TopUpSheet> createState() => _TopUpSheetState();
}

class _TopUpSheetState extends ConsumerState<_TopUpSheet> {
  // Step 0: amount + method selection
  // Step 1: Mobicash card number
  // Step 2: Mobicash OTP
  int _step = 0;
  int? _selected = 100;
  String _paymentId = 'mobicash';
  bool _loading = false;
  String? _error;
  final _customCtrl = TextEditingController();
  final _cardCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  String? _mobicashReference;
  String? _mitfTransactionId;

  static const _quickAmounts = [100, 200, 500, 1000];

  // Wallet top-up methods are DRIVEN BY THE BACKEND (site_settings.payment_methods, minus
  // cash-on-delivery and wallet) so admin renames/toggles and new gateways appear here without
  // an app rebuild. Descriptions fall back to a per-gateway default when the admin left one blank.
  static const _descById = {
    'mobicash': 'ادفع بكارت موبيكاش',
    'tadawel':  'دفع إلكتروني عبر تداول',
    'moamlat':  'دفع إلكتروني بالبطاقة المصرفية',
    'paypal':   'ادفع بحساب PayPal',
    'sadad':    'دفع إلكتروني عبر سداد',
  };

  List<({String id, String label, String desc})> get _methods {
    final pm = ref.read(appConfigProvider).paymentMethods
        .where((m) => m.enabled && m.id != 'cash_on_delivery' && m.id != 'wallet')
        .toList();
    if (pm.isEmpty) {
      return const [(id: 'mobicash', label: 'موبيكاش', desc: 'ادفع بكارت موبيكاش')];
    }
    return pm.map((m) => (
      id: m.id,
      label: m.labelAr,
      desc: m.descriptionAr.isNotEmpty ? m.descriptionAr : (_descById[m.id] ?? ''),
    )).toList();
  }

  @override
  void initState() {
    super.initState();
    // Default the selection to the first backend-provided method (mobicash may be disabled).
    final ms = _methods;
    if (ms.isNotEmpty && !ms.any((m) => m.id == _paymentId)) {
      _paymentId = ms.first.id;
    }
  }

  double get _amount {
    final custom = double.tryParse(_customCtrl.text.trim());
    if (custom != null && custom > 0) return custom;
    return _selected?.toDouble() ?? 0;
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    _cardCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _proceed(double minTopup) async {
    if (_step == 0) {
      if (_amount < minTopup) {
        setState(() => _error = 'أقل مبلغ للشحن هو ${fmtPrice(minTopup)} د.ل');
        return;
      }
      if (_paymentId == 'mobicash') {
        setState(() { _step = 1; _error = null; });
      } else if (_paymentId == 'paypal') {
        await _initiatePaypal();
      } else {
        await _initiateGateway();
      }
    } else if (_step == 1) {
      await _mobicashOpen();
    } else if (_step == 2) {
      await _mobicashComplete();
    }
  }

  Future<void> _initiateGateway() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiClient.instance.dio.post('/wallet/topup/initiate', data: {
        'amount': _amount,
        'gateway': _paymentId,
      });
      final url = res.data['payment_url'] as String?;
      if (url != null && url.isNotEmpty) {
        if (mounted) Navigator.of(context).pop();
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        setState(() { _loading = false; _error = 'لم يتم الحصول على رابط الدفع'; });
      }
    } catch (_) {
      setState(() { _loading = false; _error = 'حدث خطأ، حاول مجدداً'; });
    }
  }

  Future<void> _initiatePaypal() async {
    setState(() { _loading = true; _error = null; });
    try {
      // 1) create the wallet top-up to get a reference, 2) get the PayPal approval URL,
      // 3) open it in the in-app webview (returns the deep-link on return), 4) capture → credit.
      final init = await ApiClient.instance.dio.post('/wallet/topup/initiate', data: {
        'amount': _amount, 'gateway': 'paypal',
      });
      final ref0 = init.data['reference'] as String?;
      if (ref0 == null || ref0.isEmpty) {
        setState(() { _loading = false; _error = 'تعذّر بدء عملية الدفع'; });
        return;
      }
      final pp = await ApiClient.instance.dio.post('/payment/paypal/initiate', data: {
        'topup_ref': ref0, 'platform': 'mobile',
      });
      final approvalUrl = pp.data['approval_url'] as String?;
      if (approvalUrl == null || approvalUrl.isEmpty) {
        setState(() { _loading = false; _error = 'خدمة PayPal غير متاحة حالياً'; });
        return;
      }
      if (!mounted) return;
      final Uri? deepLink = await Navigator.of(context).push<Uri?>(
        MaterialPageRoute(builder: (_) => PaymentWebViewScreen(
          url: approvalUrl, title: 'الدفع عبر PayPal')),
      );
      if (!mounted) return;
      final token = deepLink?.queryParameters['token'] ?? '';
      if (token.isEmpty) {
        setState(() { _loading = false; _error = 'تم إلغاء الدفع'; });
        return;
      }
      await ApiClient.instance.dio.post('/payment/paypal/capture', data: {
        'topup_ref': ref0, 'paypal_order_id': token,
      });
      if (mounted) { Navigator.of(context).pop(); widget.onSuccess(); }
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'حدث خطأ، حاول مجدداً'; });
    }
  }

  Future<void> _mobicashOpen() async {
    if (_cardCtrl.text.trim().isEmpty) {
      setState(() => _error = 'يرجى إدخال رقم البطاقة');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiClient.instance.dio.post('/wallet/topup/mobicash/open', data: {
        'amount': _amount,
        'card_number': _cardCtrl.text.trim(),
      });
      _mobicashReference = res.data['reference'] as String?;
      _mitfTransactionId = res.data['mitf_transaction_id']?.toString();
      setState(() { _loading = false; _step = 2; });
    } catch (_) {
      setState(() { _loading = false; _error = 'البطاقة غير صحيحة أو الخدمة غير متاحة'; });
    }
  }

  Future<void> _mobicashComplete() async {
    if (_otpCtrl.text.trim().isEmpty) {
      setState(() => _error = 'يرجى إدخال رمز OTP');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ApiClient.instance.dio.post('/wallet/topup/mobicash/complete', data: {
        'reference': _mobicashReference,
        'card_number': _cardCtrl.text.trim(),
        'otp': _otpCtrl.text.trim(),
        'mitf_transaction_id': _mitfTransactionId ?? '',
      });
      if (mounted) {
        Navigator.of(context).pop();
        widget.onSuccess();
      }
    } catch (_) {
      setState(() { _loading = false; _error = 'رمز OTP غير صحيح، حاول مجدداً'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final minTopup = config.minWalletTopup;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Container(
      margin: const EdgeInsets.all(12),
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottom + 20),
      decoration: BoxDecoration(
        color: context.col.surface,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: context.col.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),

          Row(children: [
            if (_step > 0)
              GestureDetector(
                onTap: () => setState(() { _step--; _error = null; }),
                child: const Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: Icon(Icons.arrow_back, size: 20)),
              ),
            Expanded(
              child: Text(
                _step == 0 ? 'شحن المحفظة'
                    : _step == 1 ? 'رقم بطاقة موبيكاش'
                    : 'رمز التحقق OTP',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 4),
          Text(
            _step == 0 ? 'ادفع مرة، استخدمه عبر الطلبات.'
                : _step == 1 ? 'أدخل رقم البطاقة لإرسال رمز OTP'
                : 'تم إرسال رمز OTP إلى بطاقتك',
            style: TextStyle(fontSize: 13, color: context.col.ink2)),
          const SizedBox(height: 20),

          if (_step == 0) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.col.bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(_amount > 0 ? fmtPrice(_amount) : '0',
                    style: TextStyle(fontFamily: 'PlusJakartaSans',
                      fontSize: 42, fontWeight: FontWeight.w800, color: context.col.ink0)),
                  const SizedBox(width: 8),
                  Text(context.s.lydUnit,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: context.col.ink2)),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Row(children: _quickAmounts.asMap().entries.map((e) {
              final i = e.key; final amt = e.value;
              final isSelected = _customCtrl.text.trim().isEmpty && _selected == amt;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: i < _quickAmounts.length - 1 ? 6 : 0),
                  child: GestureDetector(
                    onTap: () => setState(() { _selected = amt; _customCtrl.clear(); }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : context.col.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : context.col.border, width: 1.5)),
                      child: Center(child: Text('$amt',
                        style: TextStyle(fontFamily: 'PlusJakartaSans',
                          fontWeight: FontWeight.w800, fontSize: 14,
                          color: isSelected ? Colors.white : context.col.ink0))),
                    ),
                  ),
                ),
              );
            }).toList()),
            const SizedBox(height: 10),

            Container(
              decoration: BoxDecoration(
                color: context.col.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _customCtrl.text.trim().isNotEmpty ? AppColors.primary : context.col.border,
                  width: _customCtrl.text.trim().isNotEmpty ? 1.5 : 1)),
              child: TextField(
                controller: _customCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: false),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                onChanged: (_) => setState(() => _selected = null),
                decoration: InputDecoration(
                  hintText: 'أو أدخل مبلغاً آخر',
                  hintStyle: TextStyle(fontSize: 13, color: context.col.ink3),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  suffixText: 'د.ل',
                  suffixStyle: TextStyle(fontSize: 13, color: context.col.ink2, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 20),

            ..._methods.map((m) {
              final isSelected = _paymentId == m.id;
              return GestureDetector(
                onTap: () => setState(() => _paymentId = m.id),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? context.col.surfaceSoft : context.col.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : context.col.border,
                      width: isSelected ? 1.5 : 1)),
                  child: Row(children: [
                    Container(
                      width: 18, height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? AppColors.primary : Colors.transparent,
                        border: isSelected ? null : Border.all(color: context.col.borderStrong, width: 1.5)),
                      child: isSelected
                          ? const Icon(Icons.circle, size: 8, color: Colors.white) : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(m.label,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      Text(m.desc,
                        style: TextStyle(fontSize: 11.5, color: context.col.ink2)),
                    ])),
                    Icon(
                      m.id == 'mobicash' ? Icons.credit_card_outlined : Icons.language_rounded,
                      size: 18, color: context.col.ink3),
                  ]),
                ),
              );
            }),
          ],

          if (_step == 1) ...[
            Container(
              decoration: BoxDecoration(
                color: context.col.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.col.border)),
              child: TextField(
                controller: _cardCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'رقم بطاقة موبيكاش',
                  hintStyle: TextStyle(fontSize: 14, color: context.col.ink3),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(14),
                  prefixIcon: Icon(Icons.credit_card_outlined, size: 18, color: context.col.ink3),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(context.isAr ? 'المبلغ: ${fmtPrice(_amount)} د.ل' : 'Amount: ${fmtPrice(_amount)} LYD',
              style: TextStyle(fontSize: 12.5, color: context.col.ink2)),
          ],

          if (_step == 2) ...[
            Container(
              decoration: BoxDecoration(
                color: context.col.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.col.border)),
              child: TextField(
                controller: _otpCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                autofocus: true,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: 'أدخل رمز OTP',
                  hintStyle: TextStyle(fontSize: 14, color: context.col.ink3),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
            ),
          ],

          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
          ],
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _loading ? null : () => _proceed(minTopup),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _loading
                  ? SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(
                      _step == 0
                          ? (_amount > 0 ? 'متابعة · ${fmtPrice(_amount)} د.ل' : 'متابعة')
                          : _step == 1 ? 'إرسال OTP'
                          : 'تأكيد الشحن',
                      style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
                        fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white)),
            ),
          ),
        ],
      ),
    ));
  }
}

// ── Transaction row ───────────────────────────────────────────────────────────

class _TransactionRow extends StatelessWidget {
  final Map<String, dynamic> tx;
  final bool hasBorder;
  const _TransactionRow({required this.tx, required this.hasBorder});

  static const _arMonths = [
    'يناير','فبراير','مارس','أبريل','مايو','يونيو',
    'يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر',
  ];

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return '';
    final hour = dt.toLocal().hour;
    final amPm = hour < 12 ? 'ص' : 'م';
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${_arMonths[dt.month - 1]} ${dt.year} - $h:$min $amPm';
  }

  String _buildDescription(String type, bool isCredit) {
    final raw = (tx['description'] as String? ?? '').trim();
    final gateway = (tx['gateway'] as String? ?? '').toLowerCase();
    final senderName = tx['sender_name'] as String?;
    final recipientName = tx['recipient_name'] as String?;

    // If backend provided a meaningful non-generic description, use it
    final generics = {'إيداع', 'سحب', 'deposit', 'withdrawal', 'topup', 'top up', 'top-up'};
    if (raw.isNotEmpty && !generics.contains(raw.toLowerCase())) return raw;

    switch (type) {
      case 'cashback': return 'كاش باك على طلبك';
      case 'referral': return 'مكافأة إحالة';
      case 'refund': return 'استرداد مبلغ';
      case 'transfer_in':
        if (senderName != null && senderName.isNotEmpty) return 'تحويل من $senderName';
        return 'تحويل وارد';
      case 'transfer_out':
        if (recipientName != null && recipientName.isNotEmpty) return 'تحويل إلى $recipientName';
        return 'تحويل صادر';
      case 'topup':
      case 'deposit':
        if (gateway == 'tadawel' || gateway == 'tadawul') return 'إيداع عبر تداول';
        if (gateway == 'moamlat') return 'إيداع بالبطاقة المصرفية';
        if (gateway == 'mobicash') return 'إيداع عبر موبيكاش';
        if (gateway == 'admin' || gateway == 'manual' || gateway == 'baahy') return 'إيداع بواسطة باهي';
        if (raw.isNotEmpty) return raw;
        return 'إيداع في المحفظة';
      default:
        if (raw.isNotEmpty) return raw;
        return isCredit ? 'إيداع' : 'سحب';
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawAmt = tx['amount'];
    final amount = rawAmt is num ? rawAmt.toDouble() : double.tryParse(rawAmt?.toString() ?? '') ?? 0.0;
    final type = (tx['type'] as String? ?? '').toLowerCase();
    final direction = (tx['direction'] as String? ?? '').toLowerCase();
    final isCredit = direction == 'credit' || type == 'cashback' || type == 'referral'
        || type == 'refund' || type == 'transfer_in';

    final IconData iconData;
    final Color iconBg;
    final Color iconColor;
    switch (type) {
      case 'cashback':
        iconData = Icons.shopping_bag_outlined;
        iconBg = AppColors.success.withValues(alpha: 0.12);
        iconColor = AppColors.success;
      case 'referral':
        iconData = Icons.group_outlined;
        iconBg = AppColors.info.withValues(alpha: 0.10);
        iconColor = AppColors.info;
      case 'refund':
        iconData = Icons.assignment_return_outlined;
        iconBg = AppColors.success.withValues(alpha: 0.12);
        iconColor = AppColors.success;
      case 'transfer_out':
        iconData = Icons.upload_outlined;
        iconBg = AppColors.danger.withValues(alpha: 0.10);
        iconColor = AppColors.danger;
      case 'transfer_in':
        iconData = Icons.download_outlined;
        iconBg = AppColors.success.withValues(alpha: 0.10);
        iconColor = AppColors.success;
      default:
        iconData = isCredit ? Icons.add_rounded : Icons.remove_rounded;
        iconBg = isCredit
            ? AppColors.success.withValues(alpha: 0.10)
            : AppColors.danger.withValues(alpha: 0.10);
        iconColor = isCredit ? AppColors.success : AppColors.danger;
    }

    final amountColor = isCredit ? AppColors.success : AppColors.danger;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: hasBorder
            ? Border(bottom: BorderSide(color: context.col.border))
            : null,
      ),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(shape: BoxShape.circle, color: iconBg),
          child: Icon(iconData, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_buildDescription(type, isCredit),
              style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
                fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.3)),
            if (tx['created_at'] != null)
              Text(
                _formatDate(tx['created_at']),
                style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 11, color: context.col.ink3),
              ),
          ]),
        ),
        Text(
          '${isCredit ? '+' : '-'}${fmtPrice(amount)} د.ل',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w800, fontSize: 14,
            color: amountColor)),
      ]),
    );
  }
}

// ── Wallet QR sheet ───────────────────────────────────────────────────────────

class _WalletQrSheet extends StatelessWidget {
  final String phone;
  final String name;
  const _WalletQrSheet({required this.phone, required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
      decoration: BoxDecoration(
        color: context.col.surface,
        borderRadius: const BorderRadius.all(Radius.circular(20)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(width: 40, height: 4,
          decoration: BoxDecoration(color: context.col.border, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 20),
        const Text('كود QR محفظتك',
          style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('يمكن لأي شخص مسح هذا الكود لإرسال مبلغ لمحفظتك',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 12.5, color: Colors.grey.shade600)),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4))],
          ),
          child: QrImageView(
            data: 'https://baahy.com/wallet/send?phone=${Uri.encodeComponent(phone)}',
            version: QrVersions.auto,
            size: 200,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Color(0xFF12AEBA),
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Color(0xFF1A1A2E),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(name,
          style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(phone,
          textDirection: TextDirection.ltr,
          style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 14, color: Colors.grey.shade500)),
      ]),
    );
  }
}

// ── Transfer sheet ───────────────────────────────────────────────────────────

class _TransferSheet extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;
  const _TransferSheet({required this.onSuccess});

  @override
  ConsumerState<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends ConsumerState<_TransferSheet> {
  int _step = 0;
  bool _loading = false;
  String? _error;
  bool _saveContact = false;
  List<Map<String, dynamic>> _savedContacts = [];

  final _phoneCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  String? _recipientName;
  String? _recipientPhoneMasked;

  @override
  void initState() {
    super.initState();
    _loadSavedContacts();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSavedContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('wallet_saved_contacts') ?? [];
    if (!mounted) return;
    setState(() {
      _savedContacts = raw.map((e) => Map<String, dynamic>.from(json.decode(e) as Map)).toList();
    });
  }

  Future<void> _saveContactNow() async {
    if (_recipientName == null) return;
    final contact = <String, dynamic>{
      'name': _recipientName!,
      'phone': _phoneCtrl.text.trim(),
      'phone_masked': _recipientPhoneMasked ?? _phoneCtrl.text.trim(),
    };
    final existing = _savedContacts.indexWhere((c) => c['phone'] == contact['phone']);
    if (existing >= 0) {
      _savedContacts[existing] = contact;
    } else {
      _savedContacts.insert(0, contact);
      if (_savedContacts.length > 10) _savedContacts = _savedContacts.sublist(0, 10);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'wallet_saved_contacts',
      _savedContacts.map((e) => json.encode(e)).toList(),
    );
  }

  double get _amount => double.tryParse(_amountCtrl.text.trim()) ?? 0;

  Future<void> _lookup() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = 'يرجى إدخال رقم الهاتف');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiClient.instance.dio.get('/wallet/lookup', queryParameters: {'phone': phone});
      final data = res.data as Map<String, dynamic>;
      if (data['found'] == true) {
        setState(() {
          _recipientName = data['name'] as String;
          _recipientPhoneMasked = data['phone_masked'] as String;
          _step = 1;
          _loading = false;
        });
      } else {
        setState(() { _loading = false; _error = 'لم يتم العثور على مستخدم بهذا الرقم'; });
      }
    } catch (e) {
      final msg = _extractError(e);
      setState(() { _loading = false; _error = msg; });
    }
  }

  Future<void> _confirm() async {
    if (_amount <= 0) {
      setState(() => _error = 'يرجى إدخال مبلغ صحيح');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ApiClient.instance.dio.post('/wallet/transfer', data: {
        'recipient_phone': _phoneCtrl.text.trim(),
        'amount': _amount,
        if (_noteCtrl.text.trim().isNotEmpty) 'note': _noteCtrl.text.trim(),
      });
      if (_saveContact) await _saveContactNow();
      if (mounted) {
        Navigator.of(context).pop();
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تحويل ${fmtPrice(_amount)} د.ل إلى $_recipientName'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      final msg = _extractError(e);
      setState(() { _loading = false; _error = msg; });
    }
  }

  String _extractError(dynamic e) {
    try {
      final data = (e as dynamic).response?.data;
      if (data is Map && data['message'] != null) return data['message'].toString();
    } catch (_) {}
    return 'حدث خطأ، حاول مجدداً';
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final balance = ref.watch(currentUserProvider)?.walletBalance ?? 0.0;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: EdgeInsets.fromLTRB(20, 20, 20, bottom + 20),
        decoration: BoxDecoration(
          color: context.col.surface,
          borderRadius: const BorderRadius.all(Radius.circular(20)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),

          Row(children: [
            if (_step > 0)
              GestureDetector(
                onTap: () => setState(() { _step--; _error = null; }),
                child: const Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: Icon(Icons.arrow_back, size: 20)),
              ),
            Expanded(
              child: Text(
                _step == 0 ? 'تحويل رصيد'
                    : _step == 1 ? 'المبلغ والملاحظة'
                    : 'تأكيد التحويل',
                style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 20, fontWeight: FontWeight.w800,
                  color: context.col.ink0)),
            ),
          ]),
          const SizedBox(height: 4),
          Text(
            _step == 0 ? 'أدخل رقم هاتف المستلم'
                : _step == 1 ? 'رصيدك المتاح: ${fmtPrice(balance)} د.ل'
                : 'راجع التفاصيل قبل التأكيد',
            style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 13, color: context.col.ink2)),
          const SizedBox(height: 20),

          if (_step == 0) ...[
            if (_savedContacts.isNotEmpty) ...[
              Wrap(spacing: 8, runSpacing: 6, children: _savedContacts.map((c) {
                return GestureDetector(
                  onTap: () {
                    _phoneCtrl.text = c['phone'] as String? ?? '';
                    _lookup();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F9F9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF08AAAC).withValues(alpha: 0.4)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.person_outline_rounded, size: 13, color: Color(0xFF08AAAC)),
                      const SizedBox(width: 5),
                      Text(c['name'] as String? ?? '',
                        style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 12,
                          fontWeight: FontWeight.w600, color: Color(0xFF08AAAC))),
                    ]),
                  ),
                );
              }).toList()),
              const SizedBox(height: 12),
            ],
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.col.border)),
              child: TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                autofocus: true,
                textDirection: TextDirection.ltr,
                style: TextStyle(fontFamily: 'PlusJakartaSans', color: context.col.ink0),
                decoration: InputDecoration(
                  hintText: '0912345678',
                  hintTextDirection: TextDirection.ltr,
                  hintStyle: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, color: context.col.ink3),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(14),
                  prefixIcon: Icon(Icons.phone_outlined, size: 18, color: context.col.ink2),
                ),
              ),
            ),
          ],

          if (_step == 1) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F9F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(Icons.person_outline_rounded, size: 18, color: Color(0xFF08AAAC)),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_recipientName ?? '',
                    style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF08AAAC))),
                  Text(_recipientPhoneMasked ?? '',
                    textDirection: TextDirection.ltr,
                    style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11.5, color: Colors.grey.shade600)),
                ]),
              ]),
            ),
            const SizedBox(height: 14),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.col.border)),
              child: TextField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 24, fontWeight: FontWeight.w800),
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 24,
                    fontWeight: FontWeight.w800, color: Colors.grey.shade300),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  suffixText: 'د.ل',
                  suffixStyle: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 14,
                    fontWeight: FontWeight.w600, color: Colors.grey.shade500),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 10),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.col.border)),
              child: TextField(
                controller: _noteCtrl,
                maxLength: 200,
                decoration: InputDecoration(
                  hintText: 'ملاحظة (اختياري)',
                  hintStyle: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 13, color: Colors.grey.shade400),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(14),
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(height: 10),

            GestureDetector(
              onTap: () => setState(() => _saveContact = !_saveContact),
              child: Row(children: [
                SizedBox(
                  width: 20, height: 20,
                  child: Checkbox(
                    value: _saveContact,
                    onChanged: (v) => setState(() => _saveContact = v ?? false),
                    activeColor: const Color(0xFF1FD7E2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),
                Text('حفظ المستلم للتحويل السريع لاحقاً',
                  style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 13, color: context.col.ink1)),
              ]),
            ),
          ],

          if (_step == 2) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(children: [
                _ConfirmRow(label: 'إلى', value: _recipientName ?? ''),
                _ConfirmRow(label: 'رقم الهاتف', value: _recipientPhoneMasked ?? '', ltr: true),
                _ConfirmRow(label: 'المبلغ', value: '${fmtPrice(_amount)} د.ل', highlight: true),
                if (_noteCtrl.text.trim().isNotEmpty)
                  _ConfirmRow(label: 'ملاحظة', value: _noteCtrl.text.trim()),
                _ConfirmRow(label: 'رصيدك بعد التحويل',
                  value: '${fmtPrice((balance - _amount).clamp(0, double.infinity))} د.ل'),
              ]),
            ),
          ],

          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], color: AppColors.danger, fontSize: 13)),
          ],
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _loading ? null : () {
                if (_step == 0) {
                  _lookup();
                } else if (_step == 1) {
                  if (_amount <= 0) { setState(() => _error = 'يرجى إدخال مبلغ صحيح'); return; }
                  if (_amount > balance) { setState(() => _error = 'الرصيد غير كافٍ'); return; }
                  setState(() { _step = 2; _error = null; });
                } else {
                  _confirm();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1FD7E2),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _loading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(
                      _step == 0 ? 'بحث عن المستلم'
                          : _step == 1 ? 'متابعة'
                          : 'تأكيد التحويل',
                      style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
                        fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _ConfirmRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  final bool ltr;
  const _ConfirmRow({required this.label, required this.value, this.highlight = false, this.ltr = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Text(label,
          style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 13, color: Colors.grey.shade600)),
        const Spacer(),
        Text(value,
          textDirection: ltr ? TextDirection.ltr : null,
          style: TextStyle(
            fontFamily: ltr ? 'PlusJakartaSans' : 'Manrope',
            fontFamilyFallback: const ['Tajawal'],
            fontSize: 13.5,
            fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
            color: highlight ? const Color(0xFF08AAAC) : Colors.black87)),
      ]),
    );
  }
}
