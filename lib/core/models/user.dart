double _dUser(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0.0;
  return 0.0;
}

class User {
  final int id;
  final String name;
  final String phone;
  final String? email;
  final String? avatar;
  final String? city;
  final double walletBalance;
  final int loyaltyPoints;
  final String? referralCode;
  final String? birthday;
  final String? username;
  final String privacyWishlist;
  final String privacyPurchases;
  final String privacyReviews;
  final String privacyTier;
  /// Cash on delivery withdrawn from this customer (two doorsteps the driver could not reach) —
  /// they prepay. Absent from older servers, which means not blocked.
  final bool codBlocked;
  /// Staff restricted this account: it can sign in but cannot order or start a payment. Sent only
  /// for the person themself; absent from older servers, which means not blocked.
  final bool orderingBlocked;
  /// Why ordering is restricted, when staff gave a reason. Null when none.
  final String? orderingBlockReason;

  const User({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.avatar,
    this.city,
    this.walletBalance = 0.0,
    this.loyaltyPoints = 0,
    this.referralCode,
    this.birthday,
    this.username,
    this.privacyWishlist = 'friends',
    this.privacyPurchases = 'friends',
    this.privacyReviews = 'public',
    this.privacyTier = 'friends',
    this.codBlocked = false,
    this.orderingBlocked = false,
    this.orderingBlockReason,
  });

  User copyWith({String? avatar}) => User(
    id: id, name: name, phone: phone, email: email,
    avatar: avatar ?? this.avatar,
    city: city, walletBalance: walletBalance, loyaltyPoints: loyaltyPoints,
    referralCode: referralCode, birthday: birthday, username: username,
    privacyWishlist: privacyWishlist, privacyPurchases: privacyPurchases,
    privacyReviews: privacyReviews, privacyTier: privacyTier,
    codBlocked: codBlocked,
    orderingBlocked: orderingBlocked, orderingBlockReason: orderingBlockReason,
  );

  /// This user with ordering restricted — used when the server refuses an order before the
  /// profile refresh has caught up.
  User withOrderingBlocked(String? reason) => User(
    id: id, name: name, phone: phone, email: email, avatar: avatar,
    city: city, walletBalance: walletBalance, loyaltyPoints: loyaltyPoints,
    referralCode: referralCode, birthday: birthday, username: username,
    privacyWishlist: privacyWishlist, privacyPurchases: privacyPurchases,
    privacyReviews: privacyReviews, privacyTier: privacyTier,
    codBlocked: codBlocked,
    orderingBlocked: true,
    orderingBlockReason: (reason != null && reason.trim().isNotEmpty) ? reason.trim() : orderingBlockReason,
  );

  factory User.fromJson(Map<String, dynamic> j) => User(
    id: j['id'],
    name: j['name'] ?? '',
    phone: j['phone'] ?? '',
    email: j['email'],
    avatar: j['avatar'],
    city: j['city'],
    walletBalance: j['wallet_balance'] != null ? _dUser(j['wallet_balance']) : 0.0,
    loyaltyPoints: j['loyalty_points'] ?? 0,
    referralCode: j['referral_code'],
    birthday: j['birthday'] as String?,
    username: j['username'] as String?,
    privacyWishlist:  j['privacy_wishlist']  as String? ?? 'friends',
    privacyPurchases: j['privacy_purchases'] as String? ?? 'friends',
    privacyReviews:   j['privacy_reviews']   as String? ?? 'public',
    privacyTier:      j['privacy_tier']      as String? ?? 'friends',
    codBlocked:       j['cod_blocked'] == true,
    orderingBlocked:  j['ordering_blocked'] == true || j['ordering_blocked'] == 1,
    orderingBlockReason: _reasonOrNull(j['ordering_block_reason']),
  );
}

String? _reasonOrNull(dynamic v) {
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}
