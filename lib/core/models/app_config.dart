class PaymentMethod {
  final String id;
  final String labelAr;
  final String labelEn;
  final double fee;
  final String descriptionAr;
  final String descriptionEn;
  final bool enabled;

  const PaymentMethod({
    required this.id,
    required this.labelAr,
    required this.labelEn,
    this.fee = 0,
    required this.descriptionAr,
    this.descriptionEn = '',
    this.enabled = true,
  });

  factory PaymentMethod.fromJson(Map<String, dynamic> j) => PaymentMethod(
    id: j['id'] as String,
    labelAr: j['label_ar'] as String? ?? j['id'],
    labelEn: j['label_en'] as String? ?? '',
    fee: _d(j['fee'] ?? 0),
    descriptionAr: j['description_ar'] as String? ?? '',
    descriptionEn: j['description_en'] as String? ?? '',
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
  final double collectionFee;
  final double freeShippingThreshold;
  final int returnDays;
  final int deliveryCitiesCount;
  final List<PaymentMethod> paymentMethods;
  final String deliveryPromiseAr;
  final String deliveryPromiseEn;
  final List<String> trendingSearches;
  final double minWalletTopup;
  final int referralGiverAmount;
  final int referralReceiverAmount;
  final String referralTextAr;
  final String referralTextEn;
  final double cashbackRate;
  final double cashbackMinOrder;
  final double welcomeBonusAmount;
  final double reviewRewardAmount;

  const AppConfig({
    required this.shippingFee,
    this.collectionFee = 0,
    required this.freeShippingThreshold,
    this.returnDays = 7,
    this.deliveryCitiesCount = 12,
    required this.paymentMethods,
    required this.deliveryPromiseAr,
    this.deliveryPromiseEn = 'Most orders arrive within 1-2 days',
    required this.trendingSearches,
    required this.minWalletTopup,
    required this.referralGiverAmount,
    required this.referralReceiverAmount,
    required this.referralTextAr,
    this.referralTextEn = 'Give 10, Get 10',
    this.cashbackRate = 2.0,
    this.cashbackMinOrder = 80.0,
    this.welcomeBonusAmount = 10.0,
    this.reviewRewardAmount = 3.0,
  });

  static const AppConfig defaults = AppConfig(
    shippingFee: 10,
    collectionFee: 0,
    freeShippingThreshold: 150,
    paymentMethods: [
      PaymentMethod(
        id: 'cash_on_delivery',
        labelAr: 'الدفع عند الاستلام',
        labelEn: 'Cash on Delivery',
        fee: 5,
        descriptionAr: 'رسوم خدمة 5 د.ل',
        descriptionEn: 'Service fee 5 LYD',
      ),
      PaymentMethod(
        id: 'wallet',
        labelAr: 'محفظة باهي',
        labelEn: 'Baahy Wallet',
        fee: 0,
        descriptionAr: 'فوري · بدون رسوم',
        descriptionEn: 'Instant · No fees',
      ),
    ],
    deliveryPromiseAr: 'معظم الطلبات تصل خلال 1-2 يوم',
    trendingSearches: ['عطور وبخور', 'سماعات لاسلكية', 'عباءات', 'كاميرات', 'ملابس رياضية'],
    minWalletTopup: 5,
    referralGiverAmount: 10,
    referralReceiverAmount: 10,
    referralTextAr: 'أعطِ 10، احصل على 10',
    cashbackRate: 2.0,
    cashbackMinOrder: 80.0,
    welcomeBonusAmount: 10.0,
    reviewRewardAmount: 3.0,
  );

  factory AppConfig.fromJson(Map<String, dynamic> j) {
    final methods = (j['payment_methods'] as List?)
        ?.map((m) => PaymentMethod.fromJson(m as Map<String, dynamic>))
        .toList();
    final referral = j['referral'] as Map<String, dynamic>?;
    final rewards = j['rewards'] as Map<String, dynamic>?;
    final delivery = j['delivery_promise'] as Map<String, dynamic>?;
    return AppConfig(
      shippingFee: _d(j['shipping_fee'] ?? defaults.shippingFee),
      collectionFee: _d(j['collection_fee'] ?? defaults.collectionFee),
      freeShippingThreshold: _d(j['free_shipping_threshold'] ?? defaults.freeShippingThreshold),
      returnDays: (j['return_days'] as num?)?.toInt() ?? defaults.returnDays,
      deliveryCitiesCount: (j['delivery_cities_count'] as num?)?.toInt() ?? defaults.deliveryCitiesCount,
      paymentMethods: (methods?.isNotEmpty == true) ? methods! : defaults.paymentMethods,
      deliveryPromiseAr: delivery?['text_ar'] as String? ?? defaults.deliveryPromiseAr,
      deliveryPromiseEn: delivery?['text_en'] as String? ?? defaults.deliveryPromiseEn,
      trendingSearches: (j['trending_searches'] as List?)?.cast<String>() ?? defaults.trendingSearches,
      minWalletTopup: _d(j['min_wallet_topup'] ?? defaults.minWalletTopup),
      referralGiverAmount: (referral?['giver_discount'] as num?)?.toInt() ?? defaults.referralGiverAmount,
      referralReceiverAmount: (referral?['receiver_discount'] as num?)?.toInt() ?? defaults.referralReceiverAmount,
      referralTextAr: referral?['text_ar'] as String? ?? defaults.referralTextAr,
      referralTextEn: referral?['text_en'] as String? ?? defaults.referralTextEn,
      cashbackRate: _d(rewards?['cashback_rate'] ?? defaults.cashbackRate),
      cashbackMinOrder: _d(rewards?['cashback_min_order'] ?? defaults.cashbackMinOrder),
      welcomeBonusAmount: _d(rewards?['welcome_bonus_amount'] ?? defaults.welcomeBonusAmount),
      reviewRewardAmount: _d(rewards?['review_reward_amount'] ?? defaults.reviewRewardAmount),
    );
  }

  static double _d(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }
}
