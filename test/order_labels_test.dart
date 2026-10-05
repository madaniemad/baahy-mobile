import 'package:flutter_test/flutter_test.dart';
import 'package:baahy_customer/core/l10n/strings.dart';

void main() {
  const ar = AppStrings(true);
  const en = AppStrings(false);

  test('new backend statuses have Arabic and English labels', () {
    expect(ar.statusLabel('pending_payment'), 'بانتظار التحويل');
    expect(en.statusLabel('pending_payment'), 'Awaiting transfer');
    expect(ar.statusLabel('returned_to_vendor'), 'أُعيد إلى المتجر');
    expect(en.statusLabel('returned_to_vendor'), 'Returned to store');
    expect(ar.statusLabel('failed'), 'فشل التوصيل');
    expect(en.statusLabel('failed'), 'Delivery failed');
    expect(ar.statusLabel('partial_return'), 'مرتجع جزئي');
    expect(en.statusLabel('partial_return'), 'Partial return');
  });

  test('no backend status falls back to the raw string', () {
    const backendStatuses = [
      'pending_payment',
      'pending_confirmation',
      'confirmed',
      'processing',
      'shipped',
      'out_for_delivery',
      'delivered',
      'cancelled',
      'returned',
      'returned_to_vendor',
      'failed',
      'partial_return',
      'refunded',
    ];
    for (final s in backendStatuses) {
      expect(ar.statusLabel(s), isNot(s), reason: 'ar label for $s');
      expect(en.statusLabel(s), isNot(s), reason: 'en label for $s');
    }
  });
}
