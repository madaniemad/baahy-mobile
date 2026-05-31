import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:badges/badges.dart' as badges;
import '../providers/cart_provider.dart';
import '../providers/notifications_provider.dart';
import '../providers/wishlist_provider.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/offline_banner.dart';

class MainShell extends ConsumerWidget {
  final Widget child;
  const MainShell({required this.child, super.key});

  static const _tabs = [
    (path: '/home',     icon: Icons.home_outlined,           labelAr: 'الرئيسية', labelEn: 'Home'),
    (path: '/wishlist', icon: Icons.favorite_outline,        labelAr: 'المفضلة',  labelEn: 'Wishlist'),
    (path: '/browse',   icon: Icons.grid_view_outlined,      labelAr: 'الأقسام',  labelEn: 'Categories'),
    (path: '/cart',     icon: Icons.shopping_cart_outlined,  labelAr: 'السلة',    labelEn: 'Cart'),
    (path: '/account',  icon: Icons.person_outline,          labelAr: 'حسابي',    labelEn: 'Me'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    final currentIdx = _tabs.indexWhere((t) => location.startsWith(t.path));
    // select() — rebuild tab bar ONLY when count changes, not on every cart mutation
    final cartCount = ref.watch(cartProvider.select((s) => s.count));
    final wishlistCount = ref.watch(wishlistProvider.select((s) => s.length));
    final unreadCount = ref.watch(notificationsProvider.select(
        (list) => list.where((n) => !n.isRead).length));
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      body: Stack(children: [
        child,
        const Positioned(top: 0, left: 0, right: 0, child: OfflineBanner()),
      ]),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          border: const Border(top: BorderSide(color: AppColors.border)),
          boxShadow: AppShadows.shadowPop,
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 56,
            child: Row(
              children: List.generate(_tabs.length, (i) {
                final tab = _tabs[i];
                final isActive = i == currentIdx;
                Widget icon = Icon(
                  tab.icon,
                  size: 24,
                  color: isActive ? AppColors.primary : AppColors.ink3,
                );

                // Cart badge
                if (tab.path == '/cart' && cartCount > 0) {
                  icon = badges.Badge(
                    badgeContent: Text('$cartCount',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                    badgeStyle: const badges.BadgeStyle(badgeColor: AppColors.danger),
                    child: icon,
                  );
                }

                // Wishlist badge
                if (tab.path == '/wishlist' && wishlistCount > 0) {
                  icon = badges.Badge(
                    badgeContent: Text('$wishlistCount',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                    badgeStyle: const badges.BadgeStyle(badgeColor: AppColors.danger),
                    child: icon,
                  );
                }

                // Notifications badge
                if (tab.path == '/account' && unreadCount > 0) {
                  icon = badges.Badge(
                    badgeContent: Text('$unreadCount',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                    badgeStyle: const badges.BadgeStyle(badgeColor: AppColors.danger),
                    child: icon,
                  );
                }

                return Expanded(
                  child: GestureDetector(
                    onTap: () => context.go(tab.path),
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        icon,
                        const SizedBox(height: 2),
                        Text(
                          isAr ? tab.labelAr : tab.labelEn,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isActive ? AppColors.primary : AppColors.ink3,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
