import 'package:flutter_test/flutter_test.dart';
import 'package:baahy_customer/features/vendor/widgets/store_filters.dart';

void main() {
  test('untouched filters are inactive (no dot on the button)', () {
    expect(const StoreFilters().isActive, isFalse);
  });

  test('every field marks the filters active', () {
    expect(const StoreFilters(sort: 'price_asc').isActive, isTrue);
    expect(const StoreFilters(minPrice: 10).isActive, isTrue);
    expect(const StoreFilters(maxPrice: 99).isActive, isTrue);
    expect(const StoreFilters(onSaleOnly: true).isActive, isTrue);
    expect(const StoreFilters(minRating: 4).isActive, isTrue);
    expect(const StoreFilters(brands: {'Tefal'}).isActive, isTrue);
    expect(const StoreFilters(attributeValueIds: {7}).isActive, isTrue);
  });
}
