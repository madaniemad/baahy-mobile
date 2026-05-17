import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/city_screen.dart';
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
import '../shell/main_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash',   builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/city',     builder: (_, __) => const CityScreen()),
      GoRoute(path: '/signin',   builder: (_, __) => const PhoneSignInScreen()),
      GoRoute(path: '/otp',      builder: (_, state) => OtpScreen(phone: state.extra as String)),

      // Main shell (tab bar)
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/home',       builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/wishlist',   builder: (_, __) => const WishlistScreen()),
          GoRoute(path: '/browse',     builder: (_, __) => const BrowseScreen()),
          GoRoute(path: '/cart',       builder: (_, __) => const CartScreen()),
          GoRoute(path: '/account',    builder: (_, __) => const AccountScreen()),
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
          )),
      GoRoute(path: '/product/:id', builder: (_, state) =>
          ProductDetailScreen(id: int.parse(state.pathParameters['id']!))),
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
    ],
  );
});
