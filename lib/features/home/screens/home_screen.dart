import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../../../core/providers/home_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/models/product.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/product_card.dart';
import '../../../shared/widgets/section_header.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeProvider);
    final user = ref.watch(currentUserProvider);
    final isAr = context.isAr;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(homeProvider.notifier).fetch(),
        child: CustomScrollView(
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _HomeAppBar(user: user, isAr: isAr),
            ),
            if (home.loading && home.featured.isEmpty)
              const SliverFillRemaining(child: _HomeSkeleton())
            else ...[
              // Featured banner carousel
              if (home.featured.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _FeaturedCarousel(products: home.featured),
                  ),
                ),

              // Categories
              if (home.categories.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: _CategoriesRow(categories: home.categories),
                  ),
                ),

              // Promise strip
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 20, left: 16, right: 16),
                  child: _PromiseStrip(),
                ),
              ),

              // New Arrivals
              if (home.newArrivals.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 24, bottom: 12),
                    child: SectionHeader(
                      titleAr: 'وصل حديثاً',
                      titleEn: 'New Arrivals',
                      onSeeAll: () => context.push('/search/results?q=&sort=latest'),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _HorizontalProductList(products: home.newArrivals),
                ),
              ],

              // Popular
              if (home.popular.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 24, bottom: 12),
                    child: SectionHeader(
                      titleAr: 'الأكثر مبيعاً',
                      titleEn: 'Best Sellers',
                      onSeeAll: () => context.push('/search/results?q=&sort=popular'),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _HorizontalProductList(products: home.popular),
                ),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ],
        ),
      ),
    );
  }
}

class _HomeAppBar extends SliverPersistentHeaderDelegate {
  final dynamic user;
  final bool isAr;
  const _HomeAppBar({this.user, required this.isAr});

  @override double get minExtent => 60;
  @override double get maxExtent => 60;
  @override bool shouldRebuild(_) => true;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
        left: 16, right: 16,
      ),
      child: Row(
        children: [
          Image.asset('assets/images/logo.png', height: 32,
            errorBuilder: (_, __, ___) => const Text('baahy',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 22, fontWeight: FontWeight.w800,
                color: AppColors.primary)),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => context.push('/search'),
            child: Container(
              width: 180,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  const Icon(Icons.search, size: 18, color: AppColors.ink3),
                  const SizedBox(width: 6),
                  Text(
                    isAr ? 'ابحث عن منتج...' : 'Search products...',
                    style: const TextStyle(color: AppColors.ink3, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _FeaturedCarousel extends StatefulWidget {
  final List<Product> products;
  const _FeaturedCarousel({required this.products});

  @override
  State<_FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends State<_FeaturedCarousel> {
  int _current = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CarouselSlider.builder(
          itemCount: widget.products.length.clamp(0, 5),
          itemBuilder: (context, i, _) {
            final p = widget.products[i];
            return GestureDetector(
              onTap: () => context.push('/product/${p.id}'),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white,
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (p.firstImage != null)
                      CachedNetworkImage(imageUrl: p.firstImage!, fit: BoxFit.cover)
                    else
                      Container(color: AppColors.bg),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              Localizations.localeOf(context).languageCode == 'ar'
                                  ? p.nameAr : p.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '${p.displayPrice.toStringAsFixed(0)} د.ل',
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'PlusJakartaSans',
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          options: CarouselOptions(
            height: 200,
            viewportFraction: 0.88,
            enableInfiniteScroll: true,
            autoPlay: true,
            autoPlayInterval: const Duration(seconds: 4),
            onPageChanged: (i, _) => setState(() => _current = i),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.products.length.clamp(0, 5), (i) => AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == _current ? 20 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == _current ? AppColors.primary : AppColors.border,
              borderRadius: BorderRadius.circular(3),
            ),
          )),
        ),
      ],
    );
  }
}

class _CategoriesRow extends StatelessWidget {
  final List<Category> categories;
  const _CategoriesRow({required this.categories});

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final display = categories.take(8).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
          child: Row(
            children: [
              Text(
                isAr ? 'الأقسام' : 'Categories',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => context.go('/browse'),
                child: const Text('عرض الكل',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 88,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: display.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _CategoryChip(category: display[i]),
          ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final Category category;
  const _CategoryChip({required this.category});

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return GestureDetector(
      onTap: () => context.push('/search/results?q=&category=${category.id}'),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppShadows.shadowCard,
            ),
            child: category.image != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: category.image!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const Icon(Icons.grid_view_rounded,
                          color: AppColors.primary, size: 24),
                    ),
                  )
                : const Icon(Icons.grid_view_rounded, color: AppColors.primary, size: 24),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 64,
            child: Text(
              isAr ? category.nameAr : category.name,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _PromiseStrip extends StatelessWidget {
  const _PromiseStrip();

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final items = [
      (Icons.local_shipping_outlined, isAr ? 'توصيل سريع' : 'Fast Delivery'),
      (Icons.verified_outlined, isAr ? 'منتجات أصلية' : 'Authentic'),
      (Icons.support_agent_outlined, isAr ? 'دعم ٢٤/٧' : '24/7 Support'),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items.map((item) => Column(
          children: [
            Icon(item.$1, color: AppColors.primary, size: 22),
            const SizedBox(height: 4),
            Text(item.$2,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.ink1)),
          ],
        )).toList(),
      ),
    );
  }
}

class _HorizontalProductList extends StatelessWidget {
  final List<Product> products;
  const _HorizontalProductList({required this.products});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => ProductCard(product: products[i], width: 155),
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            height: 200,
            decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(16)),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 6,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, __) => Column(children: [
                Container(width: 56, height: 56,
                  decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(16))),
                const SizedBox(height: 6),
                Container(width: 48, height: 10, color: AppColors.bg),
              ]),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(height: 16, width: 120, color: AppColors.bg),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 240,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 4,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, __) => ProductCardSkeleton(width: 155),
            ),
          ),
        ],
      ),
    );
  }
}
