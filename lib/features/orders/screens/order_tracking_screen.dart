import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/optimized_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/order.dart';
import '../../../core/models/app_config.dart';
import '../../../core/providers/app_config_provider.dart';
import '../../../core/models/product.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/utils/delivery.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/l10n.dart';
import '../../../core/utils/navigation.dart';
import '../widgets/bank_transfer_card.dart';
import '../widgets/change_payment_method.dart';
import '../../notifications/widgets/notifications_reminder.dart';
import '../widgets/order_help.dart';
import '../widgets/return_request_card.dart';
import '../../../shared/theme/app_theme.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> _shareOrderPdf(BuildContext context, Order order) async {
  try {
    final response = await ApiClient.instance.dio.get(
      '/orders/${order.id}/invoice',
      options: Options(
        responseType: ResponseType.bytes,
        receiveTimeout: const Duration(seconds: 30),
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/invoice_${order.orderNumber}.pdf');
    await file.writeAsBytes(response.data as List<int>);

    if (!context.mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null ? box.localToGlobal(Offset.zero) & box.size : null;
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'application/pdf')],
      subject: context.tr('فاتورة ${order.orderNumber}', 'Invoice ${order.orderNumber}'),
      sharePositionOrigin: origin,
    ));
  } catch (e, st) {
    Sentry.captureException(e, stackTrace: st);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('تعذر تحميل الفاتورة، حاول مجدداً', 'Could not load the invoice, please try again'))),
      );
    }
  }
}

final _orderDetailProvider = FutureProvider.autoDispose.family<Order, int>((ref, id) async {
  final res = await ApiClient.instance.dio.get('/orders/$id');
  return Order.fromJson(res.data['data']);
});

class OrderTrackingScreen extends ConsumerStatefulWidget {
  final int id;
  const OrderTrackingScreen({required this.id, super.key});

  @override
  ConsumerState<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends ConsumerState<OrderTrackingScreen> {
  final _body = GlobalKey<_OrderBodyState>();

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(_orderDetailProvider(widget.id));

    return Scaffold(
      backgroundColor: context.col.bg,
      appBar: AppBar(
        backgroundColor: context.col.surface, elevation: 0,
        leading: IconButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/orders'),
          icon: Icon(Icons.arrow_back, color: context.col.ink0)),
        titleSpacing: 0,
        title: orderAsync.maybeWhen(
          data: (o) => Text(context.s.orderNumber(o.orderNumber),
            style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontWeight: FontWeight.w800)),
          orElse: () => Text(context.s.orderDetails,
            style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontWeight: FontWeight.w800)),
        ),
        actions: [
          if (orderAsync.hasValue)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: OutlinedButton.icon(
                onPressed: () => _body.currentState?._openHelp(context),
                icon: const Icon(Icons.support_agent_rounded, size: 17, color: AppColors.primary),
                label: Text(context.tr('تحتاج مساعدة؟', 'Need help?'),
                  style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontWeight: FontWeight.w700, fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.col.ink0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  side: const BorderSide(color: AppColors.primary, width: 1.2),
                ),
              ),
            ),
        ],
      ),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, __) => Center(child: Text(context.s.loadOrderFailed)),
        data: (order) => _OrderBody(key: _body, order: order),
      ),
    );
  }
}

class _OrderBody extends ConsumerStatefulWidget {
  final Order order;
  const _OrderBody({required this.order, super.key});

  @override
  ConsumerState<_OrderBody> createState() => _OrderBodyState();
}

class _OrderBodyState extends ConsumerState<_OrderBody> {
  bool _reordering = false;
  bool _cancelling = false;

  /// «تحتاج مساعدة؟» (Emad, 2026-11-26: at the top of the page, where every customer sees it). Self-service first:
  /// the sheet offers what fits this order's stage, then the assistant. Never WhatsApp from here.
  void _openHelp(BuildContext context) {
    final order = widget.order;
    final openReturn = kOpenReturnStatuses.contains(ref.read(orderReturnProvider(order.id)).valueOrNull?['status']);
    showOrderHelpSheet(context, ref, orderId: order.id, orderNumber: order.orderNumber, extra: [
      if (order.status == 'delivered' && order.returnEligible && !openReturn)
        (icon: Icons.assignment_return_outlined, label: context.s.returnItems, color: null, onTap: () async {
          await safePush(context, '/orders/${order.id}/return', extra: order.returnDeadline);
          ref.invalidate(orderReturnProvider(order.id));
        }),
      if (_isCancellable(order))
        (icon: Icons.cancel_outlined, label: context.s.cancelOrder, color: AppColors.danger, onTap: () => _cancelOrder(context)),
    ]);
  }

  /// The statuses OrderController::cancel accepts from the customer (2026-11-27: widened to match
  /// the server; 113542673 sat in pending_payment with no way to cancel).
  static const _cancellableStatuses = {
    'pending', 'pending_payment', 'pending_confirmation', 'pending_vendor', 'paid', 'confirmed', 'processing',
  };

  /// Processing only until a driver collects: `delivery_driver` is sent once he has picked it up.
  static bool _isCancellable(Order o) =>
      _cancellableStatuses.contains(o.status) && !(o.status == 'processing' && o.deliveryDriver != null);

