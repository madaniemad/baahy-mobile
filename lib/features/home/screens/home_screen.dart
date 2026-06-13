import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
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
                        border: isDark ? Border.all(color: context.col.border) : null,
                      ),
                      child: Row(children: [
                        Icon(Icons.search, size: 17, color: context.col.ink3),
                        const SizedBox(width: 7),
                        Expanded(child: _SearchHintText()),
                        GestureDetector(
                          onTap: () => safePush(context, '/search/camera'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(Icons.camera_alt_outlined, size: 17, color: context.col.ink3),
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
              if (banners.promoStrip.any((b) => b.hasImage))
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: _BrandCarousel(brands: banners.promoStrip),
                  ),
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
                          ? () => safePush(context, '/search/results?q=${item.viewAllUrl}')
                          : null,
                    ),
                  );
                  yield SliverToBoxAdapter(child: _BudgetCarousel(products: item.products));
                } else if (item is DynCarousel) {
                  yield SliverToBoxAdapter(
                    child: _CategoryCarouselSection(section: item.section),
                  );
                } else if (item is DynBannerDuo) {
                  yield SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: _DuoBannerRow(section: item.section),
                    ),
                  );
                } else if (item is DynStripBanner) {
                  yield SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: GestureDetector(
                        onTap: () => BannerLink.navigate(context, item.linkUrl),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: AspectRatio(
                            aspectRatio: 1920 / 350,
                            child: CachedNetworkImage(
                              imageUrl: item.imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(color: context.col.surfaceSoft),
                              errorWidget: (_, __, ___) => const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                } else if (item is DynCategoryCarousel) {
                  yield SliverToBoxAdapter(
                    child: _CategoryImagesCarousel(item: item),
                  );
                } else if (item is DynBanner) {
                  yield SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: _SingleBannerSection(item: item),
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

// ── App Bar ──────────────────────────────────────────────────────────────────

class _CityLabel extends ConsumerWidget {
  const _CityLabel();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cityAr = ref.watch(cityProvider);
    final fromAddress = ref.watch(cityFromAddressProvider);
    final address = ref.watch(primaryAddressProvider);
    final isAr = ref.watch(localeProvider).languageCode == 'ar';
    final cities = ref.watch(appPagesProvider).cities;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? context.col.ink0 : Colors.white;

    // When city is from a saved delivery address, show neighborhood if available
    final String displayLabel;
    if (fromAddress && address != null) {
      final neighborhood = (address['neighborhood'] as String?)?.trim();
      final city = (address['city'] as String?)?.trim() ?? cityAr;
      displayLabel = isAr
          ? (neighborhood != null && neighborhood.isNotEmpty ? neighborhood : city)
          : (address['city_en'] as String? ?? city);
    } else {
      displayLabel = isAr
          ? cityAr
          : (cities.firstWhere((c) => c.ar == cityAr, orElse: () => CityEntry(ar: cityAr, en: cityAr)).en);
    }

    return GestureDetector(
      onTap: () => fromAddress
          ? safePush(context, '/addresses')
          : context.push('/city'),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(
          fromAddress ? Icons.home_outlined : Icons.location_on_outlined,
          size: 15,
          color: isDark ? AppColors.adaptive(context) : Colors.white,
        ),
        const SizedBox(width: 3),
        Text(displayLabel, style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700,
            fontFamily: 'Cairo', color: labelColor)),
        const SizedBox(width: 2),
        Icon(Icons.keyboard_arrow_down_rounded, size: 15, color: labelColor.withValues(alpha: 0.7)),
      ]),
    );
  }
}

