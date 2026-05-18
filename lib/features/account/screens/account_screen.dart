import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/wishlist_provider.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/app_button.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final isAr = context.isAr;

    if (!auth.isLoggedIn) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          title: const Text('حسابي', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
          backgroundColor: Colors.white, elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80, height: 80,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceSoft, shape: BoxShape.circle),
                  child: const Icon(Icons.person_outline, size: 44, color: AppColors.ink3),
                ),
                const SizedBox(height: 16),
                const Text('سجّل دخولك إلى باهي',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text('احفظ مفضلتك، تتبّع طلباتك، وزامن عبر الأجهزة.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: AppColors.ink2)),
                const SizedBox(height: 24),
                AppButton(label: 'تسجيل الدخول', onTap: () => context.push('/signin')),
              ],
            ),
          ),
        ),
      );
    }

    final user = auth.user!;
    final wishlistCount = ref.watch(wishlistProvider).length;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            pinned: true,
            title: const Text('حسابي',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
            centerTitle: true,
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Profile header
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                        child: Text(
                          user.name.isNotEmpty ? user.name[0] : 'U',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800,
                            color: AppColors.teal600),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('أهلاً بك،',
                              style: TextStyle(fontSize: 12, color: AppColors.ink3)),
                            Text(user.name,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.1)),
                            Row(children: [
                              Text(user.phone,
                                style: const TextStyle(fontFamily: 'PlusJakartaSans',
                                  fontSize: 12, color: AppColors.ink3)),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  const Icon(Icons.check, size: 8, color: AppColors.success),
                                  const SizedBox(width: 2),
                                  const Text('موثّق',
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                                      color: AppColors.success, letterSpacing: 0.3)),
                                ]),
                              ),
                            ]),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 3-column stat grid
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Row(
                    children: [
                      _StatTile(
                        value: '1',
                        label: 'نشط',
                        accent: true,
                        onTap: () => context.push('/orders'),
                      ),
                      const SizedBox(width: 8),
                      _StatTile(
                        value: '${user.loyaltyPoints > 0 ? user.loyaltyPoints : "—"}',
                        label: 'طلب',
                        onTap: () => context.push('/orders'),
                      ),
                      const SizedBox(width: 8),
                      _StatTile(
                        value: '$wishlistCount',
                        label: 'محفوظ',
                        onTap: () {},
                      ),
                    ],
                  ),
                ),

                // Wallet row
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: GestureDetector(
                    onTap: () => context.push('/wallet'),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: AppShadows.shadowCard,
                      ),
                      child: Row(children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.account_balance_wallet_outlined,
                            color: AppColors.teal600, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('محفظة باهي',
                            style: TextStyle(fontSize: 12, color: AppColors.ink2)),
                          Text('${user.walletBalance.toStringAsFixed(0)} د.ل',
                            style: const TextStyle(fontFamily: 'PlusJakartaSans',
                              fontSize: 18, fontWeight: FontWeight.w800)),
                        ]),
                        const Spacer(),
                        const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.ink3),
                      ]),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Menu group 1
                _MenuGroup([
                  _MenuRow(Icons.shopping_bag_outlined, 'طلباتي', () => context.push('/orders')),
                  _MenuRow(Icons.location_on_outlined, 'عناويني', () => context.push('/addresses')),
                  _MenuRow(Icons.assignment_return_outlined, 'الإرجاعات والاسترداد', () => context.push('/orders')),
                  _MenuRow(Icons.auto_awesome_outlined, 'ادعُ أصدقاءك · أعطِ 10، احصل 10', () => context.push('/referral')),
                ]),

                const SizedBox(height: 8),

                // Menu group 2
                _MenuGroup([
                  _MenuRow(Icons.notifications_outlined, 'الإشعارات', () => context.push('/notifications')),
                  _MenuRow(Icons.language_outlined, isAr ? 'English' : 'العربية', () {
                    ref.read(localeProvider.notifier).toggle();
                  }),
                  _MenuRow(Icons.settings_outlined, 'الإعدادات', () {}),
                ]),

                const SizedBox(height: 16),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: AppButton(
                    label: 'تسجيل الخروج',
                    variant: AppButtonVariant.outline,
                    onTap: () => ref.read(authProvider.notifier).logout(),
                  ),
                ),

                const SizedBox(height: 12),
                const Text('baahy v1.0 · 2026',
                  style: TextStyle(fontSize: 11, color: AppColors.ink4)),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String value;
  final String label;
  final bool accent;
  final VoidCallback onTap;
  const _StatTile({required this.value, required this.label,
    this.accent = false, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: accent ? const Color(0xFFE8F8F8) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: accent ? const Color(0xFFB2E4E6) : AppColors.border),
          boxShadow: accent ? null : AppShadows.shadowCard,
        ),
        child: Column(children: [
          Text(value, style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 26, fontWeight: FontWeight.w800,
            color: accent ? AppColors.teal600 : AppColors.ink0, height: 1)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(
            fontSize: 11.5,
            color: accent ? AppColors.teal600 : AppColors.ink2)),
        ]),
      ),
    ),
  );
}

class _MenuGroup extends StatelessWidget {
  final List<_MenuRow> rows;
  const _MenuGroup(this.rows);

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      children: [
        for (int i = 0; i < rows.length; i++) ...[
          rows[i],
          if (i < rows.length - 1)
            const Divider(height: 1, color: AppColors.border),
        ],
      ],
    ),
  );
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuRow(this.icon, this.label, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: AppColors.surfaceSoft,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 18, color: AppColors.ink2),
        ),
        const SizedBox(width: 14),
        Expanded(child: Text(label,
          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500))),
        const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.ink3),
      ]),
    ),
  );
}