  Future<void> _cancelOrder(BuildContext context) async {
    if (_cancelling) return;
    final order = widget.order;
    final paidSomething = order.paymentStatus == 'paid' || order.walletAmount > 0;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: context.col.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 36, height: 4,
              decoration: BoxDecoration(color: context.col.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text(context.s.cancelOrderQ,
              style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
                fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(context.s.orderNumber(order.orderNumber),
              style: TextStyle(fontSize: 13, color: context.col.ink2)),
            if (paidSomething) ...[
              const SizedBox(height: 10),
              Text(context.s.cancelOrderPaidNote,
                style: TextStyle(fontSize: 12.5, height: 1.5, color: context.col.ink2)),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity, height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.of(sheetCtx).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger, foregroundColor: Colors.white, elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text(context.s.yesCancelOrder,
                  style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity, height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.of(sheetCtx).pop(false),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: context.col.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text(context.s.keepOrder,
                  style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal'],
                    fontWeight: FontWeight.w700, color: context.col.ink0)),
              ),
            ),
          ]),
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    setState(() => _cancelling = true);
    try {
      final res = await ApiClient.instance.dio.post('/orders/${order.id}/cancel');
      if (!context.mounted) return;
      final serverMsg = res.data is Map ? res.data['message']?.toString() : null;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(serverMsg ?? context.s.orderCancelled),
        backgroundColor: AppColors.success));
      ref.invalidate(_orderDetailProvider(order.id));
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      if (!context.mounted) return;
      String msg = context.s.orderError;
      if (e is DioException) {
        final d = e.response?.data;
        if (d is Map && d['message'] != null) msg = d['message'].toString();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.danger));
      // The order may have moved on (e.g. already being prepared) — show where it is now.
      ref.invalidate(_orderDetailProvider(order.id));
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  bool _removeSheetOpen = false;
  /// The amount row glows in `col.hilite` for about 2 s after a removal, then fades.
  bool _hiliteTotal = false;

  /// «حذف» on one line (Emad 2026-11-27, option A: a link per removable line, no multi-select).
  /// The sheet previews the change with the server's dry_run before anything is removed; the server
  /// decides what is removable, the new total, the wallet refund and whether the order is cancelled.
  Future<void> _removeItem(BuildContext context, OrderItem item) async {
    if (_removeSheetOpen) return;
    _removeSheetOpen = true;
    final order = widget.order;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: context.col.surface,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => _RemoveItemSheet(
          order: order,
          item: item,
          onDone: _afterRemove,
          onReload: () { if (mounted) ref.invalidate(_orderDetailProvider(order.id)); },
          onHelp: () { if (mounted) _openHelp(this.context); },
        ),
      );
    } finally {
      _removeSheetOpen = false;
    }
  }

  /// After a removal: reload the order from the server, confirm in a toast, and briefly mark the new amount.
  Future<void> _afterRemove(_RemoveOutcome r) async {
    if (!mounted) return;
    final id = widget.order.id;
    ref.invalidate(_orderDetailProvider(id));
    final s = context.s;
    String text;
    if (r.cancelled) {
      text = s.removeOrderCancelled;
    } else {
      text = (r.message != null && r.message!.trim().isNotEmpty) ? r.message!.trim() : s.removeDone;
      if (r.newTotal != null) {
        final total = '${fmtPrice(r.newTotal!)} ${s.lydUnit}';
        text += '\n${r.refund > 0
            ? s.removeNewTotalRefund(total, '${fmtPrice(r.refund)} ${s.lydUnit}')
            : s.removeNewTotal(total)}';
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: context.col.ink0,
      content: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(Icons.check_circle_rounded, size: 18, color: AppColors.primary)),
        const SizedBox(width: 10),
        Expanded(child: Text(text,
          style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal'],
            fontSize: 13.5, height: 1.5, color: context.col.surface))),
      ]),
    ));
    if (r.cancelled) return;
    // Mark the amount once the reloaded figures are on screen, not the old ones.
    try {
      await ref.read(_orderDetailProvider(id).future);
    } catch (_) {
      return;
    }
    if (!mounted) return;
    setState(() => _hiliteTotal = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _hiliteTotal = false);
  }

  /// "Rate this product" on a delivered order — POST /reviews (the endpoint baahy.com uses).
  /// The server checks the purchase itself and holds the review for moderation.
  Future<void> _rateItem(BuildContext context, OrderItem item) async {
    int rating = 0;
    bool sending = false;
    String? error;
    final commentCtrl = TextEditingController();
    final done = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.col.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setS) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(sheetCtx).viewInsets.bottom + 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 36, height: 4,
                decoration: BoxDecoration(color: context.col.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text(context.s.rateProduct,
                style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
                  fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(context.isAr ? item.productNameAr : item.productName,
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: context.col.ink2)),
              const SizedBox(height: 12),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) =>
                  IconButton(
                    onPressed: sending ? null : () => setS(() { rating = i + 1; error = null; }),
                    icon: Icon(i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 34, color: i < rating ? AppColors.gold : context.col.ink4),
                  ))),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: commentCtrl,
                maxLines: 3,
                maxLength: 1000,
                decoration: InputDecoration(
                  hintText: context.s.reviewHint,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              if (error != null) ...[
                Text(error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
                const SizedBox(height: 8),
              ],
              SizedBox(
                width: double.infinity, height: 48,
                child: ElevatedButton(
                  onPressed: sending ? null : () async {
                    if (rating == 0) {
                      setS(() => error = context.s.chooseStars);
                      return;
                    }
                    setS(() { sending = true; error = null; });
                    final thanks = context.s.reviewThanks;
                    final fallbackError = context.s.orderError;
                    final isAr = Localizations.localeOf(context).languageCode == 'ar';
                    try {
                      // Stars alone are published at once; a comment waits for review (2026-11-15). The server says which.
                      final res = await ApiClient.instance.dio.post('/reviews', data: {
                        'product_id': item.productId,
                        'rating': rating,
                        if (commentCtrl.text.trim().isNotEmpty) 'comment': commentCtrl.text.trim(),
                      });
                      final d = res.data is Map ? res.data as Map : const {};
                      final said = (isAr ? d['message'] : (d['message_en'] ?? d['message']))?.toString();
                      if (sheetCtx.mounted) Navigator.of(sheetCtx).pop(said ?? thanks);
                    } catch (e) {
                      String msg = fallbackError;
                      if (e is DioException) {
                        final d = e.response?.data;
                        if (d is Map && d['message'] != null) msg = d['message'].toString();
                      }
                      setS(() { sending = false; error = msg; });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: sending
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(context.s.submitReview,
                          style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
    commentCtrl.dispose();
    if (done != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(done), backgroundColor: AppColors.success));
    }
  }

  Future<void> _reorder(BuildContext context) async {
    if (_reordering) return;
    setState(() => _reordering = true);
    try {
      final ids = widget.order.vendorGroups
          .expand((g) => g.items)
          .map((i) => i.productId)
          .toSet()
          .toList();
      final queryParams = ids.map((id) => 'ids[]=$id').join('&');
      final res = await ApiClient.instance.dio.get('/products?$queryParams');
      // The batch endpoint wraps the list as { data: { data: [...] } }.
      // Tolerate both the nested and flat shapes.
      final dataNode = res.data['data'];
      final raw = dataNode is List
          ? dataNode
          : (dataNode is Map ? (dataNode['data'] as List? ?? const []) : const []);
      final products = {for (final j in raw) (j['id'] as int): Product.fromJson(j)};
      final cart = ref.read(cartProvider.notifier);
      var added = 0;
      var skipped = 0;
      var adjusted = false;
      for (final group in widget.order.vendorGroups) {
        for (final item in group.items) {
          final p = products[item.productId];
          if (p == null) { skipped++; continue; }
          if (item.variationId != null) {
            // Variable product — require the exact same variation, still present + in stock.
            final matches = p.variations.where((vv) => vv.id == item.variationId);
            if (matches.isEmpty) { skipped++; continue; } // variation was removed
            final v = matches.first;
            if (!v.inStock || v.stockQuantity <= 0) { skipped++; continue; }
            final qty = v.stockQuantity < item.quantity ? v.stockQuantity : item.quantity;
            if (qty <= 0) { skipped++; continue; }
            if (qty < item.quantity) adjusted = true;
            await cart.add(p, variation: v, qty: qty);
            added++;
          } else {
            // Simple product
            if (!p.inStock) { skipped++; continue; }
            final stock = p.stockQuantity ?? item.quantity;
            final qty = stock < item.quantity ? stock : item.quantity;
            if (qty <= 0) { skipped++; continue; }
            if (qty < item.quantity) adjusted = true;
            await cart.add(p, variation: null, qty: qty);
            added++;
          }
        }
      }
      if (!context.mounted) return;
      if (added == 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.s.noItemsInStock),
          backgroundColor: AppColors.warn));
        return;
      }
      if (skipped > 0 || adjusted) {
        final isAr = context.isAr;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isAr
            ? 'تمت إضافة المتوفر إلى السلة. بعض المنتجات غير متوفرة أو تغيّرت الكمية.'
            : 'Available items added — some were unavailable or their quantity changed.')));
      }
      context.go('/cart');
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.isAr ? 'تعذرت إعادة الطلب' : 'Could not reorder')));
      }
    } finally {
      if (mounted) setState(() => _reordering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final isActive = ['pending_payment', 'pending_confirmation', 'pending_vendor', 'pending', 'paid', 'confirmed', 'processing',
        'fulfilled', 'shipped', 'out_for_delivery'].contains(order.status);
    // What is still owed: the server's figure (it also nets off items refused at the door);
    // the old local sum only when talking to a server that does not send it.
    final amountDue = order.amountDue ??
        (order.paymentStatus == 'paid' ? 0.0 : (order.total - order.walletAmount).clamp(0.0, double.infinity));
    final showAmountDue = order.walletAmount > 0 || order.doorstepDeduction > 0 || order.doorstepRejections.isNotEmpty;
    // Lines she may still «حذف» (server-decided). A store with none gets one quiet footer, but only
    // while something else in the order is removable — on a normal order it would just be noise.
    final removable = isActive ? order.removableItemIds : const <int>{};
    final anyRemovable = order.allItems.any((i) => removable.contains(i.id));
    // After a removal the amount she will pay (or has paid) glows briefly; it is the total row when
    // the amount-due row is not shown.
    Widget glow(Widget row) => Stack(clipBehavior: Clip.none, children: [
      Positioned(left: -6, right: -6, top: 0, bottom: 0,
        child: AnimatedOpacity(
          opacity: _hiliteTotal ? 1 : 0,
          duration: Duration(milliseconds: _hiliteTotal ? 200 : 700),
          child: DecoratedBox(decoration: BoxDecoration(
            color: context.col.hilite, borderRadius: BorderRadius.circular(8))))),
      row,
    ]);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Hero ETA card for active orders
        if (isActive) ...[
          _HeroCard(order: order),
          const SizedBox(height: 14),
        ],

        // Notifications off while the order is on its way: the updates promised above reach nobody.
        if (isActive && order.status != 'pending_payment') const NotificationsReminder.order(),

        // Who is bringing it — only while Baahy's own driver has the order (server decides), and
        // never on a delivered/cancelled order shown from a stale copy.
        if (isActive && order.deliveryDriver != null) ...[
          _DriverCard(driver: order.deliveryDriver!),
          const SizedBox(height: 14),
        ],

        // Bank transfer instructions — while the order awaits a manual transfer.
        if (order.paymentMethod == 'lypay' && order.status == 'pending_payment') ...[
          BankTransferCard(
            orderId: order.id,
            // Amount to transfer = what is still owed (total minus what the wallet already covered).
            total: amountDue,
            alreadyUploaded: order.paymentSlip != null && order.paymentSlip!.isNotEmpty,
          ),
          const SizedBox(height: 14),
        ],

        // Timeline card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.col.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.col.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.s.orderStatus,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            _Timeline(status: order.status, history: order.statusHistory, orderCreatedAt: order.createdAt),
          ]),
        ),

        const SizedBox(height: 14),

        // Items
        ...order.vendorGroups.map((group) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                (context.isAr && group.vendor.storeNameAr.isNotEmpty)
                    ? group.vendor.storeNameAr
                    : group.vendor.storeName,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14,
                  letterSpacing: 0.3)),
            ),
            Container(
              decoration: BoxDecoration(
                color: context.col.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.col.border),
              ),
              child: Column(
                children: [
                  ...group.items.asMap().entries.map((e) =>
                    _OrderItemRow(
                      item: e.value,
                      hasBorder: e.key < group.items.length - 1,
                      onRate: order.status == 'delivered'
                          ? () => _rateItem(context, e.value)
                          : null,
                      onRemove: removable.contains(e.value.id)
                          ? () => _removeItem(context, e.value)
                          : null,
                    ),
                  ),
                  if (anyRemovable && !group.items.any((i) => removable.contains(i.id)))
                    _LockedStoreFooter(onHelp: () => _openHelp(context)),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        )),

        // Items she did not accept at the door, and how many of each.
        if (order.doorstepRejections.isNotEmpty) ...[
          _DoorstepRejectionsCard(lines: order.doorstepRejections),
          const SizedBox(height: 12),
        ],

        // Price breakdown
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.col.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.col.border),
          ),
          child: Column(children: [
            _SumRow(context.s.subtotalOrder, '${fmtPrice(order.subtotal)} ${context.s.lydUnit}', ctx: context),
            _SumRow(
              context.s.shippingLabel,
              order.shippingCost > 0
                  ? '${fmtPrice(order.shippingCost)} ${context.s.lydUnit}'
                  : (context.isAr ? 'مجاني' : 'Free'),
              color: order.shippingCost == 0 ? AppColors.success : null,
              ctx: context,
            ),
            if (order.discount > 0)
              _SumRow(context.s.discountLabel, '-${fmtPrice(order.discount)} ${context.s.lydUnit}',
                color: AppColors.success, ctx: context),
            // The coupon has its own field and `discount` is 0 on coupon orders, so without this
            // row the breakdown printed 88 + 20 above a 99.20 total.
            if (order.couponDiscount > 0)
              _SumRow(
                order.couponCode != null && order.couponCode!.isNotEmpty
                    ? '${context.tr('كوبون', 'Coupon')} (${order.couponCode})'
                    : context.tr('كوبون', 'Coupon'),
                '-${fmtPrice(order.couponDiscount)} ${context.s.lydUnit}',
                color: AppColors.success, ctx: context),
            Divider(height: 20, color: context.col.border),
            if (showAmountDue)
              _SumRow(context.s.totalLabel, '${fmtPrice(order.total)} ${context.s.lydUnit}', bold: true, ctx: context)
            else
              glow(_SumRow(context.s.totalLabel, '${fmtPrice(order.total)} ${context.s.lydUnit}', bold: true, ctx: context)),
            // Part (or all) of the order already paid from wallet balance, or items refused at the
            // door — the customer needs to know what is still owed.
            if (showAmountDue) ...[
              if (order.walletAmount > 0)
                _SumRow(context.tr('مدفوع من المحفظة', 'Paid from wallet'),
                  '-${fmtPrice(order.walletAmount)} ${context.s.lydUnit}',
                  color: AppColors.success, ctx: context),
              if (order.doorstepDeduction > 0)
                _SumRow(context.s.doorstepDeductionLabel,
                  '-${fmtPrice(order.doorstepDeduction)} ${context.s.lydUnit}',
                  color: AppColors.success, ctx: context),
              glow(_SumRow(
                order.paymentStatus == 'paid'
                    ? context.tr('مدفوع بالكامل', 'Already paid')
                    : context.tr('المبلغ المستحق', 'Amount due'),
                '${fmtPrice(amountDue)} ${context.s.lydUnit}',
                bold: true, ctx: context)),
            ],
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(context.tr('طريقة الدفع', 'Payment method'),
                style: TextStyle(fontSize: 13.5, color: context.col.ink2,
                  fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal'])),
              Text(
                order.walletAmount > 0
                    ? (order.walletAmount >= order.total
                        ? context.tr('المحفظة', 'Wallet')
                        : '${context.tr('المحفظة', 'Wallet')} + ${_paymentMethodLabel(context, order.paymentMethod, configured: ref.watch(appConfigProvider).paymentMethods)}')
                    : _paymentMethodLabel(context, order.paymentMethod, configured: ref.watch(appConfigProvider).paymentMethods),
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: context.col.ink0,
                  fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal'])),
            ]),
            // She changes how she pays until delivery (Emad 2026-11-25); the server has the last word.
            if (order.paymentStatus != 'paid' && !const {'delivered', 'cancelled', 'refunded', 'failed', 'returned_to_vendor'}.contains(order.status))
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: ChangePaymentMethodButton(orderId: order.id, onChanged: () => ref.invalidate(_orderDetailProvider(order.id))),
              ),
            // Only the payment outcomes she would not otherwise see (money sent back, payment voided).
            if (const {'refunded', 'partial_refunded', 'void'}.contains(order.paymentStatus)) ...[
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(context.s.paymentStatusTitle,
                  style: TextStyle(fontSize: 13.5, color: context.col.ink2,
                    fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal'])),
                Text(context.s.paymentStatusLabel(order.paymentStatus),
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: context.col.ink0,
                    fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal'])),
              ]),
            ],
          ]),
        ),

        // Her return on this order, with edit / cancel until it is collected.
        if (const {'delivered', 'partial_return', 'returned'}.contains(order.status))
          ReturnRequestCard(orderId: order.id),

        // What she asked through "Need help?", with our status and answer.
        HelpRequestsCard(orderId: order.id),

        // Actions
        if (order.status == 'delivered') ...[
          const SizedBox(height: 14),
          // One open return per order (the API refuses a second), so the button steps aside
          // while one is in progress — she edits that one from the card above instead.
          if (kOpenReturnStatuses.contains(ref.watch(orderReturnProvider(order.id)).valueOrNull?['status']))
            const SizedBox.shrink()
          else if (order.returnEligible) ...[
            if (order.returnDeadline != null)
              Builder(builder: (ctx) {
                final today       = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
                final deadlineDay = DateTime(order.returnDeadline!.year, order.returnDeadline!.month, order.returnDeadline!.day);
                final daysLeft    = deadlineDay.difference(today).inDays;
                final color       = daysLeft <= 2 ? AppColors.danger : AppColors.primary;
                final dateStr     = '${order.returnDeadline!.day}/${order.returnDeadline!.month}/${order.returnDeadline!.year}';
                final label       = daysLeft <= 0
                  ? (ctx.isAr ? 'آخر يوم للإرجاع — ينتهي $dateStr' : 'Last day to return — expires $dateStr')
                  : ctx.isAr
                    ? 'متبقٍ ${dayCountLabel(daysLeft, true)} للإرجاع — ينتهي $dateStr'
                    : '${dayCountLabel(daysLeft, false)} left to return — deadline $dateStr';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      Icon(daysLeft <= 2 ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
                        size: 15, color: color),
                      const SizedBox(width: 8),
                      Expanded(child: Text(label,
                        style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 12.5,
                          fontWeight: FontWeight.w600, color: color))),
                    ]),
                  ),
                );
              }),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await safePush(context, '/orders/${order.id}/return', extra: order.returnDeadline);
                  // A return filed just now shows up in the card without a manual refresh.
                  ref.invalidate(orderReturnProvider(order.id));
                },
                icon: const Icon(Icons.assignment_return_outlined, size: 16),
                label: Text(context.s.returnItems,
                  style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(color: context.col.border),
                ),
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              decoration: BoxDecoration(
                color: context.col.surfaceSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.col.border),
              ),
              child: Row(children: [
                Icon(Icons.block_rounded, size: 16, color: context.col.ink3),
                const SizedBox(width: 8),
                Text(
                  context.isAr ? 'انتهت مدة الإرجاع' : 'Return window has closed',
                  style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 13, color: context.col.ink3)),
              ]),
            ),
          ],
        ],
        const SizedBox(height: 8),
        // Cancel — only while the backend still accepts it (OrderController::cancel).
        if (_isCancellable(order)) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _cancelling ? null : () => _cancelOrder(context),
              icon: _cancelling
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.danger))
                  : const Icon(Icons.cancel_outlined, size: 16, color: AppColors.danger),
              label: Text(context.s.cancelOrder,
                style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
                  fontWeight: FontWeight.w700, color: AppColors.danger)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: BorderSide(color: AppColors.danger.withValues(alpha: 0.5)),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        // Reorder button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _reordering ? null : () => _reorder(context),
            icon: _reordering
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.shopping_bag_outlined, size: 16),
            label: Text(
              context.isAr ? 'إعادة الطلب' : 'Reorder',
              style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 8),
        // The invoice moved here from the header (Emad, 2026-11-26).
        Builder(
          builder: (btnCtx) => SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () => _shareOrderPdf(btnCtx, order),
              icon: Icon(Icons.receipt_long_outlined, size: 18, color: context.col.ink2),
              label: Text(context.s.downloadInvoice,
                style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal'], fontWeight: FontWeight.w600, color: context.col.ink2)),
            ),
          ),
        ),
      ]),
    );
  }
}