class _NotificationBell extends ConsumerWidget {
  const _NotificationBell();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationCountProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? context.col.ink0 : Colors.white;
    final badgeBorder = isDark ? context.col.surface : const Color(0xFF1FD7E2);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: () => safePush(context, '/notifications'),
          icon: Icon(Icons.notifications_none_rounded, color: iconColor, size: 22),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        if (unread > 0)
          Positioned(
            top: -1, right: -1,
            child: Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                color: AppColors.danger, shape: BoxShape.circle,
                border: Border.all(color: badgeBorder, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}

class _SearchHintText extends StatelessWidget {
  const _SearchHintText();
  @override
  Widget build(BuildContext context) => Text(
    context.s.searchHint,
    style: TextStyle(color: context.col.ink3, fontSize: 14));
}

// ── Active order strip + rewards nudge carousel ───────────────────────────────

final _activeOrderProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  try {
    final res = await ApiClient.instance.dio.get('/orders',
      queryParameters: {
        'status': 'out_for_delivery',
        'per_page': 1,
      });
    final d = res.data['data'];
    List? list;
    if (d is Map) list = d['data'] as List?;
    else if (d is List) list = d;
    if (list != null && list.isNotEmpty) return Map<String, dynamic>.from(list.first);
    return null;
  } catch (_) { return null; }
});

String _orderStripLabel(BuildContext context, String status) {
  switch (status) {
    case 'pending_confirmation': return context.s.isAr ? 'بانتظار التأكيد' : 'Pending Confirmation';
    case 'pending':
    case 'confirmed':            return context.s.isAr ? 'تم تأكيد طلبك'  : 'Order Confirmed';
    case 'processing':
    case 'fulfilled':            return context.s.isAr ? 'قيد التجهيز'    : 'Processing';
    case 'shipped':
    case 'out_for_delivery':     return context.s.isAr ? 'طلبك في الطريق' : 'On the Way';
    default:                     return context.s.isAr ? 'طلبك في الطريق' : 'On the Way';
  }
}

// Combines active order + rewards nudge into a carousel (1–2 strips)
class _ActiveOrderStrip extends ConsumerStatefulWidget {
  const _ActiveOrderStrip();
  @override
  ConsumerState<_ActiveOrderStrip> createState() => _ActiveOrderStripState();
}

class _ActiveOrderStripState extends ConsumerState<_ActiveOrderStrip> {
  final _ctrl = PageController();
  int _page = 0;
  int _count = 1;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_ctrl.hasClients || _count <= 1) return;
      final next = (_page + 1) % _count;
      _ctrl.animateToPage(next,
          duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync  = ref.watch(_activeOrderProvider);
    final tierAsync   = ref.watch(tierProvider);
    final config      = ref.watch(appConfigProvider);
    final user        = ref.watch(currentUserProvider);

    final strips = <Widget>[];

    // Strip 1: active order (always first if present)
    orderAsync.whenData((order) {
      if (order != null) {
        final orderId  = order['id'];
        final orderNum = order['order_number'] ?? '#$orderId';
        final status   = (order['status'] as String?) ?? '';
        strips.add(_StripTile(
          icon: status.contains('delivery') || status == 'shipped'
              ? Icons.local_shipping_outlined : Icons.receipt_long_outlined,
          label: _orderStripLabel(context, status),
          sub: orderNum,
          onTap: () => safePush(context, '/orders/$orderId'),
        ));
      }
    });

    // Strip 2: referral — shown immediately from config (no API wait)
    final referralAmt = config?.referralGiverAmount ?? 0;
    if (referralAmt > 0) {
      strips.add(_StripTile(
        icon: Icons.group,
        label: context.s.nudgeReferral(referralAmt.toString()),
        sub: null,
        onTap: () => safePush(context, '/account'),
        iconColor: AppColors.primary,
      ));
    }

    // Strip 3+: tier-dependent strips (load after API responds)
    tierAsync.whenData((tier) {
      if (identical(tier, TierStatus.empty)) return;
      final remaining = tier.nextMilestoneRemaining;
      final reward    = tier.nextMilestoneReward;
      String? nudgeMsg;

      if (remaining != null && remaining <= 2 && reward != null) {
        nudgeMsg = remaining == 1
            ? context.s.nudgeMilestone1(reward.toStringAsFixed(0))
            : context.s.nudgeMilestone2(reward.toStringAsFixed(0));
      } else {
        final t      = tier.tier?.toLowerCase();
        final orders = tier.ordersRemaining;
        final spend  = tier.spendRemaining.toStringAsFixed(0);
        if (t == null || t == 'bronze') nudgeMsg = context.s.nudgeNoTier(orders, spend);
        else if (t == 'silver')         nudgeMsg = context.s.nudgeSilver(orders, spend);
        else if (t == 'gold')           nudgeMsg = context.s.nudgeGold(orders, spend);
        else if (t == 'platinum')       nudgeMsg = context.s.nudgePlatinum(tier.cashbackRate.toStringAsFixed(1));
      }
      if (nudgeMsg != null) {
        strips.add(_StripTile(
          icon: Icons.card_giftcard,
          label: nudgeMsg,
          sub: null,
          onTap: () => safePush(context, '/rewards-hub'),
          iconColor: AppColors.success,
        ));
      }

      // Cashback rate
      if (tier.cashbackRate > 0) {
        strips.add(_StripTile(
          icon: Icons.local_offer,
          label: context.s.nudgeCashback(tier.cashbackRate.toStringAsFixed(1)),
          sub: null,
          onTap: () => safePush(context, '/rewards-hub'),
          iconColor: AppColors.success,
        ));
      }

      // Pending rewards
      if (tier.pendingTotal > 0) {
        strips.add(_StripTile(
          icon: Icons.hourglass_top,
          label: context.s.nudgePending(tier.pendingTotal.toStringAsFixed(2)),
          sub: null,
          onTap: () => safePush(context, '/rewards-hub'),
          iconColor: const Color(0xFFD4A82E),
        ));
      }

      // Wallet balance
      final walletBal = user?.walletBalance ?? 0.0;
      if (walletBal >= 5) {
        strips.add(_StripTile(
          icon: Icons.account_balance_wallet,
          label: context.s.nudgeWallet(walletBal.toStringAsFixed(2)),
          sub: null,
          onTap: () => safePush(context, '/wallet'),
          iconColor: AppColors.primary,
        ));
      }
    });

    if (_count != strips.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _count = strips.length);
      });
    }

    if (strips.isEmpty) return const SizedBox.shrink();
    if (strips.length == 1) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: strips.first,
      );
    }

    return SizedBox(
      height: 44,
      child: PageView(
        controller: _ctrl,
        onPageChanged: (p) => setState(() => _page = p),
        children: strips.map((s) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: s,
        )).toList(),
      ),
    );
  }
}

