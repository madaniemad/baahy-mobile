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
  });

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
  );
}
