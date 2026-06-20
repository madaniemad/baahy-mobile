import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:badges/badges.dart' as badges;
import 'package:sentry_flutter/sentry_flutter.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/notifications_provider.dart';
import '../providers/wishlist_provider.dart';
import '../providers/app_config_provider.dart';
import '../api/api_client.dart';
import '../../shared/theme/app_theme.dart';
import '../../core/utils/l10n.dart';
import '../../shared/widgets/offline_banner.dart';

class _AppLifecycleRefresh extends ConsumerStatefulWidget {
  const _AppLifecycleRefresh();
  @override
  ConsumerState<_AppLifecycleRefresh> createState() => _AppLifecycleRefreshState();
}
class _AppLifecycleRefreshState extends ConsumerState<_AppLifecycleRefresh>
    with WidgetsBindingObserver {
  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) ref.read(appConfigProvider.notifier).refresh();
    if (state == AppLifecycleState.paused) _syncCart();
  }

  Future<void> _syncCart() async {
    if (!ref.read(authProvider).isLoggedIn) return;
    try {
      final items = ref.read(cartProvider).items;
      final payload = items.map((i) => {
        'product_id':   i.productId,
        'variation_id': i.variationId,
        'quantity':     i.quantity,
      }).toList();
      await ApiClient.instance.dio.post('/cart/sync', data: {'items': payload});
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// Branch indices must match router.dart: 0=home 1=wishlist 2=browse 3=cart 4=account
typedef _Tab = ({IconData icon, String labelAr, String labelEn, int branchIdx});

const _Tab _tabHome     = (icon: Icons.home_outlined,          labelAr: 'الرئيسية', labelEn: 'Home',       branchIdx: 0);
const _Tab _tabWishlist = (icon: Icons.favorite_outline,       labelAr: 'المفضلة',  labelEn: 'Wishlist',   branchIdx: 1);
const _Tab _tabBrowse   = (icon: Icons.grid_view_outlined,      labelAr: 'الأقسام',  labelEn: 'Categories', branchIdx: 2);
const _Tab _tabCart     = (icon: Icons.shopping_cart_outlined, labelAr: 'السلة',    labelEn: 'Cart',       branchIdx: 3);
const _Tab _tabAccount  = (icon: Icons.person_outline,         labelAr: 'حسابي',    labelEn: 'Me',         branchIdx: 4);

const _tabs = [_tabHome, _tabWishlist, _tabBrowse, _tabCart, _tabAccount];

class MainShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  const MainShell({required this.navigationShell, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentBranch = navigationShell.currentIndex;
    const tabs = _tabs;
    final currentTabIdx = tabs.indexWhere((t) => t.branchIdx == currentBranch);

    final cartCount     = ref.watch(cartProvider.select((s) => s.count));
    final wishlistCount = ref.watch(wishlistProvider.select((s) => s.length));
    final unreadCount   = ref.watch(notificationsProvider.select(
        (list) => list.where((n) => !n.isRead).length));
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      body: Stack(children: [
        navigationShell,
        const Positioned(top: 0, left: 0, right: 0, child: OfflineBanner()),
        const _AppLifecycleRefresh(),
      ]),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: context.col.surface.withValues(alpha: 0.92),
          border: Border(top: BorderSide(color: context.col.border)),
          boxShadow: AppShadows.shadowPop,
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 56,
            child: Row(
              children: List.generate(tabs.length, (i) {
                final tab = tabs[i];
                final isActive = i == currentTabIdx;

                Widget icon = Icon(
                  tab.icon,
                  size: 24,
                  color: isActive ? AppColors.primary : context.col.ink3,
                );

                // Cart badge
                if (tab.branchIdx == 3 && cartCount > 0) {
                  icon = badges.Badge(
                    badgeContent: Text('$cartCount',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                    badgeStyle: const badges.BadgeStyle(badgeColor: AppColors.danger),
                    child: icon,
                  );
                }

                // Wishlist badge
                if (tab.branchIdx == 1 && wishlistCount > 0) {
                  icon = badges.Badge(
                    badgeContent: Text('$wishlistCount',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                    badgeStyle: const badges.BadgeStyle(badgeColor: AppColors.danger),
                    child: icon,
                  );
                }

                // Notifications badge on account
                if (tab.branchIdx == 4 && unreadCount > 0) {
                  icon = badges.Badge(
                    badgeContent: Text('$unreadCount',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                    badgeStyle: const badges.BadgeStyle(badgeColor: AppColors.danger),
                    child: icon,
                  );
                }

                return Expanded(
                  child: GestureDetector(
                    onTap: () => navigationShell.goBranch(
                      tab.branchIdx,
                      initialLocation: tab.branchIdx == currentBranch,
                    ),
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
                            color: isActive ? AppColors.primary : context.col.ink3,
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