class _StripTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sub;
  final VoidCallback onTap;
  final Color iconColor;
  const _StripTile({
    required this.icon, required this.label,
    required this.sub, required this.onTap,
    this.iconColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Builder(builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isDark ? Colors.transparent : const Color(0xFFE8F8F8),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isDark ? AppColors.teal : const Color(0xFFE0E0E0),
              width: isDark ? 1.4 : 1,
            ),
          ),
          child: Row(children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: const TextStyle(fontSize: 12.5),
                  children: [
                    TextSpan(text: label,
                      style: TextStyle(fontWeight: FontWeight.w700, color: context.col.ink0)),
                    if (sub != null)
                      TextSpan(text: ' · $sub',
                        style: TextStyle(color: context.col.ink3)),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 12, color: context.col.ink3),
          ]),
        );
      }),
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
  static const _multiplier = 1000;
  late final PageController _pageCtrl;
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
    final n = widget.banners.length;
    final startPage = n > 1 ? _multiplier * n : 0;
    _pageCtrl = PageController(viewportFraction: 0.9, initialPage: startPage);
    _current = n > 0 ? startPage % n : 0;
    if (n > 1) {
      _timer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (!mounted) return;
        _pageCtrl.nextPage(
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

    return AspectRatio(
      aspectRatio: 1400 / 480,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageCtrl,
            itemCount: widget.banners.length > 1 ? widget.banners.length * _multiplier * 2 : widget.banners.length,
            onPageChanged: (i) => setState(() => _current = i % widget.banners.length),
            itemBuilder: (_, i) {
              final idx = i % widget.banners.length;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: _BannerSlide(
                    banner: widget.banners[idx],
                    gradient: _gradients[idx % _gradients.length],
                  ),
                ),
              );
            },
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
            placeholder: (_, __) => const _BannerSkeleton(),
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
    return const AspectRatio(
      aspectRatio: 1400 / 480,
      child: _BannerSkeleton(),
    );
  }
}

class _BannerSkeleton extends StatefulWidget {
  const _BannerSkeleton();
  @override
  State<_BannerSkeleton> createState() => _BannerSkeletonState();
}

