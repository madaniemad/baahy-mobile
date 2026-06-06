import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers/app_config_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/friends_provider.dart';
import '../../../core/providers/tier_provider.dart';
import '../../../core/providers/wishlist_provider.dart';
import '../../../core/utils/l10n.dart';
import '../../../core/utils/navigation.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/app_button.dart';

const _kActiveStatuses = [
  'pending_confirmation', 'pending', 'confirmed',
  'processing', 'fulfilled', 'shipped', 'out_for_delivery',
];

// One call returns both total and active order counts.
final _ordersCountsProvider = FutureProvider<({int active, int total})>((ref) async {
  try {
    final res = await ApiClient.instance.dio.get('/orders', queryParameters: {'per_page': 50});
    final d = res.data['data'];
    List? raw;
    if (d is Map) raw = d['data'] as List?;
    else if (d is List) raw = d;
    final orders = raw ?? [];
    final total = (d is Map ? (d['total'] as num?)?.toInt() : null) ?? orders.length;
    final active = orders.where((o) => _kActiveStatuses.contains(o['status'])).length;
    return (active: active, total: total);
  } catch (_) {
    return (active: 0, total: 0);
  }
});

final _freshWalletBalanceProvider = FutureProvider<double>((ref) async {
  try {
    final res = await ApiClient.instance.dio.get('/wallet');
    return (res.data['data']?['balance'] as num?)?.toDouble() ?? 0.0;
  } catch (_) {
    return 0.0;
  }
});

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth        = ref.watch(authProvider);
    final config      = ref.watch(appConfigProvider);

    if (!auth.isLoggedIn) {
      return Scaffold(
        backgroundColor: context.col.bg,
        appBar: AppBar(
          title: Text(context.s.myAccount,
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
          backgroundColor: context.col.surface, elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: context.col.surfaceSoft, shape: BoxShape.circle),
                  child: Icon(Icons.person_outline, size: 44, color: context.col.ink3),
                ),
                const SizedBox(height: 16),
                Text(context.s.signInPrompt,
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(context.s.signInSub,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: context.col.ink2)),
                const SizedBox(height: 24),
                AppButton(label: context.s.signIn, onTap: () => safePush(context, '/signin')),
              ],
            ),
          ),
        ),
      );
    }

    final user = auth.user!;
    final wishlistCount = ref.watch(wishlistProvider).length;
    final counts = ref.watch(_ordersCountsProvider).value;
    final activeOrders = counts?.active ?? 0;
    final totalOrders = counts?.total ?? 0;
    final freshWallet = ref.watch(_freshWalletBalanceProvider);
    final walletDisplay = freshWallet.valueOrNull ?? user.walletBalance;

    return Scaffold(
      backgroundColor: context.col.bg,
      body: CustomScrollView(
        slivers: [
          // ── Dark gradient header ────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _ProfileHeader(
              user: user,
              onEdit: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: context.col.surface,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                builder: (_) => _EditProfileSheet(
                  currentName: user.name,
                  onSaved: () => ref.read(authProvider.notifier).refreshProfile(),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              children: [
                // ── Stats row ───────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Row(children: [
                    _StatTile(
                      icon: Icons.local_shipping_outlined,
                      iconColor: const Color(0xFF2563EB),
                      iconBg: const Color(0xFF2563EB).withValues(alpha: 0.12),
                      value: counts == null ? '—' : '$activeOrders',
                      label: context.s.activeOrdersLbl,
                      onTap: () => safePush(context, '/orders'),
                    ),
                    const SizedBox(width: 8),
                    _StatTile(
                      icon: Icons.receipt_long_outlined,
                      iconColor: const Color(0xFF7C3AED),
                      iconBg: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                      value: counts == null ? '—' : '$totalOrders',
                      label: context.s.totalOrdersLbl,
                      onTap: () => safePush(context, '/orders'),
                    ),
                    const SizedBox(width: 8),
                    _StatTile(
                      icon: Icons.favorite_outline_rounded,
                      iconColor: const Color(0xFFE11D48),
                      iconBg: const Color(0xFFE11D48).withValues(alpha: 0.12),
                      value: '$wishlistCount',
                      label: context.s.savedItems,
                      onTap: () => safePush(context, '/wishlist'),
                    ),
                  ]),
                ),

                // ── Wallet card ─────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: GestureDetector(
                    onTap: () => safePush(context, '/wallet'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: context.col.surface,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: AppShadows.shadowCard,
                        border: Border.all(color: context.col.border),
                      ),
                      child: Row(children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.account_balance_wallet_outlined,
                            color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(context.s.myWallet,
                              style: TextStyle(fontSize: 11.5, color: context.col.ink2)),
                            Text(
                              '${walletDisplay.toStringAsFixed(0)} ${context.s.lyd}',
                              style: TextStyle(fontFamily: 'PlusJakartaSans',
                                fontSize: 20, fontWeight: FontWeight.w800, color: context.col.ink0, height: 1.1)),
                          ],
                        )),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: context.col.ink2, width: 1.0),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(context.s.chargeWallet, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                              color: context.col.ink2, fontFamily: 'Cairo')),
                            const SizedBox(width: 4),
                            Icon(Icons.add, size: 12, color: context.col.ink2),
                          ]),
                        ),
                      ]),
                    ),
                  ),
                ),

                // ── Tier card ───────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: GestureDetector(
                    onTap: () => safePush(context, '/rewards-hub'),
                    child: _TierCard(),
                  ),
                ),

                const SizedBox(height: 12),

                // ── Friends card (social feature) ───────────────────────────
                if (config.socialEnabled)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: _FriendsCard(),
                  ),

                // ── Menu group 1 ────────────────────────────────────────────
                _MenuGroup([
                  _MenuRow(
                    icon: Icons.shopping_bag_outlined,
                    label: context.s.myOrders,
                    onTap: () => safePush(context, '/orders'),
                  ),
                  _MenuRow(
                    icon: Icons.location_on_outlined,
                    label: context.s.myAddresses,
                    onTap: () => safePush(context, '/addresses'),
                  ),
                  _MenuRow(
                    icon: Icons.assignment_return_outlined,
                    label: context.tr('الإرجاعات والاسترداد', 'Returns & Refunds'),
                    onTap: () => safePush(context, '/return-policy'),
                  ),
                  _MenuRow(
                    icon: Icons.auto_awesome_outlined,
                    label: context.s.inviteFriends,
                    onTap: () => safePush(context, '/referral'),
                    badge: context.s.inviteEarnBadge,
                  ),
                ]),

                // ── Birthday row ─────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: _BirthdayRow(user: user),
                ),

                const SizedBox(height: 8),

                // ── Menu group 2 ────────────────────────────────────────────
                _MenuGroup([
                  _MenuRow(
                    icon: Icons.notifications_outlined,
                    label: context.s.notifications,
                    onTap: () => safePush(context, '/notifications'),
                  ),
                  _MenuRow(
                    icon: Icons.language_outlined,
                    label: context.s.switchLang,
                    onTap: () => ref.read(localeProvider.notifier).toggle(),
                  ),
                  _MenuRow(
                    icon: Icons.settings_outlined,
                    label: context.tr('الإعدادات', 'Settings'),
                    onTap: () => safePush(context, '/settings'),
                  ),
                ]),

                const SizedBox(height: 16),

                // ── Sign out ────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: GestureDetector(
                    onTap: () => ref.read(authProvider.notifier).logout(),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.logout_rounded, size: 17, color: AppColors.danger),
                        const SizedBox(width: 8),
                        Text(context.s.signOut,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                            color: AppColors.danger, fontFamily: 'Cairo')),
                      ]),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                Text('baahy v1.0 · 2026',
                  style: TextStyle(fontSize: 11, color: context.col.ink4)),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Friends card ─────────────────────────────────────────────────────────────

