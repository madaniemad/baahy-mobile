import 'product.dart';

double _d(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0.0;
  return 0.0;
}

class Order {
  final int id;
  final String orderNumber;
  final String status;
  final double total;
  final double subtotal;
  final double shippingCost;
  final double discount;
  final String? couponCode;
  final String paymentMethod;
  final String paymentStatus;
  final String? notes;
  final Map<String, dynamic>? shippingAddress;
  final List<OrderVendorGroup> vendorGroups;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Order({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.total,
    required this.subtotal,
    required this.shippingCost,
    required this.discount,
    this.couponCode,
    required this.paymentMethod,
    required this.paymentStatus,
    this.notes,
    this.shippingAddress,
    required this.vendorGroups,
    required this.createdAt,
    this.updatedAt,
  });

  List<OrderItem> get allItems =>
      vendorGroups.expand((g) => g.items).toList();

  String get statusAr {
    const map = {
      'pending_confirmation': 'في انتظار التأكيد',
      'pending': 'قيد الانتظار',
      'confirmed': 'مؤكد',
      'processing': 'قيد التجهيز',
      'fulfilled': 'تم التجهيز',
      'shipped': 'تم الشحن',
      'out_for_delivery': 'خارج للتوصيل',
      'delivered': 'تم التوصيل',
      'cancelled': 'ملغي',
      'returned': 'مُرجَع',
      'refunded': 'مُسترد',
    };
    return map[status] ?? status;
  }

  factory Order.fromJson(Map<String, dynamic> j) => Order(
    id: j['id'],
    orderNumber: j['order_number'] ?? '#${j['id']}',
    status: j['status'] ?? 'pending',
    total: _d(j['total']),
    subtotal: _d(j['subtotal'] ?? 0),
    shippingCost: _d(j['shipping_cost'] ?? 0),
    discount: _d(j['discount'] ?? 0),
    couponCode: j['coupon_code'],
    paymentMethod: j['payment_method'] ?? 'cash',
    paymentStatus: j['payment_status'] ?? 'pending',
    notes: j['notes'],
    shippingAddress: j['shipping_address'] is Map
        ? Map<String, dynamic>.from(j['shipping_address'])
        : null,
    vendorGroups: (j['vendor_groups'] as List?)
        ?.map((g) => OrderVendorGroup.fromJson(g)).toList() ?? [],
    createdAt: DateTime.tryParse(j['created_at'] ?? '') ?? DateTime.now(),
    updatedAt: j['updated_at'] != null
        ? DateTime.tryParse(j['updated_at'])
        : null,
  );
}

class OrderVendorGroup {
  final Vendor vendor;
  final List<OrderItem> items;
  final String status;
  final String? trackingNumber;

  const OrderVendorGroup({
    required this.vendor,
    required this.items,
    required this.status,
    this.trackingNumber,
  });

  factory OrderVendorGroup.fromJson(Map<String, dynamic> j) => OrderVendorGroup(
    vendor: Vendor.fromJson(j['vendor']),
    items: (j['items'] as List?)
        ?.map((i) => OrderItem.fromJson(i)).toList() ?? [],
    status: j['status'] ?? 'pending',
    trackingNumber: j['tracking_number'],
  );
}

class OrderItem {
  final int id;
  final int productId;
  final String productName;
  final String productNameAr;
  final String? productImage;
  final int? variationId;
  final String? variationLabel;
  final int quantity;
  final double price;
  final double total;

  const OrderItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productNameAr,
    this.productImage,
    this.variationId,
    this.variationLabel,
    required this.quantity,
    required this.price,
    required this.total,
  });

  factory OrderItem.fromJson(Map<String, dynamic> j) {
    final product = j['product'] as Map<String, dynamic>?;
    String? productImage = j['product_image'];
    if (productImage == null && product != null) {
      final raw = product['images'];
      if (raw is List && raw.isNotEmpty) {
        productImage = raw.first.toString();
      } else if (raw is String && raw.length > 2) {
        try {
          final stripped = raw.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '').split(',');
          if (stripped.isNotEmpty) productImage = stripped.first.trim();
        } catch (_) {}
      }
    }
    return OrderItem(
      id: j['id'],
      productId: j['product_id'],
      productName: j['product_name'] ?? product?['name'] ?? '',
      productNameAr: j['product_name_ar'] ?? product?['name_ar'] ?? j['product_name'] ?? '',
      productImage: productImage,
      variationId: j['variation_id'],
      variationLabel: j['variation_label'],
      quantity: j['quantity'] ?? 1,
      price: _d(j['price']),
      total: _d(j['total'] ?? j['subtotal'] ?? (_d(j['price']) * (j['quantity'] ?? 1))),
    );
  }
}