class _BannerSkeletonState extends State<_BannerSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base  = context.col.surfaceSoft;
    final light = context.col.surface;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: Color.lerp(base, light, _anim.value),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}

// ── Sub-hero banner: fades between multiple images on a timer ────────────────

class _SubHeroBanner extends StatefulWidget {
  final List<AppBanner> banners;
  const _SubHeroBanner({required this.banners});
  @override
  State<_SubHeroBanner> createState() => _SubHeroBannerState();
}

class _SubHeroBannerState extends State<_SubHeroBanner> {
  int _current = 0;
  Timer? _timer;

  List<AppBanner> get _visible => widget.banners.where((b) => b.hasImage).toList();

  @override
  void initState() {
    super.initState();
    if (_visible.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (mounted) setState(() => _current = (_current + 1) % _visible.length);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banners = _visible;
    if (banners.isEmpty) return const SizedBox.shrink();
    final banner = banners[_current];
    return GestureDetector(
      onTap: () => BannerLink.navigate(context, banner.buttonLink),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: AspectRatio(
          aspectRatio: 1920 / 350,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 700),
            child: CachedNetworkImage(
              key: ValueKey(banner.imageUrl),
              imageUrl: banner.imageUrl!,
              fit: BoxFit.cover,
              width: double.infinity,
              placeholder: (_, __) => Container(color: context.col.surfaceSoft),
              errorWidget: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
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
            borderRadius: BorderRadius.circular(6),
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

// ── Duo banner row (2 square banners side by side) ───────────────────────────

class _DuoBannerRow extends StatelessWidget {
  final BannerDuoSection section;
  const _DuoBannerRow({required this.section});

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final badge1 = isAr ? section.badgeAr : section.badgeEn;
    final badge2 = isAr ? section.badgeAr2 : section.badgeEn2;

    Widget tile(String? url, String? link, String? badge) {
      if (url == null || url.isEmpty) return const SizedBox.shrink();
      return Expanded(
        child: GestureDetector(
          onTap: () { if (link != null && link.isNotEmpty) BannerLink.navigate(context, link); },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(imageUrl: url, fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: Colors.grey.shade100),
                    errorWidget: (_, __, ___) => Container(color: Colors.grey.shade200),
                  ),
                  if (section.showOverlay)
                    Container(color: Colors.black.withValues(alpha: 0.2)),
                  if (badge != null && badge.isNotEmpty)
                    Positioned(
                      bottom: 10, right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(badge,
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tile(section.imageUrl, section.linkUrl, badge1),
        const SizedBox(width: 8),
        tile(section.imageUrl2, section.linkUrl2, badge2),
      ],
    );
  }
}

// ── Single banner section ─────────────────────────────────────────────────────

class _SingleBannerSection extends StatelessWidget {
  final DynBanner item;
  const _SingleBannerSection({required this.item});
  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final badge = isAr ? item.badgeAr : item.badgeEn;
    return GestureDetector(
      onTap: () { if (item.linkUrl != null) BannerLink.navigate(context, item.linkUrl!); },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: AspectRatio(
          aspectRatio: 1920 / 700,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(imageUrl: item.imageUrl!, fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: Colors.grey.shade100),
                errorWidget: (_, __, ___) => Container(color: Colors.grey.shade200),
              ),
              if (item.showOverlay)
                Container(color: Colors.black.withValues(alpha: 0.3)),
              if (badge != null && badge.isNotEmpty)
                Positioned(
                  bottom: 12, right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(badge,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Promise strip ─────────────────────────────────────────────────────────────

class _PromiseStrip extends StatelessWidget {
  final AppConfig config;
  const _PromiseStrip({required this.config});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
      decoration: BoxDecoration(
        color: context.col.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: context.col.border),
        boxShadow: AppShadows.shadowCard,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          const _PromiseChip(icon: Icons.local_shipping_outlined,
            ar: 'توصيل سريع', en: 'Fast delivery'),
          Container(width: 1, height: 24, color: context.col.border),
          const _PromiseChip(icon: Icons.refresh_rounded,
            ar: 'ارجاع واستبدال', en: 'Returns & exchanges'),
          Container(width: 1, height: 24, color: context.col.border),
          const _PromiseChip(icon: Icons.verified_outlined,
            ar: 'ضمان المنتج', en: 'Product warranty'),
        ],
      ),
    );
  }
}

class _PromiseChip extends StatelessWidget {
  final IconData icon;
  final String ar;
  final String en;
  const _PromiseChip({required this.icon, required this.ar, required this.en, super.key});
  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Column(children: [
      Icon(icon, size: 18, color: AppColors.primary),
      const SizedBox(height: 3),
      Text(isAr ? ar : en,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: context.col.ink1),
        textAlign: TextAlign.center),
    ]);
  }
}

// ── Section head ──────────────────────────────────────────────────────────────

// ── Category images carousel (admin section type: category_carousel) ──────────

class _CategoryImagesCarousel extends StatelessWidget {
  final DynCategoryCarousel item;
  const _CategoryImagesCarousel({required this.item});

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final title = isAr ? item.titleAr : item.titleEn;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Text(title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, fontFamily: 'Cairo')),
          ),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: item.categories.length,
            itemBuilder: (_, i) {
              final cat = item.categories[i];
              return GestureDetector(
                onTap: () => safePush(context, '/search/results?q=&category=${cat.id}'),
                child: Container(
                  width: 80,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: CachedNetworkImage(
                          imageUrl: cat.image!,
                          width: 72, height: 72,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            width: 72, height: 72, color: context.col.surfaceSoft),
                          errorWidget: (_, __, ___) => Container(
                            width: 72, height: 72, color: context.col.surfaceSoft,
                            child: Icon(Icons.category_outlined,
                              size: 28, color: context.col.ink3)),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        isAr ? cat.nameAr : cat.name,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                          fontFamily: 'Cairo', color: context.col.ink1),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
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

// ── Deals section header ──────────────────────────────────────────────────────

class _DealsHead extends StatelessWidget {
  final VoidCallback? onAll;
  const _DealsHead({this.onAll});

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.danger,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(Icons.bolt_rounded, size: 14, color: Colors.white),
        ),
        const SizedBox(width: 8),
        Text(isAr ? 'عروض اليوم' : "Today's Deals",
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
      height: 340,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => Align(
          alignment: Alignment.topCenter,
          child: ProductCard(product: products[i], width: 165),
        ),
      ),
    );
  }
}

// ── Categories 2-row horizontal carousel ─────────────────────────────────────

class _CategoriesGrid extends StatefulWidget {
  final List<Category> categories;
  const _CategoriesGrid({required this.categories});
  @override
  State<_CategoriesGrid> createState() => _CategoriesGridState();
}

class _CategoriesGridState extends State<_CategoriesGrid> {
  List<({Category cat, Color color, bool isParent})> _items = [];

  static const _parentColors = [
    Color(0xFF0D9488), Color(0xFF7C3AED), Color(0xFFD97706),
    Color(0xFFDB2777), Color(0xFF2563EB), Color(0xFF059669), Color(0xFFDC2626),
  ];

  void _buildAndShuffle(List<Category> categories) {
    final flat = <({Category cat, Color color, bool isParent})>[];
    for (var i = 0; i < categories.length; i++) {
      final color = _parentColors[i % _parentColors.length];
      for (final child in categories[i].children) {
        flat.add((cat: child, color: color, isParent: false));
      }
    }
    flat.shuffle(Random());
    setState(() => _items = flat);
  }

  @override
  void initState() {
    super.initState();
    _buildAndShuffle(widget.categories);
  }

  @override
  void didUpdateWidget(_CategoriesGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Compare total child count — cache may have categories without children,
    // fresh fetch populates them. Root count stays same (8) so must check deeper.
    final oldChildCount = oldWidget.categories.fold(0, (s, c) => s + c.children.length);
    final newChildCount = widget.categories.fold(0, (s, c) => s + c.children.length);
    if (oldChildCount != newChildCount) _buildAndShuffle(widget.categories);
  }

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
    if (_items.isEmpty) return const SizedBox.shrink();
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return SizedBox(
      height: 172,
      child: GridView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          mainAxisExtent: 80,
        ),
        itemCount: _items.length,
        itemBuilder: (_, i) {
          final item = _items[i];
          final name = isAr ? item.cat.nameAr : item.cat.name;
          final icon = _iconFor(item.cat.nameAr + item.cat.name);
          return GestureDetector(
            onTap: () => safePush(context, '/search/results?q=&category=${item.cat.id}'),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.col.surfaceSoft,
                  ),
                  child: ClipOval(
                    child: item.cat.image != null
                        ? CachedNetworkImage(imageUrl: item.cat.image!, fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Center(
                              child: Icon(icon, size: 26, color: context.col.ink3)))
                        : Center(child: Icon(icon, size: 20, color: context.col.ink3)),
                  ),
                ),
                const SizedBox(height: 3),
                Text(name,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: item.isParent ? FontWeight.w700 : FontWeight.w500,
                    color: item.isParent ? context.col.ink0 : context.col.ink1,
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

class _FashionBannerTiles extends StatefulWidget {
  final List<AppBanner> banners;
  const _FashionBannerTiles({required this.banners});
  @override
  State<_FashionBannerTiles> createState() => _FashionBannerTilesState();
}

class _FashionBannerTilesState extends State<_FashionBannerTiles> {
  late final ScrollController _ctrl = ScrollController();
  static const _midIndex = 5000; // jump here so user can scroll both ways

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_ctrl.hasClients) return;
      final sw = MediaQuery.of(context).size.width;
      final cardW = (sw - 16) / 3.3;
      _ctrl.jumpTo(_midIndex * (cardW + 8));
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.banners.where((b) => b.hasImage).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    final sw = MediaQuery.of(context).size.width;
    // 3 cards + ~0.3 peek; 16px left padding, 8px gap between cards
    final cardW = (sw - 16) / 3.3;
    final cardH = cardW * 1.7;

    return SizedBox(
      height: cardH,
      child: ListView.separated(
        controller: _ctrl,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 16),
        itemCount: visible.length * 10000,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final banner = visible[i % visible.length];
          return _FashionTile(banner: banner, width: cardW, height: cardH);
        },
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
        borderRadius: BorderRadius.circular(6),
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

  static const double _tileW = 78;
  static const double _tileH = 64;
  static const double _gap = 8;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(context.s.shopByBrand,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center),
        ),
        SizedBox(
          height: _tileH,
          child: GridView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 1,
              mainAxisSpacing: _gap,
              crossAxisSpacing: _gap,
              mainAxisExtent: _tileW,
            ),
            itemCount: brands.length,
            itemBuilder: (_, i) {
              final brand = brands[i];
              return GestureDetector(
                onTap: () => BannerLink.navigate(context, brand.buttonLink),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: brand.hasImage
                      ? CachedNetworkImage(imageUrl: brand.imageUrl!, fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(color: context.col.surfaceSoft,
                            child: Icon(Icons.store_outlined, color: context.col.ink3, size: 24)))
                      : Container(color: context.col.surfaceSoft,
                          child: Icon(Icons.store_outlined, color: context.col.ink3, size: 24)),
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
  Timer? _timer;

  static const _gradients = [
    [Color(0xFF1F2E2E), Color(0xFF0A1A1A)],
    [Color(0xFF1A1A3E), Color(0xFF0A0A1A)],
    [Color(0xFF2E1A1A), Color(0xFF1A0A0A)],
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
  void dispose() {
    _timer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
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
          mainAxisExtent: 364,
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
    final viewAllRoute = section.viewAllUrl != null
        ? '/search/results?q=${section.viewAllUrl}'
        : '/search/results?q=&category=${section.category.id}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHead(
          ar: catName,
          en: catName,
          onAll: () => safePush(context, viewAllRoute),
        ),
        SizedBox(
          height: 340,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: section.products.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => Align(
              alignment: Alignment.topCenter,
              child: ProductCard(product: section.products[i], width: 165),
            ),
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
          mainAxisExtent: 364,
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
      height: 340,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => Align(
          alignment: Alignment.topCenter,
          child: ProductCard(product: products[i], width: 165),
        ),
      ),
    );
  }
}

// ── Under 100 LYD — horizontal 2-row carousel with partial 4th column peek ───

class _BudgetCarousel extends StatelessWidget {
  final List<Product> products;
  const _BudgetCarousel({required this.products});

  static const double _tileW = 108;
  static const double _tileH = 96;
  static const double _gap   = 8;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _tileH * 2 + _gap,
      child: GridView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 16, right: 6),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: _gap,
          crossAxisSpacing: _gap,
          mainAxisExtent: _tileW,
        ),
        itemCount: products.length,
        itemBuilder: (_, i) {
          final p = products[i];
          return GestureDetector(
            onTap: () => safePush(context, '/product/${p.id}'),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(fit: StackFit.expand, children: [
                p.firstImage != null
                    ? CachedNetworkImage(imageUrl: p.firstImage!, fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(color: context.col.surfaceSoft))
                    : Container(color: context.col.surfaceSoft),
                Positioned(
                  left: 6, bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD32F2F).withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('${fmtPrice(p.displayPrice)} ${context.s.lydUnit}',
                      style: const TextStyle(fontFamily: 'PlusJakartaSans',
                        fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
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
        borderRadius: BorderRadius.circular(6),
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [context.col.ink0, Color(0xFF1A3838)],
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
            Text(context.s.baahyPromise,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                letterSpacing: 1, color: AppColors.primary)),
            const SizedBox(height: 6),
            Text(context.s.baahyPromiseSub,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800,
                color: Colors.white, height: 1.25)),
            const SizedBox(height: 8),
            Text(
              context.s.baahyPromiseDetail(config.deliveryCitiesCount),
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
        _SectionHead(
          ar: context.s.recentlyViewed,
          en: context.s.recentlyViewed,
          onAll: null,
        ),
        SizedBox(
          height: 340,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => Align(
          alignment: Alignment.topCenter,
          child: ProductCard(product: products[i], width: 165),
        ),
          ),
        ),
      ],
    );
  }
}

// ── Contextual rewards nudge card ────────────────────────────────────────────

class _RewardsNudgeCard extends ConsumerWidget {
  const _RewardsNudgeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.watch(authProvider).isLoggedIn;
    if (!isLoggedIn) return const SizedBox.shrink();

    final tierAsync = ref.watch(tierProvider);
    return tierAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (tier) {
        if (identical(tier, TierStatus.empty)) return const SizedBox.shrink();

        final String message;
        final IconData icon;
        final Color color;

        final remaining = tier.nextMilestoneRemaining;
        final reward    = tier.nextMilestoneReward;

        if (remaining != null && remaining <= 2 && reward != null) {
          message = remaining == 1
              ? context.s.nudgeMilestone1(reward.toStringAsFixed(0))
              : context.s.nudgeMilestone2(reward.toStringAsFixed(0));
          icon  = Icons.card_giftcard_rounded;
          color = AppColors.success;
        } else if (tier.tier == null) {
          message = context.s.nudgeNoTier(tier.ordersRemaining, tier.spendRemaining.toStringAsFixed(0));
          icon  = Icons.workspace_premium_outlined;
          color = AppColors.primary;
        } else if (tier.tier == 'silver') {
          message = context.s.nudgeSilver(tier.ordersRemaining, tier.spendRemaining.toStringAsFixed(0));
          icon  = Icons.workspace_premium_outlined;
          color = const Color(0xFF9E9E9E);
        } else if (tier.tier == 'gold') {
          message = context.s.nudgeGold(tier.ordersRemaining, tier.spendRemaining.toStringAsFixed(0));
          icon  = Icons.workspace_premium_rounded;
          color = AppColors.gold;
        } else {
          message = context.s.nudgePlatinum(tier.cashbackRate.toStringAsFixed(0));
          icon  = Icons.diamond_outlined;
          color = AppColors.primary;
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: GestureDetector(
            onTap: () => safePush(context, '/rewards-hub'),
            child: Builder(builder: (ctx) {
              final isDk = Theme.of(ctx).brightness == Brightness.dark;
              return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDk ? Colors.transparent : color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: color.withValues(alpha: isDk ? 0.45 : 0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: color,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_forward_ios, size: 11, color: color.withValues(alpha: 0.6)),
                ],
              ),
            );
            }),
          ),
        );
      },
    );
  }
}

