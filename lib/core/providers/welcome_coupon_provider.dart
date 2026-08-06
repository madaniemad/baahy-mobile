import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../api/api_client.dart';

/// The auto-applied offer the backend is currently holding for this customer.
///
/// This used to be the first-order coupon and nothing else. It now returns
/// whichever offer the customer's order history places them in — today that is
/// the 10% second-order win-back, since the first order is carried by the 20 LYD
/// welcome wallet bonus alone. All customer-facing copy comes from the server so
/// the offer can be re-aimed from admin without shipping an app release.
class WelcomeCoupon {
  final String code;
  final double discount;
  final double? maxDiscount;
  final String type;
  final String messageAr;
  /// "10% off your second order — applied automatically"
  final String headlineAr;
  final String headlineEn;
  /// Same, phrased for a cart that already has the coupon applied.
  final String appliedAr;
  final String appliedEn;
  final String subAr;
  final String subEn;

  const WelcomeCoupon({
    required this.code,
    required this.discount,
    this.maxDiscount,
    required this.type,
    required this.messageAr,
    required this.headlineAr,
    required this.headlineEn,
    required this.appliedAr,
    required this.appliedEn,
    required this.subAr,
    required this.subEn,
  });
}

final welcomeCouponProvider = FutureProvider.autoDispose<WelcomeCoupon?>((ref) async {
  try {
    final res = await ApiClient.instance.dio.get('/coupons/welcome');
    final data = res.data;
    if (data['eligible'] != true) return null;

    final code = data['code'] as String? ?? '';
    final discount = (data['discount'] as num?)?.toDouble() ?? 10.0;
    final type = data['type'] as String? ?? 'percentage';
    final label = type == 'percentage'
        ? '${discount.toStringAsFixed(0)}%'
        : '${discount.toStringAsFixed(0)} د.ل';

    return WelcomeCoupon(
      code:        code,
      discount:    discount,
      maxDiscount: (data['max_discount'] as num?)?.toDouble(),
      type:        type,
      messageAr:   data['message_ar'] as String? ?? 'كود خصم خاص لك',
      // Fallbacks stay deliberately vague about WHICH order the offer targets —
      // an older server that doesn't send these must not claim "first order".
      headlineAr:  data['headline_ar'] as String? ?? 'خصم $label — يُطبَّق تلقائياً',
      headlineEn:  data['headline_en'] as String? ?? '$label off — applied automatically',
      appliedAr:   data['applied_ar']  as String? ?? 'تم تطبيق خصم $label على سلتك',
      appliedEn:   data['applied_en']  as String? ?? '$label discount applied to your cart',
      subAr:       data['sub_ar']      as String? ?? 'عرض لمرة واحدة — لا تفوّته!',
      subEn:       data['sub_en']      as String? ?? "One-time offer — don't miss it!",
    );
  } catch (e, st) {
    Sentry.captureException(e, stackTrace: st);
    return null;
  }
});
