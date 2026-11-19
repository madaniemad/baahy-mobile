import 'package:flutter_test/flutter_test.dart';
import 'package:baahy_customer/core/models/cart.dart';
import 'package:baahy_customer/core/models/order.dart';
import 'package:baahy_customer/core/models/product.dart';
import 'package:baahy_customer/shared/widgets/personal_items_note.dart';

// Personal items (2026-11-19): return_rule on products, personal_item on order lines. Both stay
// null on an old API or while the server switch is off, and then nothing may change.
void main() {
  Map<String, dynamic> product([Object? rule = _absent]) => {
        'id': 7,
        'name': 'Lipstick',
        'name_ar': 'أحمر شفاه',
        'price': 25,
        'status': 'active',
        if (!identical(rule, _absent)) 'return_rule': rule,
      };

  test('absent or null return_rule parses to null', () {
    expect(Product.fromJson(product()).returnRule, isNull);
    expect(Product.fromJson(product(null)).returnRule, isNull);
    expect(Product.fromJson(product('weird')).returnRule, isNull);
    expect(Product.fromJson(product({'personal': false})).returnRule, isNull);
  });

  test('a personal return_rule parses, survives the cart round trip', () {
    final p = Product.fromJson(product({
      'personal': true,
      'note_ar': 'منتج شخصي',
      'note_en': 'Personal item',
      'reasons': ['wrong_item', 'damaged'],
    }));
    expect(p.returnRule, isNotNull);
    expect(p.returnRule!.note(true), 'منتج شخصي');
    expect(p.returnRule!.note(false), 'Personal item');
    expect(p.returnRule!.reasons, ['wrong_item', 'damaged']);

    final item = CartItem(productId: 7, product: p, quantity: 1);
    final back = CartItem.fromJson(item.toJson());
    expect(back.product.returnRule?.noteAr, 'منتج شخصي');
    expect(cartHasPersonalItems([back]), isTrue);
  });

  test('missing notes fall back to the server wording', () {
    final p = Product.fromJson(product({'personal': true}));
    expect(p.returnRule!.noteAr, kPersonalItemNoteAr);
    expect(p.returnRule!.noteEn, kPersonalItemNoteEn);
  });

  test('a cart without the rule has no personal items and writes no key', () {
    final p = Product.fromJson(product());
    expect(p.toJson().containsKey('return_rule'), isFalse);
    expect(cartHasPersonalItems([CartItem(productId: 7, product: p, quantity: 1)]), isFalse);
  });

  test('order line personal_item: true / false / null and 0/1', () {
    Map<String, dynamic> line([Object? v = _absent]) => {
          'id': 1,
          'product_id': 7,
          'product_name': 'Lipstick',
          'quantity': 1,
          'price': 25,
          if (!identical(v, _absent)) 'personal_item': v,
        };
    expect(OrderItem.fromJson(line()).personalItem, isNull);
    expect(OrderItem.fromJson(line(null)).personalItem, isNull);
    expect(OrderItem.fromJson(line(true)).personalItem, isTrue);
    expect(OrderItem.fromJson(line(1)).personalItem, isTrue);
    expect(OrderItem.fromJson(line(false)).personalItem, isFalse);
    expect(OrderItem.fromJson(line(0)).personalItem, isFalse);
  });
}

const _absent = Object();
