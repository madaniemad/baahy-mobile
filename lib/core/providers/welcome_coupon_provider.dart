import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../api/api_client.dart';

class WelcomeCoupon {
  final String code;
  final double discount;
  final double? maxDiscount;
  final String type;
  final String messageAr;

  const WelcomeCoupon({
    required this.code,
    required this.discount,
    this.maxDiscount,
    required this.type,
    required this.messageAr,
  });
}

final welcomeCouponProvider = FutureProvider.autoDispose<WelcomeCoupon?>((ref) async {
  try {
    final res = await ApiClient.instance.dio.get('/coupons/welcome');
    final data = res.data;
    if (data['eligible'] != true) return null;
    return WelcomeCoupon(
      code:        data['code'] as String? ?? 'FIRSTORDER',
      discount:    (data['discount'] as num?)?.toDouble() ?? 10.0,
      maxDiscount: (data['max_discount'] as num?)?.toDouble(),
      type:        data['type'] as String? ?? 'percentage',
      messageAr:   data['message_ar'] as String? ?? 'كود خصم خاص لطلبك الأول',
    );
  } catch (e, st) {
    Sentry.captureException(e, stackTrace: st);
    return null;
  }
});
