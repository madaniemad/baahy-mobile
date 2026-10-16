import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';

/// A gateway payment that has started but whose outcome the app has not seen yet.
class PendingCheckout {
  final String ref;
  final String method;
  /// False for a reorder session, which never touched the cart.
  final bool clearCart;
  final DateTime startedAt;
  const PendingCheckout({
    required this.ref,
    required this.method,
    required this.clearCart,
    required this.startedAt,
  });
}

/// What the server said about a pending checkout.
enum PendingOutcome { completed, review, failed, pending, unknown }

class PendingStatus {
  final PendingOutcome outcome;
  final Map<String, dynamic> data;
  const PendingStatus(this.outcome, [this.data = const {}]);

  dynamic get orderId => data['order_id'];
  String get orderNumber => data['order_number']?.toString() ?? '';
  String? get message => data['message']?.toString();
}

/// Remembers the pending checkout reference of a card/wallet-gateway payment on disk, so a
/// payment interrupted by the app being killed, backgrounded or the webview being closed is
/// still followed to its end (order created, under review, or failed) instead of leaving the
/// customer to pay a second time.
class PendingCheckoutService {
  PendingCheckoutService._();
  static final instance = PendingCheckoutService._();

  static const _key = 'baahy_pending_checkout';

  /// A pending checkout lives 30 minutes server-side and its result a few hours; past this the
  /// status endpoint can only answer "expired", so the record is dropped unread.
  static const _maxAge = Duration(hours: 6);

  /// True while the checkout screen is itself following a payment (webview open, OTP sheet,
  /// polling). The app-resume check stays out of its way so the outcome is handled once.
  bool handledOnScreen = false;

  Future<void> save(String ref, String method, {bool clearCart = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key,
        jsonEncode({
          'ref': ref,
          'method': method,
          'clear_cart': clearCart,
          'started_at': DateTime.now().toIso8601String(),
        }));
  }

  Future<PendingCheckout?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final p = PendingCheckout(
        ref: j['ref'] as String,
        method: j['method'] as String? ?? '',
        clearCart: j['clear_cart'] != false,
        startedAt: DateTime.tryParse(j['started_at'] as String? ?? '') ?? DateTime.now(),
      );
      if (DateTime.now().difference(p.startedAt) > _maxAge) {
        await prefs.remove(_key);
        return null;
      }
      return p;
    } catch (_) {
      await prefs.remove(_key);
      return null;
    }
  }

  /// Forget the stored checkout — only [ref]'s, when given, so finishing an old one never
  /// erases a newer payment.
  Future<void> clear([String? ref]) async {
    final prefs = await SharedPreferences.getInstance();
    if (ref != null) {
      final current = await load();
      if (current != null && current.ref != ref) return;
    }
    await prefs.remove(_key);
  }

  /// One look at GET /payment/pending-status/{ref}. [PendingOutcome.unknown] = no answer
  /// (offline, timeout, 5xx) — never read that as failed.
  Future<PendingStatus> fetchStatus(String ref) async {
    try {
      final r = await ApiClient.instance.dio.get('/payment/pending-status/$ref',
          options: Options(extra: {'silent401': true}));
      final data = r.data is Map ? Map<String, dynamic>.from(r.data as Map) : <String, dynamic>{};
      switch (data['status']) {
        case 'completed':
          return PendingStatus(PendingOutcome.completed, data);
        case 'payment_review':
          return PendingStatus(PendingOutcome.review, data);
        case 'failed':
        case 'expired':
          return PendingStatus(PendingOutcome.failed, data);
        case 'pending':
          return PendingStatus(PendingOutcome.pending, data);
      }
      return const PendingStatus(PendingOutcome.unknown);
    } catch (_) {
      return const PendingStatus(PendingOutcome.unknown);
    }
  }
}