class _DoorstepRejectionsCard extends StatelessWidget {
  final List<DoorstepRejectionLine> lines;
  const _DoorstepRejectionsCard({required this.lines});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.col.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.col.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.assignment_late_outlined, size: 18, color: context.col.ink2),
          const SizedBox(width: 8),
          Expanded(child: Text(context.s.doorstepTitle,
            style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
              fontSize: 14, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 10),
        ...lines.map((l) {
          final name = context.isAr
              ? (l.productNameAr.isNotEmpty ? l.productNameAr : l.productName)
              : (l.productName.isNotEmpty ? l.productName : l.productNameAr);
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name.isNotEmpty ? name : context.tr('منتج', 'Item'),
                  textAlign: TextAlign.start,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, height: 1.35, color: context.col.ink0)),
                if (l.variationLabel != null && l.variationLabel!.isNotEmpty)
                  Text(l.variationLabel!,
                    style: TextStyle(fontSize: 11, color: context.col.ink3)),
              ])),
              const SizedBox(width: 10),
              Text(context.s.quantityN(l.quantity),
                style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal'],
                  fontSize: 12.5, fontWeight: FontWeight.w600, color: context.col.ink2)),
            ]),
          );
        }),
        const SizedBox(height: 4),
        Text(context.s.doorstepNote,
          textAlign: TextAlign.start,
          style: TextStyle(fontSize: 12, height: 1.4, color: context.col.ink3)),
      ]),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final Order order;
  const _HeroCard({required this.order});

  _HeroInfo _info(BuildContext context) {
    final s = order.status;
    // Not paid yet — it is not on its way (it used to fall through to "On the way").
    if (s == 'pending_payment') {
      return _HeroInfo(
        icon: Icons.payments_outlined,
        badge: context.s.statusLabel(s),
        title: context.s.awaitingPaymentTitle,
        subtitle: context.s.awaitingPaymentSub,
      );
    }
    if (s == 'pending_vendor') {
      return _HeroInfo(
        icon: Icons.storefront_outlined,
        badge: context.s.statusLabel(s),
        title: context.s.isAr ? 'تم استلام طلبك' : 'Order Received',
        subtitle: context.s.confirmingWithSellerSub,
      );
    }
    if (s == 'pending_confirmation' || s == 'paid') {
      return _HeroInfo(
        icon: Icons.hourglass_empty_rounded,
        badge: context.s.statusLabel(s),
        title: context.s.isAr ? 'تم استلام طلبك' : 'Order Received',
        subtitle: context.s.isAr ? 'سيتم مراجعة طلبك قريباً' : 'We\'ll review your order soon',
      );
    }
    if (s == 'confirmed' || s == 'pending') {
      return _HeroInfo(
        icon: Icons.check_circle_outline_rounded,
        badge: context.s.isAr ? 'مؤكد' : 'Confirmed',
        title: context.s.isAr ? 'تم تأكيد طلبك' : 'Order Confirmed',
        subtitle: context.s.isAr ? 'سيبدأ تجهيز طلبك قريباً' : 'Preparing soon',
      );
    }
    // Processing / fulfilled both read as "being prepared" for the customer.
    if (s == 'processing' || s == 'fulfilled') {
      return _HeroInfo(
        icon: Icons.inventory_2_outlined,
        badge: context.s.isAr ? 'قيد التجهيز' : 'Processing',
        title: context.s.isAr ? 'جارٍ تجهيز طلبك' : 'Preparing Your Order',
        subtitle: context.s.isAr ? 'بدأنا بتجهيز طلبك' : 'We\'ve started preparing your order',
      );
    }
    // shipped / out_for_delivery
    return _HeroInfo(
      icon: Icons.local_shipping_outlined,
      badge: context.s.onTheWay,
      title: context.s.inDelivery,
      subtitle: context.s.deliveryPromise,
    );
  }

  @override
  Widget build(BuildContext context) {
    final info = _info(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.col.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.col.border),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(info.icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(info.badge,
            style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], color: AppColors.primary,
              fontSize: 12, fontWeight: FontWeight.w700)),
          Text(info.title,
            style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], color: context.col.ink0,
              fontSize: 15, fontWeight: FontWeight.w800)),
          Text(info.subtitle,
            style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], color: context.col.ink3, fontSize: 12)),
        ])),
      ]),
    );
  }
}

