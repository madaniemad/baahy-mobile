class Review {
  final int id;
  final String reviewerName;
  final int rating;
  final String body;
  final String? createdAt;
  final List<String> photos;

  const Review({
    required this.id,
    required this.reviewerName,
    required this.rating,
    required this.body,
    this.createdAt,
    this.photos = const [],
  });

  /// The reviews endpoint answers `data: {reviews: <paginator>, stats: {...}}`; older shapes were a
  /// bare list or a paginator. Accept all of them and skip any malformed item.
  static List<Review> parseList(dynamic data) {
    dynamic list = data;
    if (list is Map) list = list['reviews'] ?? list['data'];
    if (list is Map) list = list['data'];
    if (list is! List) return const [];
    final out = <Review>[];
    for (final r in list) {
      if (r is Map<String, dynamic>) {
        try {
          out.add(Review.fromJson(r));
        } catch (_) {}
      }
    }
    return out;
  }

  factory Review.fromJson(Map<String, dynamic> j) => Review(
    id: j['id'] ?? 0,
    reviewerName: j['reviewer_name'] ?? j['user']?['name'] ?? '',
    rating: j['rating'] != null ? (j['rating'] is num ? (j['rating'] as num).toInt() : int.tryParse(j['rating'].toString()) ?? 5) : 5,
    body: j['body'] ?? j['comment'] ?? '',
    createdAt: j['created_at'],
    photos: (j['photos'] as List?)?.map((e) => e.toString()).toList() ?? [],
  );
}
