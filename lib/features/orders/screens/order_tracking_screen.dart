import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/order.dart';
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
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/orders'),
          icon: const Icon(Icons.arrow_back, color: AppColors.ink0)),
        titleSpacing: 0,
        title: orderAsync.maybeWhen(
          data: (o) => Text('الطلب ${o.orderNumber}',
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
          orElse: () => const Text('تفاصيل الطلب',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        ),
      ),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, __) => const Center(child: Text('تعذر تحميل الطلب')),
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
    final isActive = ['shipped', 'processing', 'confirmed'].contains(order.status);

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
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('حالة الطلب',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            _Timeline(status: order.status),
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(children: [
            _SumRow('المجموع الفرعي', '${order.subtotal.toStringAsFixed(0)} د.ل'),
            if (order.shippingCost > 0)
              _SumRow('الشحن', '${order.shippingCost.toStringAsFixed(0)} د.ل'),
            if (order.discount > 0)
              _SumRow('الخصم', '-${order.discount.toStringAsFixed(0)} د.ل',
                color: AppColors.success),
            const Divider(height: 20, color: AppColors.border),
            _SumRow('الإجمالي', '${order.total.toStringAsFixed(0)} د.ل', bold: true),
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
              label: const Text('إرجاع منتجات',
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                side: const BorderSide(color: AppColors.border),
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
            label: const Text('مساعدة بخصوص هذا الطلب',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              side: const BorderSide(color: AppColors.border),
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
        color: AppColors.ink0,
        borderRadius: BorderRadius.circular(10),
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
            const Text('في الطريق',
              style: TextStyle(fontFamily: 'Cairo', color: AppColors.primary,
                fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
          ]),
          const SizedBox(height: 8),
          const Text('قيد التوصيل',
            style: TextStyle(color: Colors.white,
              fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('1-2 يوم · طرابلس',
            style: TextStyle(color: Colors.white70, fontSize: 13)),
        ]),
      ]),
    );
  }
}

class _Timeline extends StatelessWidget {
  final String status;
  const _Timeline({required this.status});

  static const _steps = [
    ('pending',     'تم استلام الطلب'),
    ('confirmed',   'مؤكد'),
    ('processing',  'قيد التجهيز'),
    ('shipped',     'في الطريق'),
    ('delivered',   'تم التسليم'),
  ];

  int get _currentIdx {
    for (int i = 0; i < _steps.length; i++) {
      if (_steps[i].$1 == status) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentIdx;
    return Column(
      children: List.generate(_steps.length, (i) {
        final isDone = i <= current;
        final isActive = i == current;
        final isLast = i == _steps.length - 1;
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
                    color: isDone ? AppColors.primary : AppColors.borderStrong,
                    width: 2),
                ),
                child: isDone
                    ? const Icon(Icons.check_rounded, size: 12, color: AppColors.ink0)
                    : null,
              ),
              if (!isLast)
                Container(
                  width: 2, height: 40,
                  color: isDone && (i + 1) <= current
                      ? AppColors.primary
                      : AppColors.border),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 1, bottom: isLast ? 0 : 20),
              child: Text(_steps[i].$2,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? AppColors.primary : AppColors.ink0)),
            ),
          ),
        ]);
      }),
    );
  }
}

Widget _SummaryRow(String label, String value, {Color? color, bool bold = false}) =>
  Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(fontSize: 14)),
      Text(value, style: TextStyle(
        fontFamily: 'PlusJakartaSans', fontSize: 14,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
        color: color ?? AppColors.ink0)),
    ]),
  );

Widget _SumRow(String label, String value, {Color? color, bool bold = false}) =>
  _SummaryRow(label, value, color: color, bold: bold);

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
            ? const Border(bottom: BorderSide(color: AppColors.border))
            : null,
      ),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 44, height: 44,
            child: item.productImage != null
                ? CachedNetworkImage(imageUrl: item.productImage!, fit: BoxFit.cover)
                : Container(color: AppColors.bg,
                    child: const Icon(Icons.image_outlined, color: AppColors.ink4)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.productNameAr, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, height: 1.3)),
            if (item.variationLabel != null)
              Text(item.variationLabel!,
                style: const TextStyle(fontSize: 11, color: AppColors.ink3)),
            Text('×${item.quantity}',
              style: const TextStyle(fontFamily: 'PlusJakartaSans',
                fontSize: 11, color: AppColors.ink2)),
          ]),
        ),
        Text('${item.total.toStringAsFixed(0)} د.ل',
          style: const TextStyle(fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w700, fontSize: 13)),
      ]),
    );
  }
}