class _DriverCard extends StatelessWidget {
  final DeliveryDriver driver;
  const _DriverCard({required this.driver});

  @override
  Widget build(BuildContext context) {
    const size = 48.0;
    final fallback = Container(
      width: size, height: size,
      decoration: BoxDecoration(color: context.col.surfaceSoft, shape: BoxShape.circle),
      child: Icon(Icons.person_outline_rounded, size: 26, color: context.col.ink3),
    );
    final photo = driver.photoUrl;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.col.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.col.border),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.6), width: 1.5),
          ),
          child: ClipOval(
            child: photo == null
                ? fallback
                : CachedNetworkImage(
                    imageUrl: photo,
                    width: size, height: size,
                    fit: BoxFit.cover,
                    memCacheWidth: 160,
                    placeholder: (_, __) => fallback,
                    errorWidget: (_, __, ___) => fallback,
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.s.driverOnTheWay(driver.name),
            textAlign: TextAlign.start,
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal'], color: context.col.ink0,
              fontSize: 14.5, fontWeight: FontWeight.w700, height: 1.35)),
          const SizedBox(height: 2),
          Text(context.s.driverHasOrder,
            textAlign: TextAlign.start,
            style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal'], color: context.col.ink3,
              fontSize: 12)),
        ])),
      ]),
    );
  }
}

