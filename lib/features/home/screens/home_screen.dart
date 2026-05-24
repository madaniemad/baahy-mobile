import 'dart:async';
import 'package:flutter/material.dart';
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
import '../../../core/models/app_config.dart';
import '../../../core/models/product.dart';
import '../../../core/models/banner.dart';
import '../../../core/utils/banner_link.dart';
import '../../../core/utils/l10n.dart';
import '../../../core/utils/navigation.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/product_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeProvider);
    final unread = ref.watch(unreadNotificationCountProvider);
    final banners = ref.watch(bannersProvider);
    final config = ref.watch(appConfigProvider);
    final city = ref.watch(cityProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(homeProvider.notifier).fetch(),
        child: CustomScrollView(
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _HomeAppBar(
                city: city,
                unreadCount: unread,
                topPadding: MediaQuery.of(context).padding.top,
              ),
            ),
            if (home.loading && home.featured.isEmpty)
              const SliverFillRemaining(child: _HomeSkeleton())
            else ...[
              // Active order strip
              const SliverToBoxAdapter(child: _ActiveOrderStrip()),

              // Hero banner slider (real data from /api/content/banners)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _HeroBannerSlider(banners: banners.hero),
                ),
              ),

              // Promise strip
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: _PromiseStrip(config: config),
                ),
              ),

              // Categories 4-col grid
              if (home.categories.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _SectionHead(
                    ar: 'تسوّق حسب القسم',
                    en: 'Categories',
                    onAll: () => context.go('/browse'),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _CategoriesGrid(categories: home.categories),
                ),
              ],

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

              // ── Deals of the day (matches web: after promo) ──
              if (home.deals.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _SectionHead(
                    ar: 'عروض اليوم',
                    en: 'Deals of the day',
                    onAll: () => safePush(context, '/search/results?q='),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _HorizontalProductList(products: home.deals),
                ),
              ],

              // ── Category carousel 0 ──
              if (home.categorySections.isNotEmpty)
                SliverToBoxAdapter(
                  child: _CategoryCarouselSection(section: home.categorySections[0]),
                ),

              // ── Bestsellers 2x2 ──
              if (home.popular.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _SectionHead(
                    ar: 'الأكثر مبيعاً',
                    en: 'Bestsellers',
                    onAll: () => safePush(context, '/search/results?q=&sort=popular'),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _BestsellerGrid(products: home.popular.take(4).toList()),
                ),
              ],

              // ── Category carousel 1 ──
              if (home.categorySections.length > 1)
                SliverToBoxAdapter(
                  child: _CategoryCarouselSection(section: home.categorySections[1]),
                ),

              // ── Fashion banner cards carousel (slot: fashion_banner) ──
              if (banners.fashionBanner.any((b) => b.hasImage))
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _FashionBannerTiles(banners: banners.fashionBanner),
                  ),
                ),

              // ── Brand carousel — immediately after fashion cards ──
              if (banners.promoStrip.any((b) => b.hasImage))
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: _BrandCarousel(brands: banners.promoStrip),
                  ),
                ),

              // ── New arrivals ──
              if (home.newArrivals.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _SectionHead(
                    ar: 'وصل حديثاً',
                    en: 'New arrivals',
                    onAll: () => safePush(context, '/search/results?q=&sort=latest'),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _NewArrivalsRow(products: home.newArrivals),
                ),
              ],

              // ── Under 50 LYD ──
              if (home.budget.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _SectionHead(ar: 'أقل من 50 د.ل', en: 'Under 50 LYD',
                    onAll: () => safePush(context, '/search/results?q=&max_price=50')),
                ),
                SliverToBoxAdapter(
                  child: _BudgetGrid(products: home.budget),
                ),
              ],

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

              // ── Category carousel 2 ──
              if (home.categorySections.length > 2)
                SliverToBoxAdapter(
                  child: _CategoryCarouselSection(section: home.categorySections[2]),
                ),

              // ── Mid banners ──
              if (banners.midBanner.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: _BannerStack(banners: banners.midBanner),
                  ),
                ),

              // ── Remaining category carousels (3+) ──
              ...List.generate(
                (home.categorySections.length - 3).clamp(0, 20),
                (i) => SliverToBoxAdapter(
                  child: _CategoryCarouselSection(section: home.categorySections[3 + i]),
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

// ── App Bar ──────────────────────────────────────────────────────────────────

class _HomeAppBar extends SliverPersistentHeaderDelegate {
  final String city;
  final int unreadCount;
  final double topPadding;
  const _HomeAppBar({required this.city, required this.unreadCount, required this.topPadding});

  double get _height => topPadding + 112;

  @override double get minExtent => _height;
  @override double get maxExtent => _height;
  @override bool shouldRebuild(_) => true;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        top: topPadding,
        left: 16, right: 16, bottom: 10,
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => context.push('/city'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(children: [
                    const Icon(Icons.location_on_rounded, size: 12, color: AppColors.teal600),
                    const SizedBox(width: 4),
                    Text(city, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 3),
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: AppColors.ink3),
                  ]),
                ),
              ),
              const Spacer(),
              Stack(
                children: [
                  IconButton(
                    onPressed: () => safePush(context, '/notifications'),
                    icon: const Icon(Icons.notifications_none_rounded, color: AppColors.ink0),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      top: 0, right: 0,
                      child: Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => safePush(context, '/search'),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(children: const [
                Icon(Icons.search, size: 18, color: AppColors.ink3),
                SizedBox(width: 8),
                Expanded(child: _SearchHintText()),
                Icon(Icons.mic_none_rounded, size: 18, color: AppColors.ink3),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchHintText extends StatelessWidget {
  const _SearchHintText();
  @override
  Widget build(BuildContext context) => Text(
    context.s.searchHint,
    style: const TextStyle(color: AppColors.ink3, fontSize: 14));
}

// ── Active order strip ────────────────────────────────────────────────────────

final _activeOrderProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  try {
    final res = await ApiClient.instance.dio.get('/orders',
      queryParameters: {'status': 'shipped,confirmed,processing', 'per_page': 1});
    final list = res.data['data']['data'] as List?;
    if (list != null && list.isNotEmpty) return Map<String, dynamic>.from(list.first);
    return null;
  } catch (_) { return null; }
});

class _ActiveOrderStrip extends ConsumerWidget {
  const _ActiveOrderStrip();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(_activeOrderProvider);
    return orderAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (order) {
        if (order == null) return const SizedBox.shrink();
        final orderId = order['id'];
        final orderNum = order['order_number'] ?? '#$orderId';
        return GestureDetector(
          onTap: () => safePush(context, '/orders/$orderId'),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F8F8),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFB2E4E6)),
            ),
            child: Row(children: [
              const Icon(Icons.local_shipping_outlined, size: 16, color: AppColors.teal600),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(TextSpan(
                  style: const TextStyle(fontSize: 12.5),
                  children: [
                    const TextSpan(text: 'في الطريق',
                      style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink0)),
                    TextSpan(text: ' · $orderNum',
                      style: const TextStyle(color: AppColors.ink3)),
                  ],
                )),
              ),
              const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.ink3),
            ]),
          ),
        );
      },
    );
  }
}

