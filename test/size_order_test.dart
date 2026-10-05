import 'package:flutter_test/flutter_test.dart';
import 'package:baahy_customer/core/utils/size_order.dart';

void main() {
  test(
      'the real mixed size list from the store filter sorts naturally, not alphabetically',
      () {
    // Exactly what the server returned (alphabetical): kids ages, shoe sizes and letters in one pile.
    const raw = [
      '10 Years',
      '29',
      '3-4 Years',
      '30',
      '31',
      '34',
      '36',
      '37',
      '38',
      '39',
      '4 Years',
      '4-5 Years',
      '40',
      '41',
      '42',
      '44',
      '5 Years',
      '5-6 Years',
      '6 Years',
      '7 Years',
      '8 Years',
      '9 years',
      'L',
      'L/XL',
      'M',
      'S',
      'Standard',
      'XL',
      'XXL',
    ];
    expect(sortSizeValues(raw, (s) => s), [
      '29',
      '30',
      '31',
      '34',
      '36',
      '37',
      '38',
      '39',
      '40',
      '41',
      '42',
      '44',
      'S',
      'M',
      'L',
      'L/XL',
      'XL',
      'XXL',
      '3-4 Years',
      '4 Years',
      '4-5 Years',
      '5 Years',
      '5-6 Years',
      '6 Years',
      '7 Years',
      '8 Years',
      '9 years',
      '10 Years',
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

  List<String> sorted(List<String> raw) => sortSizeValues(raw, (s) => s);

  test('size attribute also accepts قياس', () {
    expect(isSizeAttribute('', 'القياس'), isTrue);
  });

  test('any count of X before L sorts after XXL, in order', () {
    expect(sorted(['XXXXL', 'XXXL', 'XXL', 'XL', 'L', 'S']),
        ['S', 'L', 'XL', 'XXL', 'XXXL', 'XXXXL']);
    expect(sorted(['4XL', '3XL', 'XXL', 'XL']), ['XL', 'XXL', '3XL', '4XL']);
    expect(sorted(['XXXL', 'XXL', 'M']), ['M', 'XXL', 'XXXL']);
    // XXXL is the same size as 3XL: neither sorts into the "anything else" tail.
    expect(sorted(['Standard', 'XXXL', '5XL']), ['XXXL', '5XL', 'Standard']);
  });

  test('S-M, M-L, L-XL ranges (dash like slash) sit between their ends', () {
    expect(sorted(['L', 'M-L', 'S', 'M', 'S-M', 'L-XL', 'XL']),
        ['S', 'S-M', 'M', 'M-L', 'L', 'L-XL', 'XL']);
    expect(sorted(['XL', 'L - XL', 'L']), ['L', 'L - XL', 'XL']);
  });

  test(
      'year and month abbreviations are classified as years/months, not plain numbers',
      () {
    expect(sorted(['3-4Y', '40', '6M', '12M', 'M', '5-6 Yrs', '2 Years']), [
      '40',
      'M',
      '6M',
      '12M',
      '2 Years',
      '3-4Y',
      '5-6 Yrs',
    ]);
    expect(sorted(['10 Yrs', '9 year', '6 mos', '18 mo']),
        ['6 mos', '18 mo', '9 year', '10 Yrs']);
  });

  test('Arabic-Indic digits are read as numbers', () {
    expect(sorted(['٤٠', '٣٨', '٢٩']), ['٢٩', '٣٨', '٤٠']);
    expect(sorted(['١٠ Years', '٣-٤ Years', '40']),
        ['40', '٣-٤ Years', '١٠ Years']);
    expect(sorted(['۱۲M', '۶M']), ['۶M', '۱۲M']);
  });

  test('trailing quote and x forms stay in the numeric group by first number',
      () {
    expect(sorted(['Standard', 'S', '36x32', '30"', '32"', '34x30']),
        ['30"', '32"', '34x30', '36x32', 'S', 'Standard']);
  });
}