class _HeroInfo {
  final IconData icon;
  final String badge;
  final String title;
  final String subtitle;
  const _HeroInfo({required this.icon, required this.badge, required this.title, required this.subtitle});
}

class _Timeline extends StatelessWidget {
  final String status;
  final List<OrderStatusEntry> history;
  final DateTime orderCreatedAt;
  const _Timeline({required this.status, this.history = const [], required this.orderCreatedAt});

  static const _extraMap = {
    // Not confirmed yet: waiting for payment, for us, or for the seller → the first step.
    'pending_payment': 0,
    'pending_confirmation': 0,
    'pending_vendor': 0,
    'paid': 0,
    // 'confirmed' resolves to its own step (مؤكد). The order auto-advances to 'processing'
    // ~30s later, and 'fulfilled' rolls up when collected — both map to قيد التجهيز (step 2).
    'processing': 2,
    'fulfilled': 2,
    'out_for_delivery': 3,
  };

  /// Statuses an order ends in. The timeline shows the steps it actually reached, then one closing
  /// row in its own words — failed / returned_to_vendor / partial_return used to sit on step 0
  /// ("Order received"), and cancelled did too.
  static const _endedStatuses = {
    'cancelled', 'failed', 'returned_to_vendor', 'refunded', 'returned', 'partial_return',
  };
  static const _endedBad = {'cancelled', 'failed', 'returned_to_vendor'};
  /// These only happen after the hand-over, so the delivered step is reached even when the
  /// history (legacy orders) does not say so.
  static const _afterDelivery = {'returned', 'partial_return'};

  // Each step maps to one or more possible to_status values in history
  static const _stepAliases = {
    'pending':    ['pending', 'pending_payment', 'pending_confirmation', 'pending_vendor', 'paid'],
    'confirmed':  ['confirmed'],
    'processing': ['processing', 'fulfilled'],
    'shipped':    ['shipped', 'out_for_delivery'],
    'delivered':  ['delivered'],
  };

  int _currentIdx(List<(String, String)> steps) {
    if (_endedStatuses.contains(status)) {
      final reached = _reachedIdx(steps);
      return _afterDelivery.contains(status) ? steps.length - 1 : reached;
    }
    if (_extraMap.containsKey(status)) return _extraMap[status]!;
    for (int i = 0; i < steps.length; i++) {
      if (steps[i].$1 == status) return i;
    }
    return 0;
  }

