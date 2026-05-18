class PaymentMethod {
  final String id;
  final String labelAr;
  final String labelEn;
  final double fee;
  final String descriptionAr;
  final bool enabled;

  const PaymentMethod({
    required this.id,
    required this.labelAr,
    required this.labelEn,
    this.fee = 0,
    required this.descriptionAr,
    this.enabled = true,
  });

  factory PaymentMethod.fromJson(Map<String, dynamic> j) => PaymentMethod(
    id: j['id'] as String,
    labelAr: j['label_ar'] as String? ?? j['id'],
    labelEn: j['label_en'] as String? ?? '',
    fee: _d(j['fee'] ?? 0),
    descriptionAr: j['description_ar'] as String? ?? '',
    enabled: j['enabled'] as bool? ?? true,
  );

  static double _d(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }
}

class AppConfig {
  final double shippingFee;
  final double freeShippingThreshold;
  final List<PaymentMethod> paymentMethods;
  final String deliveryPromiseAr;
  final List<String> trendingSearches;
  final double minWalletTopup;
  final int referralGiverAmount;
  final int referralReceiverAmount;
  final String referralTextAr;

  const AppConfig({
    required this.shippingFee,
    required this.freeShippingThreshold,
    required this.paymentMethods,
    required this.deliveryPromiseAr,
    required this.trendingSearches,
    required this.minWalletTopup,
    required this.referralGiverAmount,
    required this.referralReceiverAmount,
    required this.referralTextAr,
  });

  static const AppConfig defaults = AppConfig(
    shippingFee: 10,
    freeShippingThreshold: 150,
    paymentMethods: [
      PaymentMethod(
        id: 'cash_on_delivery',
        labelAr: 'الدفع عند الاستلام',
        labelEn: 'Cash on Delivery',
        fee: 5,
        descriptionAr: 'رسوم خدمة 5 د.ل',
      ),
      PaymentMethod(
        id: 'wallet',
        labelAr: 'محفظة باهي',
        labelEn: 'Baahy Wallet',
        fee: 0,
        descriptionAr: 'فوري · بدون رسوم',
      ),
    ],
    deliveryPromiseAr: 'معظم الطلبات تصل خلال 1-2 يوم',
    trendingSearches: ['عطور وبخور', 'سماعات لاسلكية', 'عباءات', 'كاميرات', 'ملابس رياضية'],
    minWalletTopup: 5,
    referralGiverAmount: 10,
    referralReceiverAmount: 10,
    referralTextAr: 'أعطِ 10، احصل على 10',
  );

  factory AppConfig.fromJson(Map<String, dynamic> j) {
    final methods = (j['payment_methods'] as List?)
        ?.map((m) => PaymentMethod.fromJson(m as Map<String, dynamic>))
        .toList();
    final referral = j['referral'] as Map<String, dynamic>?;
    final delivery = j['delivery_promise'] as Map<String, dynamic>?;
    return AppConfig(
      shippingFee: _d(j['shipping_fee'] ?? defaults.shippingFee),
      freeShippingThreshold: _d(j['free_shipping_threshold'] ?? defaults.freeShippingThreshold),
      paymentMethods: (methods?.isNotEmpty == true) ? methods! : defaults.paymentMethods,
      deliveryPromiseAr: delivery?['text_ar'] as String? ?? defaults.deliveryPromiseAr,
      trendingSearches: (j['trending_searches'] as List?)?.cast<String>() ?? defaults.trendingSearches,
      minWalletTopup: _d(j['min_wallet_topup'] ?? defaults.minWalletTopup),
      referralGiverAmount: (referral?['giver_discount'] as num?)?.toInt() ?? defaults.referralGiverAmount,
      referralReceiverAmount: (referral?['receiver_discount'] as num?)?.toInt() ?? defaults.referralReceiverAmount,
      referralTextAr: referral?['text_ar'] as String? ?? defaults.referralTextAr,
    );
  }

  static double _d(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }
}