// ── Seasonal cashback banner ──────────────────────────────────────────────────

class _SeasonalBanner extends StatelessWidget {
  final AppConfig config;
  const _SeasonalBanner({required this.config});

  int? _daysRemaining() {
    final endsAt = config.seasonalEndsAt;
    if (endsAt == null || endsAt.isEmpty) return null;
    try {
      final end = DateTime.parse(endsAt);
      final diff = end.difference(DateTime.now()).inDays;
      return diff > 0 ? diff : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = _daysRemaining();
    return Container(
      width: double.infinity,
      height: 44,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, Color(0xFF1E40AF)],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${config.seasonalLabelAr} 🎉',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            if (days != null) ...[
              const SizedBox(width: 8),
              Text(
                context.isAr ? 'ينتهي خلال $days يوم' : 'Ends in $days days',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  color: Colors.white70,
                ),
              ),
            ],
          ],
        ),
      ),
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
          color: context.col.surfaceSoft, borderRadius: BorderRadius.circular(6))),
        const SizedBox(height: 14),
        Container(height: 54, decoration: BoxDecoration(
          color: context.col.surfaceSoft, borderRadius: BorderRadius.circular(6))),
        const SizedBox(height: 24),
        Wrap(spacing: 10, runSpacing: 10,
          children: List.generate(8, (_) => Container(
            width: (MediaQuery.of(context).size.width - 82) / 4,
            height: 80,
            decoration: BoxDecoration(
              color: context.col.surfaceSoft, borderRadius: BorderRadius.circular(6))))),
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

