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

  factory Review.fromJson(Map<String, dynamic> j) => Review(
    id: j['id'] ?? 0,
    reviewerName: j['reviewer_name'] ?? j['user']?['name'] ?? 'مجهول',
    rating: j['rating'] != null ? (j['rating'] is num ? (j['rating'] as num).toInt() : int.tryParse(j['rating'].toString()) ?? 5) : 5,
    body: j['body'] ?? j['comment'] ?? '',
    createdAt: j['created_at'],
    photos: (j['photos'] as List?)?.map((e) => e.toString()).toList() ?? [],
  );
}
