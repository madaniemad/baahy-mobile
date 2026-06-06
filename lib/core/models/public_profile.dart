import 'friend.dart';

class PublicProfile {
  final Friend user;
  final List<Map<String, dynamic>>? wishlist;
  final List<Map<String, dynamic>>? recentPurchases;
  final List<Map<String, dynamic>>? reviews;

  const PublicProfile({
    required this.user,
    this.wishlist,
    this.recentPurchases,
    this.reviews,
  });

  factory PublicProfile.fromJson(Map<String, dynamic> j) {
    final wishlistRaw     = j['wishlist'] as List?;
    final purchasesRaw    = j['recent_purchases'] as List?;
    final reviewsRaw      = j['reviews'] as List?;
    return PublicProfile(
      user:            Friend.fromJson(j),
      wishlist:        wishlistRaw?.map((e) => e as Map<String, dynamic>).toList(),
      recentPurchases: purchasesRaw?.map((e) => e as Map<String, dynamic>).toList(),
      reviews:         reviewsRaw?.map((e) => e as Map<String, dynamic>).toList(),
    );
  }
}
