import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/product.dart';
import '../../../core/utils/l10n.dart';
import '../../../core/utils/navigation.dart';
import '../../../shared/theme/app_theme.dart';

/// A store as the browse list needs it: the vendor plus how many products it sells.
class StoreEntry {
  final Vendor vendor;
  final int productsCount;
  final int reviewsCount;

  /// Root departments the store has visible products in: (arabic name, english name).
  final List<(String, String)> departments;
  const StoreEntry(this.vendor, this.productsCount,
      {this.reviewsCount = 0, this.departments = const []});
}

/// Active stores, optionally narrowed to those selling in a root category.
/// Stores with nothing to sell are dropped here as well as on the server.
final storesProvider =
    FutureProvider.family<List<StoreEntry>, int?>((ref, categoryId) async {
  try {
    final res = await ApiClient.instance.dio.get('/vendors', queryParameters: {
      'per_page': 100,
      'has_products': 1,
      // App list: the server drops stores staff switched off (Vendors > "Hide from the app's Stores list").
      'app_list': 1,
      if (categoryId != null) 'category_id': categoryId,
    });
    final raw = res.data?['data'];
    final list = (raw is Map ? raw['data'] : raw) as List? ?? const [];
    final out = <StoreEntry>[];
    for (final j in list) {
      if (j is! Map<String, dynamic>) continue;
      try {
        final count = (j['products_count'] as num?)?.toInt() ?? 0;
        if (count <= 0) continue;
        final deps = <(String, String)>[];
        for (final c in (j['main_categories'] as List? ?? const [])) {
          if (c is! Map) continue;
          final en = (c['name'] ?? '').toString();
          final ar = (c['name_ar'] ?? '').toString();
          if (en.isNotEmpty || ar.isNotEmpty)
            deps.add((ar.isNotEmpty ? ar : en, en.isNotEmpty ? en : ar));
        }
        out.add(StoreEntry(
          Vendor.fromJson(j),
          count,
          reviewsCount: (j['reviews_count'] as num?)?.toInt() ?? 0,
          departments: deps,
        ));
      } catch (e, st) {
        Sentry.captureException(e, stackTrace: st);
      }
    }
    // Biggest shelves first — the stores a shopper is most likely to want.
    out.sort((a, b) => b.productsCount.compareTo(a.productsCount));
    return out;
  } catch (e, st) {
    Sentry.captureException(e, stackTrace: st);
    rethrow;
  }
});

/// Up to three product photos for a store with no banner of its own, from the chosen
/// department when one is selected so the strip matches the filter.
final storePreviewProvider =
    FutureProvider.family<List<String>, (int, int?)>((ref, key) async {
  final (vendorId, categoryId) = key;
  try {
    final res = await ApiClient.instance.dio.get('/products', queryParameters: {
      'vendor_id': vendorId,
      'per_page': 3,
      'has_image': 1,
      if (categoryId != null) 'category_id': categoryId,
    });
    final list = res.data?['data']?['data'] as List? ?? const [];
    final out = <String>[];
    for (final p in list) {
      if (p is! Map<String, dynamic>) continue;
      try {
        final img = Product.fromJson(p).firstImage;
        if (img != null && img.isNotEmpty) out.add(img);
      } catch (_) {}
    }
    return out;
  } catch (_) {
    return const [];
  }
});

/// The "المتاجر" tab of the browse screen: filter chips by department, then one
/// card per store that opens its storefront at /vendors/:id.
class StoresTab extends ConsumerStatefulWidget {
  final List<Category> categories;
  final String query;
  const StoresTab({super.key, required this.categories, required this.query});

  @override
  ConsumerState<StoresTab> createState() => _StoresTabState();
}

class _StoresTabState extends ConsumerState<StoresTab> {
  int? _categoryId;

  @override
  Widget build(BuildContext context) {
    final isAr = context.isAr;
    final stores = ref.watch(storesProvider(_categoryId));
    final q = widget.query.trim().toLowerCase();

    return RefreshIndicator(
      color: AppColors.teal,
      onRefresh: () async {
        ref.invalidate(storesProvider(_categoryId));
        await ref
            .read(storesProvider(_categoryId).future)
            .catchError((_) => <StoreEntry>[]);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 14, 4, 12),
            child: Text(
              context.s.storesTab,
              textAlign: isAr ? TextAlign.right : TextAlign.left,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: context.col.ink0,
                fontFamily: 'Manrope',
                fontFamilyFallback: const ['Tajawal'],
              ),
            ),
          ),
          if (widget.categories.isNotEmpty)
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _FilterChip(
                    label: context.s.all,
                    selected: _categoryId == null,
                    onTap: () => setState(() => _categoryId = null),
                  ),
                  for (final c in widget.categories)
                    _FilterChip(
                      label: isAr && c.nameAr.isNotEmpty ? c.nameAr : c.name,
                      selected: _categoryId == c.id,
                      onTap: () => setState(() => _categoryId = c.id),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          ...stores.when(
            loading: () => const [
              SizedBox(
                height: 220,
                child: Center(
                    child: CircularProgressIndicator(color: AppColors.teal)),
              ),
            ],
            error: (_, __) => [
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(children: [
                  Text(context.s.loadStoresFailed,
                      style: TextStyle(color: context.col.ink3)),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () =>
                        ref.invalidate(storesProvider(_categoryId)),
                    child: Text(context.s.retry),
                  ),
                ]),
              ),
            ],
            data: (all) {
              final shown = q.isEmpty
                  ? all
                  : all
                      .where((e) =>
                          e.vendor.storeNameAr.toLowerCase().contains(q) ||
                          e.vendor.storeName.toLowerCase().contains(q))
                      .toList();
              if (shown.isEmpty) {
                return [
                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                      child: Text(context.s.noStoresFound,
                          style: TextStyle(color: context.col.ink3)),
                    ),
                  ),
                ];
              }
              return [
                for (final e in shown)
                  _StoreCard(
                    entry: e,
                    categoryId: _categoryId,
                    key: ValueKey('${e.vendor.id}-$_categoryId'),
                  )
              ];
            },
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsetsDirectional.only(end: 8),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? AppColors.teal.withValues(alpha: 0.10)
                : context.col.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.teal : context.col.borderStrong,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.teal600 : context.col.ink1,
              fontFamily: 'Manrope',
              fontFamilyFallback: const ['Tajawal'],
            ),
          ),
        ),
      );
}

