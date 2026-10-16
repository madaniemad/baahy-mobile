import 'product.dart';

class CartItem {
  final int productId;
  final int? variationId;
  final Product product;
  final ProductVariation? variation;
  final int quantity;

  /// The unit price the server quoted for this line at /cart/validate (`current_price` on a
  /// `price_changed` answer). The server prices an order with its own expression, which can
  /// differ from what the product payload shows (a sale the product endpoint reads differently,
  /// a stale cached copy). Without adopting the server's figure the line kept sending the old
  /// price and checkout answered "تغير سعر X" on every tap, forever.
  final double? priceOverride;

  const CartItem({
    required this.productId,
    this.variationId,
    required this.product,
    this.variation,
    required this.quantity,
    this.priceOverride,
  });

  String get key => variationId != null ? '${productId}_$variationId' : '$productId';
  /// What the line costs before any server correction.
  double get catalogUnitPrice => variation?.salePrice ?? variation?.price ?? product.displayPrice;
  double get unitPrice => priceOverride ?? catalogUnitPrice;
  double get total => unitPrice * quantity;
  String? get image => product.firstImage;

  CartItem copyWith({int? quantity, double? priceOverride, bool clearPriceOverride = false}) => CartItem(
    productId: productId,
    variationId: variationId,
    product: product,
    variation: variation,
    quantity: quantity ?? this.quantity,
    priceOverride: clearPriceOverride ? null : (priceOverride ?? this.priceOverride),
  );

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'variation_id': variationId,
    'product': product.toJson(),
    'variation': variation?.toJson(),
    'quantity': quantity,
    if (priceOverride != null) 'price_override': priceOverride,
  };

  factory CartItem.fromJson(Map<String, dynamic> j) => CartItem(
    productId: j['product_id'],
    variationId: j['variation_id'],
    product: Product.fromJson(j['product']),
    variation: j['variation'] != null ? ProductVariation.fromJson(j['variation']) : null,
    quantity: j['quantity'] ?? 1,
    priceOverride: (j['price_override'] as num?)?.toDouble(),
  );
}
