import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
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
                  decoration: BoxDecoration(color: AppColors.bg, shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border, width: 2)),
                  child: const Icon(Icons.person_outline, size: 44, color: AppColors.ink3),
                ),
                const SizedBox(height: 16),
                const Text('سجّل دخولك',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text('للوصول إلى طلباتك، محفظتك، وعروضك',
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
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                        child: Text(
                          user.name.isNotEmpty ? user.name[0] : 'U',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800,
                            color: AppColors.primary),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.name,
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                            Text(user.phone,
                              style: const TextStyle(fontFamily: 'PlusJakartaSans',
                                fontSize: 14, color: AppColors.ink2)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Wallet + loyalty
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(child: _StatCard(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'المحفظة',
                        value: '${user.walletBalance.toStringAsFixed(0)} د.ل',
                        onTap: () => context.push('/wallet'),
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _StatCard(
                        icon: Icons.stars_outlined,
                        label: 'النقاط',
                        value: '${user.loyaltyPoints}',
                        onTap: () {},
                      )),
                    ],
                  ),
                ),

                // Menu items
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppShadows.shadowCard,
                  ),
                  child: Column(
                    children: [
                      _MenuItem(Icons.shopping_bag_outlined, 'طلباتي', () => context.push('/orders')),
                      _Divider(),
                      _MenuItem(Icons.location_on_outlined, 'عناويني', () => context.push('/addresses')),
                      _Divider(),
                      _MenuItem(Icons.assignment_return_outlined, 'إرجاع منتج', () => context.push('/orders')),
                      _Divider(),
                      _MenuItem(Icons.card_giftcard_outlined, 'ادعُ أصدقاءك واكسب', () => context.push('/referral')),
                      _Divider(),
                      _MenuItem(Icons.notifications_outlined, 'الإشعارات', () => context.push('/notifications')),
                      _Divider(),
                      _MenuItem(Icons.language_outlined, isAr ? 'English' : 'العربية', () {
                        ref.read(localeProvider.notifier).toggle();
                      }),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: AppButton(
                    label: 'تسجيل الخروج',
                    variant: AppButtonVariant.outline,
                    onTap: () => ref.read(authProvider.notifier).logout(),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _StatCard({
    required this.icon, required this.label,
    required this.value, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppShadows.shadowCard,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: AppColors.ink2)),
              Text(value, style: const TextStyle(fontFamily: 'PlusJakartaSans',
                fontSize: 15, fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    ),
  );
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuItem(this.icon, this.label, this.onTap);

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: AppColors.ink1, size: 22),
    title: Text(label, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
    trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.ink3),
    onTap: onTap,
  );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
    const Divider(height: 1, indent: 56, color: AppColors.border);
}
