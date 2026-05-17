import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/app_button.dart';

class OrderConfirmedScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  const OrderConfirmedScreen({required this.data, super.key});

  @override
  Widget build(BuildContext context) {
    final orderNumber = data['order_number'] ?? '#${data['id']}';
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: AppColors.success, size: 52),
              ),
              const SizedBox(height: 24),
              const Text('تم تأكيد طلبك!',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('رقم الطلب: $orderNumber',
                style: const TextStyle(fontFamily: 'PlusJakartaSans',
                  fontSize: 16, color: AppColors.ink2)),
              const SizedBox(height: 12),
              const Text(
                'سيتم مراجعة طلبك والتواصل معك قريباً',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: AppColors.ink2),
              ),
              const SizedBox(height: 40),
              AppButton(
                label: 'متابعة الطلب',
                onTap: () {
                  final orderId = data['id'];
                  if (orderId != null) {
                    context.go('/orders/$orderId');
                  } else {
                    context.go('/orders');
                  }
                },
              ),
              const SizedBox(height: 12),
              AppButton(
                label: 'العودة للرئيسية',
                variant: AppButtonVariant.ghost,
                onTap: () => context.go('/home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
