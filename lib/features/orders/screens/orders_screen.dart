import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/cart.dart';
import '../../../core/models/order.dart';
import '../../../core/models/product.dart';
import '../../../core/providers/reorder_provider.dart';
import '../../../core/utils/l10n.dart';
import '../../../core/utils/navigation.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/app_button.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

final _ordersProvider = FutureProvider.autoDispose<List<Order>>((ref) async {
  final res = await ApiClient.instance.dio.get('/orders', queryParameters: {'per_page': 50});
  final body = res.data;
  // API may return paginated {data:{data:[...]}} or flat {data:[...]}
  List? raw;
  final d = body['data'];
  if (d is Map) {
    raw = d['data'] as List?;
  } else if (d is List) {
    raw = d;
  }
  return raw?.map((o) => Order.fromJson(o as Map<String, dynamic>)).toList() ?? [];
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

  static const _activeStatuses = [
    'pending_confirmation', 'pending', 'confirmed',
    'processing', 'fulfilled', 'shipped', 'out_for_delivery',
  ];

  List<Order> _filtered(List<Order> all) {
    switch (_tab) {
      case 'active':
        return all.where((o) => _activeStatuses.contains(o.status)).toList();
      case 'delivered':
        return all.where((o) =>
          ['delivered', 'returned', 'refunded', 'cancelled'].contains(o.status)).toList();
      default:
        return all;
    }
  }

  Future<void> _reorder(BuildContext context, Order order) async {
    final snack = ScaffoldMessenger.of(context);
    final isAr  = context.isAr;
    snack.showSnackBar(SnackBar(
      content: Text(context.s.addingToCart),
      duration: const Duration(seconds: 2),
    ));

    // Fetch current product state for each order item
    final results = await Future.wait(
      order.allItems.map((item) async {
        try {
          final res = await ApiClient.instance.dio.get('/products/${item.productId}');
          return (
            product: Product.fromJson(res.data['data']),
            originalQty: item.quantity,
            originalPrice: item.price,
            nameAr: item.productNameAr.isNotEmpty ? item.productNameAr : item.productName,
            variationId: item.variationId,
          );
        } catch (e, st) {
          Sentry.captureException(e, stackTrace: st);
          return null;
        }
      }),
    );

    if (!context.mounted) return;

    // Classify each item — handles simple products and variable products separately
    final toAdd   = <({Product product, ProductVariation? variation, int qty})>[];
    final notices = <_ReorderNotice>[];

    for (var i = 0; i < results.length; i++) {
      final r = results[i];
      if (r == null) {
        final name = i < order.allItems.length
            ? (order.allItems[i].productNameAr.isNotEmpty
                ? order.allItems[i].productNameAr
                : order.allItems[i].productName)
            : '—';
        notices.add(_ReorderNotice(name: name, kind: _NoticeKind.deleted));
        continue;
      }

      final p    = r.product;
      final name = r.nameAr;

      if (r.variationId != null) {
        // Variable product — check the specific variation's stock
        final matches = p.variations.where((v) => v.id == r.variationId);
        if (matches.isEmpty) {
          notices.add(_ReorderNotice(name: name, kind: _NoticeKind.deleted));
          continue;
        }
        final variation = matches.first;
        if (!variation.inStock || variation.stockQuantity <= 0) {
          notices.add(_ReorderNotice(name: name, kind: _NoticeKind.outOfStock));
          continue;
        }
        final stock  = variation.stockQuantity;
        final addQty = stock < r.originalQty ? stock : r.originalQty;
        if (stock < r.originalQty) {
          notices.add(_ReorderNotice(
            name: name, kind: _NoticeKind.qtyReduced,
            originalQty: r.originalQty, actualQty: addQty));
        }
        final currentPrice = variation.salePrice ?? variation.price;
        final priceDiff    = (currentPrice - r.originalPrice).abs();
        if (priceDiff > r.originalPrice * 0.01) {
          notices.add(_ReorderNotice(
            name: name, kind: _NoticeKind.priceChanged,
            originalPrice: r.originalPrice, currentPrice: currentPrice));
        }
        if (addQty > 0) toAdd.add((product: p, variation: variation, qty: addQty));
      } else {
        // Simple product
        if (!p.inStock) {
          notices.add(_ReorderNotice(name: name, kind: _NoticeKind.outOfStock));
          continue;
        }
        final stock  = p.stockQuantity ?? r.originalQty;
        final addQty = stock < r.originalQty ? stock : r.originalQty;
        if (stock < r.originalQty) {
          notices.add(_ReorderNotice(
            name: name, kind: _NoticeKind.qtyReduced,
            originalQty: r.originalQty, actualQty: addQty));
        }
        final currentPrice = p.displayPrice;
        final priceDiff    = (currentPrice - r.originalPrice).abs();
        if (priceDiff > r.originalPrice * 0.01) {
          notices.add(_ReorderNotice(
            name: name, kind: _NoticeKind.priceChanged,
            originalPrice: r.originalPrice, currentPrice: currentPrice));
        }
        if (addQty > 0) toAdd.add((product: p, variation: null, qty: addQty));
      }
    }

    // Nothing available at all → show error, stay on page
    if (toAdd.isEmpty) {
      snack.showSnackBar(SnackBar(
        content: Text(context.s.noItemsInStock),
        backgroundColor: AppColors.warn,
      ));
      return;
    }

    if (!context.mounted) return;

    // If some items have notices, warn the user before proceeding
    if (notices.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(isAr ? 'ملاحظات على إعادة الطلب' : 'Reorder Notes',
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAr
                    ? 'سيتم طلب ${toAdd.length} من ${order.allItems.length} منتجات.'
                    : '${toAdd.length} of ${order.allItems.length} items will be ordered.',
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                ),
                const SizedBox(height: 12),
                ...notices.map((n) => _NoticeRow(notice: n, isAr: isAr)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(isAr ? 'إلغاء' : 'Cancel',
                style: TextStyle(fontFamily: 'Cairo', color: context.col.ink2)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(isAr ? 'متابعة' : 'Continue',
                style: const TextStyle(fontFamily: 'Cairo', color: AppColors.primary,
                  fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }

    // Build CartItems for the reorder session (no cart modification)
    final sessionItems = toAdd.map((r) => CartItem(
      productId: r.product.id,
      variationId: r.variation?.id,
      product: r.product,
      variation: r.variation,
      quantity: r.qty,
    )).toList();

    // Set reorder session and navigate directly to checkout
    ref.read(reorderSessionProvider.notifier).state = ReorderSession(
      items: sessionItems,
      address: order.shippingAddress,
      paymentMethod: order.paymentMethod,
    );

    if (context.mounted) safePush(context, '/checkout');
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(_ordersProvider);

    return Scaffold(
      backgroundColor: context.col.bg,
      appBar: AppBar(
        backgroundColor: context.col.surface, elevation: 0,
        title: Text(context.s.myOrders,
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back, color: context.col.ink0)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: context.col.surface,
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
                          color: isActive ? AppColors.primary : context.col.surfaceSoft,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(t.$2,
                          style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600,
                            color: isActive ? Colors.black87 : context.col.ink1)),
                      ),
                    );
                  }).toList(),
                ),
              ),
              Divider(height: 1, color: context.col.border),
            ]),
          ),
        ),
      ),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, __) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(context.s.loadFailed, style: TextStyle(color: context.col.ink2)),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => ref.invalidate(_ordersProvider),
            child: Text(context.s.retry),
          ),
        ])),
        data: (orders) {
          final list = _filtered(orders);
          if (list.isEmpty) {
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async => ref.invalidate(_ordersProvider),
              child: ListView(children: [
                const SizedBox(height: 120),
                Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.receipt_long_outlined, size: 72, color: context.col.ink4),
                    const SizedBox(height: 12),
                    Text(context.s.noOrders,
                      style: TextStyle(fontSize: 16, color: context.col.ink2)),
                    const SizedBox(height: 20),
                    AppButton(
                      label: context.s.startShopping,
                      width: 200,
                      onTap: () => context.go('/home'),
                    ),
                  ]),
                ),
              ]),
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.invalidate(_ordersProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _OrderCard(
                order: list[i],
                onReorder: list[i].status == 'delivered'
                    ? () => _reorder(context, list[i])
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback? onReorder;
  const _OrderCard({required this.order, this.onReorder});

  static Color _statusColor(String s) {
    switch (s) {
      case 'delivered': return AppColors.success;
      case 'cancelled':
      case 'returned': return AppColors.danger;
      case 'shipped': return AppColors.info;
      default: return AppColors.warn;
    }
  }

  static Color _statusBg(String s) {
    switch (s) {
      case 'delivered': return AppColors.success.withValues(alpha: 0.15);
      case 'cancelled':
      case 'returned': return AppColors.danger.withValues(alpha: 0.15);
      case 'shipped': return AppColors.info.withValues(alpha: 0.15);
      default: return AppColors.warn.withValues(alpha: 0.15);
    }
  }

  String _statusLabel(BuildContext context, String s) =>
      context.s.statusLabel(s);

  bool get _isActive => _OrdersScreenState._activeStatuses.contains(order.status);

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
          color: context.col.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: _isActive ? AppColors.primary.withValues(alpha: 0.4) : context.col.border),
          boxShadow: _isActive ? AppShadows.shadowCard : null,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 56, height: 56,
                child: firstImage != null
                    ? CachedNetworkImage(imageUrl: firstImage, fit: BoxFit.cover)
                    : Container(color: context.col.surfaceSoft,
                        child: Icon(Icons.shopping_bag_outlined,
                          color: context.col.ink3, size: 24)),
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(6),
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
                    style: TextStyle(fontFamily: 'PlusJakartaSans',
                      fontSize: 11.5, color: context.col.ink3)),
                  Text('  ·  ', style: TextStyle(color: context.col.ink4)),
                  Text('${order.allItems.length} ${context.s.items}',
                    style: TextStyle(fontSize: 11.5, color: context.col.ink3)),
                ]),
                const SizedBox(height: 6),
                Text('${order.total.toStringAsFixed(0)} ${context.s.lyd}',
                  style: TextStyle(fontFamily: 'PlusJakartaSans',
                    fontSize: 14, fontWeight: FontWeight.w700, color: context.col.ink0)),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, color: context.col.ink3, size: 20),
          ]),
          if (onReorder != null) ...[
            const SizedBox(height: 10),
            Divider(height: 1, color: context.col.border),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onReorder,
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.col.ink0,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  side: BorderSide(color: context.col.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.refresh_rounded, size: 16, color: context.col.ink0),
                    const SizedBox(width: 6),
                    Text(context.s.reorder,
                      style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700,
                        fontSize: 13, color: context.col.ink0)),
                  ],
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