// ── Hero banner slider ────────────────────────────────────────────────────────

class _HeroBannerSlider extends StatefulWidget {
  final List<AppBanner> banners;
  const _HeroBannerSlider({required this.banners});
  @override
  State<_HeroBannerSlider> createState() => _HeroBannerSliderState();
}

class _HeroBannerSliderState extends State<_HeroBannerSlider> {
  final _pageCtrl = PageController();
  int _current = 0;
  Timer? _timer;

  static const _gradients = [
    [Color(0xFF1F2E2E), Color(0xFF0A1A1A)],
    [Color(0xFF1A1A3E), Color(0xFF0A0A1A)],
    [Color(0xFF2E1A1A), Color(0xFF1A0A0A)],
    [Color(0xFF1A2E1A), Color(0xFF0A1A0A)],
  ];

  @override
  void initState() {
    super.initState();
    if (widget.banners.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (!mounted) return;
        final next = (_current + 1) % widget.banners.length;
        _pageCtrl.animateToPage(next,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Eagerly precache all banner images so scroll transitions are instant.
    for (final b in widget.banners) {
      if (b.hasImage) {
        precacheImage(CachedNetworkImageProvider(b.imageUrl!), context);
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) return const _HeroBannerFallback();

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: AspectRatio(
        aspectRatio: 1920 / 700,
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageCtrl,
              itemCount: widget.banners.length,
              onPageChanged: (i) => setState(() => _current = i),
              itemBuilder: (_, i) => _BannerSlide(
                banner: widget.banners[i],
                gradient: _gradients[i % _gradients.length],
              ),
            ),
            if (widget.banners.length > 1)
              Positioned(
                bottom: 10, left: 0, right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(widget.banners.length, (i) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _current == i ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: _current == i ? 0.9 : 0.35),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  )),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BannerSlide extends StatelessWidget {
  final AppBanner banner;
  final List<Color> gradient;
  const _BannerSlide({required this.banner, required this.gradient});

  void _handleTap(BuildContext context) =>
      BannerLink.navigate(context, banner.buttonLink);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _handleTap(context),
      child: Stack(fit: StackFit.expand, children: [
        // Background: real image or gradient
        if (banner.hasImage)
          CachedNetworkImage(
            imageUrl: banner.imageUrl!,
            fit: BoxFit.cover,
            placeholder: (_, __) => _gradientBg(gradient),
            errorWidget: (_, __, ___) => _gradientBg(gradient),
          )
        else
          _gradientBg(gradient),

        if (banner.showOverlay) ...[
          // Dark gradient for text readability
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: banner.textSide == 'left' ? Alignment.topLeft : Alignment.topRight,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.65)],
              ),
            ),
          ),

          // Text content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: banner.textSide == 'left'
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (banner.badgeText != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(banner.badgeText!,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                        color: Colors.white, letterSpacing: 0.5)),
                  ),
                if (banner.titleAr != null)
                  Text(banner.titleAr!,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                      color: Colors.white, height: 1.2)),
                if (banner.subtitleAr != null) ...[
                  const SizedBox(height: 4),
                  Text(banner.subtitleAr!,
                    style: TextStyle(fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.8))),
                ],
                if (banner.buttonText != null) ...[
                  const SizedBox(height: 10),
                  Text('${banner.buttonText} ←',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
                ],
              ],
            ),
          ),
        ],
      ]),
    );
  }

  Widget _gradientBg(List<Color> colors) => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
    ),
  );
}

