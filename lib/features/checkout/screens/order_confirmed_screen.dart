import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/theme/app_theme.dart';

class OrderConfirmedScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  const OrderConfirmedScreen({required this.data, super.key});

  @override
  Widget build(BuildContext context) {
    final orderNumber = data['order_number'] ?? '#${data['id']}';
    final orderId = data['id'];
    final total = (data['total'] as num?)?.toDouble();

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
                        color: const Color(0xFFEAF8F8),
                        border: Border.all(color: AppColors.primary, width: 3),
                      ),
                      child: const Icon(Icons.check_rounded,
                        color: AppColors.teal600, size: 48),
                    ),
                    const SizedBox(height: 16),
                    const Text('تم الطلب!',
                      style: TextStyle(fontFamily: 'Cairo',
                        fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                    const SizedBox(height: 8),
                    Text(
                      'أرسلنا رسالة تأكيد · رقم الطلب $orderNumber',
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
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('التسليم',
                                  style: TextStyle(fontSize: 13, color: AppColors.ink2)),
                                const Text('1-2 يوم · طرابلس',
                                  style: TextStyle(fontSize: 13.5,
                                    fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('المدفوع',
                                  style: TextStyle(fontSize: 13, color: AppColors.ink2)),
                                Text('${total.toStringAsFixed(0)} د.ل',
                                  style: const TextStyle(fontFamily: 'PlusJakartaSans',
                                    fontSize: 15, fontWeight: FontWeight.w800,
                                    color: AppColors.teal600)),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('مواصلة التسوّق',
                      style: TextStyle(fontFamily: 'Cairo',
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('تتبّع الطلب',
                      style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
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
