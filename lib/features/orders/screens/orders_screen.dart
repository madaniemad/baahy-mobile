import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/order.dart';
import '../../../core/utils/navigation.dart';
import '../../../shared/theme/app_theme.dart';

final _ordersProvider = FutureProvider<List<Order>>((ref) async {
  final res = await ApiClient.instance.dio.get('/orders');
  return (res.data['data']['data'] as List?)
      ?.map((o) => Order.fromJson(o)).toList() ?? [];
});

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  String _tab = 'all';

  static const _tabs = [
    ('all', 'الكل'),
    ('active', 'نشطة'),
    ('delivered', 'مكتملة'),
  ];

  List<Order> _filtered(List<Order> all) {
    switch (_tab) {
      case 'active':
        return all.where((o) =>
          ['pending', 'confirmed', 'processing', 'shipped'].contains(o.status)).toList();
      case 'delivered':
        return all.where((o) => o.status == 'delivered').toList();
      default:
        return all;
    }
  }

  @override
  Widget build(BuildContext context) {
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            child: Column(children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: _tabs.map((t) {
                    final isActive = _tab == t.$1;
                    return GestureDetector(
                      onTap: () => setState(() => _tab = t.$1),
                      child: Container(
                        margin: const EdgeInsets.only(right: 6, bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                        decoration: BoxDecoration(
                          color: isActive ? AppColors.ink0 : AppColors.surfaceSoft,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(t.$2,
                          style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600,
                            color: isActive ? Colors.white : AppColors.ink1)),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
            ]),
          ),
        ),
      ),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, __) => const Center(child: Text('تعذر تحميل الطلبات')),
        data: (orders) {
          final list = _filtered(orders);
          if (list.isEmpty) {
            return const Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.receipt_long_outlined, size: 72, color: AppColors.ink4),
                SizedBox(height: 12),
                Text('لا توجد طلبات',
                  style: TextStyle(fontSize: 16, color: AppColors.ink2)),
              ]),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _OrderCard(order: list[i]),
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  const _OrderCard({required this.order});

  static Color _statusColor(String s) {
    switch (s) {
      case 'delivered': return AppColors.success;
      case 'cancelled':
      case 'returned': return AppColors.danger;
      case 'shipped': return AppColors.primary;
      default: return const Color(0xFFE8A020);
    }
  }

  static String _statusLabel(String s) {
    switch (s) {
      case 'pending': return 'قيد الانتظار';
      case 'confirmed': return 'مؤكد';
      case 'processing': return 'قيد التجهيز';
      case 'shipped': return 'في الطريق';
      case 'delivered': return 'تم التسليم';
      case 'cancelled': return 'ملغي';
      case 'returned': return 'مُرجَع';
      default: return s;
    }
  }

  bool get _isActive => ['pending', 'confirmed', 'processing', 'shipped'].contains(order.status);

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(order.status);
    final firstImage = order.allItems.isNotEmpty ? order.allItems.first.productImage : null;

    return GestureDetector(
      onTap: () => safePush(context, '/orders/${order.id}'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _isActive ? const Color(0xFFEAF8F8) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _isActive ? AppColors.primary : AppColors.border),
        ),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 54, height: 54,
              child: firstImage != null
                  ? CachedNetworkImage(imageUrl: firstImage, fit: BoxFit.cover)
                  : Container(color: AppColors.surfaceSoft,
                      child: const Icon(Icons.inventory_2_outlined,
                        color: AppColors.ink3, size: 24)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(order.orderNumber,
                style: const TextStyle(fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 3),
              Row(children: [
                Text(_statusLabel(order.status),
                  style: TextStyle(color: statusColor,
                    fontWeight: FontWeight.w600, fontSize: 12.5)),
                const Text(' · ', style: TextStyle(color: AppColors.ink3)),
                Text(
                  '${order.createdAt.day}/${order.createdAt.month}',
                  style: const TextStyle(fontFamily: 'PlusJakartaSans',
                    fontSize: 12, color: AppColors.ink3)),
                const Text(' · ', style: TextStyle(color: AppColors.ink3)),
                Text('${order.allItems.length} منتج',
                  style: const TextStyle(fontSize: 12, color: AppColors.ink3)),
              ]),
              const SizedBox(height: 4),
              Text('${order.total.toStringAsFixed(0)} د.ل',
                style: const TextStyle(fontFamily: 'PlusJakartaSans',
                  fontSize: 12, color: AppColors.ink2)),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.ink3, size: 20),
        ]),
      ),
    );
  }
}