class _HeroBannerFallback extends StatelessWidget {
  const _HeroBannerFallback();
  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1920 / 700,
      child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF1F2E2E), Color(0xFF0A1A1A)],
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Text('أهلاً بك في باهي',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
              color: Colors.white)),
          const SizedBox(height: 4),
          Text('اكتشف آلاف المنتجات من متاجر ليبيا',
            style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.75))),
        ],
      ),
      ),
    );
  }
}

// ── Generic banner stack (N banners, vertically stacked) ─────────────────────

class _BannerStack extends StatelessWidget {
  final List<AppBanner> banners;
  final double aspectRatio;
  const _BannerStack({required this.banners, this.aspectRatio = 1920 / 700});

  static const _gradients = [
    [Color(0xFF1F2E2E), Color(0xFF0A1A1A)],
    [Color(0xFF1A1A3E), Color(0xFF0A0A1A)],
    [Color(0xFF2E1A1A), Color(0xFF1A0A0A)],
    [Color(0xFF1A2E1A), Color(0xFF0A1A0A)],
  ];

  @override
  Widget build(BuildContext context) {
    if (banners.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (int i = 0; i < banners.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: _BannerSlide(
                banner: banners[i],
                gradient: _gradients[i % _gradients.length],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Promise strip ─────────────────────────────────────────────────────────────

class _PromiseStrip extends StatelessWidget {
  final AppConfig config;
  const _PromiseStrip({required this.config});
  @override
  Widget build(BuildContext context) {
    final threshold = config.freeShippingThreshold.toStringAsFixed(0);
    final returnDays = config.returnDays;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.shadowCard,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _PromiseChip(icon: Icons.local_shipping_outlined,
            ar: 'مجاني فوق $threshold', en: 'Free over $threshold'),
          Container(width: 1, height: 28, color: AppColors.border),
          _PromiseChip(icon: Icons.refresh_rounded,
            ar: 'إرجاع $returnDays أيام', en: '${returnDays}-day returns'),
          Container(width: 1, height: 28, color: AppColors.border),
          _PromiseChip(icon: Icons.payments_outlined, ar: 'دفع عند الاستلام', en: 'COD available'),
        ],
      ),
    );
  }
}

class _PromiseChip extends StatelessWidget {
  final IconData icon;
  final String ar;
  final String en;
  const _PromiseChip({required this.icon, required this.ar, required this.en});
  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Column(children: [
      Icon(icon, size: 20, color: AppColors.teal600),
      const SizedBox(height: 4),
      Text(isAr ? ar : en,
        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.ink1),
        textAlign: TextAlign.center),
    ]);
  }
}

