import 'dart:convert';
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

/// Unified analytics facade. Fires the standard e-commerce funnel to BOTH Firebase
/// Analytics (→ GA4 + Google Ads app campaigns) and Meta app events (→ Facebook/Instagram
/// ad campaigns + the same pixel 351917185901752 the web and server-side CAPI use).
/// The call sites throughout the app stay the same, so this is the single place tracking
/// is maintained. (TikTok deferred — not targetable in Libya.)
class Analytics {
  Analytics._();
  static final Analytics instance = Analytics._();

  final FirebaseAnalytics _fa = FirebaseAnalytics.instance;
  final FacebookAppEvents _fb = FacebookAppEvents();

  bool _trackingInitialized = false;

  /// Attach to GoRouter `observers:` for automatic screen_view tracking.
  static FirebaseAnalyticsObserver observer() =>
      FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance);

  /// Ask for iOS App Tracking Transparency once, then tell the Meta SDK whether it may
  /// use the advertiser ID. On Android tracking is allowed by default (AD_ID permission).
  /// Safe to call multiple times — only prompts once per launch.
  Future<void> initTracking() async {
    if (_trackingInitialized) return;
    _trackingInitialized = true;
    try {
      if (Platform.isIOS) {
        var status = await AppTrackingTransparency.trackingAuthorizationStatus;
        if (status == TrackingStatus.notDetermined) {
          // Let the first frame settle so the system prompt lands on top of live UI.
          await Future.delayed(const Duration(milliseconds: 400));
          status = await AppTrackingTransparency.requestTrackingAuthorization();
        }
        final granted = status == TrackingStatus.authorized;
        await _fb.setAdvertiserTracking(enabled: granted, collectId: granted);
      } else {
        await _fb.setAdvertiserTracking(enabled: true, collectId: true);
      }
    } catch (_) {}
  }

  Future<void> _safe(Future<void> Function() f) async {
    try {
      await f();
    } catch (_) {}
  }

  Future<void> viewItem({required String id, required String name, double? price, String? category}) =>
      _safe(() async {
        await _fa.logViewItem(
          currency: 'LYD',
          value: price,
          items: [AnalyticsEventItem(itemId: id, itemName: name, itemCategory: category, price: price)],
        );
        await _fb.logViewContent(id: id, type: 'product', currency: 'LYD', price: price);
      });

  Future<void> addToCart({required String id, required String name, double? price, int quantity = 1}) =>
      _safe(() async {
        final value = (price ?? 0) * quantity;
        await _fa.logAddToCart(
          currency: 'LYD',
          value: value,
          items: [AnalyticsEventItem(itemId: id, itemName: name, price: price, quantity: quantity)],
        );
        // `price` here is the unit price — Meta's AddToCart takes the item price,
        // and the line total was being sent instead, inflating basket values.
        await _fb.logAddToCart(id: id, type: 'product', currency: 'LYD', price: price ?? value);
      });

  Future<void> beginCheckout({double? total, int itemCount = 0}) => _safe(() async {
        await _fa.logBeginCheckout(currency: 'LYD', value: total, parameters: {'item_count': itemCount});
        await _fb.logInitiatedCheckout(totalPrice: total, currency: 'LYD', numItems: itemCount);
      });

  /// Purchase.
  ///
  /// [contentIds] must be the live product IDs, and they matter: without them the
  /// catalog has nothing to match a purchase against, which is why the app event
  /// source reported 0 matched Purchase content IDs on all 28 days audited.
  /// `logPurchase` has no id argument, so they travel in `parameters`.
  /// See Marketing/research/tracking-audit.md §3.
  Future<void> purchase({
    required String orderId,
    required double total,
    List<String> contentIds = const [],
    int numItems = 0,
  }) =>
      _safe(() async {
        await _fa.logPurchase(
          currency: 'LYD',
          value: total,
          transactionId: orderId,
          items: contentIds.map((id) => AnalyticsEventItem(itemId: id)).toList(),
        );
        await _fb.logPurchase(
          amount: total,
          currency: 'LYD',
          parameters: {
            'fb_order_id': orderId,
            if (contentIds.isNotEmpty) ...{
              'fb_content_type': 'product',
              'fb_content_id': jsonEncode(contentIds),
            },
            if (numItems > 0) 'fb_num_items': numItems,
          },
        );
      });

  Future<void> signUp() => _safe(() async {
        await _fa.logSignUp(signUpMethod: 'phone');
        await _fb.logCompletedRegistration(registrationMethod: 'phone');
      });

  Future<void> search(String query) => _safe(() async {
        await _fa.logSearch(searchTerm: query);
        await _fb.logEvent(name: 'fb_mobile_search', parameters: {'fb_search_string': query});
      });

  Future<void> logEvent(String name, [Map<String, Object>? params]) =>
      _safe(() => _fa.logEvent(name: name, parameters: params));
}
