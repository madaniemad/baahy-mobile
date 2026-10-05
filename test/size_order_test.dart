import 'package:flutter_test/flutter_test.dart';
import 'package:baahy_customer/core/utils/size_order.dart';

void main() {
  test('the real mixed size list from the store filter sorts naturally, not alphabetically', () {
    // Exactly what the server returned (alphabetical): kids ages, shoe sizes and letters in one pile.
    const raw = [
      '10 Years', '29', '3-4 Years', '30', '31', '34', '36', '37', '38', '39', '4 Years', '4-5 Years',
      '40', '41', '42', '44', '5 Years', '5-6 Years', '6 Years', '7 Years', '8 Years', '9 years',
      'L', 'L/XL', 'M', 'S', 'Standard', 'XL', 'XXL',
    ];
    expect(sortSizeValues(raw, (s) => s), [
      '29', '30', '31', '34', '36', '37', '38', '39', '40', '41', '42', '44',
      'S', 'M', 'L', 'L/XL', 'XL', 'XXL',
      '3-4 Years', '4 Years', '4-5 Years', '5 Years', '5-6 Years', '6 Years', '7 Years', '8 Years',
      '9 years', '10 Years',
      'Standard',
    ]);
  });

  test('months come before years, and the input list is not mutated', () {
    const raw = ['2 Years', '6 Months', '12 Months'];
    final out = sortSizeValues(raw, (s) => s);
    expect(out, ['6 Months', '12 Months', '2 Years']);
    expect(raw, ['2 Years', '6 Months', '12 Months']);
  });

  test('size attributes are recognised in English and Arabic', () {
    expect(isSizeAttribute('Size', 'المقاس'), isTrue);
    expect(isSizeAttribute('', 'الحجم'), isTrue);
    expect(isSizeAttribute('Color', 'اللون'), isFalse);
  });
}