// ── Section head ──────────────────────────────────────────────────────────────

class _SectionHead extends StatelessWidget {
  final String ar;
  final String en;
  final VoidCallback? onAll;
  const _SectionHead({required this.ar, required this.en, this.onAll});
  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Row(children: [
        Text(isAr ? ar : en,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const Spacer(),
        if (onAll != null)
          GestureDetector(
            onTap: onAll,
            child: Text(isAr ? '← الكل' : 'See all →',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: AppColors.primary)),
          ),
      ]),
    );
  }
}

// ── Horizontal product list ───────────────────────────────────────────────────

class _HorizontalProductList extends StatelessWidget {
  final List<Product> products;
  const _HorizontalProductList({required this.products});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 366,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => ProductCard(product: products[i], width: 165),
      ),
    );
  }
}

// ── Categories 2-row horizontal carousel ─────────────────────────────────────

class _CategoriesGrid extends StatelessWidget {
  final List<Category> categories;
  const _CategoriesGrid({required this.categories});

  static const _parentColors = [
    Color(0xFF0D9488), Color(0xFF7C3AED), Color(0xFFD97706),
    Color(0xFFDB2777), Color(0xFF2563EB), Color(0xFF059669), Color(0xFFDC2626),
  ];

  static IconData _iconFor(String name) {
    final n = name.toLowerCase();
    if (n.contains('cloth') || n.contains('ملاب')) return Icons.checkroom_outlined;
    if (n.contains('shoe') || n.contains('احذية')) return Icons.directions_walk_outlined;
    if (n.contains('bag') || n.contains('حقيب')) return Icons.shopping_bag_outlined;
    if (n.contains('watch') || n.contains('ساعة') || n.contains('ساعات')) return Icons.watch_outlined;
    if (n.contains('eye') || n.contains('نظار')) return Icons.visibility_outlined;
    if (n.contains('access') || n.contains('اكسسوار')) return Icons.diamond_outlined;
    if (n.contains('perfume') || n.contains('عطور') || n.contains('عطر')) return Icons.science_outlined;
    if (n.contains('makeup') || n.contains('مكياج')) return Icons.face_retouching_natural_outlined;
    if (n.contains('hair') || n.contains('شعر')) return Icons.content_cut_outlined;
    if (n.contains('skin') || n.contains('بشرة')) return Icons.spa_outlined;
    if (n.contains('baby') || n.contains('مواليد')) return Icons.child_care_outlined;
    if (n.contains('girl') || n.contains('بنات')) return Icons.girl_outlined;
    if (n.contains('boy') || n.contains('اولاد')) return Icons.boy_outlined;
    if (n.contains('phone') || n.contains('هاتف')) return Icons.smartphone_outlined;
    if (n.contains('laptop') || n.contains('حاسوب')) return Icons.laptop_outlined;
    if (n.contains('electron') || n.contains('إلكترون') || n.contains('الكترون')) return Icons.devices_outlined;
    if (n.contains('kitchen') || n.contains('مطبخ')) return Icons.kitchen_outlined;
    if (n.contains('furniture') || n.contains('اثاث')) return Icons.weekend_outlined;
    if (n.contains('home') || n.contains('منزل') || n.contains('بيت')) return Icons.home_outlined;
    if (n.contains('sport') || n.contains('رياضة')) return Icons.sports_outlined;
    if (n.contains('women') || n.contains('نساء')) return Icons.woman_outlined;
    if (n.contains('men') || n.contains('رجال')) return Icons.man_outlined;
    if (n.contains('kid') || n.contains('اطفال') || n.contains('طفل')) return Icons.child_friendly_outlined;
    if (n.contains('beauty') || n.contains('جمال')) return Icons.auto_awesome_outlined;
    return Icons.category_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    // Build flat list: each parent followed by its children
    final items = <({Category cat, Color color, bool isParent})>[];
    for (var i = 0; i < categories.length; i++) {
      final color = _parentColors[i % _parentColors.length];
      final parent = categories[i];
      items.add((cat: parent, color: color, isParent: true));
      for (final child in parent.children) {
        items.add((cat: child, color: color, isParent: false));
      }
    }

    return SizedBox(
      height: 190,
      child: GridView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 6,
          mainAxisExtent: 80,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final item = items[i];
          final name = isAr ? item.cat.nameAr : item.cat.name;
          final icon = _iconFor(item.cat.nameAr + item.cat.name);
          return GestureDetector(
            onTap: () => safePush(context, '/search/results?q=&category=${item.cat.id}'),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 64, height: 64,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: item.cat.image != null
                        ? CachedNetworkImage(imageUrl: item.cat.image!, fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              color: item.color.withValues(alpha: 0.15),
                              child: Icon(icon, size: 26, color: item.color)))
                        : Container(
                            color: item.color.withValues(alpha: 0.15),
                            child: Icon(icon, size: 20, color: item.color)),
                  ),
                ),
                const SizedBox(height: 3),
                Text(name,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: item.isParent ? FontWeight.w700 : FontWeight.w500,
                    color: item.isParent ? AppColors.ink0 : AppColors.ink1,
                  ),
                  textAlign: TextAlign.center, maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Fashion banner portrait tiles ─────────────────────────────────────────────

class _FashionBannerTiles extends StatelessWidget {
  final List<AppBanner> banners;
  const _FashionBannerTiles({required this.banners});