// ── Reorder notice helpers ────────────────────────────────────────────────────

enum _NoticeKind { deleted, outOfStock, qtyReduced, priceChanged }

class _ReorderNotice {
  final String name;
  final _NoticeKind kind;
  final int? originalQty;
  final int? actualQty;
  final double? originalPrice;
  final double? currentPrice;
  const _ReorderNotice({
    required this.name, required this.kind,
    this.originalQty, this.actualQty,
    this.originalPrice, this.currentPrice,
  });
}

class _NoticeRow extends StatelessWidget {
  final _ReorderNotice notice;
  final bool isAr;
  const _NoticeRow({required this.notice, required this.isAr});

  @override
  Widget build(BuildContext context) {
    final (icon, color, detail) = switch (notice.kind) {
      _NoticeKind.deleted      => (Icons.delete_outline, AppColors.danger,
          isAr ? 'تم حذف المنتج' : 'Product no longer exists'),
      _NoticeKind.outOfStock   => (Icons.remove_shopping_cart_outlined, AppColors.warn,
          isAr ? 'نفدت الكمية' : 'Out of stock'),
      _NoticeKind.qtyReduced   => (Icons.info_outline, AppColors.primary,
          isAr
            ? 'الكمية المتاحة ${notice.actualQty} (طلبت ${notice.originalQty})'
            : 'Only ${notice.actualQty} available (ordered ${notice.originalQty})'),
      _NoticeKind.priceChanged => (Icons.price_change_outlined,
          (notice.currentPrice ?? 0) > (notice.originalPrice ?? 0)
              ? AppColors.danger : AppColors.success,
          isAr
            ? 'السعر تغير: ${notice.originalPrice?.toStringAsFixed(0)} ← ${notice.currentPrice?.toStringAsFixed(0)} د.ل'
            : 'Price changed: ${notice.originalPrice?.toStringAsFixed(0)} → ${notice.currentPrice?.toStringAsFixed(0)} LYD'),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(notice.name,
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5,
                fontWeight: FontWeight.w600)),
            Text(detail,
              style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: color)),
          ]),
        ),
      ]),
    );
  }
}