class _FriendsCard extends ConsumerWidget {
  const _FriendsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsState = ref.watch(friendsProvider);
    final friendCount  = friendsState.friends.length;
    final pendingCount = friendsState.incomingRequests.length;

    return GestureDetector(
      onTap: () => safePush(context, '/friends'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: context.col.surface,
          borderRadius: BorderRadius.circular(10),
          boxShadow: AppShadows.shadowCard,
          border: Border.all(color: context.col.border),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.people_outline, color: AppColors.teal, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.tr('الأصدقاء', 'Friends'),
              style: TextStyle(fontSize: 11.5, color: context.col.ink2)),
            Text('$friendCount ${context.tr('صديق', 'friends')}',
              style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 18,
                fontWeight: FontWeight.w800, color: context.col.ink0, height: 1.1)),
          ])),
          if (pendingCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$pendingCount',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, color: context.col.ink3),
        ]),
      ),
    );
  }
}

// ── Profile header ────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final dynamic user;
  final VoidCallback onEdit;
  const _ProfileHeader({required this.user, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final initial = (user.name as String).isNotEmpty ? (user.name as String)[0] : 'U';
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: context.col.surface),
      child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              // Avatar
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.12),
                ),
                child: Center(
                  child: Text(initial,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                      color: AppColors.primary, fontFamily: 'Cairo')),
                ),
              ),
              const SizedBox(width: 12),

              // Name + phone
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user.name as String,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                      color: context.col.ink0, fontFamily: 'Cairo', height: 1.2)),
                  const SizedBox(height: 3),
                  Row(children: [
                    Text(user.phone as String,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(fontFamily: 'PlusJakartaSans',
                        fontSize: 12, color: context.col.ink3)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.check_circle_outline, size: 8, color: AppColors.success),
                        const SizedBox(width: 3),
                        Text(context.s.verified, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                          color: AppColors.success, fontFamily: 'Cairo')),
                      ]),
                    ),
                  ]),
                ]),
              ),

              // Edit button
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.col.surfaceSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.edit_outlined, size: 17, color: context.col.ink2),
                ),
              ),
            ]),
          ),
        ),
      );
  }
}

