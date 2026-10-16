import 'package:flutter_test/flutter_test.dart';
import 'package:baahy_customer/core/models/cart.dart';
import 'package:baahy_customer/core/models/product.dart';
import 'package:baahy_customer/core/models/shipping_rate.dart';
import 'package:baahy_customer/core/providers/cart_provider.dart';

Product _product(int id, {required int vendorId, double fee = 5, double price = 50}) =>
    Product.fromJson({
      'id': id,
      'name': 'P$id',
      'price': price,
      'vendor': {'id': vendorId, 'store_name': 'V$vendorId', 'collection_fee': fee},
    });

ShippingRate _rate(String zone) => ShippingRate.fromJson({
      'id': 1,
      'city': 'X',
      'city_ar': 'X',
      'rate': 20,
      'zone_type': zone,
    });

void main() {
  final items = [
    CartItem(productId: 1, product: _product(1, vendorId: 1, fee: 5), quantity: 1),
    CartItem(productId: 2, product: _product(2, vendorId: 2, fee: 7), quantity: 1),
  ];

  test('collection fee only for Tripoli-hub deliveries (first vendor free)', () {
    final hub = CartState(items: items, cityRate: _rate('hub_city'));
    expect(hub.totalCollectionFee, 5); // largest (7) waived
    expect(hub.deliveryFee, 25);

    final regional = CartState(items: items, cityRate: _rate('regional_city'));
    expect(regional.totalCollectionFee, 0);
    expect(regional.deliveryFee, 20);
    expect(hub.collectionFeeFor(_rate('regional_city')), 0);
  });

  test('a server-quoted price overrides the catalogue price and survives a save', () {
    final item = CartItem(productId: 1, product: _product(1, vendorId: 1, price: 50), quantity: 2)
        .copyWith(priceOverride: 45);
    expect(item.unitPrice, 45);
    expect(item.total, 90);
    final back = CartItem.fromJson(item.toJson());
    expect(back.unitPrice, 45);
    expect(back.copyWith(clearPriceOverride: true).unitPrice, 50);
  });
}
