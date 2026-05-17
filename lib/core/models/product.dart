class Product {
  final int id;
  final String name;
  final String nameAr;
  final String? sku;
  final double price;
  final double? salePrice;
  final double? currentPrice;
  final bool inStock;
  final int? stockQuantity;
  final String status;
  final bool featured;
  final String productType;
  final List<String> images;
  final Vendor? vendor;
  final Category? category;
  final List<ProductVariation> variations;
  final double? averageRating;
  final int? reviewsCount;

  const Product({
    required this.id,
    required this.name,
    required this.nameAr,
    this.sku,
    required this.price,
    this.salePrice,
    this.currentPrice,
    required this.inStock,
    this.stockQuantity,
    required this.status,
    this.featured = false,
    this.productType = 'simple',
    this.images = const [],
    this.vendor,
    this.category,
    this.variations = const [],
    this.averageRating,
    this.reviewsCount,
  });

  double get displayPrice => currentPrice ?? salePrice ?? price;
  bool get hasDiscount => salePrice != null && salePrice! < price;
  int get discountPercent => hasDiscount
      ? ((1 - displayPrice / price) * 100).round()
      : 0;
  String? get firstImage => images.isNotEmpty ? images.first : null;

  factory Product.fromJson(Map<String, dynamic> j) => Product(
    id: j['id'],
    name: j['name'] ?? '',
    nameAr: j['name_ar'] ?? j['name'] ?? '',
    sku: j['sku'],
    price: (j['price'] as num).toDouble(),
    salePrice: j['sale_price'] != null ? (j['sale_price'] as num).toDouble() : null,
    currentPrice: j['current_price'] != null ? (j['current_price'] as num).toDouble() : null,
    inStock: j['in_stock'] == true || j['in_stock'] == 1,
    stockQuantity: j['stock_quantity'],
    status: j['status'] ?? 'active',
    featured: j['featured'] == true || j['featured'] == 1,
    productType: j['product_type'] ?? 'simple',
    images: _parseImages(j['images']),
    vendor: j['vendor'] != null ? Vendor.fromJson(j['vendor']) : null,
    category: j['category'] != null ? Category.fromJson(j['category']) : null,
    variations: (j['variations'] as List?)
        ?.map((v) => ProductVariation.fromJson(v)).toList() ?? [],
    averageRating: j['average_rating'] != null ? (j['average_rating'] as num).toDouble() : null,
    reviewsCount: j['reviews_count'],
  );

  static List<String> _parseImages(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String) {
      // Sometimes images come as JSON string
      try {
        final decoded = raw.replaceAll(RegExp(r'^\[|\]$'), '').split(',')
            .map((e) => e.trim().replaceAll('"', '')).where((e) => e.isNotEmpty).toList();
        return decoded;
      } catch (_) { return []; }
    }
    return [];
  }
}

class ProductVariation {
  final int id;
  final String? sku;
  final double price;
  final double? salePrice;
  final int stockQuantity;
  final bool isActive;
  final List<VariationAttribute> attributes;

  const ProductVariation({
    required this.id,
    this.sku,
    required this.price,
    this.salePrice,
    required this.stockQuantity,
    this.isActive = true,
    this.attributes = const [],
  });

  factory ProductVariation.fromJson(Map<String, dynamic> j) => ProductVariation(
    id: j['id'],
    sku: j['sku'],
    price: (j['price'] as num).toDouble(),
    salePrice: j['sale_price'] != null ? (j['sale_price'] as num).toDouble() : null,
    stockQuantity: j['stock_quantity'] ?? 0,
    isActive: j['is_active'] == true || j['is_active'] == 1,
    attributes: (j['variation_attributes'] as List?)
        ?.map((a) => VariationAttribute.fromJson(a)).toList() ?? [],
  );
}

class VariationAttribute {
  final String typeName;
  final String typeNameAr;
  final String value;
  final String valueAr;
  final String? colorHex;

  const VariationAttribute({
    required this.typeName,
    required this.typeNameAr,
    required this.value,
    required this.valueAr,
    this.colorHex,
  });

  factory VariationAttribute.fromJson(Map<String, dynamic> j) => VariationAttribute(
    typeName: j['attribute_type']?['name'] ?? '',
    typeNameAr: j['attribute_type']?['name_ar'] ?? '',
    value: j['attribute_value']?['value'] ?? '',
    valueAr: j['attribute_value']?['value_ar'] ?? '',
    colorHex: j['attribute_value']?['color_hex'],
  );
}

class Vendor {
  final int id;
  final String storeName;
  final String storeNameAr;
  final String? logo;
  final String? city;
  final double? averageRating;

  const Vendor({
    required this.id,
    required this.storeName,
    required this.storeNameAr,
    this.logo,
    this.city,
    this.averageRating,
  });

  factory Vendor.fromJson(Map<String, dynamic> j) => Vendor(
    id: j['id'],
    storeName: j['store_name'] ?? '',
    storeNameAr: j['store_name_ar'] ?? j['store_name'] ?? '',
    logo: j['logo'],
    city: j['city'],
    averageRating: j['average_rating'] != null ? (j['average_rating'] as num).toDouble() : null,
  );
}

class Category {
  final int id;
  final String name;
  final String nameAr;
  final String? image;
  final int? parentId;
  final List<Category> children;
  final int? sortOrder;

  const Category({
    required this.id,
    required this.name,
    required this.nameAr,
    this.image,
    this.parentId,
    this.children = const [],
    this.sortOrder,
  });

  factory Category.fromJson(Map<String, dynamic> j) => Category(
    id: j['id'],
    name: j['name'] ?? '',
    nameAr: j['name_ar'] ?? j['name'] ?? '',
    image: j['image'],
    parentId: j['parent_id'],
    children: (j['children'] as List?)
        ?.map((c) => Category.fromJson(c)).toList() ?? [],
    sortOrder: j['sort_order'],
  );
}
