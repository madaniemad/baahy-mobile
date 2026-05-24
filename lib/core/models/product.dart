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
  final int? soldCount;
  final String? description;
  final String? descriptionAr;
  final String? brand;
  final String fulfillmentType;

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
    this.soldCount,
    this.description,
    this.descriptionAr,
    this.brand,
    this.fulfillmentType = 'inherit',
  });

  double get displayPrice => currentPrice ?? salePrice ?? price;
  bool get hasDiscount => salePrice != null && salePrice! < price;
  bool get fulfilledByBaahy {
    if (fulfillmentType == 'baahy') return true;
    if (fulfillmentType == 'vendor') return false;
    return vendor?.fulfillmentType == 'baahy';
  }
  int get discountPercent => hasDiscount
      ? ((1 - displayPrice / price) * 100).round()
      : 0;
  String? get firstImage => images.isNotEmpty ? images.first : null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'name_ar': nameAr,
    'sku': sku,
    'price': price,
    'sale_price': salePrice,
    'current_price': currentPrice,
    'in_stock': inStock,
    'stock_quantity': stockQuantity,
    'status': status,
    'featured': featured,
    'product_type': productType,
    'images': images,
    'vendor': vendor?.toJson(),
    'category': category?.toJson(),
    'variations': variations.map((v) => v.toJson()).toList(),
    'average_rating': averageRating,
    'reviews_count': reviewsCount,
    'sold_count': soldCount,
    'description': description,
    'description_ar': descriptionAr,
    'brand': brand,
    'fulfillment_type': fulfillmentType,
  };

  static double _d(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  factory Product.fromJson(Map<String, dynamic> j) => Product(
    id: j['id'],
    name: j['name'] ?? '',
    nameAr: j['name_ar'] ?? j['name'] ?? '',
    sku: j['sku'],
    price: _d(j['price']),
    salePrice: j['sale_price'] != null ? _d(j['sale_price']) : null,
    currentPrice: j['current_price'] != null ? _d(j['current_price']) : null,
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
    averageRating: j['average_rating'] != null ? _d(j['average_rating']) : null,
    reviewsCount: j['reviews_count'],
    soldCount: j['sold_count'] != null ? _d(j['sold_count']).toInt() : null,
    description: j['description'],
    descriptionAr: j['description_ar'],
    brand: j['brand'] as String?,
    fulfillmentType: j['fulfillment_type'] as String? ?? 'inherit',
  );

  static const _storageBase = 'https://phplaravel-1620145-6391034.cloudwaysapps.com/storage/';

  static String _resolveImageUrl(String path) {
    if (path.startsWith('http')) return path;
    return _storageBase + path.replaceAll(RegExp(r'^/+'), '');
  }

  static List<String> _parseImages(dynamic raw) {
    if (raw == null) return [];
    List<String> paths;
    if (raw is List) {
      paths = raw.map((e) => e.toString()).toList();
    } else if (raw is String) {
      try {
        paths = raw.replaceAll(RegExp(r'^\[|\]$'), '').split(',')
            .map((e) => e.trim().replaceAll('"', '')).where((e) => e.isNotEmpty).toList();
      } catch (_) { return []; }
    } else {
      return [];
    }
    return paths.where((p) => p.isNotEmpty).map(_resolveImageUrl).toList();
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'sku': sku,
    'price': price,
    'sale_price': salePrice,
    'stock_quantity': stockQuantity,
    'is_active': isActive,
    'variation_attributes': attributes.map((a) => a.toJson()).toList(),
  };

  factory ProductVariation.fromJson(Map<String, dynamic> j) => ProductVariation(
    id: j['id'],
    sku: j['sku'],
    price: Product._d(j['price']),
    salePrice: j['sale_price'] != null ? Product._d(j['sale_price']) : null,
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

  Map<String, dynamic> toJson() => {
    'attribute_type': {'name': typeName, 'name_ar': typeNameAr},
    'attribute_value': {'value': value, 'value_ar': valueAr, 'color_hex': colorHex},
  };

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
  final String fulfillmentType;

  const Vendor({
    required this.id,
    required this.storeName,
    required this.storeNameAr,
    this.logo,
    this.city,
    this.averageRating,
    this.fulfillmentType = 'vendor',
  });

  bool get fulfilledByBaahy => fulfillmentType == 'baahy';

  Map<String, dynamic> toJson() => {
    'id': id,
    'store_name': storeName,
    'store_name_ar': storeNameAr,
    'logo': logo,
    'city': city,
    'average_rating': averageRating,
    'fulfillment_type': fulfillmentType,
  };

  factory Vendor.fromJson(Map<String, dynamic> j) => Vendor(
    id: j['id'],
    storeName: j['store_name'] ?? '',
    storeNameAr: j['store_name_ar'] ?? j['store_name'] ?? '',
    logo: j['logo'],
    city: j['city'],
    averageRating: j['average_rating'] != null ? Product._d(j['average_rating']) : null,
    fulfillmentType: j['fulfillment_type'] as String? ?? 'vendor',
  );
}

class Category {
  final int id;
  final String name;
  final String nameAr;
  final String? image;
  final int? parentId;
  final Category? parent;
  final List<Category> children;
  final int? sortOrder;

  const Category({
    required this.id,
    required this.name,
    required this.nameAr,
    this.image,
    this.parentId,
    this.parent,
    this.children = const [],
    this.sortOrder,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'name_ar': nameAr,
    'image': image,
    'parent_id': parentId,
    'children': children.map((c) => c.toJson()).toList(),
    'sort_order': sortOrder,
  };

  factory Category.fromJson(Map<String, dynamic> j) => Category(
    id: j['id'],
    name: j['name'] ?? '',
    nameAr: j['name_ar'] ?? j['name'] ?? '',
    image: _resolveImage(j['image']),
    parentId: j['parent_id'],
    parent: j['parent'] != null ? Category.fromJson(j['parent']) : null,
    children: (j['children'] as List?)
        ?.map((c) => Category.fromJson(c)).toList() ?? [],
    sortOrder: j['sort_order'],
  );

  static String? _resolveImage(dynamic v) {
    if (v == null || (v as String).isEmpty) return null;
    if (v.startsWith('http')) return v;
    return 'https://phplaravel-1620145-6391034.cloudwaysapps.com/storage/${v.replaceAll(RegExp(r'^/+'), '')}';
  }
}
