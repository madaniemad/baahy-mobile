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

class OrderTrackingScreen extends ConsumerWidget {
  final int id;
  const OrderTrackingScreen({required this.id, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(_orderDetailProvider(id));

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
          orderAsync.maybeWhen(
            data: (o) => IconButton(
              icon: const Icon(Icons.auto_awesome_outlined, size: 22),
              tooltip: context.tr('اسأل عن طلبك', 'Ask about your order'),
              onPressed: () => safePush(context, '/chat',
                  extra: context.tr('أحتاج مساعدة بخصوص طلب رقم ${o.orderNumber}', 'I need help with order ${o.orderNumber}')),
            ),
            orElse: () => IconButton(
              icon: const Icon(Icons.auto_awesome_outlined, size: 22),
              tooltip: context.tr('اسأل عن طلبك', 'Ask about your order'),
              onPressed: () => safePush(context, '/chat'),
            ),
          ),
          orderAsync.maybeWhen(
            data: (o) => Builder(
              builder: (btnCtx) => IconButton(
                icon: Icon(Icons.download_outlined, size: 22, color: context.col.ink0),
                tooltip: context.s.downloadInvoice,
                onPressed: () => _shareOrderPdf(btnCtx, o),
              ),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, __) => Center(child: Text(context.s.loadOrderFailed)),
        data: (order) => _OrderBody(order: order),
      ),
    );
  }
}

class _OrderBody extends ConsumerStatefulWidget {
  final Order order;
  const _OrderBody({required this.order});

  @override
  ConsumerState<_OrderBody> createState() => _OrderBodyState();
}

class _OrderBodyState extends ConsumerState<_OrderBody> {
  bool _reordering = false;
  bool _cancelling = false;

  /// The statuses OrderController::cancel accepts from the customer.
  static const _cancellable = ['pending_confirmation', 'paid', 'confirmed'];

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
                    try {
                      await ApiClient.instance.dio.post('/reviews', data: {
                        'product_id': item.productId,
                        'rating': rating,
                        if (commentCtrl.text.trim().isNotEmpty) 'comment': commentCtrl.text.trim(),
                      });
                      if (sheetCtx.mounted) Navigator.of(sheetCtx).pop(thanks);
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

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Hero ETA card for active orders
        if (isActive) ...[
          _HeroCard(order: order),
          const SizedBox(height: 14),
        ],

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
                children: group.items.asMap().entries.map((e) =>
                  _OrderItemRow(
                    item: e.value,
                    hasBorder: e.key < group.items.length - 1,
                    onRate: order.status == 'delivered'
                        ? () => _rateItem(context, e.value)
                        : null,
                  ),
                ).toList(),
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
            _SumRow(context.s.totalLabel, '${fmtPrice(order.total)} ${context.s.lydUnit}', bold: true, ctx: context),
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
              _SumRow(
                order.paymentStatus == 'paid'
                    ? context.tr('مدفوع بالكامل', 'Already paid')
                    : context.tr('المبلغ المستحق', 'Amount due'),
                '${fmtPrice(amountDue)} ${context.s.lydUnit}',
                bold: true, ctx: context),
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
        if (_cancellable.contains(order.status)) ...[
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
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            // Self-service first (Emad, 2026-10-18): the sheet offers what fits this order's stage,
            // then the assistant. Never WhatsApp from here.
            onPressed: () {
              final openReturn = kOpenReturnStatuses.contains(ref.read(orderReturnProvider(order.id)).valueOrNull?['status']);
              showOrderHelpSheet(context, ref, orderId: order.id, orderNumber: order.orderNumber, extra: [
                if (order.status == 'delivered' && order.returnEligible && !openReturn)
                  (icon: Icons.assignment_return_outlined, label: context.s.returnItems, color: null, onTap: () async {
                    await safePush(context, '/orders/${order.id}/return', extra: order.returnDeadline);
                    ref.invalidate(orderReturnProvider(order.id));
                  }),
                if (_cancellable.contains(order.status))
                  (icon: Icons.cancel_outlined, label: context.s.cancelOrder, color: AppColors.danger, onTap: () => _cancelOrder(context)),
              ]);
            },
            icon: const Icon(Icons.help_outline_rounded, size: 16),
            label: Text(context.tr('تحتاج مساعدة؟', 'Need help?'),
              style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontWeight: FontWeight.w700)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              side: BorderSide(color: context.col.border),
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
  const _OrderItemRow({required this.item, required this.hasBorder, this.onRate});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _navigateToProduct(context),
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
            ]),
          ),
          Text('${fmtPrice(item.total)} ${context.s.lydUnit}',
            style: const TextStyle(fontFamily: 'PlusJakartaSans',
              fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, size: 16, color: context.col.ink4),
        ]),
      ),
    );
  }

  void _navigateToProduct(BuildContext context) {
    safePush(context, '/product/${item.productId}');
  }
}
