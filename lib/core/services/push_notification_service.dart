import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/api_client.dart';

// Top-level handler — must be a top-level function (not a closure or class method).
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialized when this runs.
  // No UI work here — just handle data if needed.
}

/// Where a notification leads. Shared by the push tap handler and the in-app notifications
/// list so both behave the same (audit 2026-10-19).
class NotificationTarget {
  NotificationTarget._();

  static String? _val(Map<String, dynamic> d, String k) {
    final v = d[k];
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  /// Staff alerts (`staff: "1"`) are for team members who also use the customer app. They open
  /// their admin `link` in the browser and never a customer screen.
  static bool isStaff(Map<String, dynamic> d) {
    final v = _val(d, 'staff');
    return v == '1' || v == 'true';
  }

  /// The absolute https link a push may carry (e.g. "choose how you want your refund" after an
  /// order edit). Anything that is not a plain web URL is ignored.
  static Uri? link(Map<String, dynamic> d) {
    final s = _val(d, 'link');
    if (s == null) return null;
    final u = Uri.tryParse(s);
    if (u == null || u.host.isEmpty || (u.scheme != 'https' && u.scheme != 'http')) return null;
    return u;
  }

  static bool isOrderType(String? t) =>
      t == 'order' || t == 'order_update' || t == 'order_items_unavailable';

  static bool isReturnType(String? t) => t != null && t.startsWith('return_');

  /// Order and return notifications lead to the order page. Order pushes carry the order in
  /// `order_id` (and `id`); on a return push `id` is the RETURN id, so only `order_id` is used —
  /// her return is shown on that order's page.
  static String? orderRoute(String? type, Map<String, dynamic> d) {
    if (isOrderType(type)) {
      final id = _val(d, 'order_id') ?? _val(d, 'id');
      return id != null ? '/orders/$id' : '/orders';
    }
    if (isReturnType(type)) {
      final oid = _val(d, 'order_id');
      return oid != null ? '/orders/$oid' : '/orders';
    }
    return null;
  }

  /// Types whose destination must be the same from a push and from the bell, checked by both
  /// before their own fallbacks (audit 2026-10-19). Null = not one of these types.
  static String? typedRoute(String? type, Map<String, dynamic> d) {
    switch (type) {
      // Cart / checkout abandonment reminders. abandoned_offer carries a coupon; the server has
      // never sent `abandoned_cart` (the bell looked for it), it sends cart_abandoned.
      case 'abandoned_offer':
      case 'abandoned_followup':
      case 'abandoned_cart':
      case 'cart_abandoned':
        return '/cart';
      // A section she has never bought from with many new arrivals: the newest first. Not
      // on_sale — the reason given is new arrivals, not discounts.
      case 'explore_categories':
        final cid = _val(d, 'category_id');
        return cid != null ? '/search/results?q=&category=$cid&sort=latest' : '/browse';
      // The driver could not reach her / she postponed: that order's page.
      case 'delivery_postponed':
      case 'delivery_attempt_failed':
        final oid = _val(d, 'order_id');
        return oid != null ? '/orders/$oid' : '/orders';
      // Wishlist alerts are about one product; the wishlist only when none is named.
      case 'wishlist_price_drop':
      case 'wishlist_back_in_stock':
      case 'wishlist_low_stock':
        final pid = _val(d, 'product_id');
        return pid != null ? '/product/$pid' : '/wishlist';
    }
    return null;
  }

  /// Opens [uri] in the browser. False when it could not be opened, so the caller can fall back.
  static Future<bool> openLink(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      return false;
    }
  }
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