class _StoreCard extends ConsumerWidget {
  final StoreEntry entry;
  final int? categoryId;
  const _StoreCard({required this.entry, this.categoryId, super.key});

  static const _maxChips = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAr = context.isAr;
    final v = entry.vendor;
    final name = isAr && v.storeNameAr.isNotEmpty ? v.storeNameAr : v.storeName;
    // The count is the store's whole catalogue. While a department chip is selected the server
    // narrows the number to that department, which read as if the store had shrunk.
    final total = ref
            .watch(storesProvider(null))
            .valueOrNull
            ?.where((e) => e.vendor.id == v.id)
            .firstOrNull
            ?.productsCount ??
        entry.productsCount;
    final rating = v.averageRating ?? 0;
    final hasReviews = entry.reviewsCount > 0 && rating > 0;
    final deps = entry.departments;
    final shown = deps.take(_maxChips).toList();
    final more = deps.length - shown.length;

    final countText = Text(
      context.s.storeProductsN(total),
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: context.col.ink1,
        fontFamily: 'Manrope',
        fontFamilyFallback: const ['Tajawal'],
      ),
    );

    // One card = name, banner, then departments and count, with generous space below
    // (no divider lines) so it is clear which banner and count belong to which store.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => safePush(context, '/vendors/${v.id}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 14, 0, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Name (+ logo, stars) above the banner
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (v.logo != null && v.logo!.isNotEmpty) ...[
                  ClipOval(
                    child: SizedBox(
                      width: 34,
                      height: 34,
                      child: CachedNetworkImage(
                        imageUrl: v.logo!,
                        fit: BoxFit.cover,
                        memCacheWidth: 110,
                        errorWidget: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: context.col.ink0,
                          fontFamily: 'Manrope',
                          fontFamilyFallback: const ['Tajawal'],
                        ),
                      ),
                      if (hasReviews) ...[
                        const SizedBox(height: 2),
                        Row(children: [
                          for (int i = 1; i <= 5; i++)
                            Icon(
                              i <= rating.round()
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              size: 15,
                              color: i <= rating.round()
                                  ? AppColors.gold
                                  : context.col.ink3,
                            ),
                          const SizedBox(width: 5),
                          Text(
                            '${rating.toStringAsFixed(1)} (${entry.reviewsCount})',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.col.ink3,
                              fontFamily: 'Manrope',
                              fontFamilyFallback: const ['Tajawal'],
                            ),
                          ),
                        ]),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 2.6,
                child: _StoreVisual(vendor: v, categoryId: categoryId),
              ),
            ),
            const SizedBox(height: 6),
            // Departments and the product count on ONE line under the banner
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      for (final d in shown)
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsetsDirectional.only(end: 6),
                            child: _DeptChip(label: isAr ? d.$1 : d.$2),
                          ),
                        ),
                      if (more > 0) _DeptChip(label: '\u200E+$more'),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                countText,
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A small, non-interactive label for one of the store's main departments.
class _DeptChip extends StatelessWidget {
  final String label;
  const _DeptChip({required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: context.col.surfaceSoft,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.col.border),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: context.col.ink1,
            fontFamily: 'Manrope',
            fontFamilyFallback: const ['Tajawal'],
          ),
        ),
      );
}

/// The store's own banner when it has one, otherwise a strip of its products.
class _StoreVisual extends ConsumerWidget {
  final Vendor vendor;
  final int? categoryId;
  const _StoreVisual({required this.vendor, this.categoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bg = context.col.surfaceSoft;
    if (vendor.banner != null && vendor.banner!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: vendor.banner!,
        fit: BoxFit.cover,
        memCacheWidth: 900,
        placeholder: (_, __) => ColoredBox(color: bg),
        errorWidget: (_, __, ___) => ColoredBox(color: bg),
      );
    }
    final imgs =
        ref.watch(storePreviewProvider((vendor.id, categoryId))).valueOrNull;
    if (imgs == null || imgs.isEmpty) {
      return ColoredBox(
        color: bg,
        child: Center(
          child: Icon(Icons.storefront_outlined,
              size: 40, color: context.col.ink3),
        ),
      );
    }
    return ColoredBox(
      color: bg,
      child: Row(
        children: [
          for (int i = 0; i < imgs.length; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            Expanded(
              child: CachedNetworkImage(
                imageUrl: imgs[i],
                fit: BoxFit.cover,
                height: double.infinity,
                memCacheWidth: 400,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