  @override
  Widget build(BuildContext context) {
    final visible = banners.where((b) => b.hasImage).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    final sw = MediaQuery.of(context).size.width;
    // Height fixed from original formula; width slightly increased (peek shrinks to 10px).
    final cardH = ((sw - 46) / 2) * 16 / 9;
    final cardW = (sw - 16 - 2 - 10) / 2;

    return SizedBox(
      height: cardH,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 16),
        itemCount: visible.length,
        separatorBuilder: (_, __) => const SizedBox(width: 2),
        itemBuilder: (_, i) => _FashionTile(banner: visible[i], width: cardW, height: cardH),
      ),
    );
  }
}

class _FashionTile extends StatelessWidget {
  final AppBanner banner;
  final double width;
  final double height;
  const _FashionTile({required this.banner, required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => BannerLink.navigate(context, banner.buttonLink),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(fit: StackFit.expand, children: [
            if (banner.hasImage)
              CachedNetworkImage(imageUrl: banner.imageUrl!, fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(color: const Color(0xFF1A1A3E)))
            else
              Container(color: const Color(0xFF1A1A3E)),
            if (banner.showOverlay) ...[
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (banner.badgeText != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary, borderRadius: BorderRadius.circular(99)),
                        child: Text(banner.badgeText!,
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                            color: Colors.white)),
                      ),
                    if (banner.titleAr != null)
                      Text(banner.titleAr!,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                          color: Colors.white, height: 1.2)),
                    if (banner.buttonText != null) ...[
                      const SizedBox(height: 8),
                      Text('${banner.buttonText} ←',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                    ],
                  ],
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

// ── Brand logo carousel ───────────────────────────────────────────────────────

class _BrandCarousel extends StatelessWidget {
  final List<AppBanner> brands;
  const _BrandCarousel({required this.brands});

  static const double _tileSize = 78;
  static const double _gap = 8;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text('تسوق حسب البراند',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center),
        ),
        SizedBox(
          height: _tileSize * 2 + _gap,
          child: GridView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: _gap,
              crossAxisSpacing: _gap,
              mainAxisExtent: _tileSize,
            ),
            itemCount: brands.length,
            itemBuilder: (_, i) {
              final brand = brands[i];
              return GestureDetector(
                onTap: () => BannerLink.navigate(context, brand.buttonLink),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: brand.hasImage
                      ? CachedNetworkImage(imageUrl: brand.imageUrl!, fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(color: AppColors.surfaceSoft,
                            child: const Icon(Icons.store_outlined, color: AppColors.ink3, size: 24)))
                      : Container(color: AppColors.surfaceSoft,
                          child: const Icon(Icons.store_outlined, color: AppColors.ink3, size: 24)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Tile carousel — full-width swipeable, 1920/700 ratio (all tile slots) ──────

class _TileCarousel extends StatefulWidget {
  final List<AppBanner> banners;
  const _TileCarousel({required this.banners});
  @override
  State<_TileCarousel> createState() => _TileCarouselState();
}

class _TileCarouselState extends State<_TileCarousel> {
  final _pageCtrl = PageController();
  int _current = 0;

  static const _gradients = [
    [Color(0xFF1F2E2E), Color(0xFF0A1A1A)],
    [Color(0xFF1A1A3E), Color(0xFF0A0A1A)],
    [Color(0xFF2E1A1A), Color(0xFF1A0A0A)],
  ];

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: AspectRatio(
        aspectRatio: 1920 / 700,
        child: Stack(children: [
          PageView.builder(
            controller: _pageCtrl,
            itemCount: widget.banners.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (_, i) => _BannerSlide(
              banner: widget.banners[i],
              gradient: _gradients[i % _gradients.length],
            ),
          ),
          if (widget.banners.length > 1)
            Positioned(
              bottom: 10, left: 0, right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.banners.length, (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _current == i ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: _current == i ? 0.9 : 0.35),
                    borderRadius: BorderRadius.circular(99),
                  ),
                )),
              ),
            ),
        ]),
      ),
    );
  }
}

