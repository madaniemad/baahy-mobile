import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers/app_config_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/tier_provider.dart';
import '../../../core/models/tier_status.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/l10n.dart';
import '../../../core/utils/navigation.dart';
import '../../../shared/theme/app_theme.dart';

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
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: Padding(
          padding: const EdgeInsets.all(10),
          child: GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              decoration: BoxDecoration(
                color: context.col.surfaceSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.qr_code_2_rounded, size: 20, color: context.col.ink0),
            ),
          ),
        ),
        title: const Text('محفظة باهي',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 17)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: context.col.surfaceSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.close_rounded, size: 18, color: context.col.ink0),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFF32DDE5),
        onRefresh: () async {
          ref.invalidate(_walletProvider);
          ref.invalidate(tierProvider);
          await ref.read(authProvider.notifier).refreshProfile();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _HeroBalanceCard(
                balance: balance,
                onTopUp: () => _showTopUpSheet(context, ref),
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
                  child: CircularProgressIndicator(color: Color(0xFF32DDE5)))),
              error: (_, __) => const SizedBox.shrink(),
              data: (txns) => _TransactionsSection(txns: txns),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 36),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.shield_outlined, size: 13, color: context.col.ink3),
                const SizedBox(width: 6),
                Text('رصيدك آمن 100% ويمكنك استخدامه في أي وقت',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: context.col.ink3)),
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
}

// ── Hero balance card ─────────────────────────────────────────────────────────

class _HeroBalanceCard extends StatelessWidget {
  final double balance;
  final VoidCallback onTopUp;
  const _HeroBalanceCard({required this.balance, required this.onTopUp});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF32DDE5), Color(0xFF08AAAC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Opacity(
              opacity: 0.12,
              child: Image.asset('assets/images/onb-pattern.png', fit: BoxFit.cover),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.qr_code_2_rounded, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 10),
              const Text('رصيدك المتاح',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w500,
                  color: Colors.white)),
              const Spacer(),
              Icon(Icons.account_balance_wallet_rounded, size: 52,
                color: Colors.white.withValues(alpha: 0.22)),
            ]),
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic, children: [
              Text(fmtPrice(balance),
                style: const TextStyle(fontFamily: 'PlusJakartaSans',
                  fontSize: 44, fontWeight: FontWeight.w800, color: Colors.white,
                  letterSpacing: -1, height: 1)),
              const SizedBox(width: 8),
              const Text('د.ل',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w600,
                  color: Colors.white)),
            ]),
            const SizedBox(height: 6),
            Row(children: const [
              Text('✦  ', style: TextStyle(fontSize: 11, color: Colors.white)),
              Text('أنت تكسب مع كل طلب',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 12.5, color: Colors.white,
                  fontWeight: FontWeight.w500)),
            ]),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: onTopUp,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.add_rounded, size: 15, color: Color(0xFF08AAAC)),
                      SizedBox(width: 5),
                      Text('شحن',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 13.5,
                          fontWeight: FontWeight.w800, color: Color(0xFF08AAAC))),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.75), width: 1.5),
                  ),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.upload_outlined, size: 15, color: Colors.white),
                    SizedBox(width: 5),
                    Text('إرسال',
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 13.5,
                        fontWeight: FontWeight.w800, color: Colors.white)),
                  ]),
                ),
              ),
            ]),
          ]),
        ),
      ]),
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
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: context.col.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.col.border),
        ),
        child: Row(children: [
          _StatItem(
            label: 'كاش باك\nمكتسب',
            amount: cashbackEarned,
            iconBg: const Color(0xFFE8F8F0),
            iconColor: const Color(0xFF1F8A5B),
            icon: Icons.trending_up_rounded,
          ),
          _StatDivider(),
          _StatItem(
            label: 'استرداد\nمعلق',
            amount: pendingRefunds,
            iconBg: const Color(0xFFFFF3E0),
            iconColor: const Color(0xFFE65100),
            icon: Icons.hourglass_empty_rounded,
          ),
          _StatDivider(),
          _StatItem(
            label: 'مكافآت\nالدعوات',
            amount: referralRewards,
            iconBg: const Color(0xFFF3E5F5),
            iconColor: const Color(0xFF7B1FA2),
            icon: Icons.people_alt_outlined,
          ),
          _StatDivider(),
          _StatItem(
            label: 'رصيد\nمتاح',
            amount: balance,
            iconBg: const Color(0xFFE3F2FD),
            iconColor: const Color(0xFF1565C0),
            icon: Icons.account_balance_wallet_outlined,
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
  final IconData icon;
  const _StatItem({required this.label, required this.amount,
    required this.iconBg, required this.iconColor, required this.icon});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? Colors.transparent : iconBg,
            border: isDark ? Border.all(color: iconColor.withValues(alpha: 0.5)) : null,
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(height: 6),
        Text(fmtPrice(amount),
          style: TextStyle(fontFamily: 'PlusJakartaSans',
            fontSize: 13, fontWeight: FontWeight.w800, color: context.col.ink0)),
        const SizedBox(height: 2),
        Text(label,
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Cairo',
            fontSize: 9.5, color: isDark ? context.col.ink2 : context.col.ink3, height: 1.3)),
      ]),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 44, color: context.col.border);
  }
}