  /// Furthest step the history shows the order got to.
  int _reachedIdx(List<(String, String)> steps) {
    var reached = 0;
    for (int i = 0; i < steps.length; i++) {
      final aliases = _stepAliases[steps[i].$1] ?? [steps[i].$1];
      if (history.any((e) => aliases.contains(e.toStatus))) reached = i;
    }
    return reached;
  }

  DateTime? _timestampFor(String stepStatus, bool isFirst) {
    if (isFirst) return orderCreatedAt;
    final aliases = _stepAliases[stepStatus] ?? [stepStatus];
    for (final entry in history) {
      if (aliases.contains(entry.toStatus)) return entry.createdAt;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final steps = [
      // Waiting for payment is not "received" yet — say what it is waiting for.
      ('pending',     status == 'pending_payment' ? context.s.statusLabel(status) : context.s.stepPending),
      ('confirmed',   context.s.stepConfirmed),
      ('processing',  context.s.stepProcessing),
      ('shipped',     context.s.stepShipped),
      ('delivered',   context.s.stepDelivered),
    ];
    final current = _currentIdx(steps);
    final ended = _endedStatuses.contains(status);
    // An ended order shows only the steps it reached, then the closing row.
    final shown = ended ? current + 1 : steps.length;
    final rows = shown + (ended ? 1 : 0);
    final endColor = _endedBad.contains(status) ? AppColors.danger : AppColors.info;
    DateTime? endTs;
    if (ended) {
      for (final e in history) {
        if (e.toStatus == status) endTs = e.createdAt;
      }
    }
    final endNote = ended ? context.s.orderEndedNote(status) : null;

    return Column(
      children: List.generate(rows, (i) {
        final isEnd = ended && i == shown;
        final isDone = isEnd || i <= current;
        final isActive = isEnd || (!ended && i == current);
        final isLast = i == rows - 1;
        final ts = isEnd ? endTs : (isDone ? _timestampFor(steps[i].$1, i == 0) : null);
        final dotColor = isEnd ? endColor : AppColors.primary;
        final label = isEnd ? context.s.statusLabel(status) : steps[i].$2;
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 22,
            child: Column(children: [
              Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone ? dotColor : Colors.transparent,
                  border: Border.all(
                    color: isDone ? dotColor : context.col.borderStrong,
                    width: 2),
                ),
                child: isDone
                    ? Icon(
                        isEnd
                            ? (_endedBad.contains(status) ? Icons.close_rounded : Icons.undo_rounded)
                            : Icons.check_rounded,
                        size: 12, color: Colors.white)
                    : null,
              ),
              if (!isLast)
                Container(
                  width: 2, height: ts != null ? 50 : 40,
                  color: (isDone && (i + 1) <= current) || (ended && i + 1 == shown)
                      ? AppColors.primary
                      : context.col.border),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 1, bottom: isLast ? 0 : (ts != null ? 24 : 20)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isEnd ? endColor : (isActive ? AppColors.primary : context.col.ink0))),
                if (ts != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    () {
                      final t = ts.toLocal();
                      return '${t.day}/${t.month}/${t.year} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                    }(),
                    style: TextStyle(fontSize: 11, color: context.col.ink3,
                      fontFamily: 'PlusJakartaSans')),
                ],
                if (isEnd && endNote != null) ...[
                  const SizedBox(height: 3),
                  Text(endNote,
                    textAlign: TextAlign.start,
                    style: TextStyle(fontSize: 12, height: 1.4, color: context.col.ink2)),
                ],
              ]),
            ),
          ),
        ]);
      }),
    );
  }
}

Widget _SummaryRow(String label, String value, {Color? color, bool bold = false, required BuildContext ctx}) =>
  Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(fontSize: 14)),
      Text(value, style: TextStyle(
        fontFamily: 'PlusJakartaSans', fontSize: 14,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
        color: color ?? ctx.col.ink0)),
    ]),
  );

Widget _SumRow(String label, String value, {Color? color, bool bold = false, required BuildContext ctx}) =>
  _SummaryRow(label, value, color: color, bold: bold, ctx: ctx);

/// Label for a payment method, preferring what admin actually configured.
///
/// The hardcoded list below never learned `lypay` (or sadad / the Masarat wallets), so the order
/// screen printed the raw gateway id — the customer read "lypay" where the admin panel says
/// "تحويل مصرفي". Admin owns these names in Payment Methods and ships them in /app-config; use
/// those first and keep the switch as the offline fallback.
String _paymentMethodLabel(BuildContext ctx, String m, {List<PaymentMethod> configured = const []}) {
  final ar = ctx.isAr;
  for (final pm in configured) {
    if (pm.id != m) continue;
    final label = ar ? pm.labelAr : pm.labelEn;
    if (label.trim().isNotEmpty) return label;
  }
  switch (m) {
    case 'cash_on_delivery':
    case 'cash':     return ar ? 'الدفع عند الاستلام' : 'Cash on Delivery';
    case 'wallet':   return ar ? 'المحفظة'            : 'Wallet';
    case 'tadawel':  return ar ? 'تداول'              : 'Tadawel';
    case 'moamlat':  return ar ? 'بطاقة مصرفية'            : 'Bank Card';
    case 'mobicash': return ar ? 'موبي كاش'           : 'Mobicash';
    case 'paypal':   return 'PayPal';
    case 'lypay':    return ar ? 'تحويل مصرفي'        : 'Bank Transfer';
    case 'sadad':    return ar ? 'سداد'               : 'Sadad';
    case 'yousrpay':   return ar ? 'يسر باي'   : 'Yousr Pay';
    case 'masrafipay': return ar ? 'مصرفي باي' : 'Masrafi Pay';
    case 'saharapay':  return ar ? 'صحارى باي' : 'Sahara Pay';
    case 'crypto':     return ar ? 'عملات رقمية' : 'Crypto';
    default:         return m.isEmpty ? (ar ? 'غير محدد' : 'Not specified') : m;
  }
}

class _OrderItemRow extends StatelessWidget {
  final OrderItem item;
  final bool hasBorder;
  /// Set on a delivered order: shows "Rate this product".
  final VoidCallback? onRate;
  /// Set when the server lists this line in `removable_item_ids`: shows «حذف».
  final VoidCallback? onRemove;
  /// The copy of the line inside the «حذف» sheet: no link, no chevron, not tappable.
  final bool inSheet;
  const _OrderItemRow({required this.item, required this.hasBorder, this.onRate, this.onRemove, this.inSheet = false});

