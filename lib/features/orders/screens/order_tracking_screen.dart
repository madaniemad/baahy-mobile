import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/order.dart';
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
        title: const Text('تفاصيل الطلب',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.ink0)),
      ),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, __) => const Center(child: Text('تعذر تحميل الطلب')),
        data: (order) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: AppShadows.shadowCard,
                ),
                child: Column(
                  children: [
                    Text(order.orderNumber,
                      style: const TextStyle(fontFamily: 'PlusJakartaSans',
                        fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    _StatusStepper(status: order.status),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Items
              ...order.vendorGroups.map((group) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(group.vendor.storeName,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: AppShadows.shadowCard,
                    ),
                    child: Column(
                      children: group.items.map((item) => _OrderItemRow(item: item)).toList(),
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
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: AppShadows.shadowCard,
                ),
                child: Column(
                  children: [
                    _Row('المجموع الفرعي', '${order.subtotal.toStringAsFixed(0)} د.ل'),
                    if (order.shippingCost > 0)
                      _Row('الشحن', '${order.shippingCost.toStringAsFixed(0)} د.ل'),
                    if (order.discount > 0)
                      _Row('الخصم', '-${order.discount.toStringAsFixed(0)} د.ل',
                        color: AppColors.success),
                    const Divider(height: 20, color: AppColors.border),
                    _Row('الإجمالي', '${order.total.toStringAsFixed(0)} د.ل', bold: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _Row(String label, String value, {Color? color, bool bold = false}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(value, style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 14,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: color ?? AppColors.ink0)),
        ],
      ),
    );
}

class _StatusStepper extends StatelessWidget {
  final String status;
  const _StatusStepper({required this.status});

  static const _steps = [
    ('pending', 'قيد الانتظار', Icons.hourglass_empty_rounded),
    ('confirmed', 'مؤكد', Icons.check_circle_outline_rounded),
    ('processing', 'قيد التجهيز', Icons.inventory_2_outlined),
    ('shipped', 'تم الشحن', Icons.local_shipping_outlined),
    ('delivered', 'تم التوصيل', Icons.home_outlined),
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
    return Row(
      children: List.generate(_steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final stepIdx = i ~/ 2;
          return Expanded(
            child: Container(
              height: 2,
              color: stepIdx < current ? AppColors.primary : AppColors.border,
            ),
          );
        }
        final stepIdx = i ~/ 2;
        final isDone = stepIdx <= current;
        return Column(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone ? AppColors.primary : Colors.white,
                border: Border.all(
                  color: isDone ? AppColors.primary : AppColors.border, width: 2),
              ),
              child: Icon(_steps[stepIdx].$3, size: 16,
                color: isDone ? Colors.white : AppColors.ink3),
            ),
            const SizedBox(height: 4),
            Text(_steps[stepIdx].$2,
              style: TextStyle(fontSize: 9, color: isDone ? AppColors.primary : AppColors.ink3,
                fontWeight: isDone ? FontWeight.w700 : FontWeight.normal)),
          ],
        );
      }),
    );
  }
}

class _OrderItemRow extends StatelessWidget {
  final OrderItem item;
  const _OrderItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 52, height: 52,
              child: item.productImage != null
                  ? CachedNetworkImage(imageUrl: item.productImage!, fit: BoxFit.cover)
                  : Container(color: AppColors.bg,
                      child: const Icon(Icons.image_outlined, color: AppColors.ink4)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.productNameAr, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                if (item.variationLabel != null)
                  Text(item.variationLabel!,
                    style: const TextStyle(fontSize: 12, color: AppColors.ink3)),
                Text('${item.quantity} × ${item.price.toStringAsFixed(0)} د.ل',
                  style: const TextStyle(fontFamily: 'PlusJakartaSans',
                    fontSize: 12, color: AppColors.ink2)),
              ],
            ),
          ),
          Text('${item.total.toStringAsFixed(0)} د.ل',
            style: const TextStyle(fontFamily: 'PlusJakartaSans',
              fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }
}
