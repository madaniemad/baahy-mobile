import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/api/api_client.dart';
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

class RewardsHubScreen extends ConsumerWidget {
  const RewardsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tierAsync  = ref.watch(tierProvider);
    final refAsync   = ref.watch(_hubReferralProvider);
    final config     = ref.watch(appConfigProvider);
    final user       = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: context.col.bg,
      appBar: AppBar(
        backgroundColor: context.col.surface,
        elevation: 0,
        title: Text(context.isAr ? 'برنامج الولاء' : 'Loyalty Program',
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back, color: context.col.ink0)),
      ),
      body: tierAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error:   (_, __) => const SizedBox.shrink(),
        data: (tier) => SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 40),
          child: Column(children: [
            // ── 1. Tier hero ───────────────────────────────────────────────
            _TierHero(tier: tier),

            // ── 2. Progress (hide when Platinum) ──────────────────────────
            if (tier.nextTier != null)
              _ProgressSection(tier: tier),

            const SizedBox(height: 16),

            // ── 3. Benefits table ─────────────────────────────────────────
            _SectionCard(
              title: context.s.hubBenefitsTitle,
              child: _BenefitsTable(),
            ),

            const SizedBox(height: 16),

            // ── 4. Milestones timeline ────────────────────────────────────
            _SectionCard(
              title: context.s.hubMilestonesTitle,
              child: _MilestonesTimeline(tier: tier),
            ),

            const SizedBox(height: 16),

            // ── 5. Referral ───────────────────────────────────────────────
            _SectionCard(
              title: context.s.hubInviteTitle,
              child: refAsync.when(
                loading: () => const SizedBox(height: 80,
                  child: Center(child: CircularProgressIndicator(color: AppColors.primary))),
                error: (_, __) => _ReferralCard(
                  code: user?.referralCode ?? '',
                  invited: 0, joined: 0, earned: 0,
                  giverAmount: config.referralGiverAmount,
                  receiverAmount: config.referralReceiverAmount,
                ),
                data: (data) => _ReferralCard(
                  code: (data['code'] as String).isNotEmpty
                      ? data['code'] as String
                      : user?.referralCode ?? '',
                  invited:  data['invited_count'] as int,
                  joined:   data['used_count'] as int,
                  earned:   data['earned_amount'] as double,
                  giverAmount:    config.referralGiverAmount,
                  receiverAmount: config.referralReceiverAmount,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── 6. Cashback how-to ────────────────────────────────────────
            _SectionCard(
              title: context.s.hubCashbackHowTitle,
              child: _CashbackHowTo(),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Tier hero ──────────────────────────────────────────────────────────────────
class _TierHero extends StatelessWidget {
  final TierStatus tier;
  const _TierHero({required this.tier});

  static const _tierDefs = {
    'silver':   _TierDef(name: 'Silver',   nameAr: 'فضي',     icon: Icons.workspace_premium_outlined, iconColor: Color(0xFFB0BEC5), gradA: Color(0xFF8FA3B1), gradB: Color(0xFF4E6070)),
    'gold':     _TierDef(name: 'Gold',     nameAr: 'ذهبي',    icon: Icons.workspace_premium_rounded,  iconColor: Color(0xFFD4A82E), gradA: Color(0xFFD4A82E), gradB: Color(0xFF9B7012)),
    'platinum': _TierDef(name: 'Platinum', nameAr: 'بلاتيني', icon: Icons.diamond_rounded,            iconColor: Colors.white,     gradA: Color(0xFF6A82FB), gradB: Color(0xFF0E3C46)),
  };
  static const _noTierDef = _TierDef(name: 'Starter', nameAr: 'مبتدئ', icon: Icons.storefront_outlined, iconColor: Colors.white, gradA: Color(0xFF2563EB), gradB: Color(0xFF0E3C46));

  @override
  Widget build(BuildContext context) {
    final def = _tierDefs[tier.tier?.toLowerCase()] ?? _noTierDef;
    final isAr = context.isAr;
    final cashback = tier.cashbackRate.toStringAsFixed(0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [def.gradA, def.gradB],
        ),
      ),
      child: Column(children: [
        Icon(def.icon, size: 52, color: def.iconColor),
        const SizedBox(height: 8),
        Text(isAr ? def.nameAr : def.name,
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 28,
            fontWeight: FontWeight.w900, color: Colors.white)),
        const SizedBox(height: 4),
        Text(context.s.currentTierLabel,
          style: TextStyle(fontFamily: 'Cairo', fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.75))),
        const SizedBox(height: 16),
        // Stats row
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _HeroStat(
            value: '$cashback%',
            label: context.s.cashbackLabel,
          ),
          Container(width: 1, height: 36, color: Colors.white.withValues(alpha: 0.3),
            margin: const EdgeInsets.symmetric(horizontal: 20)),
          _HeroStat(
            value: '${tier.totalDelivered}',
            label: isAr ? 'طلب مكتمل' : 'Completed',
          ),
          Container(width: 1, height: 36, color: Colors.white.withValues(alpha: 0.3),
            margin: const EdgeInsets.symmetric(horizontal: 20)),
          _HeroStat(
            value: '${tier.returnDays}',
            label: isAr ? 'يوم إرجاع' : 'Return days',
          ),
        ]),
      ]),
    );
  }
}

