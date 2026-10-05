import 'package:flutter_test/flutter_test.dart';
import 'package:baahy_customer/core/utils/size_order.dart';

void main() {
  test('size types are always المقاس / Size, whatever the server calls them',
      () {
    expect(attrTypeLabel(true, 'Size', 'الحجم'), 'المقاس');
    expect(attrTypeLabel(true, 'Size', ''), 'المقاس');
    expect(attrTypeLabel(true, '', 'الحجم'), 'المقاس');
    expect(attrTypeLabel(true, 'Shoe size', 'قياس'), 'المقاس');
    expect(attrTypeLabel(false, 'Size', 'الحجم'), 'Size');
    expect(attrTypeLabel(false, '', 'الحجم'), 'Size');
  });

  test('colour types are اللون / Color', () {
    expect(attrTypeLabel(true, 'Color', ''), 'اللون');
    expect(attrTypeLabel(true, 'Colour', 'لون'), 'اللون');
    expect(attrTypeLabel(false, 'Color', 'اللون'), 'Color');
    expect(attrTypeLabel(false, '', 'اللون'), 'Color');
  });

  test(
      'other types use their own name, falling back across languages when one is blank',
      () {
    expect(attrTypeLabel(true, 'Material', 'الخامة'), 'الخامة');
    expect(attrTypeLabel(false, 'Material', 'الخامة'), 'Material');
    expect(attrTypeLabel(true, 'Material', ''), 'Material');
    expect(attrTypeLabel(true, 'Material', '  '), 'Material');
    expect(attrTypeLabel(false, '', 'الخامة'), 'الخامة');
    expect(attrTypeLabel(false, '  ', 'الخامة'), 'الخامة');
  });
}