// ── Stat tile ─────────────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String value;
  final String label;
  final VoidCallback onTap;
  const _StatTile({
    required this.icon, required this.iconColor, required this.iconBg,
    required this.value, required this.label, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: context.col.surface,
          borderRadius: BorderRadius.circular(10),
          boxShadow: AppShadows.shadowCard,
        ),
        child: Column(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 22, fontWeight: FontWeight.w800,
            color: context.col.ink0, height: 1)),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(fontSize: 11, color: context.col.ink2),
            textAlign: TextAlign.center),
        ]),
      ),
    ),
  );
}

// ── Menu group ────────────────────────────────────────────────────────────────

class _MenuGroup extends StatelessWidget {
  final List<_MenuRow> rows;
  const _MenuGroup(this.rows);

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: context.col.surface,
      borderRadius: BorderRadius.circular(10),
      boxShadow: AppShadows.shadowCard,
    ),
    child: Column(
      children: [
        for (int i = 0; i < rows.length; i++) ...[
          rows[i],
          if (i < rows.length - 1)
            Divider(height: 1, color: context.col.border, indent: 58, endIndent: 0),
        ],
      ],
    ),
  );
}

// ── Menu row ──────────────────────────────────────────────────────────────────

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? badge;
  const _MenuRow({
    required this.icon, required this.label, required this.onTap, this.badge,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: context.col.surfaceSoft,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 17, color: context.col.ink0),
        ),
        const SizedBox(width: 13),
        Expanded(child: Text(label,
          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500))),
        if (badge != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(badge!,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                color: Color(0xFF7C3AED), fontFamily: 'Cairo')),
          ),
          const SizedBox(width: 6),
        ],
        Icon(Icons.arrow_forward_ios, size: 13, color: context.col.ink4),
      ]),
    ),
  );
}

// ── Tier card ─────────────────────────────────────────────────────────────────

class _TierCard extends ConsumerWidget {
  const _TierCard();

  String _tierName(BuildContext context, String? tier) {
    switch (tier) {
      case 'silver':   return context.s.silverTier;
      case 'gold':     return context.s.goldTier;
      case 'platinum': return context.s.platinumTier;
      default:         return context.s.noTier;
    }
  }