class _TierDef {
  final String name;
  final String nameAr;
  final IconData icon;
  final Color iconColor;
  final Color gradA;
  final Color gradB;
  const _TierDef({required this.name, required this.nameAr,
    required this.icon, required this.iconColor,
    required this.gradA, required this.gradB});
}

class _HeroStat extends StatelessWidget {
  final String value;
  final String label;
  const _HeroStat({required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value,
      style: const TextStyle(fontFamily: 'PlusJakartaSans',
        fontSize: 22, fontWeight: FontWeight.w800,
        color: Colors.white, height: 1)),
    const SizedBox(height: 4),
    Text(label,
      style: TextStyle(fontFamily: 'Cairo', fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.white.withValues(alpha: 0.78))),
  ]);
}

// ── Progress section ───────────────────────────────────────────────────────────
class _ProgressSection extends StatelessWidget {
  final TierStatus tier;
  const _ProgressSection({required this.tier});

  @override
  Widget build(BuildContext context) {
    final isAr = context.isAr;
    final ordPct = tier.ordersNeeded > 0
        ? ((tier.ordersNeeded - tier.ordersRemaining) / tier.ordersNeeded).clamp(0.0, 1.0)
        : 1.0;
    final spdPct = tier.spendNeeded > 0
        ? ((tier.spendNeeded - tier.spendRemaining) / tier.spendNeeded).clamp(0.0, 1.0)
        : 1.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.col.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.shadowCard,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(context.s.hubProgressTitle,
          style: TextStyle(fontFamily: 'Cairo', fontSize: 15,
            fontWeight: FontWeight.w800, color: context.col.ink0)),
        const SizedBox(height: 14),
        _ProgressBar(
          label: context.s.hubOrders,
          progress: ordPct,
          current: tier.ordersNeeded - tier.ordersRemaining,
          needed: tier.ordersNeeded,
          isAr: isAr,
        ),
        const SizedBox(height: 10),
        _ProgressBar(
          label: context.s.hubSpend,
          progress: spdPct,
          current: (tier.spendNeeded - tier.spendRemaining).toInt(),
          needed: tier.spendNeeded.toInt(),
          isAr: isAr,
          isMoney: true,
        ),
        const SizedBox(height: 10),
        Text(context.s.hubBothRequired,
          style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5,
            color: context.col.ink3)),
      ]),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final String label;
  final double progress;
  final int current;
  final int needed;
  final bool isAr;
  final bool isMoney;
  const _ProgressBar({required this.label, required this.progress,
    required this.current, required this.needed,
    required this.isAr, this.isMoney = false});

  @override
  Widget build(BuildContext context) {
    final suffix = isMoney ? ' ${context.s.lydUnit}' : '';
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
          style: TextStyle(fontFamily: 'Cairo', fontSize: 13,
            fontWeight: FontWeight.w600, color: context.col.ink1)),
        Text('$current / $needed$suffix',
          style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12,
            fontWeight: FontWeight.w700, color: context.col.ink1)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(
          value: progress,
          minHeight: 8,
          backgroundColor: context.col.surfaceSoft,
          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      ),
    ]);
  }
}

// ── Section card wrapper ───────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.col.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.shadowCard,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
          style: TextStyle(fontFamily: 'Cairo', fontSize: 15,
            fontWeight: FontWeight.w800, color: context.col.ink0)),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }
}

// ── Benefits table ─────────────────────────────────────────────────────────────
class _BenefitsTable extends StatelessWidget {
  // [No Tier, Silver, Gold, Platinum]
  static const _cashback = ['2%', '3%', '4%', '6%'];
  static const _shipping = ['150', '120', '100', '80'];
  static const _returns  = ['3', '3', '5', '7'];

