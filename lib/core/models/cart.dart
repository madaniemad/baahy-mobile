import 'product.dart';

class CartItem {
  final int productId;
  final int? variationId;
  final Product product;
  final ProductVariation? variation;
  final int quantity;

  const CartItem({
    required this.productId,
    this.variationId,
    required this.product,
    this.variation,
    required this.quantity,
  });

  String get key => variationId != null ? '${productId}_$variationId' : '$productId';
  double get unitPrice => variation?.salePrice ?? variation?.price ?? product.displayPrice;
  double get total => unitPrice * quantity;
  String? get image => product.firstImage;

  CartItem copyWith({int? quantity}) => CartItem(
    productId: productId,
    variationId: variationId,
    product: product,
    variation: variation,
    quantity: quantity ?? this.quantity,
  );

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'variation_id': variationId,
    'product': product.toJson(),
    'variation': variation?.toJson(),
    'quantity': quantity,
  };

  factory CartItem.fromJson(Map<String, dynamic> j) => CartItem(
    productId: j['product_id'],
    variationId: j['variation_id'],
    product: Product.fromJson(j['product']),
    variation: j['variation'] != null ? ProductVariation.fromJson(j['variation']) : null,
    quantity: j['quantity'] ?? 1,
  );
}