  @override
  Widget build(BuildContext context) {
    final red = _removeRed(context);
    return GestureDetector(
      onTap: inSheet ? null : () => _navigateToProduct(context),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: hasBorder
              ? Border(bottom: BorderSide(color: context.col.border))
              : null,
        ),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 44, height: 44,
              child: item.productImage != null && item.productImage!.startsWith('http')
                  ? OptimizedNetworkImage(
                      url: item.productImage!,
                      fit: BoxFit.cover,
                      memCacheWidth: 140,
                      variantWidth: 400,
                      error: Container(color: context.col.bg,
                          child: Icon(Icons.image_outlined, color: context.col.ink4)),
                      placeholder: Container(color: context.col.bg))
                  : Container(color: context.col.bg,
                      child: Icon(Icons.image_outlined, color: context.col.ink4)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.isAr ? item.productNameAr : item.productName,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, height: 1.3)),
              if (item.variationLabel != null)
                Text(item.variationLabel!,
                  style: TextStyle(fontSize: 11, color: context.col.ink3)),
              Text('${fmtPrice(item.price)} ${context.s.lydUnit} × ${item.quantity}',
                style: TextStyle(fontFamily: 'PlusJakartaSans',
                  fontSize: 11, color: context.col.ink2)),
              if (onRate != null)
                GestureDetector(
                  onTap: onRate,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 2),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.star_outline_rounded, size: 15, color: AppColors.gold),
                      const SizedBox(width: 4),
                      Text(context.s.rateProduct,
                        style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal'],
                          fontSize: 12, fontWeight: FontWeight.w700, color: context.col.ink1)),
                    ]),
                  ),
                ),
              if (onRemove != null && !inSheet)
                GestureDetector(
                  onTap: onRemove,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 2),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.remove_circle_outline, size: 15, color: red),
                      const SizedBox(width: 4),
                      Text(context.s.removeItem,
                        style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal'],
                          fontSize: 12, fontWeight: FontWeight.w700, color: red)),
                    ]),
                  ),
                ),
            ]),
          ),
          Text('${fmtPrice(item.total)} ${context.s.lydUnit}',
            style: const TextStyle(fontFamily: 'PlusJakartaSans',
              fontWeight: FontWeight.w700, fontSize: 13)),
          if (!inSheet) ...[
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 16, color: context.col.ink4),
          ],
        ]),
      ),
    );
  }

  void _navigateToProduct(BuildContext context) {
    safePush(context, '/product/${item.productId}');
  }
}

// ── «حذف» an item (Emad 2026-11-27, option A) ─────────────────────────────────────────────────

/// The destructive red of the «حذف» link and the error box: #B42318, lifted in dark mode so it stays readable.
Color _removeRed(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? const Color(0xFFF97066) : const Color(0xFFB42318);

/// Footer of a store whose lines the store has already confirmed: one quiet line pointing to help.
/// The store is never named or offered as a contact.
class _LockedStoreFooter extends StatelessWidget {
  final VoidCallback onHelp;
  const _LockedStoreFooter({required this.onHelp});

  @override
  Widget build(BuildContext context) {
    const font = TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 12, height: 1.5);
    // A one-sided border cannot carry a radius, so the rounding comes from the clip.
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.col.surfaceSoft,
          border: Border(top: BorderSide(color: context.col.border)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.lock_outline_rounded, size: 15, color: context.col.ink3)),
          const SizedBox(width: 8),
          Expanded(child: Text.rich(
            TextSpan(text: context.s.removeLockedNote, children: [
              // A widget span keeps «تحتاج مساعدة؟» on one line.
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: GestureDetector(
                  onTap: onHelp,
                  behavior: HitTestBehavior.opaque,
                  child: Text(context.s.needHelpQ,
                    style: font.copyWith(fontWeight: FontWeight.w700, color: AppColors.teal700)),
                ),
              ),
            ]),
            style: font.copyWith(color: context.col.ink2),
          )),
        ]),
      ),
    );
  }
}

/// What a finished removal tells the order page.
class _RemoveOutcome {
  final String? message;
  final bool cancelled;
  final double? newTotal;
  final double refund;
  const _RemoveOutcome({this.message, this.cancelled = false, this.newTotal, this.refund = 0});
}

double? _numOrNull(dynamic v) => v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);

/// The confirm sheet for «حذف»: the cancel sheet's shell. It asks the server for a dry_run first and
/// shows its figures; `cancels:true` turns it into the cancel variant; a 422 is shown inside the sheet.
class _RemoveItemSheet extends StatefulWidget {
  final Order order;
  final OrderItem item;
  final void Function(_RemoveOutcome) onDone;
  final VoidCallback onReload;
  final VoidCallback onHelp;
  const _RemoveItemSheet({
    required this.order, required this.item,
    required this.onDone, required this.onReload, required this.onHelp,
  });

  @override
  State<_RemoveItemSheet> createState() => _RemoveItemSheetState();
}

class _RemoveItemSheetState extends State<_RemoveItemSheet> {
  /// The dry_run answer: {current_total, new_total, reduction, refund_to_wallet, cancels}.
  Map<String, dynamic>? _preview;
  /// The server's message (422) or a generic failure, shown in place of the totals.
  String? _error;
  bool _sending = false;

  bool get _loading => _preview == null && _error == null;
  bool get _cancels => _error == null && _preview?['cancels'] == true;
  String get _path => '/orders/${widget.order.id}/remove-items';

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  String _messageOf(Object e, String fallback) {
    if (e is DioException) {
      final d = e.response?.data;
      if (d is Map && d['message'] != null && d['message'].toString().trim().isNotEmpty) {
        return d['message'].toString();
      }
    }
    return fallback;
  }

  void _report(Object e, StackTrace st) {
    // A 422 is the server saying no in words she reads; anything else is worth knowing about.
    if (e is DioException && e.response?.statusCode == 422) return;
    Sentry.captureException(e, stackTrace: st);
  }

  // Runs from initState: nothing here may read the context (context.s, Theme…) before the first await.
  Future<void> _loadPreview() async {
    try {
      final res = await ApiClient.instance.dio.post(_path, data: {'item_ids': [widget.item.id], 'dry_run': 1});
      if (!mounted) return;
      final d = res.data;
      if (d is Map && d['success'] != false) {
        setState(() => _preview = Map<String, dynamic>.from(d));
      } else {
        setState(() => _error = (d is Map ? d['message']?.toString() : null) ?? context.s.orderError);
      }
    } catch (e, st) {
      _report(e, st);
      if (!mounted) return;
      setState(() => _error = _messageOf(e, context.s.orderError));
    }
  }