  @override
  Widget build(BuildContext context) {
    final isAr = context.isAr;
    final headers = isAr
        ? ['—', 'فضي', 'ذهبي', 'بلاتيني']
        : ['—', 'Silver', 'Gold', 'Platinum'];
    final rowLabels = isAr
        ? ['كاش باك', 'شحن مجاني فوق', 'أيام إرجاع']
        : ['Cashback', 'Free shipping', 'Returns'];
    final rows = [_cashback, _shipping, _returns];
    final rowSuffix = isAr ? ['', ' د.ل', ' يوم'] : ['', ' LYD', ' days'];

    return Table(
      border: TableBorder.all(color: context.col.border, width: 1,
        borderRadius: BorderRadius.circular(8)),
      columnWidths: const {0: FlexColumnWidth(1.6)},
      children: [
        // Header row
        TableRow(
          decoration: BoxDecoration(color: context.col.surfaceSoft,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8))),
          children: [
            const _Cell('', isHeader: true),
            ...headers.map((h) => _Cell(h, isHeader: true)),
          ],
        ),
        // Data rows
        for (int r = 0; r < rows.length; r++)
          TableRow(children: [
            _Cell(rowLabels[r], isLabel: true),
            ...rows[r].map((v) => _Cell('$v${rowSuffix[r]}')),
          ]),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  final String text;
  final bool isHeader;
  final bool isLabel;
  const _Cell(this.text, {this.isHeader = false, this.isLabel = false});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
      child: Text(text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: isHeader ? 'Cairo' : 'PlusJakartaSans',
          fontSize: isHeader ? 13 : 12,
          fontWeight: isHeader || isLabel ? FontWeight.w700 : FontWeight.w600,
          color: isHeader ? context.col.ink0 : context.col.ink1)),
    );
  }
}

// ── Milestones timeline ───────────────────────────────────────────────────────
class _MilestonesTimeline extends StatelessWidget {
  final TierStatus tier;
  const _MilestonesTimeline({required this.tier});

  static const _milestones = [1, 3, 5, 10, 25, 50];

  @override
  Widget build(BuildContext context) {
    final isAr     = context.isAr;
    final done     = tier.totalDelivered;
    final nextNum  = tier.nextMilestoneOrder;
    final nextAmt  = tier.nextMilestoneReward;

    return Column(
      children: List.generate(_milestones.length, (i) {
        final orderNum  = _milestones[i];
        final isLast    = i == _milestones.length - 1;
        final completed = done >= orderNum;
        final isCurrent = orderNum == nextNum;

        // Amount: only known for the current (next) milestone
        String? amountStr;
        if (isCurrent && nextAmt != null && nextAmt > 0) {
          amountStr = '${nextAmt.toStringAsFixed(0)} ${context.s.lydUnit}';
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline track
            Column(children: [
              _MilestoneDot(completed: completed, active: isCurrent),
              if (!isLast)
                Container(
                  width: 2, height: 36,
                  color: completed
                      ? AppColors.success.withValues(alpha: 0.4)
                      : context.col.border),
            ]),
            const SizedBox(width: 14),
            // Content
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 8, top: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isAr ? 'الطلب رقم $orderNum' : 'Order #$orderNum',
                            style: TextStyle(
                              fontFamily: 'Cairo', fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: completed
                                  ? context.col.ink2
                                  : isCurrent
                                      ? context.col.ink0
                                      : context.col.ink3),
                          ),
                          if (isCurrent && nextNum != null)
                            Text(
                              isAr
                                  ? 'متبقّي ${tier.nextMilestoneRemaining ?? 0} طلب'
                                  : '${tier.nextMilestoneRemaining ?? 0} order${(tier.nextMilestoneRemaining ?? 0) == 1 ? "" : "s"} away',
                              style: TextStyle(fontFamily: 'Cairo', fontSize: 12,
                                color: context.col.ink2, height: 1.4)),
                        ],
                      ),
                    ),
                    if (completed)
                      Text(context.s.hubCompleted,
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 12,
                          fontWeight: FontWeight.w700, color: AppColors.success))
                    else if (amountStr != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Text(amountStr,
                          style: const TextStyle(fontFamily: 'PlusJakartaSans',
                            fontSize: 12, fontWeight: FontWeight.w800,
                            color: AppColors.primary)),
                      )
                    else
                      Text('—',
                        style: TextStyle(fontSize: 14, color: context.col.ink4)),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _MilestoneDot extends StatelessWidget {
  final bool completed;
  final bool active;
  const _MilestoneDot({required this.completed, required this.active});
  @override
  Widget build(BuildContext context) {
    if (completed) {
      return Container(
        width: 24, height: 24,
        decoration: const BoxDecoration(
          shape: BoxShape.circle, color: AppColors.success),
        child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
      );
    }
    if (active) {
      return Container(
        width: 24, height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primary,
          boxShadow: [BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.4),
            blurRadius: 8, spreadRadius: 1)]),
        child: const Icon(Icons.emoji_events_rounded, size: 13, color: Colors.white),
      );
    }
    return Container(
      width: 24, height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: context.col.border, width: 2),
        color: context.col.surface),
    );
  }
}

