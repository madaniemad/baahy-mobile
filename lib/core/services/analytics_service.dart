import 'package:firebase_analytics/firebase_analytics.dart';

/// Unified analytics facade. Fires the standard e-commerce funnel to Firebase Analytics
/// now (→ GA4 + Google Ads app campaigns). Meta (facebook_app_events) and TikTok Business
/// SDK calls will be added inside each method once those SDKs are wired — the call sites
/// throughout the app stay the same, so this is the single place tracking is maintained.
class Analytics {
  Analytics._();
  static final Analytics instance = Analytics._();

  final FirebaseAnalytics _fa = FirebaseAnalytics.instance;

  /// Attach to GoRouter `observers:` for automatic screen_view tracking.
  static FirebaseAnalyticsObserver observer() =>
      FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance);

  Future<void> _safe(Future<void> Function() f) async {
    try { await f(); } catch (_) {}
  }

  Future<void> viewItem({required String id, required String name, double? price, String? category}) =>
      _safe(() => _fa.logViewItem(
            currency: 'LYD',
            value: price,
            items: [AnalyticsEventItem(itemId: id, itemName: name, itemCategory: category, price: price)],
          ));

  Future<void> addToCart({required String id, required String name, double? price, int quantity = 1}) =>
      _safe(() => _fa.logAddToCart(
            currency: 'LYD',
            value: (price ?? 0) * quantity,
            items: [AnalyticsEventItem(itemId: id, itemName: name, price: price, quantity: quantity)],
          ));

  Future<void> beginCheckout({double? total, int itemCount = 0}) =>
      _safe(() => _fa.logBeginCheckout(
            currency: 'LYD',
            value: total,
            parameters: {'item_count': itemCount},
          ));

  Future<void> purchase({required String orderId, required double total}) =>
      _safe(() => _fa.logPurchase(currency: 'LYD', value: total, transactionId: orderId));

  Future<void> signUp() => _safe(() => _fa.logSignUp(signUpMethod: 'phone'));

  Future<void> search(String query) => _safe(() => _fa.logSearch(searchTerm: query));

  Future<void> logEvent(String name, [Map<String, Object>? params]) =>
      _safe(() => _fa.logEvent(name: name, parameters: params));
}
