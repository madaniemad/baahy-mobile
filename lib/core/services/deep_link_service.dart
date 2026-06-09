import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';

const _kPendingReferralCode = 'pending_referral_code';

class DeepLinkService {
  static final DeepLinkService instance = DeepLinkService._();
  DeepLinkService._();

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  ProviderContainer? _container;

  void setContainer(ProviderContainer container) {
    _container = container;
  }

  bool get _isLoggedIn => _container?.read(authProvider).isLoggedIn ?? false;

  Future<void> init() async {
    // Cold start: app was launched by tapping a link
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) await _handleUri(initial);
    } catch (_) {}

    // Warm start: link tapped while app is already running
    _sub = _appLinks.uriLinkStream.listen(
      (uri) => _handleUri(uri),
      onError: (_) {},
    );
  }

  void dispose() {
    _sub?.cancel();
  }

  Future<void> _handleUri(Uri uri) async {
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
    // Universal link: https://baahy-web.vercel.app/invite/CODE
    if (uri.host == 'baahy-web.vercel.app' && uri.pathSegments.length >= 2) {
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
