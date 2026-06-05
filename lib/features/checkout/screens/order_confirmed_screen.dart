import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_config_provider.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/theme/app_theme.dart';

class OrderConfirmedScreen extends ConsumerWidget {
  final Map<String, dynamic> data;
  const OrderConfirmedScreen({required this.data, super.key});

  String _deliveryLabel(BuildContext context) {
    final s = context.s;
    // Derive from shipping_rate if present, otherwise fall back to city-based estimate.
    final rate = data['shipping_rate'];
    if (rate is Map) {
      final days = rate['estimated_days'];
      final city = rate['city_name'] ?? rate['city'] ?? '';
      if (days != null && city.isNotEmpty) return '${s.daysUnit(days.toString())} · $city';
      if (days != null) return s.daysUnit(days.toString());
    }
    final city = (data['city'] ?? data['shipping_city'] ?? '').toString();
    final isTripoli = city.toLowerCase().contains('طرابلس') || city.toLowerCase().contains('tripoli');
    final days = isTripoli ? '1-2' : '2-5';
    return '${s.daysUnit(days)}${city.isNotEmpty ? ' · $city' : ''}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderNumber = data['order_number'] ?? '#${data['id']}';
    final orderId = data['id'];
    final rawTotal = data['total'];
    final total = rawTotal is num ? rawTotal.toDouble() : double.tryParse(rawTotal?.toString() ?? '');
    final config = ref.watch(appConfigProvider);
    final rawSubtotal = data['subtotal'];
    final subtotal = rawSubtotal is num ? rawSubtotal.toDouble() : (total ?? 0.0);
    final cashbackAmount = subtotal >= config.cashbackMinOrder
        ? (subtotal * config.cashbackRate / 100).toStringAsFixed(2)
        : null;

    return Scaffold(
      backgroundColor: context.col.bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 96, height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.1),
                        border: Border.all(color: AppColors.primary, width: 3),
                      ),
                      child: const Icon(Icons.check_rounded,
                        color: AppColors.primary, size: 48),
                    ),
                    const SizedBox(height: 16),
                    Text(context.s.orderDone,
                      style: const TextStyle(fontFamily: 'Cairo',
                        fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                    const SizedBox(height: 8),
                    Text(
                      context.s.confirmSent(orderNumber.toString()),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: context.col.ink2, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    if (total != null)
                      Container(
                        constraints: const BoxConstraints(maxWidth: 320),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.col.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: context.col.border),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(context.s.deliveryLabel,
                                  style: TextStyle(fontSize: 13, color: context.col.ink2)),
                                Text(_deliveryLabel(context),
                                  style: const TextStyle(fontSize: 13.5,
                                    fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(context.s.paidLabel,
                                  style: TextStyle(fontSize: 13, color: context.col.ink2)),
                                Text('${fmtPrice(total)} ${context.s.lydUnit}',
                                  style: const TextStyle(fontFamily: 'PlusJakartaSans',
                                    fontSize: 15, fontWeight: FontWeight.w800,
                                    color: AppColors.primary)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    if (cashbackAmount != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        constraints: const BoxConstraints(maxWidth: 320),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.savings_outlined, color: AppColors.success, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              context.isAr
                                ? 'ستحصل على $cashbackAmount ${context.s.lydUnit} استرداد عند التوصيل'
                                : 'You\'ll earn $cashbackAmount ${context.s.lydUnit} cashback on delivery',
                              style: const TextStyle(fontSize: 13, color: AppColors.success,
                                fontWeight: FontWeight.w600, height: 1.4),
                            ),
                          ),
                        ]),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16,
                MediaQuery.of(context).padding.bottom + 16),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.go('/home'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 50),
                      side: BorderSide(color: context.col.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(context.s.continueShopping,
                      style: TextStyle(fontFamily: 'Cairo',
                        fontWeight: FontWeight.w700, color: context.col.ink0)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (orderId != null) {
                        context.go('/orders/$orderId');
                      } else {
                        context.go('/orders');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 50),
                      backgroundColor: context.col.ink0,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(context.s.trackOrder,
                      style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
