import 'product.dart';

double _d(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0.0;
  return 0.0;
}

// Coerce anything (int, num, numeric string, null) to an int — legacy imported
// orders sometimes return ids/quantities as strings or null, which would throw
// when assigned to a non-nullable int field.
int _i(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? double.tryParse(v)?.toInt() ?? fallback;
  return fallback;
}

class OrderStatusEntry {
  final String toStatus;
  final DateTime? createdAt;
  const OrderStatusEntry({required this.toStatus, this.createdAt});
  factory OrderStatusEntry.fromJson(Map<String, dynamic> j) => OrderStatusEntry(
    toStatus: j['to_status'] ?? '',
    createdAt: j['created_at'] != null ? DateTime.tryParse(j['created_at']) : null,
  );
}

class Order {
  final int id;
  final String orderNumber;
  final String status;
  final double total;
  final double subtotal;
  final double shippingCost;
  final double discount;
  /// Coupon value. Lives in its own column server-side and `discount` stays 0, so a breakdown
  /// that only reads `discount` does not add up to `total`.
  final double couponDiscount;
  /// Portion of this order already settled from the customer's wallet balance.
  final double walletAmount;
  final String? couponCode;
  final String paymentMethod;
  final String paymentStatus;
  final String? paymentSlip;
  final String? notes;
  final Map<String, dynamic>? shippingAddress;
  final List<OrderVendorGroup> vendorGroups;
  final List<OrderStatusEntry> statusHistory;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool returnEligible;
  final DateTime? returnDeadline;

  const Order({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.total,
    required this.subtotal,
    required this.shippingCost,
    required this.discount,
    this.couponDiscount = 0,
    this.walletAmount = 0,
    this.couponCode,
    required this.paymentMethod,
    required this.paymentStatus,
    this.paymentSlip,
    this.notes,
    this.shippingAddress,
    required this.vendorGroups,
    this.statusHistory = const [],
    required this.createdAt,
    this.updatedAt,
    this.returnEligible = false,
    this.returnDeadline,
  });

  List<OrderItem> get allItems =>
      vendorGroups.expand((g) => g.items).toList();

  String get statusAr {
    const map = {
      'pending_payment': 'بانتظار التحويل',
      'pending_confirmation': 'في انتظار التأكيد',
      'pending_vendor': 'في انتظار التأكيد',
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
    id: _i(j['id']),
    orderNumber: j['order_number'] ?? '#${j['id']}',
    status: j['status'] ?? 'pending',
    total: _d(j['total']),
    subtotal: _d(j['subtotal'] ?? 0),
    shippingCost: _d(j['shipping_cost'] ?? 0),
    discount: _d(j['discount'] ?? 0),
    couponDiscount: _d(j['coupon_discount'] ?? 0),
    walletAmount: _d(j['wallet_amount'] ?? 0),
    couponCode: j['coupon_code'],
    paymentMethod: j['payment_method'] ?? 'cash',
    paymentStatus: j['payment_status'] ?? 'pending',
    paymentSlip: j['payment_slip']?.toString(),
    notes: j['notes'],
    shippingAddress: j['shipping_address'] is Map
        ? Map<String, dynamic>.from(j['shipping_address'])
        : null,
    vendorGroups: (j['vendor_groups'] as List?)
        ?.map((g) => OrderVendorGroup.fromJson(g)).toList() ?? [],
    statusHistory: (j['status_history'] as List?)
        ?.map((e) => OrderStatusEntry.fromJson(e)).toList() ?? [],
    createdAt: DateTime.tryParse(j['created_at'] ?? '') ?? DateTime.now(),
    updatedAt: j['updated_at'] != null ? DateTime.tryParse(j['updated_at']) : null,
    returnEligible: j['return_eligible'] == true,
    returnDeadline: j['return_deadline'] != null ? DateTime.tryParse(j['return_deadline']) : null,
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
    // A deleted/unlinked vendor comes back as null — fall back to a placeholder so it
    // doesn't crash the whole orders / tracking screen.
    vendor: j['vendor'] != null
        ? Vendor.fromJson(Map<String, dynamic>.from(j['vendor'] as Map))
        : const Vendor(id: 0, storeName: '', storeNameAr: ''),
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
      id: _i(j['id']),
      productId: _i(j['product_id']),
      productName: j['product_name'] ?? product?['name'] ?? '',
      productNameAr: j['product_name_ar'] ?? product?['name_ar'] ?? j['product_name'] ?? '',
      productImage: productImage,
      variationId: (j['variation_id'] as num?)?.toInt(),
      variationLabel: j['variation_label'],
      quantity: _i(j['quantity'], 1),
      price: _d(j['price']),
      total: _d(j['total'] ?? j['subtotal'] ?? (_d(j['price']) * (j['quantity'] ?? 1))),
    );
  }
}
