class ShippingRate {
  final int id;
  final String city;
  final String cityAr;
  final double rate;
  final int deliveryDays;
  final double? freeShippingThreshold;

  const ShippingRate({
    required this.id,
    required this.city,
    required this.cityAr,
    required this.rate,
    required this.deliveryDays,
    this.freeShippingThreshold,
  });

  factory ShippingRate.fromJson(Map<String, dynamic> j) => ShippingRate(
    id: j['id'],
    city: j['city'] ?? '',
    cityAr: j['city_ar'] ?? j['city'] ?? '',
    rate: _d(j['rate']),
    deliveryDays: (j['delivery_days'] as num?)?.toInt() ?? 3,
    freeShippingThreshold: j['free_shipping_threshold'] != null ? _d(j['free_shipping_threshold']) : null,
  );

  double effectiveRate(double orderTotal) {
    if (freeShippingThreshold != null && orderTotal >= freeShippingThreshold!) return 0;
    return rate;
  }

  static double _d(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }
}
