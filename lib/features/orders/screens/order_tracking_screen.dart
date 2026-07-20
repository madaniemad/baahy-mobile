import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/order.dart';
import '../../../core/models/product.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/l10n.dart';
import '../../../core/utils/navigation.dart';
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
      subject: 'فاتورة ${order.orderNumber}',
      sharePositionOrigin: origin,
    ));
  } catch (e, st) {
    Sentry.captureException(e, stackTrace: st);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحميل الفاتورة، حاول مجدداً')),
      );
    }
  }
}

final _orderDetailProvider = FutureProvider.family<Order, int>((ref, id) async {
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
              tooltip: 'اسأل عن طلبك',
              onPressed: () => safePush(context, '/chat',
                  extra: 'أحتاج مساعدة بخصوص طلب رقم ${o.orderNumber}'),
            ),
            orElse: () => IconButton(
              icon: const Icon(Icons.auto_awesome_outlined, size: 22),
              tooltip: 'اسأل عن طلبك',
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
      final raw = (res.data['data'] as List? ?? []);
      final products = {for (final j in raw) (j['id'] as int): Product.fromJson(j)};
      final cart = ref.read(cartProvider.notifier);
      for (final group in widget.order.vendorGroups) {
        for (final item in group.items) {
          final p = products[item.productId];
          if (p == null) continue;
          ProductVariation? v;
          if (item.variationId != null) {
            try { v = p.variations.firstWhere((vv) => vv.id == item.variationId); }
            catch (_) {}
          }
          await cart.add(p, variation: v, qty: item.quantity);
        }
      }
      if (context.mounted) context.go('/cart');
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
    final isActive = ['pending_confirmation', 'pending_vendor', 'pending', 'confirmed', 'processing',
        'fulfilled', 'shipped', 'out_for_delivery'].contains(order.status);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Hero ETA card for active orders
        if (isActive) ...[
          _HeroCard(order: order),
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
              child: Text(group.vendor.storeName,
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
                  ),
                ).toList(),
              ),
            ),
            const SizedBox(height: 12),
          ],
        )),

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
            Divider(height: 20, color: context.col.border),
            _SumRow(context.s.totalLabel, '${fmtPrice(order.total)} ${context.s.lydUnit}', bold: true, ctx: context),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(context.tr('طريقة الدفع', 'Payment method'),
                style: TextStyle(fontSize: 13.5, color: context.col.ink2,
                  fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal'])),
              Text(_paymentMethodLabel(context, order.paymentMethod),
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: context.col.ink0,
                  fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal'])),
            ]),
          ]),
        ),

        // Actions
        if (order.status == 'delivered') ...[
          const SizedBox(height: 14),
          if (order.returnEligible) ...[
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
                    ? 'متبقٍ $daysLeft يوم للإرجاع — ينتهي $dateStr'
                    : '$daysLeft day${daysLeft == 1 ? '' : 's'} left to return — deadline $dateStr';
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
                onPressed: () => safePush(context, '/orders/${order.id}/return',
                  extra: order.returnDeadline),
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
            onPressed: () => safePush(context, '/chat',
                extra: 'أحتاج مساعدة بخصوص طلب رقم ${order.orderNumber}'),
            icon: const Icon(Icons.help_outline_rounded, size: 16),
            label: Text(context.s.orderHelp,
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

class _HeroCard extends StatelessWidget {
  final Order order;
  const _HeroCard({required this.order});

  _HeroInfo _info(BuildContext context) {
    final s = order.status;
    if (s == 'pending_confirmation' || s == 'pending_vendor') {
      return _HeroInfo(
        icon: Icons.hourglass_empty_rounded,
        badge: context.s.isAr ? 'بانتظار التأكيد' : 'Pending Confirmation',
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
    if (s == 'processing' || s == 'fulfilled') {
      return _HeroInfo(
        icon: Icons.inventory_2_outlined,
        badge: context.s.isAr ? 'قيد التجهيز' : 'Processing',
        title: context.s.isAr ? 'جارٍ تجهيز طلبك' : 'Preparing Your Order',
        subtitle: context.s.isAr ? 'طلبك على وشك الشحن' : 'Getting ready to ship',
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
    'pending_confirmation': 0,
    'pending_vendor': 0,
    'fulfilled': 2,
    'out_for_delivery': 3,
    'cancelled': 0,
    'returned': 4,
    'refunded': 4,
  };

  // Each step maps to one or more possible to_status values in history
  static const _stepAliases = {
    'pending':    ['pending', 'pending_confirmation', 'pending_vendor'],
    'confirmed':  ['confirmed'],
    'processing': ['processing', 'fulfilled'],
    'shipped':    ['shipped', 'out_for_delivery'],
    'delivered':  ['delivered'],
  };

  int _currentIdx(List<(String, String)> steps) {
    if (_extraMap.containsKey(status)) return _extraMap[status]!;
    for (int i = 0; i < steps.length; i++) {
      if (steps[i].$1 == status) return i;
    }
    return 0;
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
      ('pending',     context.s.stepPending),
      ('confirmed',   context.s.stepConfirmed),
      ('processing',  context.s.stepProcessing),
      ('shipped',     context.s.stepShipped),
      ('delivered',   context.s.stepDelivered),
    ];
    final current = _currentIdx(steps);
    return Column(
      children: List.generate(steps.length, (i) {
        final isDone = i <= current;
        final isActive = i == current;
        final isLast = i == steps.length - 1;
        final ts = isDone ? _timestampFor(steps[i].$1, i == 0) : null;
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 22,
            child: Column(children: [
              Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone ? AppColors.primary : Colors.transparent,
                  border: Border.all(
                    color: isDone ? AppColors.primary : context.col.borderStrong,
                    width: 2),
                ),
                child: isDone
                    ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                    : null,
              ),
              if (!isLast)
                Container(
                  width: 2, height: ts != null ? 50 : 40,
                  color: isDone && (i + 1) <= current
                      ? AppColors.primary
                      : context.col.border),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 1, bottom: isLast ? 0 : (ts != null ? 24 : 20)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(steps[i].$2,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive ? AppColors.primary : context.col.ink0)),
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

String _paymentMethodLabel(BuildContext ctx, String m) {
  final ar = ctx.isAr;
  switch (m) {
    case 'cash_on_delivery':
    case 'cash':     return ar ? 'الدفع عند الاستلام' : 'Cash on Delivery';
    case 'wallet':   return ar ? 'المحفظة'            : 'Wallet';
    case 'tadawel':  return ar ? 'تداول'              : 'Tadawel';
    case 'moamlat':  return ar ? 'بطاقة مصرفية'            : 'Bank Card';
    case 'mobicash': return ar ? 'موبي كاش'           : 'Mobicash';
    case 'paypal':   return 'PayPal';
    default:         return m.isEmpty ? (ar ? 'غير محدد' : 'Not specified') : m;
  }
}

class _OrderItemRow extends StatelessWidget {
  final OrderItem item;
  final bool hasBorder;
  const _OrderItemRow({required this.item, required this.hasBorder});

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
                  ? CachedNetworkImage(
                      imageUrl: item.productImage!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(color: context.col.bg,
                          child: Icon(Icons.image_outlined, color: context.col.ink4)),
                      placeholder: (_, __) => Container(color: context.col.bg))
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
