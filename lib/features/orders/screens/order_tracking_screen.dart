import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/order.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/l10n.dart';
import '../../../core/utils/navigation.dart';
import '../../../shared/theme/app_theme.dart';

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
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
          orElse: () => Text(context.s.orderDetails,
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome_outlined, size: 22),
            tooltip: 'اسأل عن طلبك',
            onPressed: () => safePush(context, '/assistant'),
          ),
          orderAsync.maybeWhen(
            data: (o) => IconButton(
              icon: Icon(Icons.download_outlined, size: 22, color: context.col.ink0),
              tooltip: context.s.downloadInvoice,
              onPressed: () async {
                final url = Uri.parse(
                    '${ApiClient.instance.dio.options.baseUrl}/orders/${o.id}/invoice');
                if (await canLaunchUrl(url)) await launchUrl(url);
              },
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

class _OrderBody extends StatelessWidget {
  final Order order;
  const _OrderBody({required this.order});

  @override
  Widget build(BuildContext context) {
    final isActive = ['pending_confirmation', 'pending', 'confirmed', 'processing',
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
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: context.col.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.s.orderStatus,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            _Timeline(status: order.status, history: order.statusHistory),
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
                borderRadius: BorderRadius.circular(6),
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
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: context.col.border),
          ),
          child: Column(children: [
            _SumRow(context.s.subtotalOrder, '${fmtPrice(order.subtotal)} ${context.s.lydUnit}', ctx: context),
            if (order.shippingCost > 0)
              _SumRow(context.s.shippingLabel, '${fmtPrice(order.shippingCost)} ${context.s.lydUnit}', ctx: context),
            if (order.discount > 0)
              _SumRow(context.s.discountLabel, '-${fmtPrice(order.discount)} ${context.s.lydUnit}',
                color: AppColors.success, ctx: context),
            Divider(height: 20, color: context.col.border),
            _SumRow(context.s.totalLabel, '${fmtPrice(order.total)} ${context.s.lydUnit}', bold: true, ctx: context),
          ]),
        ),

        // Actions
        if (order.status == 'delivered') ...[
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => safePush(context, '/orders/${order.id}/return'),
              icon: const Icon(Icons.assignment_return_outlined, size: 16),
              label: Text(context.s.returnItems,
                style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                side: BorderSide(color: context.col.border),
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.help_outline_rounded, size: 16),
            label: Text(context.s.orderHelp,
              style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.col.ink0,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Stack(children: [
        Positioned(
          right: -40, top: -40,
          child: Container(width: 180, height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.2)),
          ),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.local_shipping_outlined, color: AppColors.primary, size: 14),
            const SizedBox(width: 5),
            Text(context.s.onTheWay,
              style: const TextStyle(fontFamily: 'Cairo', color: AppColors.primary,
                fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
          ]),
          const SizedBox(height: 8),
          Text(context.s.inDelivery,
            style: const TextStyle(color: Colors.white,
              fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(context.s.deliveryPromise,
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ]),
      ]),
    );
  }
}

class _Timeline extends StatelessWidget {
  final String status;
  final List<OrderStatusEntry> history;
  const _Timeline({required this.status, this.history = const []});

  static const _extraMap = {
    'pending_confirmation': 0,
    'fulfilled': 2,
    'out_for_delivery': 3,
    'cancelled': 0,
    'returned': 4,
    'refunded': 4,
  };

  int _currentIdx(List<(String, String)> steps) {
    if (_extraMap.containsKey(status)) return _extraMap[status]!;
    for (int i = 0; i < steps.length; i++) {
      if (steps[i].$1 == status) return i;
    }
    return 0;
  }

  // Find timestamp from history for a given step status
  DateTime? _timestampFor(String stepStatus) {
    for (final entry in history) {
      if (entry.toStatus == stepStatus) return entry.createdAt;
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
        final ts = isDone ? _timestampFor(steps[i].$1) : null;
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
                    ? Icon(Icons.check_rounded, size: 12, color: context.col.ink0)
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
                    '${ts.day}/${ts.month}/${ts.year} ${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}',
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

class _OrderItemRow extends StatelessWidget {
  final OrderItem item;
  final bool hasBorder;
  const _OrderItemRow({required this.item, required this.hasBorder});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: hasBorder
            ? Border(bottom: BorderSide(color: context.col.border))
            : null,
      ),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            width: 44, height: 44,
            child: item.productImage != null
                ? CachedNetworkImage(imageUrl: item.productImage!, fit: BoxFit.cover)
                : Container(color: context.col.bg,
                    child: Icon(Icons.image_outlined, color: context.col.ink4)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.isAr ? item.productNameAr : item.productName, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, height: 1.3)),
            if (item.variationLabel != null)
              Text(item.variationLabel!,
                style: TextStyle(fontSize: 11, color: context.col.ink3)),
            Text('×${item.quantity}',
              style: TextStyle(fontFamily: 'PlusJakartaSans',
                fontSize: 11, color: context.col.ink2)),
          ]),
        ),
        Text('${fmtPrice(item.total)} ${context.s.lydUnit}',
          style: const TextStyle(fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w700, fontSize: 13)),
      ]),
    );
  }
}
