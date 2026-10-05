import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/utils/l10n.dart';
import '../../../core/utils/navigation.dart';
import '../../../shared/theme/app_theme.dart';
import '../../vendor/widgets/stores_tab.dart';

/// Home-page "Shop by store": a horizontal strip of the stores with the most products.
/// Hidden while loading, on error, or when there are no stores, so it never leaves a hole.
class ShopByStoreSection extends ConsumerWidget {
  const ShopByStoreSection({super.key});

  static const _maxStores = 10;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stores = ref.watch(storesProvider(null)).valueOrNull;
    if (stores == null || stores.isEmpty) return const SizedBox.shrink();
    final shown = stores.take(_maxStores).toList();
    final isAr = context.isAr;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
          child: Row(children: [
            Text(
              context.tr('تسوق حسب المتجر', 'Shop by store'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => context.go('/browse?tab=stores'),
              child: Text(
                isAr ? '← الكل' : 'See all →',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
              ),
            ),
          ]),
        ),
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: shown.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _StoreTile(entry: shown[i]),
          ),
        ),
      ],
    );
  }
}

class _StoreTile extends ConsumerWidget {
  final StoreEntry entry;
  const _StoreTile({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAr = context.isAr;
    final v = entry.vendor;
    final name = isAr && v.storeNameAr.isNotEmpty ? v.storeNameAr : v.storeName;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => safePush(context, '/vendors/${v.id}'),
      child: SizedBox(
        width: 136,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 136,
              height: 66,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.col.border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _TileImage(vendor: v),
                    if (v.logo != null && v.logo!.isNotEmpty)
                      PositionedDirectional(
                        start: 5,
                        bottom: 5,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.18),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: v.logo!,
                              fit: BoxFit.cover,
                              memCacheWidth: 72,
                              errorWidget: (_, __, ___) => const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: context.col.ink0,
                fontFamily: 'Manrope',
                fontFamilyFallback: const ['Tajawal'],
              ),
            ),
            const SizedBox(height: 1),
            Text(
              context.s.storeProductsN(entry.productsCount),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                color: context.col.ink3,
                fontFamily: 'Manrope',
                fontFamilyFallback: const ['Tajawal'],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The store's banner when it has one, otherwise its first product photo.
class _TileImage extends ConsumerWidget {
  final dynamic vendor;
  const _TileImage({required this.vendor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bg = context.col.surfaceSoft;
    final banner = vendor.banner as String?;
    if (banner != null && banner.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: banner,
        fit: BoxFit.cover,
        memCacheWidth: 400,
        placeholder: (_, __) => ColoredBox(color: bg),
        errorWidget: (_, __, ___) => ColoredBox(color: bg),
      );
    }
    final imgs = ref.watch(storePreviewProvider((vendor.id as int, null))).valueOrNull;
    if (imgs == null || imgs.isEmpty) {
      return ColoredBox(
        color: bg,
        child: Center(
          child: Icon(Icons.storefront_outlined, size: 32, color: context.col.ink3),
        ),
      );
    }
    return ColoredBox(
      color: bg,
      child: CachedNetworkImage(
        imageUrl: imgs.first,
        fit: BoxFit.cover,
        memCacheWidth: 400,
        errorWidget: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }
}
