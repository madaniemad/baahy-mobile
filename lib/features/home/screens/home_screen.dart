import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers/home_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/notifications_provider.dart';
import '../../../core/providers/recently_viewed_provider.dart';
import '../../../core/providers/banner_provider.dart';
import '../../../core/providers/app_config_provider.dart';
import '../../../core/providers/address_provider.dart';
import '../../../core/providers/app_pages_provider.dart';
import '../../../core/models/app_config.dart';
import '../../../core/models/product.dart';
import '../../../core/models/banner.dart';
import '../../../core/utils/banner_link.dart';
import '../../../core/utils/image_url.dart';
import '../../../core/utils/l10n.dart';
import '../../../core/utils/navigation.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/product_card.dart';
import '../../../core/utils/format.dart';
import '../../../core/providers/tier_provider.dart';
import '../../../core/models/tier_status.dart';
import '../../../core/providers/welcome_coupon_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';


part '../widgets/home_screen_widgets.dart';

class Brand {
  final int id;
  final String name;
  final String nameAr;
  final String imageUrl;
  final String link;
  const Brand({required this.id, required this.name, required this.nameAr, required this.imageUrl, required this.link});
  factory Brand.fromJson(Map<String, dynamic> j) => Brand(
    id: j['id'] as int,
    name: j['name'] as String,
    nameAr: j['name_ar'] as String? ?? j['name'] as String,
    imageUrl: j['image_url'] as String? ?? '',
    link: j['link'] as String? ?? '',
  );
}