// ── 2-col product grid ────────────────────────────────────────────────────────

class _TwoColGrid extends StatelessWidget {
  final List<Product> products;
  const _TwoColGrid({required this.products});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12,
          mainAxisExtent: 378,
        ),
        itemCount: products.length,
        itemBuilder: (_, i) => ProductCard(product: products[i]),
      ),
    );
  }
}

// ── Category carousel section ─────────────────────────────────────────────────

class _CategoryCarouselSection extends StatelessWidget {
  final CategorySection section;
  const _CategoryCarouselSection({required this.section});
  @override
  Widget build(BuildContext context) {
    if (section.products.isEmpty) return const SizedBox.shrink();
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final catName = isAr ? section.category.nameAr : section.category.name;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHead(
          ar: 'في $catName',
          en: 'In $catName',
          onAll: () => safePush(context, '\1'),
        ),
        SizedBox(
          height: 366,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: section.products.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => ProductCard(product: section.products[i], width: 165),
          ),
        ),
      ],
    );
  }
}

// ── Bestsellers 2×2 with rank badges ─────────────────────────────────────────

class _BestsellerGrid extends StatelessWidget {
  final List<Product> products;
  const _BestsellerGrid({required this.products});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12,
          mainAxisExtent: 378,
        ),
        itemCount: products.length,
        itemBuilder: (_, i) => ProductCard(product: products[i]),
      ),
    );
  }
}

// ── New arrivals row with NEW badge ───────────────────────────────────────────

class _NewArrivalsRow extends StatelessWidget {
  final List<Product> products;
  const _NewArrivalsRow({required this.products});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 366,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => ProductCard(product: products[i], width: 165),
      ),
    );
  }
}