// ── Tier progress card ────────────────────────────────────────────────────────

class _TierProgressCard extends StatelessWidget {
  final TierStatus tier;
  const _TierProgressCard({required this.tier});

  static const _tiers = ['bronze', 'silver', 'gold', 'platinum'];
  static const _tierLabels = ['برونزي', 'فضي', 'ذهبي', 'بلاتيني'];
  static const _tierColors = [
    Color(0xFFCD7F32), Color(0xFF9E9E9E), Color(0xFFD4A82E), Color(0xFF4FC3F7),
  ];

  @override
  Widget build(BuildContext context) {
    final currentTier = tier.tier ?? 'bronze';
    final currentIndex = _tiers.indexOf(currentTier).clamp(0, 3);
    final nextTier = tier.nextTier;
    final nextIndex = nextTier != null ? _tiers.indexOf(nextTier).clamp(0, 3) : null;

    final totalNeeded = tier.spendAmount + tier.spendRemaining;
    final progress = totalNeeded > 0
        ? (tier.spendAmount / totalNeeded).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.col.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.col.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _tierColors[currentIndex].withValues(alpha: 0.12),
            ),
            child: Icon(Icons.workspace_premium_rounded,
              size: 22, color: _tierColors[currentIndex]),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('المستوى الحالي',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: context.col.ink3)),
            Text(_tierLabels[currentIndex],
              style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w800,
                color: _tierColors[currentIndex])),
          ]),
          const Spacer(),
          GestureDetector(
            onTap: () => safePush(context, '/rewards'),
            child: const Text('عرض جميع المزايا <',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: Color(0xFF32DDE5),
                fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 16),

        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(4, (i) {
            final active = i <= currentIndex;
            return Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active
                      ? _tierColors[i].withValues(alpha: 0.15)
                      : context.col.surfaceSoft,
                ),
                child: Icon(Icons.workspace_premium_rounded, size: 18,
                  color: active ? _tierColors[i] : context.col.ink4),
              ),
              const SizedBox(height: 4),
              Text(_tierLabels[i],
                style: TextStyle(fontFamily: 'Cairo', fontSize: 9.5,
                  color: active ? _tierColors[i] : context.col.ink4,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w400)),
            ]);
          }),
        ),
        const SizedBox(height: 14),

        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            backgroundColor: context.col.surfaceSoft,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF32DDE5)),
          ),
        ),
        const SizedBox(height: 10),

        if (nextIndex != null && tier.spendRemaining > 0)
          Text(
            'تبقى ${fmtPrice(tier.spendRemaining)} د.ل للوصول إلى ${_tierLabels[nextIndex]}',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: context.col.ink2),
          ),
      ]),
    );
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
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Text('اكسب أكثر',
          style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w800,
            color: context.col.ink0)),
      ),
      SizedBox(
        height: 128,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            _EarnCard(
              onTap: onShop,
              icon: Icons.shopping_bag_outlined,
              iconBg: const Color(0xFFE8F8F0),
              iconColor: const Color(0xFF1F8A5B),
              title: 'تسوق واحصل على كاش باك',
            ),
            const SizedBox(width: 10),
            _EarnCard(
              onTap: onInvite,
              icon: Icons.person_add_alt_1_outlined,
              iconBg: const Color(0xFFF3E5F5),
              iconColor: const Color(0xFF7B1FA2),
              title: 'ادعُ أصدقاءك واكسب مكافآت',
            ),
            const SizedBox(width: 10),
            _EarnCard(
              onTap: onDeals,
              icon: Icons.local_offer_outlined,
              iconBg: const Color(0xFFFFF3E0),
              iconColor: const Color(0xFFE65100),
              title: 'عروض حصرية بخصومات مميزة',
            ),
          ],
        ),
      ),
    ]);
  }
}

