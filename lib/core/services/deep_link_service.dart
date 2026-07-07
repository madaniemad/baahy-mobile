import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';

const _kPendingReferralCode = 'pending_referral_code';

class DeepLinkService {
  static final DeepLinkService instance = DeepLinkService._();
  DeepLinkService._();

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  ProviderContainer? _container;

  // Broadcast stream for PayPal payment return token
  final _paypalController = StreamController<String>.broadcast();
  Stream<String> get paypalReturnStream => _paypalController.stream;

  // Broadcast streams for Tadawel and Moamlat order returns
  final _tadawelController = StreamController<String>.broadcast();
  Stream<String> get tadawelReturnStream => _tadawelController.stream;

  final _moamlatController = StreamController<String>.broadcast();
  Stream<String> get moamlatReturnStream => _moamlatController.stream;

  void setContainer(ProviderContainer container) {
    _container = container;
  }

  bool get _isLoggedIn => _container?.read(authProvider).isLoggedIn ?? false;

  Future<void> init() async {
    // Cold start: app was launched by tapping a link
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) await _handleUri(initial);
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
    }

    // Warm start: link tapped while app is already running
    _sub = _appLinks.uriLinkStream.listen(
      (uri) => _handleUri(uri),
      onError: (_) {},
    );
  }

  void dispose() {
    _sub?.cancel();
    _paypalController.close();
    _tadawelController.close();
    _moamlatController.close();
  }

  Future<void> _handleUri(Uri uri) async {
    // PayPal return: baahy://paypal/return?token=PAYPAL_ORDER_ID
    if (uri.scheme == 'baahy' && uri.host == 'paypal' &&
        uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'return') {
      final token = uri.queryParameters['token'];
      if (token != null && token.isNotEmpty) {
        _paypalController.add(token);
      }
      return;
    }

    // Tadawel return: baahy://payment/tadawel/return?ref=UUID
    if (uri.scheme == 'baahy' && uri.host == 'payment' &&
        uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'tadawel' &&
        uri.pathSegments[1] == 'return') {
      final ref = uri.queryParameters['ref'] ?? uri.queryParameters['order'];
      if (ref != null && ref.isNotEmpty) {
        _tadawelController.add(ref);
      }
      return;
    }

    // Moamlat return: baahy://payment/moamlat/return?ref=UUID
    if (uri.scheme == 'baahy' && uri.host == 'payment' &&
        uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'moamlat' &&
        uri.pathSegments[1] == 'return') {
      final ref = uri.queryParameters['ref'] ?? uri.queryParameters['order'];
      if (ref != null && ref.isNotEmpty) {
        _moamlatController.add(ref);
      }
      return;
    }

    final code = _extractReferralCode(uri);
    if (code != null && code.isNotEmpty) {
      // Don't store the code if user is already signed in — they can't use it anyway
      if (_isLoggedIn) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPendingReferralCode, code);
    }
  }

  String? _extractReferralCode(Uri uri) {
    // Custom scheme: baahy://invite/CODE
    if (uri.scheme == 'baahy' && uri.host == 'invite') {
      return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    }
    // Universal link: https://baahy.com/invite/CODE or the Next.js host
    if ((uri.host == 'baahy.com' || uri.host == 'www.baahy.com' || uri.host == 'baahy-web.vercel.app')
        && uri.pathSegments.length >= 2) {
      if (uri.pathSegments[0] == 'invite') return uri.pathSegments[1];
    }
    // Query param fallback: ?ref=CODE
    final ref = uri.queryParameters['ref'];
    if (ref != null && ref.isNotEmpty) return ref;
    return null;
  }

  /// Read and clear the pending referral code (call after successful sign-up).
  static Future<String?> consumePendingCode() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_kPendingReferralCode);
    if (code != null) await prefs.remove(_kPendingReferralCode);
    return code;
  }

  /// Read without clearing (call in sign-in screen to pre-fill the field).
  static Future<String?> peekPendingCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kPendingReferralCode);
  }
}