// ── Under 50 LYD 3-col mini grid ─────────────────────────────────────────────

class _BudgetGrid extends StatelessWidget {
  final List<Product> products;
  const _BudgetGrid({required this.products});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8,
          childAspectRatio: 1,
        ),
        itemCount: products.length.clamp(0, 6),
        itemBuilder: (_, i) {
          final p = products[i];
          return GestureDetector(
            onTap: () => safePush(context, '/product/${p.id}'),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(fit: StackFit.expand, children: [
                p.firstImage != null
                    ? CachedNetworkImage(imageUrl: p.firstImage!, fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(color: AppColors.surfaceSoft))
                    : Container(color: AppColors.surfaceSoft),
                Positioned(
                  left: 6, bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('${p.displayPrice.toStringAsFixed(0)} د.ل',
                      style: const TextStyle(fontFamily: 'PlusJakartaSans',
                        fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}

// ── baahy promise block ───────────────────────────────────────────────────────

class _BaahyPromiseCard extends ConsumerWidget {
  const _BaahyPromiseCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [AppColors.ink0, Color(0xFF1A3838)],
        ),
      ),
      child: Stack(children: [
        Positioned(
          right: -20, top: -20,
          child: Container(
            width: 140, height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 40, spreadRadius: 10),
              ],
              color: AppColors.primary.withValues(alpha: 0.2),
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('وعد باهي',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                letterSpacing: 1, color: AppColors.primary)),
            const SizedBox(height: 6),
            const Text('نختار ونخزّن ونوصّل كل طلب بأنفسنا.',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800,
                color: Colors.white, height: 1.25)),
            const SizedBox(height: 8),
            Text(
              'منتجات مفحوصة. مستودعات حقيقية. سائقو باهي في ${config.deliveryCitiesCount} مدينة. إذا حدث خطأ، نحن من يحلّه.',
              style: const TextStyle(fontSize: 12.5, color: Colors.white60, height: 1.5)),
          ],
        ),
      ]),
    );
  }
}

// ── Recently viewed ───────────────────────────────────────────────────────────

class _RecentlyViewedSection extends ConsumerWidget {
  const _RecentlyViewedSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(recentlyViewedProvider);
    if (products.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: Row(children: [
            Expanded(
              child: Text(context.s.recentlyViewed,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
        SizedBox(
          height: 110,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            itemBuilder: (_, i) {
              final p = products[i];
              return GestureDetector(
                onTap: () => safePush(context, '/product/${p.id}'),
                child: Container(
                  width: 70,
                  margin: EdgeInsets.only(right: i < products.length - 1 ? 10 : 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 70, height: 70,
                          child: p.firstImage != null
                              ? CachedNetworkImage(imageUrl: p.firstImage!, fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => Container(color: AppColors.surfaceSoft))
                              : Container(color: AppColors.surfaceSoft,
                                  child: const Icon(Icons.image_outlined,
                                    color: AppColors.ink4, size: 28)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('${p.displayPrice.toStringAsFixed(0)} د.ل',
                        style: const TextStyle(fontFamily: 'PlusJakartaSans',
                          fontSize: 11, fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Skeleton ──────────────────────────────────────────────────────────────────

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Container(height: 130, decoration: BoxDecoration(
          color: AppColors.surfaceSoft, borderRadius: BorderRadius.circular(10))),
        const SizedBox(height: 14),
        Container(height: 54, decoration: BoxDecoration(
          color: AppColors.surfaceSoft, borderRadius: BorderRadius.circular(10))),
        const SizedBox(height: 24),
        Wrap(spacing: 10, runSpacing: 10,
          children: List.generate(8, (_) => Container(
            width: (MediaQuery.of(context).size.width - 82) / 4,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft, borderRadius: BorderRadius.circular(10))))),
        const SizedBox(height: 24),
        SizedBox(
          height: 320,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, __) => ProductCardSkeleton(width: 165),
          ),
        ),
      ]),
    );
  }
}
