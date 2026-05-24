import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/review.dart';
import '../../../shared/theme/app_theme.dart';

final _reviewsProvider = FutureProvider.family<List<Review>, int>((ref, productId) async {
  final res = await ApiClient.instance.dio.get('/products/$productId/reviews',
    queryParameters: {'per_page': 50});
  return (res.data['data'] as List?)
      ?.map((r) => Review.fromJson(r)).toList() ?? [];
});

class ReviewsScreen extends ConsumerStatefulWidget {
  final int productId;
  const ReviewsScreen({required this.productId, super.key});

  @override
  ConsumerState<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends ConsumerState<ReviewsScreen> {
  int? _filterRating;

  @override
  Widget build(BuildContext context) {
    final reviewsAsync = ref.watch(_reviewsProvider(widget.productId));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('التقييمات',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 17)),
      ),
      body: reviewsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, __) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.ink3),
            const SizedBox(height: 12),
            const Text('تعذر تحميل التقييمات', style: TextStyle(color: AppColors.ink2)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => ref.refresh(_reviewsProvider(widget.productId)),
              child: const Text('إعادة المحاولة')),
          ]),
        ),
        data: (reviews) {
          if (reviews.isEmpty) {
            return const Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.star_border_rounded, size: 56, color: AppColors.border),
                SizedBox(height: 12),
                Text('لا توجد تقييمات بعد',
                  style: TextStyle(color: AppColors.ink3, fontSize: 15)),
              ]),
            );
          }

          // Compute stats
          final avg = reviews.fold(0.0, (s, r) => s + r.rating) / reviews.length;
          final counts = List.generate(5, (i) =>
            reviews.where((r) => r.rating == 5 - i).length);

          final filtered = _filterRating == null
              ? reviews
              : reviews.where((r) => r.rating == _filterRating).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Rating summary ──────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(children: [
                      Text(avg.toStringAsFixed(1),
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 48, fontWeight: FontWeight.w800, height: 1)),
                      const SizedBox(height: 6),
                      RatingBarIndicator(
                        rating: avg,
                        itemSize: 18,
                        itemBuilder: (_, __) =>
                          const Icon(Icons.star_rounded, color: AppColors.gold),
                      ),
                      const SizedBox(height: 4),
                      Text('${reviews.length} تقييم',
                        style: const TextStyle(fontSize: 12, color: AppColors.ink3)),
                    ]),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        children: List.generate(5, (i) {
                          final star = 5 - i;
                          final count = counts[i];
                          final pct = reviews.isEmpty ? 0.0 : count / reviews.length;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.5),
                            child: Row(children: [
                              Text('$star',
                                style: const TextStyle(fontFamily: 'PlusJakartaSans',
                                  fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink2)),
                              const SizedBox(width: 4),
                              const Icon(Icons.star_rounded, size: 12, color: AppColors.gold),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: pct,
                                    minHeight: 7,
                                    backgroundColor: AppColors.border,
                                    color: AppColors.gold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(width: 22,
                                child: Text('$count',
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(fontFamily: 'PlusJakartaSans',
                                    fontSize: 12, color: AppColors.ink3))),
                            ]),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── Filter chips ────────────────────────────────────────
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _filterChip('الكل', null),
                    const SizedBox(width: 8),
                    ...List.generate(5, (i) {
                      final star = 5 - i;
                      return Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _filterChip('$star ★', star),
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Review list ─────────────────────────────────────────
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 32),
                  child: Center(
                    child: Text('لا توجد تقييمات لـ $_filterRating نجوم',
                      style: const TextStyle(color: AppColors.ink3)),
                  ),
                )
              else
                ...filtered.map((r) => _ReviewCard(review: r)),
            ],
          );
        },
      ),
    );
  }

  Widget _filterChip(String label, int? rating) {
    final isSelected = _filterRating == rating;
    return GestureDetector(
      onTap: () => setState(() => _filterRating = rating),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.ink0 : Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: isSelected ? AppColors.ink0 : AppColors.border),
        ),
        child: Text(label,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : AppColors.ink1,
          )),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Review review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary.withValues(alpha: 0.2),
              child: Text(
                review.reviewerName.isNotEmpty ? review.reviewerName[0] : '؟',
                style: const TextStyle(
                  fontWeight: FontWeight.w800, color: AppColors.teal600, fontSize: 15)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(review.reviewerName,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                if (review.createdAt != null)
                  Text(review.createdAt!,
                    style: const TextStyle(fontSize: 11, color: AppColors.ink3)),
              ],
            )),
            Row(children: List.generate(5, (i) => Icon(
              i < review.rating ? Icons.star_rounded : Icons.star_border_rounded,
              size: 15, color: AppColors.gold))),
          ]),
          if (review.body.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(review.body,
              style: const TextStyle(fontSize: 13.5, color: AppColors.ink1, height: 1.6)),
          ],
          if (review.photos.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: review.photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(review.photos[i],
                    width: 72, height: 72, fit: BoxFit.cover),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
