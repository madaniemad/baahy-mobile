import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/order.dart';
import '../../../core/utils/l10n.dart';
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

  List<(String, String)> _tabs(BuildContext context) => [
    ('all', context.s.allOrders),
    ('active', context.s.activeOrders),
    ('delivered', context.s.completedOrders),
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
        title: Text(context.s.myOrders,
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
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
                  children: _tabs(context).map((t) {
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
        error: (_, __) => Center(child: Text(context.s.loadFailed)),
        data: (orders) {
          final list = _filtered(orders);
          if (list.isEmpty) {
            return Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.receipt_long_outlined, size: 72, color: AppColors.ink4),
                const SizedBox(height: 12),
                Text(context.s.noOrders,
                  style: const TextStyle(fontSize: 16, color: AppColors.ink2)),
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
      default: return AppColors.warn;
    }
  }

  static Color _statusBg(String s) {
    switch (s) {
      case 'delivered': return const Color(0xFFEAF6F0);
      case 'cancelled':
      case 'returned': return const Color(0xFFFDECE9);
      case 'shipped': return AppColors.teal50bg;
      default: return const Color(0xFFFFF1EB);
    }
  }

  String _statusLabel(BuildContext context, String s) =>
      context.s.statusLabel(s);

  bool get _isActive => ['pending', 'confirmed', 'processing', 'shipped'].contains(order.status);

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(order.status);
    final statusBg = _statusBg(order.status);
    final firstImage = order.allItems.isNotEmpty ? order.allItems.first.productImage : null;

    return GestureDetector(
      onTap: () => safePush(context, '/orders/${order.id}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _isActive ? AppColors.teal100bg : AppColors.border),
          boxShadow: _isActive ? AppShadows.shadowCard : null,
        ),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 56, height: 56,
              child: firstImage != null
                  ? CachedNetworkImage(imageUrl: firstImage, fit: BoxFit.cover)
                  : Container(color: AppColors.surfaceSoft,
                      child: const Icon(Icons.shopping_bag_outlined,
                        color: AppColors.ink3, size: 24)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(order.orderNumber,
                    style: const TextStyle(fontFamily: 'PlusJakartaSans',
                      fontWeight: FontWeight.w700, fontSize: 14)),
                ),
                // Status pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_statusLabel(context, order.status),
                    style: TextStyle(color: statusColor,
                      fontWeight: FontWeight.w700, fontSize: 11)),
                ),
              ]),
              const SizedBox(height: 5),
              Row(children: [
                Text(
                  '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}',
                  style: const TextStyle(fontFamily: 'PlusJakartaSans',
                    fontSize: 11.5, color: AppColors.ink3)),
                const Text('  ·  ', style: TextStyle(color: AppColors.ink4)),
                Text('${order.allItems.length} ${context.s.items}',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.ink3)),
              ]),
              const SizedBox(height: 6),
              Text('${order.total.toStringAsFixed(0)} ${context.s.lyd}',
                style: const TextStyle(fontFamily: 'PlusJakartaSans',
                  fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink0)),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.ink3, size: 20),
        ]),
      ),
    );
  }
}