  /// This phone's current FCM token, for sign-out to tell the server which token to drop.
  /// Quick and best-effort: never waits for APNs and gives up after a few seconds.
  Future<String?> currentTokenForSignOut() async {
    try {
      if (Platform.isIOS && await _fcm.getAPNSToken() == null) return null;
      return await _fcm.getToken().timeout(const Duration(seconds: 3));
    } catch (_) {
      return null;
    }
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
    // /device-token is authenticated, and this runs on every cold start — including for the
    // logged-out majority, where it can only ever 401. That was 68 of 87 calls in one day,
    // each one also minting a Sentry event for an outcome that is entirely expected. The
    // token is uploaded again right after a successful OTP verify, so nothing is lost by
    // waiting until there is someone to attach it to.
    if (!await ApiClient.instance.isLoggedIn) return;
    try {
      await ApiClient.instance.dio.post('/device-token', data: {
        'token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
      });
    } on DioException catch (e, st) {
      // A 401 here means the token expired between the check and the call — ordinary, not
      // worth an error report. Anything else is a genuine failure to register for push.
      if (e.response?.statusCode != 401) Sentry.captureException(e, stackTrace: st);
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
      payload: jsonEncode({
        'route': _routeFromData(message.data),
        'link': NotificationTarget.link(message.data)?.toString(),
        'log_id': message.data['log_id']?.toString(),
      }),
    );
  }

  void _onMessageOpened(RemoteMessage message) {
    _reportOpened(message.data['log_id']?.toString());
    _open(route: _routeFromData(message.data), link: NotificationTarget.link(message.data));
  }

  /// A push with a `link` opens it in the browser; otherwise (or if it cannot be opened) the
  /// in-app route. Staff alerts have no route, so they only ever open their link.
  Future<void> _open({String? route, Uri? link}) async {
    if (link != null && await NotificationTarget.openLink(link)) return;
    if (route != null && route.isNotEmpty && _router != null) {
      _router!.go(route);
    }
  }

  /// Tell the backend this notification was actually opened.
  ///
  /// Until 2026-08-16 nothing ever called this, so `notification_logs.opened_at`
  /// was NULL on every row and there was no way to tell a notification people
  /// want from one they ignore. Fire-and-forget: a failed report must never
  /// interrupt the navigation the user is expecting.
  Future<void> _reportOpened(String? logId) async {
    if (logId == null || logId.isEmpty) return;
    try {
      await ApiClient.instance.dio.patch('/notification-logs/$logId/opened');
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
    }
  }

  /// Local-notification taps carry a JSON payload so the log id survives
  /// alongside the route. Older builds wrote a bare route string, so anything
  /// that is not JSON is still treated as one.
  void _handlePayload(String? payload) {
    if (payload == null || payload.isEmpty) return;

    String? route = payload;
    Uri? link;
    if (payload.startsWith('{')) {
      try {
        final decoded = jsonDecode(payload) as Map<String, dynamic>;
        _reportOpened(decoded['log_id']?.toString());
        route = decoded['route'] as String?;
        link = NotificationTarget.link(decoded);
      } catch (_) {
        route = null;
      }
    }

    _open(route: route, link: link);
  }

  /// Maps FCM data payload to an app route.
  String? _routeFromData(Map<String, dynamic> data) {
    // Staff alerts: their admin link only, never a customer order screen.
    if (NotificationTarget.isStaff(data)) return null;
    final type = data['type']?.toString();
    // order / order_update / order_items_unavailable and return_* → the order page.
    final orderRoute = NotificationTarget.orderRoute(type, data);
    if (orderRoute != null) return orderRoute;
    // Abandonment, explore, delivery and wishlist types — same table as the bell.
    final typed = NotificationTarget.typedRoute(type, data);
    if (typed != null) return typed;
    final id = data['id']?.toString();
    switch (type) {
      case 'product':
        return id != null ? '/product/$id' : null;
      case 'wallet':
        return '/wallet';
      case 'promotion':
        return '/home';
      // Cart & checkout abandonment (cart_abandoned / abandoned_* are in typedRoute)
      case 'cart_low_stock':
      case 'cart_price_drop':
        return '/cart';
      case 'checkout_abandoned':
        return '/checkout';
      // Cash on delivery switched off for her account (a failed doorstep) or back on. The app
      // has no account/payment-info screen; checkout explains a block only once she is paying.
      // The bell is where the full message can be read, so that is where it opens.
      case 'cod_blocked':
      case 'cod_restored':
        return '/notifications';
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
        return '/rewards-hub';
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
      // Staff answered her "Need help?" request on an order (2026-10-18).
      // (delivery_attempt_failed / delivery_postponed are in typedRoute.)
      case 'help_request':
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