// ── One-time rewards modal trigger ────────────────────────────────────────────
// Renders nothing; fires a post-frame callback that shows the modal once.
class _RewardsModalTrigger extends ConsumerStatefulWidget {
  const _RewardsModalTrigger();
  @override
  ConsumerState<_RewardsModalTrigger> createState() => _RewardsModalTriggerState();
}

class _RewardsModalTriggerState extends ConsumerState<_RewardsModalTrigger> {
  static bool _firedThisSession = false;

  @override
  void initState() {
    super.initState();
    if (_firedThisSession) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
  }

  Future<void> _maybeShow() async {
    final isLoggedIn = ref.read(authProvider).isLoggedIn;
    if (!isLoggedIn) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('rewards_modal_seen') == true) return;
    if (!mounted) return;
    _firedThisSession = true;
    await prefs.setBool('rewards_modal_seen', true);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _RewardsModal(),
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// ── Rewards modal sheet ───────────────────────────────────────────────────────
class _RewardsModal extends StatelessWidget {
  const _RewardsModal();

  static const _navy = Color(0xFF0E3C46);

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final s      = context.s;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        const SizedBox(height: 12),
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFFDDDDDD),
            borderRadius: BorderRadius.circular(999)),
        ),
        const SizedBox(height: 20),

        // Hero icon
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.card_membership_rounded,
            color: AppColors.primary, size: 28),
        ),
        const SizedBox(height: 16),

        // Title
        Text(s.rewardsArrived,
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 22,
            fontWeight: FontWeight.w900, color: _navy, height: 1.2)),
        const SizedBox(height: 10),

        // Subtitle
        Text(
          context.isAr
              ? 'احصل على استرداد نقدي على كل طلب، وارتقِ للمستويات الأعلى لمزايا أكبر'
              : 'Earn cashback on every order and level up for bigger perks',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Cairo', fontSize: 14,
            fontWeight: FontWeight.w600, color: const Color(0xFF0E3C46).withValues(alpha: 0.70),
            height: 1.5)),
        const SizedBox(height: 24),

        // Primary CTA → rewards hub
        GestureDetector(
          onTap: () {
            Navigator.of(context).pop();
            safePush(context, '/rewards-hub');
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.28),
                blurRadius: 14, offset: const Offset(0, 6))],
            ),
            child: Text(s.discoverBenefits,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 17,
                fontWeight: FontWeight.w900, color: Colors.white)),
          ),
        ),
        const SizedBox(height: 12),

        // Secondary — dismiss
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(s.startShoppingNow,
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Cairo', fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _navy.withValues(alpha: 0.55))),
          ),
        ),
      ]),
    );
  }
}
