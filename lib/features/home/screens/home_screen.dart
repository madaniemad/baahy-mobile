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
                        borderRadius: BorderRadius.circular(6),
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
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: _PromiseStrip(config: config),
                ),
              ),

              // ── Picked for you (matches web: featured before promo) ──
              if (home.featured.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _SectionHead(
                    ar: 'مختار لك',
                    en: 'Picked for you',
                    onAll: () => safePush(context, '/search/results?q=&sort=featured'),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _HorizontalProductList(products: home.featured),
                ),
              ],

              // ── Promo banners — full-width, same 1920/700 ratio as hero ──
              if (banners.promoLeft.any((b) => b.hasImage) || banners.promoRight.any((b) => b.hasImage))
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _BannerStack(
                      banners: [
                        ...banners.promoLeft.where((b) => b.hasImage),
                        ...banners.promoRight.where((b) => b.hasImage),
                      ],
                      aspectRatio: 1920 / 700,
                    ),
                  ),
                ),

              // ── Deals of the day with countdown timer ──
              if (home.deals.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _DealsHead(
                    onAll: () => safePush(context, '/search/results?q=&on_sale=1&sort=popular'),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _HorizontalProductList(products: home.deals),
                ),
              ],

              // ── Fashion banner cards carousel (slot: fashion_banner) ──
              if (banners.fashionBanner.any((b) => b.hasImage))
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _FashionBannerTiles(banners: banners.fashionBanner),
                  ),
                ),

              // ── Brand carousel — immediately after fashion cards ──
              SliverToBoxAdapter(
                child: Consumer(builder: (ctx, ref2, _) {
                  final brands = ref2.watch(_brandsProvider).valueOrNull ?? [];
                  if (brands.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: _BrandCarousel(brands: brands),
                  );
                }),
              ),

              // ── Featured Products ──
              if (home.newArrivals.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _SectionHead(
                    ar: 'منتجات مميزة',
                    en: 'Featured Products',
                    onAll: () => safePush(context, '/search/results?q=&featured=1&sort=popular'),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _HorizontalProductList(products: home.newArrivals),
                ),
              ],

              // ── Admin-controlled sections in exact admin order ──
              ...home.orderedDynamicSections.expand((item) sync* {
                if (item is DynGrid) {
                  yield SliverToBoxAdapter(
                    child: _SectionHead(
                      ar: item.titleAr.isNotEmpty ? item.titleAr : 'منتجات',
                      en: item.titleEn.isNotEmpty ? item.titleEn : 'Products',
                      onAll: item.viewAllUrl != null
                          ? () {
                              final isAr = Localizations.localeOf(context).languageCode == 'ar';
                              safePush(
                                context,
                                '/search/results${item.viewAllUrl}',
                                extra: {'title': isAr ? item.titleAr : item.titleEn},
                              );
                            }
                          : null,
                    ),
                  );
                  yield SliverToBoxAdapter(child: _BudgetCarousel(products: item.products));
                  yield const SliverToBoxAdapter(child: SizedBox(height: 21));
                } else if (item is DynCarousel) {
                  // SizedBox(340) naturally leaves ~21px below card content — no extra padding needed.
                  yield SliverToBoxAdapter(
                    child: _CategoryCarouselSection(section: item.section),
                  );
                } else if (item is DynBannerDuo) {
                  yield SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 21),
                      child: _DuoBannerRow(section: item.section),
                    ),
                  );
                } else if (item is DynStripBanner) {
                  yield SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 21),
                      child: GestureDetector(
                        onTap: () => BannerLink.navigate(context, item.linkUrl),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: AspectRatio(
                            aspectRatio: 1920 / 350,
                            child: CachedNetworkImage(
                              imageUrl: item.imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(color: const Color(0xFF1FD7E2)),
                              errorWidget: (_, __, ___) => Container(color: const Color(0xFF1FD7E2)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                } else if (item is DynCategoryCarousel) {
                  // SizedBox(110) has ~8px of natural bottom space; add 13px explicit = 21px total.
                  yield SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 13),
                      child: _CategoryImagesCarousel(item: item),
                    ),
                  );
                } else if (item is DynBanner) {
                  yield SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 21),
                      child: _SingleBannerSection(item: item),
                    ),
                  );
                } else if (item is DynFashionCards) {
                  yield SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 21),
                      child: _DynFashionCardsSection(item: item),
                    ),
                  );
                }
              }),

              // ── Tile carousel ──
              if (banners.tile1.isNotEmpty || banners.tile2.isNotEmpty || banners.tile3.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _TileCarousel(banners: [
                      ...banners.tile1.where((b) => b.hasImage),
                      ...banners.tile2.where((b) => b.hasImage),
                      ...banners.tile3.where((b) => b.hasImage),
                    ]),
                  ),
                ),

              // ── Mid banners ──
              if (banners.midBanner.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: _BannerStack(banners: banners.midBanner),
                  ),
                ),

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
