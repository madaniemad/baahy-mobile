import 'package:flutter_test/flutter_test.dart';
import 'package:baahy_customer/core/models/product.dart';

void main() {
  Map<String, dynamic> attr(
          {Object? typeAr = 'المقاس',
          Object? valueAr = 'كبير',
          bool omitAr = false}) =>
      {
        'attribute_type': {'name': 'Size', if (!omitAr) 'name_ar': typeAr},
        'attribute_value': {
          'value': 'Large',
          if (!omitAr) 'value_ar': valueAr,
          'color_hex': null
        },
      };

  test('Arabic text present is kept', () {
    final a = VariationAttribute.fromJson(attr());
    expect(a.valueAr, 'كبير');
    expect(a.typeNameAr, 'المقاس');
    expect(a.value, 'Large');
    expect(a.typeName, 'Size');
  });

  test('blank Arabic value and type name fall back to English', () {
    for (final blank in ['', '   ']) {
      final a =
          VariationAttribute.fromJson(attr(typeAr: blank, valueAr: blank));
      expect(a.valueAr, 'Large');
      expect(a.typeNameAr, 'Size');
    }
  });

  test('null or missing Arabic text falls back to English', () {
    final nulls =
        VariationAttribute.fromJson(attr(typeAr: null, valueAr: null));
    expect(nulls.valueAr, 'Large');
    expect(nulls.typeNameAr, 'Size');
    final missing = VariationAttribute.fromJson(attr(omitAr: true));
    expect(missing.valueAr, 'Large');
    expect(missing.typeNameAr, 'Size');
  });

  test('both languages blank stays blank and does not throw', () {
    final a = VariationAttribute.fromJson(
        {'attribute_type': {}, 'attribute_value': {}});
    expect(a.valueAr, '');
    expect(a.typeNameAr, '');
    final none = VariationAttribute.fromJson({});
    expect(none.value, '');
    expect(none.valueAr, '');
  });

  test('toJson round-trips with the filled-in Arabic text', () {
    final a = VariationAttribute.fromJson(attr(typeAr: '', valueAr: ''));
    final b = VariationAttribute.fromJson(a.toJson());
    expect(b.valueAr, 'Large');
    expect(b.typeNameAr, 'Size');
  });
}
