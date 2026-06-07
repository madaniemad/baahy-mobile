import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../providers/auth_provider.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/city_screen.dart';
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/auth/screens/rewards_intro_screen.dart';
import '../../features/auth/screens/phone_signin_screen.dart';
import '../../features/auth/screens/otp_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/search/screens/search_screen.dart';
import '../../features/search/screens/search_results_screen.dart';
import '../../features/search/screens/browse_screen.dart';
import '../../features/product/screens/product_detail_screen.dart';
import '../../features/cart/screens/cart_screen.dart';
import '../../features/checkout/screens/checkout_screen.dart';
import '../../features/checkout/screens/order_confirmed_screen.dart';
import '../../features/orders/screens/orders_screen.dart';
import '../../features/orders/screens/order_tracking_screen.dart';
import '../../features/wishlist/screens/wishlist_screen.dart';
import '../../features/account/screens/account_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/address/screens/addresses_screen.dart';
import '../../features/address/screens/edit_address_screen.dart';
import '../../features/wallet/screens/wallet_screen.dart';
import '../../features/product/screens/reviews_screen.dart';
import '../../features/orders/screens/return_screen.dart';
import '../../features/referral/screens/referral_screen.dart';
import '../../features/account/screens/settings_screen.dart';
import '../../features/account/screens/policy_screen.dart';
import '../../features/account/screens/return_policy_screen.dart';
import '../../features/account/screens/faq_screen.dart';
import '../../features/account/screens/contact_screen.dart';
import '../../features/vendor/screens/vendor_store_screen.dart';
import '../../features/assistant/screens/assistant_screen.dart';
import '../../features/rewards/screens/rewards_hub_screen.dart';
import '../../features/friends/screens/friends_screen.dart';
import '../../features/friends/screens/user_search_screen.dart';
import '../../features/friends/screens/friend_profile_screen.dart';
import '../../features/friends/screens/qr_profile_screen.dart';
import '../../features/friends/screens/privacy_settings_screen.dart';
import '../../features/friends/screens/username_setup_screen.dart';
import '../shell/main_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/splash',
    // Handle deep links from baahy:// scheme and https://baahy.ly/
    redirect: (context, state) {
      final path = state.uri.path;
      const _socialPaths = ['/friends', '/settings/privacy', '/username-setup'];
      if (_socialPaths.any((p) => path == p || path.startsWith('$p/'))) {
        final isLoggedIn = ref.read(authProvider).isLoggedIn;
        if (!isLoggedIn) return '/signin';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash',   builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/city',          builder: (_, __) => const CityScreen()),
      GoRoute(path: '/rewards-intro', builder: (_, __) => const RewardsIntroScreen()),
      GoRoute(path: '/onboarding',    builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/signin',   builder: (_, __) => const PhoneSignInScreen()),
      GoRoute(path: '/otp', builder: (_, state) {
        final extra = state.extra;
        if (extra is Map<String, dynamic>) {
          return OtpScreen(
            phone: extra['phone'] as String,
            referralCode: extra['ref'] as String?,
          );
        }
        return OtpScreen(phone: extra as String);
      }),

      // Main shell (tab bar) — StatefulShellRoute keeps each tab alive in memory
      // so switching tabs never triggers a rebuild of heavy screens (e.g. home).
      // Branch order: home=0, browse=1, assistant=2, wishlist=3, cart=4, account=5
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/home',      builder: (_, __) => const HomeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/browse',    builder: (_, state) => BrowseScreen(deepCategoryId: int.tryParse(state.uri.queryParameters['categoryId'] ?? '')))]),
          StatefulShellBranch(routes: [GoRoute(path: '/assistant', builder: (_, __) => const AssistantScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/wishlist',  builder: (_, __) => const WishlistScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/cart',      builder: (_, __) => const CartScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/account',   builder: (_, __) => const AccountScreen())]),
        ],
      ),

      // Stack screens (no tab bar)
      GoRoute(path: '/search',     builder: (_, __) => const SearchScreen()),
      GoRoute(path: '/search/results', builder: (_, state) =>
          SearchResultsScreen(
            query: state.uri.queryParameters['q'] ?? '',
            categoryId: state.uri.queryParameters['category'] != null
                ? int.tryParse(state.uri.queryParameters['category']!)
                : null,
            onSale: state.uri.queryParameters['on_sale'] == '1',
            maxPrice: state.uri.queryParameters['max_price'] != null
                ? double.tryParse(state.uri.queryParameters['max_price']!)
                : null,
            initialSort: state.uri.queryParameters['sort'],
          )),
      GoRoute(path: '/product/:id', builder: (_, state) =>
          ProductDetailScreen(id: int.parse(state.pathParameters['id']!))),
      GoRoute(path: '/product/:id/reviews', builder: (_, state) =>
          ReviewsScreen(productId: int.parse(state.pathParameters['id']!))),
      GoRoute(path: '/checkout',   builder: (_, __) => const CheckoutScreen()),
      GoRoute(path: '/order-confirmed', builder: (_, state) =>
          OrderConfirmedScreen(data: state.extra as Map<String, dynamic>)),
      GoRoute(path: '/orders',     builder: (_, __) => const OrdersScreen()),
      GoRoute(path: '/orders/:id', builder: (_, state) =>
          OrderTrackingScreen(id: int.parse(state.pathParameters['id']!))),
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
      GoRoute(path: '/addresses',  builder: (_, __) => const AddressesScreen()),
      GoRoute(path: '/addresses/edit', builder: (_, state) =>
          EditAddressScreen(address: state.extra as Map<String, dynamic>?)),
      GoRoute(path: '/wallet',     builder: (_, __) => const WalletScreen()),
      GoRoute(path: '/orders/:id/return', builder: (_, state) =>
          ReturnScreen(orderId: int.parse(state.pathParameters['id']!))),
      GoRoute(path: '/referral',      builder: (_, __) => const ReferralScreen()),
      GoRoute(path: '/rewards-hub',   builder: (_, __) => const RewardsHubScreen()),
      GoRoute(path: '/settings',      builder: (_, __) => const SettingsScreen()),
      GoRoute(path: '/return-policy', builder: (_, __) => const ReturnPolicyScreen()),
      GoRoute(path: '/privacy',       builder: (_, __) => const PolicyScreen(type: PolicyType.privacy)),
      GoRoute(path: '/terms',         builder: (_, __) => const PolicyScreen(type: PolicyType.terms)),
      GoRoute(path: '/faq',           builder: (_, __) => const FaqScreen()),
      GoRoute(path: '/contact',       builder: (_, __) => const ContactScreen()),
      GoRoute(path: '/vendors/:id', builder: (_, state) =>
        VendorStoreScreen(vendorId: int.parse(state.pathParameters['id']!))),

      // Friends
      GoRoute(path: '/friends',        builder: (_, __) => const FriendsScreen()),
      GoRoute(path: '/friends/search', builder: (_, __) => const UserSearchScreen()),
      GoRoute(path: '/friends/qr',     builder: (_, __) => const QrProfileScreen()),
      GoRoute(path: '/friends/:username', builder: (_, state) =>
          FriendProfileScreen(username: state.pathParameters['username']!)),
      GoRoute(path: '/settings/privacy', builder: (_, __) => const PrivacySettingsScreen()),
      GoRoute(path: '/username-setup',   builder: (_, __) => const UsernameSetupScreen()),
    ],
  );

  // Redirect to sign-in whenever the API returns 401 (token expired/revoked).
  ApiClient.setUnauthorizedCallback(() => router.go('/signin'));

  return router;
});
