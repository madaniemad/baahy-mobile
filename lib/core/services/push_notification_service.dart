import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../api/api_client.dart';

// Top-level handler — must be a top-level function (not a closure or class method).
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialized when this runs.
  // No UI work here — just handle data if needed.
}

class PushNotificationService {
  static PushNotificationService? _instance;
  static PushNotificationService get instance =>
      _instance ??= PushNotificationService._();
  PushNotificationService._();

  final _fcm = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();
  GoRouter? _router;

  static const _androidChannel = AndroidNotificationChannel(
    'baahy_high',
    'Baahy Notifications',
    description: 'Order updates and promotions',
    importance: Importance.high,
  );

  Future<void> init(GoRouter router) async {
    _router = router;

    // Register background handler.
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    // Android: create notification channel.
    if (Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_androidChannel);
    }

    // Initialize local notifications.
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: (details) {
        _handlePayload(details.payload);
      },
    );

    // Permission is NOT requested on cold launch — call requestPermissionIfNeeded()
    // after the user completes onboarding or performs their first meaningful action.
    await _uploadTokenIfPermitted();

    // Refresh token when it rotates.
    _fcm.onTokenRefresh.listen(_sendTokenToServer);

    // Foreground messages: show local notification.
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // App opened from notification (background → foreground).
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);

    // App launched from terminated state via notification.
    final initial = await _fcm.getInitialMessage();
    if (initial != null) _onMessageOpened(initial);

    // iOS: show notifications while app is in foreground.
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true, badge: true, sound: true);
  }

  // Called on cold launch — only uploads token if permission already granted.
  Future<void> _uploadTokenIfPermitted() async {
    try {
      final settings = await _fcm.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        final token = await _getFcmToken();
        if (token != null) await _sendTokenToServer(token);
      }
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
    }
  }

  // Call this after onboarding completes or after first order/login.
  //
  // Returns the resulting authorization status so the UI can react — in
  // particular, when it comes back `denied`, iOS will NOT show the system
  // dialog again (a denial is permanent until the user flips it in Settings),
  // so the caller should send them to Settings rather than appear to do nothing.
  // `null` means the request failed (e.g. Firebase/APNs unavailable on the
  // simulator).
  Future<AuthorizationStatus?> requestPermissionIfNeeded() async {
    try {
      final current = await _fcm.getNotificationSettings();
      if (current.authorizationStatus == AuthorizationStatus.authorized ||
          current.authorizationStatus == AuthorizationStatus.provisional) {
        await _uploadToken();
        return current.authorizationStatus;
      }
      // Already denied — iOS won't re-prompt; the caller opens Settings.
      if (current.authorizationStatus == AuthorizationStatus.denied) {
        return AuthorizationStatus.denied;
      }
      // notDetermined -> this shows the system dialog.
      final settings = await _fcm.requestPermission(
        alert: true, badge: true, sound: true, provisional: false);
      if (settings.authorizationStatus != AuthorizationStatus.denied) {
        await _uploadToken();
      }
      return settings.authorizationStatus;
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      return null;
    }
  }

  /// Fetch the FCM token. On iOS, `getToken()` returns null until the OS has
  /// delivered the APNs token to the app — on a cold start that can take a few
  /// seconds — so poll `getAPNSToken()` first (with a short backoff) before
  /// asking for the FCM token. Without this, the very first `getToken()` call
  /// returns null and the device never registers. Android has no such gate.
  Future<String?> _getFcmToken() async {
    if (Platform.isIOS) {
      String? apns;
      for (var i = 0; i < 15 && apns == null; i++) {
        apns = await _fcm.getAPNSToken();
        if (apns == null) await Future.delayed(const Duration(seconds: 1));
      }
      if (apns == null) {
        // APNs never became available — surface it so we can see the failure.
        Sentry.captureMessage('APNs token not available after wait; FCM token skipped');
        return null;
      }
    }
    return _fcm.getToken();
  }

  Future<void> _uploadToken() async {
    try {
      final token = await _getFcmToken();
      if (token != null) await _sendTokenToServer(token);
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
    }
  }

  Future<void> _sendTokenToServer(String token) async {
    try {
      await ApiClient.instance.dio.post('/device-token', data: {
        'token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
      });
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    // On iOS the system itself presents the notification while the app is in the
    // foreground (setForegroundNotificationPresentationOptions(alert:true)), so
    // showing our own local copy here would double it. Android suppresses
    // foreground FCM notifications, so there we DO need to show it manually.
    if (Platform.isIOS) return;
    final notification = message.notification;
    if (notification == null) return;
    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true, presentBadge: true, presentSound: true),
      ),
      payload: _routeFromData(message.data),
    );
  }

  void _onMessageOpened(RemoteMessage message) {
    final route = _routeFromData(message.data);
    if (route != null && _router != null) {
      _router!.go(route);
    }
  }

  void _handlePayload(String? payload) {
    if (payload != null && _router != null) {
      _router!.go(payload);
    }
  }

  /// Maps FCM data payload to an app route.
  String? _routeFromData(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final id = data['id']?.toString();
    switch (type) {
      case 'order':
      case 'order_update':
        return id != null ? '/orders/$id' : '/orders';
      case 'product':
        return id != null ? '/product/$id' : null;
      case 'wallet':
        return '/wallet';
      case 'promotion':
        return '/home';
      // Cart & checkout abandonment
      case 'cart_abandoned':
      case 'cart_low_stock':
      case 'cart_price_drop':
        return '/cart';
      case 'checkout_abandoned':
        return '/checkout';
      // Wishlist
      case 'wishlist_price_drop':
      case 'wishlist_back_in_stock':
      case 'wishlist_low_stock':
        return '/wishlist';
      // Re-engagement
      case 'reengagement_7d':
      case 'reengagement_21d':
      case 'reengagement_45d':
      case 'lapsed_buyer_30d':
      case 'lapsed_buyer_60d':
      case 'lapsed_buyer_90d':
      case 'new_arrivals_affinity':
        return '/home';
      // Loyalty / rewards
      case 'tier_upgrade_close':
      case 'referral_reminder':
      case 'referral_reward_earned':
      case 'friend_joined':
        return '/rewards';
      case 'wallet_unused':
        return '/wallet';
      // Product-specific
      case 'reorder_suggestion':
      case 'review_reminder':
      case 'price_watch_triggered':
        final pid = data['product_id']?.toString();
        return pid != null ? '/product/$pid' : '/home';
      // Vendor
      case 'favourite_vendor_sale':
      case 'favourite_vendor_new_arrivals':
        final vid = data['vendor_id']?.toString();
        return vid != null ? '/vendors/$vid' : '/home';
      // Delivery
      case 'delivery_attempt_failed':
        final oid = data['order_id']?.toString();
        return oid != null ? '/orders/$oid' : '/orders';
      // Deal of the day → open the featured product (backend sends product_id)
      case 'deal_of_the_day':
        final pid = data['product_id']?.toString();
        return (pid != null && pid.isNotEmpty) ? '/product/$pid' : '/home';
      // Brand deal / spotlight → the brand's listing. brand_all marks a spotlight,
      // i.e. a brand with a deep catalogue but NO discounts (Tefal: 210 in-stock
      // items, zero sale prices), so filtering it to on_sale would open an empty
      // listing. Without these cases both fell through to `default` and a brand
      // push landed back on the notifications list (2026-08-14).
      case 'brand_deals':
      case 'brand_spotlight':
        final brand = data['brand']?.toString();
        if (brand == null || brand.isEmpty) return '/home';
        final onSale = (data['brand_all']?.toString() ?? '').isEmpty;
        return '/search/results?q=&brand=${Uri.encodeComponent(brand)}'
            '${onSale ? '&on_sale=1' : ''}';
      // Category deals now carry the category the customer actually buys from.
      case 'deals_in_your_categories':
        final cid = data['category_id']?.toString();
        return (cid != null && cid.isNotEmpty)
            ? '/search/results?q=&category=$cid&on_sale=1'
            : '/home';
      // Generic engagement pushes → home
      case 'trending_this_week':
      case 'order_cross_sell':
        return '/home';
      default:
        return '/notifications';
    }
  }
}
