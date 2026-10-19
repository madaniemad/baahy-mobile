class Review {
  final int id;
  final String reviewerName;
  final int rating;
  final String body;
  final String? createdAt;
  final List<String> photos;
  /// The shop's public answer to this review, when the seller has replied.
  final String? reply;
  final String? repliedAt;

  const Review({
    required this.id,
    required this.reviewerName,
    required this.rating,
    required this.body,
    this.createdAt,
    this.photos = const [],
    this.reply,
    this.repliedAt,
  });

  /// The server sends `reply` (text) + `replied_at`; tolerate an object `{text, created_at}`
  /// or `reply_text` too, so a shape change does not drop the answer.
  static String? _replyText(Map<String, dynamic> j) {
    final r = j['reply'];
    final raw = r is Map ? (r['text'] ?? r['body'] ?? r['reply']) : (r ?? j['reply_text']);
    final s = raw?.toString().trim() ?? '';
    return s.isEmpty ? null : s;
  }

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
    reply: _replyText(j),
    repliedAt: (j['reply'] is Map ? (j['reply']['created_at'] ?? j['reply']['replied_at']) : j['replied_at'])?.toString(),
  );
}