  Future<void> _confirm() async {
    if (_sending || _preview == null) return;
    final preview = _preview!;
    final fallback = context.s.orderError;
    setState(() => _sending = true);
    try {
      final res = await ApiClient.instance.dio.post(_path, data: {'item_ids': [widget.item.id]});
      final d = res.data is Map ? res.data as Map : const {};
      if (d['success'] == false) {
        if (!mounted) { widget.onReload(); return; }
        setState(() { _sending = false; _error = d['message']?.toString() ?? fallback; });
        return;
      }
      final outcome = _RemoveOutcome(
        message: d['message']?.toString(),
        cancelled: d['cancelled'] == true,
        newTotal: _numOrNull(preview['new_total']),
        refund: _numOrNull(preview['refund_to_wallet']) ?? 0,
      );
      if (mounted) Navigator.of(context).pop();
      // Even if the sheet was swiped away meanwhile, the page still reloads and confirms.
      widget.onDone(outcome);
    } catch (e, st) {
      _report(e, st);
      if (!mounted) { widget.onReload(); return; }
      setState(() { _sending = false; _error = _messageOf(e, fallback); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final col = context.col;
    final order = widget.order;
    final cancels = _cancels;
    const font = TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal']);
    final paidSomething = order.paymentStatus == 'paid' || order.walletAmount > 0;

    return PopScope(
      canPop: !_sending,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 36, height: 4,
              decoration: BoxDecoration(color: col.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text(cancels ? s.removeLastTitle : s.removeItemQ,
              style: font.copyWith(fontSize: 16, fontWeight: FontWeight.w800, height: 1.4)),
            const SizedBox(height: 6),
            Text(cancels ? s.removeLastSub : s.removeOrderRef(order.orderNumber),
              style: font.copyWith(fontSize: 13, height: 1.55, color: col.ink2)),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: col.border),
              ),
              child: _OrderItemRow(item: widget.item, hasBorder: false, inSheet: true),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              _RemoveErrorBox(message: _error!),
            ] else if (_loading) ...[
              const SizedBox(height: 12),
              const _RemoveTotalsSkeleton(),
            ] else if (cancels) ...[
              if (paidSomething) ...[
                const SizedBox(height: 10),
                Text(s.cancelOrderPaidNote,
                  style: font.copyWith(fontSize: 12.5, height: 1.5, color: col.ink2)),
              ],
            ] else
              ..._totals(context),
            const SizedBox(height: 18),
            if (_error != null) ...[
              SizedBox(
                width: double.infinity, height: 48,
                child: OutlinedButton(
                  onPressed: () { Navigator.of(context).pop(); widget.onReload(); },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: col.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: Text(s.okGotIt,
                    style: font.copyWith(fontWeight: FontWeight.w700, color: col.ink0)),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity, height: 48,
                child: OutlinedButton(
                  onPressed: () { Navigator.of(context).pop(); widget.onHelp(); },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary, width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: Text(s.needHelpQ,
                    style: font.copyWith(fontWeight: FontWeight.w700, color: col.ink0)),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity, height: 48,
                child: ElevatedButton(
                  onPressed: (_loading || _sending) ? null : _confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger, foregroundColor: Colors.white, elevation: 0,
                    // Sending: stays red under the spinner. Still loading the preview: faded.
                    disabledBackgroundColor: _sending ? AppColors.danger : AppColors.danger.withValues(alpha: 0.45),
                    disabledForegroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _sending
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(cancels ? s.yesCancelOrder : s.yesRemoveItem,
                          style: font.copyWith(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity, height: 48,
                child: OutlinedButton(
                  onPressed: _sending ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: col.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: Text(cancels ? s.keepOrder : s.keepItem,
                    style: font.copyWith(fontWeight: FontWeight.w700, color: col.ink0)),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  /// The current → new figures from the dry_run, the wallet line when money goes back, and the note.
  List<Widget> _totals(BuildContext context) {
    final s = context.s;
    final col = context.col;
    final order = widget.order;
    final p = _preview!;
    final current = _numOrNull(p['current_total']) ?? order.total;
    final next = _numOrNull(p['new_total']) ?? current;
    final refund = _numOrNull(p['refund_to_wallet']) ?? 0;
    final paid = order.paymentStatus == 'paid';
    final cod = !paid && const {'cash', 'cash_on_delivery'}.contains(order.paymentMethod);
    String money(double v) => '${fmtPrice(v)} ${s.lydUnit}';
    const font = TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal']);

    Widget row(String label, String value, TextStyle labelStyle, TextStyle valueStyle, {Widget? icon}) =>
        Row(children: [
          if (icon != null) ...[icon, const SizedBox(width: 6)],
          Expanded(child: Text(label, style: labelStyle)),
          const SizedBox(width: 10),
          Text(value, style: valueStyle),
        ]);

    final note = refund > 0 ? s.removeRefundNote : (cod ? s.removeCodNote : null);
    return [
      const SizedBox(height: 12),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: col.surfaceSoft, borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          row(paid ? s.removeAmountPaid : s.removeCurrentTotal, money(current),
            font.copyWith(fontSize: 13, color: col.ink2),
            font.copyWith(fontSize: 13, fontWeight: FontWeight.w700, color: col.ink0)),
          const SizedBox(height: 7),
          row(s.removeAfter, money(next),
            font.copyWith(fontSize: 14, fontWeight: FontWeight.w800, color: col.ink0),
            font.copyWith(fontSize: 14, fontWeight: FontWeight.w800, color: col.ink0)),
          if (refund > 0) ...[
            const SizedBox(height: 7),
            row(s.removeRefundWallet, money(refund),
              font.copyWith(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.teal700),
              font.copyWith(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.teal700),
              icon: const Icon(Icons.account_balance_wallet_outlined, size: 16, color: AppColors.teal700)),
          ],
        ]),
      ),
      if (note != null) ...[
        const SizedBox(height: 10),
        Text(note, style: font.copyWith(fontSize: 12.5, height: 1.55, color: col.ink2)),
      ],
    ];
  }
}

/// Three grey lines in place of the totals while the dry_run loads.
class _RemoveTotalsSkeleton extends StatelessWidget {
  const _RemoveTotalsSkeleton();

  @override
  Widget build(BuildContext context) {
    final col = context.col;
    Widget bar(double w) => Container(width: w, height: 11,
        decoration: BoxDecoration(color: col.border, borderRadius: BorderRadius.circular(6)));
    Widget line(double label, double value) => SizedBox(
        height: 18,
        child: Row(children: [bar(label), const Spacer(), bar(value)]));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: col.surfaceSoft, borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        line(120, 56),
        const SizedBox(height: 7),
        line(80, 64),
        const SizedBox(height: 7),
        line(140, 48),
      ]),
    );
  }
}

/// The server's refusal (422), in its own words, inside the sheet.
class _RemoveErrorBox extends StatelessWidget {
  final String message;
  const _RemoveErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final red = _removeRed(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF3A1A18) : const Color(0xFFFEECEB),
        border: Border.all(color: dark ? const Color(0xFF7A2E28) : const Color(0xFFF5B5AE), width: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(Icons.error_outline_rounded, size: 18, color: red)),
        const SizedBox(width: 10),
        Expanded(child: Text(message,
          style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal'],
            fontSize: 13.5, height: 1.55, fontWeight: FontWeight.w500, color: red))),
      ]),
    );
  }
}
