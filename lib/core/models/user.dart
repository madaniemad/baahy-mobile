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
  );
}