  Color _tierColor(String? tier) {
    switch (tier) {
      case 'silver':   return Colors.grey.shade600;
      case 'gold':     return Colors.amber.shade700;
      case 'platinum': return Colors.blueAccent;
      default:         return Colors.grey.shade500;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tierAsync = ref.watch(tierProvider);

    return tierAsync.when(
      loading: () => Container(
        height: 80,
        decoration: BoxDecoration(
          color: context.col.surfaceSoft,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (tier) {
        final isPlatinum = tier.tier == 'platinum';
        final tierColor = _tierColor(tier.tier);
        final tierName = _tierName(context, tier.tier);

        // Progress: lower of orders/spend ratio, clamped 0..1
        double progress = 0.0;
        if (!isPlatinum && tier.ordersNeeded > 0 && tier.spendNeeded > 0) {
          final orderRatio = tier.ordersCount / tier.ordersNeeded;
          final spendRatio = tier.spendAmount / tier.spendNeeded;
          progress = (orderRatio < spendRatio ? orderRatio : spendRatio).clamp(0.0, 1.0);
        }

        return Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 0),
          decoration: BoxDecoration(
            color: context.col.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: AppShadows.shadowCard,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: tierColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: tierColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.star_rounded, size: 12, color: tierColor),
                    const SizedBox(width: 4),
                    Text(tierName,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        color: tierColor, fontFamily: 'Cairo')),
                  ]),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(context.s.tierLevel,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: context.col.ink1, fontFamily: 'Cairo')),
                ),
                Text(
                  '${tier.cashbackRate.toStringAsFixed(0)}% cashback',
                  style: TextStyle(fontFamily: 'PlusJakartaSans',
                    fontSize: 11, fontWeight: FontWeight.w700, color: tierColor),
                ),
              ]),

              const SizedBox(height: 12),

              if (isPlatinum) ...[
                Center(
                  child: Text(context.s.topTier,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                      color: Colors.blueAccent, fontFamily: 'Cairo')),
                ),
              ] else ...[
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: context.col.surfaceSoft,
                    valueColor: AlwaysStoppedAnimation<Color>(tierColor),
                  ),
                ),
                const SizedBox(height: 8),
                // Progress label
                Text(
                  context.isAr
                    ? '${tier.ordersRemaining} ${context.s.ordersToNextTier} · ${tier.spendRemaining.toStringAsFixed(0)} ${context.s.spendToNextTier}'
                    : '${tier.ordersRemaining} ${context.s.ordersToNextTier} · ${tier.spendRemaining.toStringAsFixed(0)} ${context.s.spendToNextTier}',
                  style: TextStyle(fontSize: 11.5, color: context.col.ink2, fontFamily: 'Cairo'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ── Birthday row ──────────────────────────────────────────────────────────────

class _BirthdayRow extends ConsumerStatefulWidget {
  final dynamic user;
  const _BirthdayRow({required this.user});

  @override
  ConsumerState<_BirthdayRow> createState() => _BirthdayRowState();
}

class _BirthdayRowState extends ConsumerState<_BirthdayRow> {
  bool _saving = false;

  String? get _birthday => widget.user.birthday?.toString();

  String _formatBirthday(String raw) {
    try {
      final parts = raw.split('-');
      if (parts.length >= 3) return '${parts[2]}/${parts[1]}';
      return raw;
    } catch (_) {
      return raw;
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final result = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25),
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year, now.month, now.day - 1),
      locale: Localizations.localeOf(context),
    );
    if (result == null || !mounted) return;
    final formatted = '${result.year.toString().padLeft(4, '0')}-'
        '${result.month.toString().padLeft(2, '0')}-'
        '${result.day.toString().padLeft(2, '0')}';
    setState(() => _saving = true);
    try {
      await ApiClient.instance.dio.patch('/user/profile/birthday', data: {'birthday': formatted});
      ref.read(authProvider.notifier).refreshProfile();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.s.errorTryAgain)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tierAsync = ref.watch(tierProvider);
    final tier = tierAsync.valueOrNull;
    final isGoldPlus = tier?.tier == 'gold' || tier?.tier == 'platinum';

    return Container(
      decoration: BoxDecoration(
        color: context.col.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.shadowCard,
      ),
      child: GestureDetector(
        onTap: _birthday == null && !_saving ? _pickDate : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: context.col.surfaceSoft,
                borderRadius: BorderRadius.circular(9),
              ),
              child: _saving
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.cake_outlined, size: 17),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.s.birthdayLabel,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500)),
                  if (_birthday == null && isGoldPlus) ...[
                    const SizedBox(height: 2),
                    Text(context.s.birthdayRewardHint,
                      style: TextStyle(fontSize: 11, color: AppColors.gold)),
                  ],
                ],
              ),
            ),
            if (_birthday != null)
              Text(_formatBirthday(_birthday!),
                style: TextStyle(fontFamily: 'PlusJakartaSans',
                  fontSize: 13, fontWeight: FontWeight.w600, color: context.col.ink2))
            else
              Text(context.s.addBirthday,
                style: TextStyle(fontSize: 12, color: AppColors.primary,
                  fontWeight: FontWeight.w600, fontFamily: 'Cairo')),
            const SizedBox(width: 4),
            if (_birthday == null)
              Icon(Icons.arrow_forward_ios, size: 13, color: context.col.ink4),
          ]),
        ),
      ),
    );
  }
}

// ── Edit profile sheet ────────────────────────────────────────────────────────

class _EditProfileSheet extends StatefulWidget {
  final String currentName;
  final VoidCallback onSaved;
  const _EditProfileSheet({required this.currentName, required this.onSaved});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _nameCtrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _loading = true);
    try {
      await ApiClient.instance.dio.patch('/auth/profile', data: {'name': name});
      widget.onSaved();
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.s.profileUpdated), backgroundColor: AppColors.success));
      }
    } catch (_) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.s.errorTryAgain)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(width: 40, height: 4,
              decoration: BoxDecoration(
                color: context.col.border, borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 16),
          Text(context.s.editProfileTitle,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Text(context.s.nameLabel,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.col.ink1)),
          const SizedBox(height: 8),
          TextField(
            controller: _nameCtrl,
            textDirection: TextDirection.rtl,
            decoration: InputDecoration(
              hintText: context.s.fullNameHint,
              hintStyle: TextStyle(fontFamily: 'Cairo', color: context.col.ink3),
              filled: true,
              fillColor: context.col.bg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: context.col.border)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: context.col.border)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.primary, width: 2)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _loading ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.ink0,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _loading
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(context.s.saveChanges,
                    style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}