class _EarnCard extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  const _EarnCard({required this.onTap, required this.icon,
    required this.iconBg, required this.iconColor, required this.title});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 128,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.col.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.col.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? Colors.transparent : iconBg,
              border: isDark ? Border.all(color: iconColor.withValues(alpha: 0.5)) : null,
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(height: 10),
          Text(title,
            style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w700,
              color: context.col.ink0, height: 1.4)),
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
          Text('آخر المعاملات',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w800,
              color: context.col.ink0)),
          const Spacer(),
          if (txns.isNotEmpty)
            const Text('عرض الكل <',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Color(0xFF32DDE5),
                fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 10),
        if (txns.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Column(children: [
                Icon(Icons.receipt_long_outlined, size: 60, color: context.col.ink4),
                const SizedBox(height: 12),
                Text('لا توجد معاملات بعد',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 15, color: context.col.ink2)),
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

  static const _methods = [
    (id: 'mobicash', label: 'موبيكاش', desc: 'ادفع بكارت موبيكاش'),
    (id: 'tadawel',  label: 'تداول',   desc: 'دفع إلكتروني عبر تداول'),
    (id: 'moamlat', label: 'معاملات', desc: 'دفع إلكتروني عبر معاملات'),
  ];

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
        borderRadius: const BorderRadius.all(Radius.circular(10)),
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
                borderRadius: BorderRadius.circular(10),
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
                        color: isSelected ? context.col.ink0 : context.col.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? context.col.ink0 : context.col.border, width: 1.5)),
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
                borderRadius: BorderRadius.circular(10),
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
                    borderRadius: BorderRadius.circular(10),
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
                borderRadius: BorderRadius.circular(10),
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
                borderRadius: BorderRadius.circular(10),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _loading
                  ? SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: context.col.ink0))
                  : Text(
                      _step == 0
                          ? (_amount > 0 ? 'متابعة · ${fmtPrice(_amount)} د.ل' : 'متابعة')
                          : _step == 1 ? 'إرسال OTP'
                          : 'تأكيد الشحن',
                      style: TextStyle(fontFamily: 'Cairo',
                        fontWeight: FontWeight.w800, fontSize: 15, color: context.col.ink0)),
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

  @override
  Widget build(BuildContext context) {
    final rawAmt = tx['amount'];
    final amount = rawAmt is num ? rawAmt.toDouble() : double.tryParse(rawAmt?.toString() ?? '') ?? 0.0;
    final isCredit = tx['type'] == 'credit' || amount > 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: hasBorder
            ? Border(bottom: BorderSide(color: context.col.border))
            : null,
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCredit
                ? const Color(0xFF32DDE5).withValues(alpha: 0.12)
                : context.col.surfaceSoft,
          ),
          child: Icon(
            isCredit ? Icons.add_rounded : Icons.remove_rounded,
            color: isCredit ? const Color(0xFF08AAAC) : context.col.ink2, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tx['description'] ?? (isCredit ? 'إيداع' : 'سحب'),
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.3)),
            if (tx['created_at'] != null)
              Text(
                () {
                  final dt = DateTime.tryParse(tx['created_at']);
                  return dt != null ? '${dt.day}/${dt.month}/${dt.year}' : '';
                }(),
                style: TextStyle(fontFamily: 'PlusJakartaSans',
                  fontSize: 11, color: context.col.ink3),
              ),
          ]),
        ),
        Text(
          '${isCredit ? '+' : ''}${fmtPrice(amount)} د.ل',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w800, fontSize: 14,
            color: isCredit ? const Color(0xFF08AAAC) : context.col.ink0)),
      ]),
    );
  }
}
