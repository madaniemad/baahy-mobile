import 'product.dart';

class CartItem {
  final int id;
  final Product product;
  final ProductVariation? variation;
  final int quantity;

  const CartItem({
    required this.id,
    required this.product,
    this.variation,
    required this.quantity,
  });

  double get unitPrice => variation?.salePrice ?? variation?.price ?? product.displayPrice;
  double get total => unitPrice * quantity;
  String? get image => product.firstImage;

  factory CartItem.fromJson(Map<String, dynamic> j) => CartItem(
    id: j['id'],
    product: Product.fromJson(j['product']),
    variation: j['variation'] != null
        ? ProductVariation.fromJson(j['variation'])
        : null,
    quantity: j['quantity'] ?? 1,
  );
}