// ── Referral card ──────────────────────────────────────────────────────────────
class _ReferralCard extends StatefulWidget {
  final String code;
  final int invited;
  final int joined;
  final double earned;
  final int giverAmount;
  final int receiverAmount;
  const _ReferralCard({required this.code, required this.invited,
    required this.joined, required this.earned,
    required this.giverAmount, required this.receiverAmount});
  @override
  State<_ReferralCard> createState() => _ReferralCardState();
}

class _ReferralCardState extends State<_ReferralCard> {
  bool _copied = false;

  void _copy() {
    Clipboard.setData(ClipboardData(text: widget.code));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.code.isEmpty) {
      return Text(context.isAr ? 'سجّل دخولك للحصول على رمز الإحالة'
          : 'Sign in to see your referral code',
        style: TextStyle(color: context.col.ink2));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Code row
      Row(children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: context.col.surfaceSoft,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: context.col.borderStrong),
            ),
            child: Text(widget.code,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'PlusJakartaSans',
                fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: 0.5)),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: _copy,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _copied ? AppColors.success.withValues(alpha: 0.1) : context.col.surfaceSoft,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: context.col.border),
            ),
            child: Row(children: [
              Icon(_copied ? Icons.check_rounded : Icons.upload_outlined,
                size: 16, color: _copied ? AppColors.success : context.col.ink1),
              const SizedBox(width: 6),
              Text(_copied ? context.s.copied : context.s.copyBtn,
                style: TextStyle(fontWeight: FontWeight.w700,
                  color: _copied ? AppColors.success : context.col.ink0)),
            ]),
          ),
        ),
      ]),

      const SizedBox(height: 12),

      // Share button
      GestureDetector(
        onTap: () => Share.share(
          context.s.referralShareGeneral(widget.code, widget.receiverAmount)),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.share_outlined, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Text(context.isAr ? 'شارك ورمز صديقك' : 'Share with friends',
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 14,
                fontWeight: FontWeight.w800, color: Colors.white)),
          ]),
        ),
      ),

      // Stats
      if (widget.invited > 0 || widget.earned > 0) ...[
        const SizedBox(height: 14),
        Divider(color: context.col.border),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _StatItem(widget.invited.toString(), context.s.statInvited),
          _StatItem(widget.joined.toString(),  context.s.statJoined),
          _StatItem(widget.earned.toStringAsFixed(0), context.s.statEarned, money: true),
        ]),
      ],
    ]);
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final bool money;
  const _StatItem(this.value, this.label, {this.money = false});
  @override
  Widget build(BuildContext context) => Column(children: [
    Row(mainAxisSize: MainAxisSize.min, children: [
      Text(value,
        style: const TextStyle(fontFamily: 'PlusJakartaSans',
          fontSize: 20, fontWeight: FontWeight.w800, height: 1)),
      if (money)
        Text(' ${context.s.lydUnit}',
          style: TextStyle(fontSize: 11, color: context.col.ink2,
            fontWeight: FontWeight.w600)),
    ]),
    const SizedBox(height: 3),
    Text(label,
      style: TextStyle(fontSize: 11, color: context.col.ink3)),
  ]);
}

// ── Cashback how-to ────────────────────────────────────────────────────────────
class _CashbackHowTo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final steps = [
      context.s.hubCashbackStep1,
      context.s.hubCashbackStep2,
      context.s.hubCashbackStep3,
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ...steps.indexed.map((pair) {
        final i = pair.$1;
        final step = pair.$2;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle),
              child: Center(child: Text('${i + 1}',
                style: const TextStyle(fontFamily: 'PlusJakartaSans',
                  fontSize: 13, fontWeight: FontWeight.w800,
                  color: AppColors.primary))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(step,
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 13.5,
                    height: 1.4, color: context.col.ink1)),
              ),
            ),
          ]),
        );
      }),
      const SizedBox(height: 4),
      Text(context.s.hubCashbackNote,
        style: TextStyle(fontFamily: 'Cairo', fontSize: 12,
          color: context.col.ink3, fontStyle: FontStyle.italic)),
    ]);
  }
}
