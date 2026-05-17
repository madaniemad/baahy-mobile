import 'product.dart';

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
      'pending': 'قيد الانتظار',
      'confirmed': 'مؤكد',
      'processing': 'قيد التجهيز',
      'shipped': 'تم الشحن',
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
    total: (j['total'] as num).toDouble(),
    subtotal: (j['subtotal'] as num? ?? 0).toDouble(),
    shippingCost: (j['shipping_cost'] as num? ?? 0).toDouble(),
    discount: (j['discount'] as num? ?? 0).toDouble(),
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

  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
    id: j['id'],
    productId: j['product_id'],
    productName: j['product_name'] ?? '',
    productNameAr: j['product_name_ar'] ?? j['product_name'] ?? '',
    productImage: j['product_image'],
    variationId: j['variation_id'],
    variationLabel: j['variation_label'],
    quantity: j['quantity'] ?? 1,
    price: (j['price'] as num).toDouble(),
    total: (j['total'] as num? ?? (j['price'] as num) * (j['quantity'] as num? ?? 1)).toDouble(),
  );
}
