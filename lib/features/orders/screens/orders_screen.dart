import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/order.dart';
import '../../../shared/theme/app_theme.dart';

final _ordersProvider = FutureProvider<List<Order>>((ref) async {
  final res = await ApiClient.instance.dio.get('/orders');
  return (res.data['data']['data'] as List?)
      ?.map((o) => Order.fromJson(o)).toList() ?? [];
});

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(_ordersProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        title: const Text('طلباتي',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.ink0)),
      ),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, __) => const Center(child: Text('تعذر تحميل الطلبات')),
        data: (orders) => orders.isEmpty
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 72, color: AppColors.ink4),
                    SizedBox(height: 12),
                    Text('لا توجد طلبات حتى الآن',
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 16, color: AppColors.ink2)),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: orders.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _OrderCard(order: orders[i]),
              ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  const _OrderCard({required this.order});

  Color _statusColor(String s) {
    switch (s) {
      case 'delivered': return AppColors.success;
      case 'cancelled':
      case 'returned': return AppColors.danger;
      case 'shipped': return AppColors.primary;
      default: return const Color(0xFFE8A020);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/orders/${order.id}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppShadows.shadowCard,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(order.orderNumber,
                  style: const TextStyle(fontFamily: 'PlusJakartaSans',
                    fontWeight: FontWeight.w700, fontSize: 14)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(order.status).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(order.statusAr,
                    style: TextStyle(color: _statusColor(order.status),
                      fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${order.allItems.length} منتج',
              style: const TextStyle(fontSize: 13, color: AppColors.ink2),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}',
                  style: const TextStyle(fontFamily: 'PlusJakartaSans',
                    fontSize: 12, color: AppColors.ink3),
                ),
                Text(
                  '${order.total.toStringAsFixed(0)} د.ل',
                  style: const TextStyle(fontFamily: 'PlusJakartaSans',
                    fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
