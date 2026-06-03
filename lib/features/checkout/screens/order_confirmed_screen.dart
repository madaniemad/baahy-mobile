import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/theme/app_theme.dart';

class OrderConfirmedScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final orderNumber = data['order_number'] ?? '#${data['id']}';
    final orderId = data['id'];
    final rawTotal = data['total'];
    final total = rawTotal is num ? rawTotal.toDouble() : double.tryParse(rawTotal?.toString() ?? '');

    return Scaffold(
      backgroundColor: AppColors.bg,
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
                        color: const Color(0xFFF5F5F5),
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
                      style: const TextStyle(fontSize: 14, color: AppColors.ink2, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    if (total != null)
                      Container(
                        constraints: const BoxConstraints(maxWidth: 320),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(context.s.deliveryLabel,
                                  style: const TextStyle(fontSize: 13, color: AppColors.ink2)),
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
                                  style: const TextStyle(fontSize: 13, color: AppColors.ink2)),
                                Text('${fmtPrice(total)} ${context.s.lydUnit}',
                                  style: const TextStyle(fontFamily: 'PlusJakartaSans',
                                    fontSize: 15, fontWeight: FontWeight.w800,
                                    color: AppColors.primary)),
                              ],
                            ),
                          ],
                        ),
                      ),
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
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(context.s.continueShopping,
                      style: const TextStyle(fontFamily: 'Cairo',
                        fontWeight: FontWeight.w700, color: AppColors.ink0)),
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
                      backgroundColor: AppColors.ink0,
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