final _brandsProvider = FutureProvider<List<Brand>>((ref) async {
  try {
    final res = await ApiClient.instance.dio.get('/brands');
    final list = (res.data?['data'] as List?) ?? [];
    return list.map((e) => Brand.fromJson(e as Map<String, dynamic>)).toList();
  } catch (_) {
    return [];
  }
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeProvider);
    final banners = ref.watch(bannersProvider);
    final config = ref.watch(appConfigProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: context.col.bg,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(_activeOrderProvider);
          await ref.read(homeProvider.notifier).fetch();
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              automaticallyImplyLeading: false,
              backgroundColor: isDark ? context.col.surface : const Color(0xFF1FD7E2),
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              toolbarHeight: 28,
              titleSpacing: 0,
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.none,
                background: Stack(fit: StackFit.expand, children: [
                  Container(color: isDark ? context.col.surface : const Color(0xFF1FD7E2)),
                  Opacity(
                    opacity: isDark ? 0.07 : 0.28,
                    child: Image.asset(
                      'assets/images/onb-pattern.png',
                      fit: BoxFit.cover,
                      color: isDark ? Colors.white : null,
                      colorBlendMode: isDark ? BlendMode.srcIn : null,
                    ),
                  ),
                ]),
              ),
              title: Padding(
                padding: const EdgeInsets.only(right: 16, left: 8),
                child: Row(children: [
                  const _CityLabel(),
                  const Spacer(),
                  const _NotificationBell(),
                ]),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(50),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                  child: GestureDetector(
                    onTap: () => safePush(context, '/search'),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? context.col.surfaceSoft : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.col.borderStrong, width: 1.0),
                      ),
                      child: Row(children: [
                        Icon(Icons.search, size: 17, color: context.col.ink1),
                        const SizedBox(width: 7),
                        Expanded(child: _SearchHintText()),
                        GestureDetector(
                          onTap: () => safePush(context, '/search/camera'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(Icons.camera_alt_outlined, size: 17, color: context.col.ink1),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
            // ── Seasonal cashback banner ────────────────────────────────────
            if (config.seasonalEnabled)
              SliverToBoxAdapter(
                child: _SeasonalBanner(config: config),
              ),

            if ((home.loading && home.featured.isEmpty && home.newArrivals.isEmpty) || !banners.initialized)
              const SliverFillRemaining(child: _HomeSkeleton())
            else ...[
              // One-time rewards modal (invisible trigger)
              const SliverToBoxAdapter(child: _RewardsModalTrigger()),

              // Active order strip + rewards nudge carousel
              const SliverToBoxAdapter(child: _ActiveOrderStrip()),

              // First-order welcome coupon banner (new users only)
              const SliverToBoxAdapter(child: _WelcomeCouponBanner()),

              // Hero banner slider (real data from /api/content/banners)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _HeroBannerSlider(banners: banners.hero),
                ),
              ),

              // Sub-hero banner — half height of hero, fades between images
              if (banners.subHero.any((b) => b.hasImage))
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: _SubHeroBanner(banners: banners.subHero),
                  ),
                ),

              // Categories 4-col grid (before trust strip, no header)
              if (home.categories.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: _CategoriesGrid(categories: home.categories),
                  ),
                ),

              // Promise strip
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _PromiseStrip(config: config),
                ),
              ),


              // ── Admin-controlled sections in exact admin order ──
              ...home.orderedDynamicSections.expand((item) sync* {
                if (item is DynGrid) {
                  yield SliverToBoxAdapter(
                    child: _SectionHead(
                      ar: item.titleAr.isNotEmpty ? item.titleAr : 'منتجات',
                      en: item.titleEn.isNotEmpty ? item.titleEn : 'Products',
                      onAll: item.viewAllUrl != null
                          ? () => BannerLink.navigate(
                              context,
                              '/products${item.viewAllUrl}',
                            )
                          : null,
                    ),
                  );
                  yield SliverToBoxAdapter(child: _BudgetCarousel(products: item.products));
                  yield const SliverToBoxAdapter(child: SizedBox(height: 20));
                } else if (item is DynCarousel) {
                  yield SliverToBoxAdapter(
                    child: _CategoryCarouselSection(section: item.section),
                  );
                } else if (item is DynBannerDuo) {
                  yield SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                      child: _DuoBannerRow(section: item.section),
                    ),
                  );
                } else if (item is DynStripBanner) {
                  yield SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                      child: GestureDetector(
                        onTap: () => BannerLink.navigate(context, item.linkUrl),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AspectRatio(
                            aspectRatio: 1920 / 350,
                            child: CachedNetworkImage(
                              imageUrl: optimizeImg(item.imageUrl, width: 1080),
                              fit: BoxFit.cover,
                              memCacheWidth: 1080,
                              placeholder: (_, __) => Container(color: const Color(0xFF1FD7E2)),
                              errorWidget: (_, __, ___) => Container(color: const Color(0xFF1FD7E2)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                } else if (item is DynCategoryCarousel) {
                  yield SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 22, bottom: 8),
                      child: _CategoryImagesCarousel(item: item),
                    ),
                  );
                } else if (item is DynBanner) {
                  yield SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                      child: _SingleBannerSection(item: item),
                    ),
                  );
                } else if (item is DynFashionCards) {
                  yield SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 14, bottom: 10),
                      child: _DynFashionCardsSection(item: item),
                    ),
                  );
                } else if (item is DynFeatured) {
                  final featProds = home.featured;
                  if (featProds.isNotEmpty) {
                    yield SliverToBoxAdapter(
                      child: _SectionHead(
                        ar: item.titleAr.isNotEmpty ? item.titleAr : 'مختار لك',
                        en: item.titleEn.isNotEmpty ? item.titleEn : 'Picks for you',
                        onAll: () => safePush(context, '/search/results?q=&sort=featured'),
                      ),
                    );
                    yield SliverToBoxAdapter(child: _HorizontalProductList(products: featProds));
                  }
                } else if (item is DynDeals) {
                  final dealProds = home.deals.isNotEmpty ? home.deals : item.fallbackProducts;
                  if (dealProds.isNotEmpty) {
                    yield SliverToBoxAdapter(
                      child: _DealsHead(
                        onAll: () => safePush(context, '/search/results?q=&on_sale=1&sort=popular'),
                      ),
                    );
                    yield SliverToBoxAdapter(child: _HorizontalProductList(products: dealProds));
                  }
                } else if (item is DynBrandCarousel) {
                  yield SliverToBoxAdapter(
                    child: Consumer(builder: (ctx, ref2, _) {
                      final brands = ref2.watch(_brandsProvider).valueOrNull ?? [];
                      if (brands.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: _BrandCarousel(brands: brands),
                      );
                    }),
                  );
                } else if (item is DynTileCarousel) {
                  yield SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: _DynTileCarousel(item: item),
                    ),
                  );
                }
              }),

              // Recently viewed
              const SliverToBoxAdapter(child: _RecentlyViewedSection()),

              // baahy promise closing block
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                  child: _BaahyPromiseCard(),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 8)),
            ],
          ],
        ),
      ),
    );
  }
}
