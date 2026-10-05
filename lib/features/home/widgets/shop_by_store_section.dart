import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/utils/l10n.dart';
import '../../../core/utils/navigation.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/store_logo_placeholder.dart';
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
          height: 128,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: shown.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => _StoreTile(entry: shown[i]),
          ),
        ),
      ],
    );
  }
}

/// Square card with the store's logo; stores with no logo get the default Baahy store mark.
class _StoreTile extends StatelessWidget {
  final StoreEntry entry;
  const _StoreTile({required this.entry});

  static const _size = 96.0;

  @override
  Widget build(BuildContext context) {
    final isAr = context.isAr;
    final v = entry.vendor;
    final name = isAr && v.storeNameAr.isNotEmpty ? v.storeNameAr : v.storeName;
    final logo = v.logo;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => safePush(context, '/vendors/${v.id}'),
      child: SizedBox(
        width: _size,
        child: Column(
          children: [
            Container(
              width: _size,
              height: _size,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: context.col.border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: logo != null && logo.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: logo,
                        fit: BoxFit.cover,
                        memCacheWidth: 300,
                        errorWidget: (_, __, ___) => const StoreLogoPlaceholder(),
                      )
                    : const StoreLogoPlaceholder(),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: context.col.ink0,
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
