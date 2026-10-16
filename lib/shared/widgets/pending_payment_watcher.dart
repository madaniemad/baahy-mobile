import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/cart_provider.dart';
import '../../core/providers/reorder_provider.dart';
import '../../core/providers/welcome_coupon_provider.dart';
import '../../core/services/pending_checkout_service.dart';
import '../../core/utils/l10n.dart';

/// Follow a stored, interrupted gateway payment to its end. On a final answer the stored
/// reference is dropped; on completed / under review the cart is emptied (the money was taken).
/// Returns the final status, or null when there is nothing to act on yet (none stored, still
/// pending, no answer, or the checkout screen is following it itself).
Future<PendingStatus?> settleStoredPendingCheckout(WidgetRef ref) async {
  final svc = PendingCheckoutService.instance;
  if (svc.handledOnScreen) return null;
  if (!ref.read(authProvider).isLoggedIn) return null;
  final p = await svc.load();
  if (p == null) return null;
  final st = await svc.fetchStatus(p.ref);
  if (svc.handledOnScreen) return null;
  switch (st.outcome) {
    case PendingOutcome.completed:
    case PendingOutcome.review:
      await svc.clear(p.ref);
      if (p.clearCart) await ref.read(cartProvider.notifier).clear();
      ref.read(reorderSessionProvider.notifier).state = null;
      ref.invalidate(welcomeCouponProvider);
      return st;
    case PendingOutcome.failed:
      await svc.clear(p.ref); // not paid: the customer may simply place the order again
      return st;
    case PendingOutcome.pending:
    case PendingOutcome.unknown:
      return null;
  }
}

/// "Your payment is under review" — the server's message, and deliberately no retry button:
/// the money was taken, so paying again would charge twice.
Future<void> showPaymentReviewDialog(BuildContext context, String? message) {
  return showDialog<void>(
    context: context,
    builder: (dlg) => AlertDialog(
      title: Text(context.s.paymentReviewTitle,
          style: const TextStyle(
              fontFamily: 'Manrope',
              fontFamilyFallback: ['Tajawal'],
              fontWeight: FontWeight.w700)),
      content: Text(
          (message != null && message.trim().isNotEmpty)
              ? message
              : context.s.paymentReviewDefault,
          style: const TextStyle(height: 1.5)),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(dlg).pop(),
            child: Text(context.s.okGotIt)),
      ],
    ),
  );
}

/// Checks for an interrupted payment when the app opens and every time it returns to the
/// foreground (back from a bank app, or reopened after being killed mid-payment).
class PendingPaymentWatcher extends ConsumerStatefulWidget {
  final GoRouter router;
  final Widget child;
  const PendingPaymentWatcher({super.key, required this.router, required this.child});

  @override
  ConsumerState<PendingPaymentWatcher> createState() => _PendingPaymentWatcherState();
}

class _PendingPaymentWatcherState extends ConsumerState<PendingPaymentWatcher>
    with WidgetsBindingObserver {
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Give the cached session a moment to load before the first look.
    Future.delayed(const Duration(seconds: 3), _check);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (_checking || !mounted) return;
    _checking = true;
    try {
      final st = await settleStoredPendingCheckout(ref);
      if (st == null || !mounted) return;
      final navCtx = widget.router.routerDelegate.navigatorKey.currentContext;
      if (st.outcome == PendingOutcome.completed && st.orderId != null) {
        widget.router.push('/orders/${st.orderId}');
        if (navCtx != null && navCtx.mounted) {
          ScaffoldMessenger.maybeOf(navCtx)?.showSnackBar(
              SnackBar(content: Text(navCtx.s.paymentConfirmedOrder)));
        }
      } else if (st.outcome == PendingOutcome.review) {
        if (navCtx != null && navCtx.mounted) {
          await showPaymentReviewDialog(navCtx, st.message);
        }
      }
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
