import 'dart:async';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/campaign.dart';
import '../../../core/models/product.dart';
import '../../../core/providers/campaign_provider.dart';
import '../../../core/utils/banner_link.dart';
import '../../../core/utils/l10n.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/product_card.dart';
import '../widgets/campaign_widgets.dart';
import '../../vendor/widgets/store_filters.dart';

const _font = 'Manrope';
const _fallback = ['Tajawal'];

/// The campaign page (`/campaign/:slug`, optional `?vendor=` / `?category=`).
///
/// Header in the campaign colours (logo, name, headline, countdown), the stores taking part, the
/// category cards (or chips), top banners, a sort control and the product grid with banners between
/// its rows. Everything comes from the API, so the page
/// serves any future campaign. Products are the normal `/products` listing with `campaign=<slug>`.
class CampaignScreen extends ConsumerStatefulWidget {
  final String slug;
  final int? initialVendorId;
  final int? initialCategoryId;
  const CampaignScreen({
    super.key,
    required this.slug,
    this.initialVendorId,
    this.initialCategoryId,
  });

  @override
  ConsumerState<CampaignScreen> createState() => _CampaignScreenState();
}

/// (server value, label getter). Default: biggest discount first.
List<(String, String)> _sortOptions(BuildContext context) => [
      ('discount', context.s.campaignSortDiscount),
      ('price_asc', context.s.campaignSortPriceAsc),
      ('price_desc', context.s.campaignSortPriceDesc),
      ('latest', context.s.campaignSortNewest),
    ];

class _CampaignScreenState extends ConsumerState<CampaignScreen> {
  final _scrollCtrl = ScrollController();
  List<Product> _products = [];
  bool _loading = true;
  bool _loadingMore = false;
  int _page = 1;
  bool _hasMore = true;
  bool _loadError = false;
  bool _loadMoreError = false;
  int _reqSeq = 0; // newest request wins
  int? _total;
  String _sort = 'discount';
  int? _vendorId;
  int? _categoryId;
  /// The «تصفية» sheet's choices (price, brand, size/colour…); sort stays [_sort].
  StoreFilters _filters = const StoreFilters();
  /// A filter change is loading: the current products stay on screen (no jump) under a thin bar.
  bool _refreshing = false;
  bool _showTitle = false;
  /// The count + sort row, so a banner that filters the page can bring the grid into view.
  final _gridTopKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _vendorId = widget.initialVendorId;
    _categoryId = widget.initialCategoryId;
    _scrollCtrl.addListener(_onScroll);
    _fetch(reset: true);
  }

  @override
  void didUpdateWidget(CampaignScreen old) {
    super.didUpdateWidget(old);
    // A new link to the page that is already open (push / deep link) reuses this state.
    if (old.slug != widget.slug ||
        old.initialVendorId != widget.initialVendorId ||
        old.initialCategoryId != widget.initialCategoryId) {
      _vendorId = widget.initialVendorId;
      _categoryId = widget.initialCategoryId;
      _fetch(reset: true);
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    final pos = _scrollCtrl.position;
    final show = pos.pixels > 56;
    if (show != _showTitle) setState(() => _showTitle = show);
    if (pos.pixels > pos.maxScrollExtent - 400) {
      // After a failed page, wait for the Retry tap instead of re-firing on every scroll tick.
      if (!_loadingMore && _hasMore && !_loadMoreError && !_loading) _fetch();
    }
  }

  /// [keep]: a filter change. The grid keeps its products until the new page arrives, so the page
  /// does not shrink and jump; the header, stores and cards are never reloaded either way.
  Future<void> _fetch({bool reset = false, bool keep = false}) async {
    if (reset && keep && _products.isNotEmpty) {
      ++_reqSeq;
      setState(() {
        _refreshing = true;
        _loadingMore = false;
        _loadError = false;
        _loadMoreError = false;
        _page = 1;
        _hasMore = true;
      });
    } else if (reset) {
      ++_reqSeq;
      setState(() {
        _refreshing = false;
        _loading = true;
        _loadingMore = false;
        _loadError = false;
        _loadMoreError = false;
        _page = 1;
        _hasMore = true;
        _products = [];
        _total = null;
      });
    } else {
      if (_loadingMore || !_hasMore) return;
      setState(() {
        _loadingMore = true;
        _loadMoreError = false;
      });
    }
    final seq = _reqSeq;
    final page = _page;
    try {
      final res = await ApiClient.instance.dio.get('/products', queryParameters: {
        ...campaignProductsParams(widget.slug),
        'sort': _sort,
        'page': page,
        'per_page': 20,
        if (_vendorId != null) 'vendor_ids[]': [_vendorId],
        if (_categoryId != null) 'category_id': _categoryId,
        ..._filters.toQuery(),
      });
      if (!mounted || seq != _reqSeq) return;
      final data = res.data['data'];
      final list = (data['data'] as List).map((p) => Product.fromJson(p)).toList();
      setState(() {
        _products = reset ? list : [..._products, ...list];
        if (reset) _total = (data['total'] as num?)?.toInt();
        _page = page + 1;
        _hasMore = (data['current_page'] as num? ?? 1) < (data['last_page'] as num? ?? 1);
        _loading = false;
        _loadingMore = false;
        _refreshing = false;
      });
    } catch (_) {
      if (!mounted || seq != _reqSeq) return;
      setState(() {
        if (reset) {
          _loadError = true;
        } else {
          _loadMoreError = true;
        }
        _loading = false;
        _loadingMore = false;
        _refreshing = false;
      });
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(campaignStoresProvider(widget.slug));
    await Future.wait([
      ref.read(campaignProvider.notifier).refresh(),
      _fetch(reset: true),
    ]);
  }

  // Stores and departments are either/or (Emad 2026-11-22): picking a store shows all of that store's offers,
  // picking a department shows that department across every store. Combining them hid everything
  // («لا توجد عروض») when the store had nothing in the department.
  void _selectVendor(int? id) {
    if (_vendorId == id) return;
    setState(() {
      _vendorId = id;
      if (id != null) _categoryId = null;
    });
    _fetch(reset: true);
  }

  void _selectCategory(int? id) {
    if (_categoryId == id) return;
    setState(() {
      _categoryId = id;
      if (id != null) _vendorId = null;
    });
    _fetch(reset: true);
  }

  /// The campaign filter a banner link points at, when it is this campaign's own page
  /// (`/offers/<slug>?vendor=…|category=…`, also as a full baahy.com URL). Null otherwise.
  ({int? vendor, int? category})? _sameCampaignFilter(String? link) {
    final raw = link?.trim() ?? '';
    if (raw.isEmpty) return null;
    var uri = Uri.tryParse(raw);
    if (uri == null) return null;
    if (uri.hasScheme && !{'baahy.com', 'www.baahy.com', 'api.baahy.com'}.contains(uri.host)) return null;
    if (campaignSlugFromPath(uri) != widget.slug) return null;
    final q = uri.queryParameters;
    return (vendor: int.tryParse(q['vendor'] ?? ''), category: int.tryParse(q['category'] ?? ''));
  }

  /// A banner for the filter already on screen would only repeat it.
  bool _bannerIsCurrentView(CampaignBanner b) {
    final f = _sameCampaignFilter(b.link);
    if (f == null || (f.vendor == null && f.category == null)) return false;
    return f.vendor == _vendorId && f.category == _categoryId;
  }

  void _openBanner(CampaignBanner b) {
    final f = _sameCampaignFilter(b.link);
    if (f == null) {
      if (b.link != null) BannerLink.navigate(context, b.link);
      return;
    }
    // This campaign's own offers for a store / category: filter in place, then show the grid.
    setState(() {
      _vendorId = f.vendor;
      _categoryId = f.category;
    });
    _fetch(reset: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _gridTopKey.currentContext;
      if (ctx != null && mounted) {
        Scrollable.ensureVisible(ctx,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut, alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart);
      }
    });
  }

  Future<void> _openFilters() async {
    final picked = await showCampaignFilterSheet(context, _filters, scope: {
      ...campaignProductsParams(widget.slug),
      if (_vendorId != null) 'vendor_ids[]': [_vendorId],
      if (_categoryId != null) 'category_id': _categoryId,
    });
    if (picked == null || !mounted) return;
    setState(() => _filters = picked);
    _fetch(reset: true, keep: true);
  }

  Future<void> _openSort() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.col.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (_) => _SortSheet(options: _sortOptions(context), selected: _sort),
    );
    if (picked != null && picked != _sort && mounted) {
      setState(() => _sort = picked);
      _fetch(reset: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(campaignProvider);
    final c = async.valueOrNull;
    if (c == null || c.slug != widget.slug) {
      return async.isLoading ? const _LoadingPage() : const _EndedPage();
    }
    return _buildPage(context, c);
  }

  Widget _buildPage(BuildContext context, Campaign c) {
    final darkIcons = c.bg.computeLuminance() > 0.5;
    final width = MediaQuery.sizeOf(context).width;
    final cols = productGridColumns(width - 24);
    final colW = productColumnWidth(maxWidth: width - 24, columns: cols, spacing: 12);

    return Scaffold(
      backgroundColor: context.col.bg,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _refresh,
        child: CustomScrollView(
          controller: _scrollCtrl,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // The header lives in the app bar itself (Emad, 2026-11-16: "too much empty space"): the
            // logo row shares the back button's band, centred, and the bar collapses to the name.
            SliverAppBar(
              pinned: true,
              expandedHeight: _Header.height(c),
              // The gradient/image also sits under the whole bar, so the collapsed bar keeps it
              // (FlexibleSpaceBar fades its own background out as it collapses).
              flexibleSpace: DecoratedBox(
                decoration: campaignBgDecoration(c, image: c.headerImage ?? c.bgImage),
                child: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: DecoratedBox(
                  decoration: campaignBgDecoration(c, image: c.headerImage ?? c.bgImage),
                  child: Stack(children: [
                    // The printed sale texture of the entry cards (Emad, 2026-11-16); none over an uploaded image.
                    if ((c.headerImage ?? c.bgImage) == null) Positioned.fill(child: CampaignSalePattern(campaign: c)),
                    SafeArea(bottom: false, child: _Header(campaign: c)),
                  ]),
                ),
              ),
              ),
              backgroundColor: c.bg,
              foregroundColor: c.fg,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              systemOverlayStyle:
                  darkIcons ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
              // Opened from a push or a link (go, not push) there is nothing to pop: go home instead.
              leading: context.canPop()
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => context.go('/home'),
                    ),
              title: AnimatedOpacity(
                opacity: _showTitle ? 1 : 0,
                duration: const Duration(milliseconds: 150),
                child: CampaignTitleText(campaign: c, fontSize: 17),
              ),
            ),

            // ── Stores taking part ──
            if (c.showStores)
              SliverToBoxAdapter(
                child: _StoresStrip(
                  campaign: c,
                  selectedId: _vendorId,
                  pinFirstId: widget.initialVendorId,
                  onSelect: _selectVendor,
                ),
              ),

            // ── Category cards (photo + campaign logo). They replace the chips: the same categories
            // and the same filter, so showing both would list every category twice.
            if (c.showCategoryCards && c.chips.isNotEmpty)
              SliverToBoxAdapter(
                child: _CategoryCards(
                  campaign: c,
                  selectedId: _categoryId,
                  onSelect: _selectCategory,
                ),
              )
            // ── Category chips ──
            else if (c.showChips && c.chips.isNotEmpty)
              SliverToBoxAdapter(
                child: _ChipsRow(
                  chips: c.chips,
                  selectedId: _categoryId,
                  onSelect: _selectCategory,
                ),
              ),

            // ── Top banners (store / brand promotions) ──
            if (c.showBanners && c.banners.any((b) => b.isTop && !_bannerIsCurrentView(b)))
              SliverToBoxAdapter(
                child: _TopBanners(
                  banners: c.banners.where((b) => b.isTop && !_bannerIsCurrentView(b)).toList(),
                  onTap: _openBanner,
                ),
              ),

            // ── Count + sort ──
            SliverToBoxAdapter(
              child: Padding(
                key: _gridTopKey,
                padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 4),
                child: Row(children: [
                  Expanded(
                    child: Text(
                        (_total ?? 0) > 0 ? context.s.resultsCountN(_total!) : '',
                        style: TextStyle(
                            fontFamily: _font,
                            fontFamilyFallback: _fallback,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: context.col.ink3)),
                  ),
                  _FilterButton(count: _filters.activeCount, onTap: _openFilters),
                  TextButton.icon(
                    onPressed: _openSort,
                    icon: Icon(Icons.sort_rounded, size: 18, color: context.col.ink0),
                    label: Text(
                        _sortOptions(context)
                            .firstWhere((o) => o.$1 == _sort,
                                orElse: () => _sortOptions(context).first)
                            .$2,
                        style: TextStyle(
                            fontFamily: _font,
                            fontFamilyFallback: _fallback,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: context.col.ink0)),
                  ),
                ]),
              ),
            ),

            if (_refreshing)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: LinearProgressIndicator(minHeight: 2, color: AppColors.primary, backgroundColor: Colors.transparent),
                ),
              ),

            // ── Products ──
            if (_loading)
              const SliverToBoxAdapter(
                child: SizedBox(
                  height: 240,
                  child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                ),
              )
            else if (_loadError)
              SliverToBoxAdapter(child: _ErrorBox(onRetry: () => _fetch(reset: true)))
            else if (_products.isEmpty)
              SliverToBoxAdapter(
                child: _EmptyBox(
                  filtered: _vendorId != null || _categoryId != null || _filters.activeCount > 0,
                  onShowAll: () {
                    setState(() {
                      _vendorId = null;
                      _categoryId = null;
                      _filters = const StoreFilters();
                    });
                    _fetch(reset: true);
                  },
                ),
              )
            else
              ..._gridSlivers(c, cols, colW),

            if (_loadMoreError)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(context.s.loadMoreFailed,
                        style: TextStyle(color: context.col.ink2, fontSize: 13)),
                    TextButton(onPressed: () => _fetch(), child: Text(context.s.retry)),
                  ]),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }
}

extension on _CampaignScreenState {
  /// The product grid in pieces, with a between-products banner after every
  /// [Campaign.bannerEveryRows] full rows, each banner once, in the admin's order.
  List<Widget> _gridSlivers(Campaign c, int cols, double colW) {
    final banners = c.showBanners
        ? c.banners.where((b) => !b.isTop && !_bannerIsCurrentView(b)).toList()
        : const <CampaignBanner>[];
    final chunk = math.max(1, c.bannerEveryRows) * cols;
    final out = <Widget>[];
    var start = 0;
    var next = 0;
    while (start < _products.length) {
      final end = next < banners.length ? math.min(start + chunk, _products.length) : _products.length;
      final last = end >= _products.length;
      out.add(_gridPiece(start, end, cols, colW, skeletons: last && _loadingMore ? cols : 0, first: start == 0));
      if (end - start == chunk && next < banners.length) {
        final b = banners[next++];
        out.add(SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 2),
            child: _BannerTile(banner: b, onTap: () => _openBanner(b)),
          ),
        ));
      }
      start = end;
    }
    return out;
  }

  Widget _gridPiece(int start, int end, int cols, double colW, {required int skeletons, required bool first}) {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(12, first ? 4 : 12, 12, 0),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (_, i) => start + i >= end ? const ProductCardSkeleton() : ProductCard(product: _products[start + i]),
          childCount: end - start + skeletons,
        ),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: productCellHeight(colW).ceilToDouble(),
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final Campaign campaign;
  const _Header({required this.campaign});

  static const double _logo = 82;

  /// The expanded app bar height (status bar excluded): logo row, then the countdown.
  /// The text block (a 2-line headline + the dates) is a little taller than the logo.
  static double height(Campaign c) => 4 + math.max(_logo, 72.0) + (c.showCountdown && c.endsAt != null ? 6 + 30 : 0) + 8;

  @override
  Widget build(BuildContext context) {
    final c = campaign;
    final isAr = context.isAr;
    // Centred (Emad 2026-11-16): logo and name/headline as one centred block in the back button's
    // band, the countdown centred under them; nothing else, so the stores and products start high.
    return Padding(
      // Clear of the back button on either side.
      padding: const EdgeInsets.fromLTRB(52, 4, 52, 8),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          CampaignLogo(campaign: c, height: _logo),
          const SizedBox(width: 10),
          Flexible(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
              // The logo says the name; the yellow line is the headline, then the dates (Emad, 2026-11-16).
              CampaignTitleText(
                  campaign: c,
                  text: c.headline(isAr).isNotEmpty ? c.headline(isAr) : c.name(isAr),
                  fontSize: 16,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  display: true),
              if (campaignDateLine(c, isAr).isNotEmpty)
                Text(campaignDateLine(c, isAr),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: _font,
                        fontFamilyFallback: _fallback,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: c.fg)),
            ]),
          ),
        ]),
        if (c.showCountdown && c.endsAt != null) ...[
          const SizedBox(height: 6),
          SizedBox(
            height: 30,
            child: FittedBox(fit: BoxFit.scaleDown, child: CampaignCountdown(campaign: c, compact: true)),
          ),
        ],
      ]),
    );
  }
}

// ── Stores strip ──────────────────────────────────────────────────────────────

class _StoresStrip extends ConsumerWidget {
  final Campaign campaign;
  final int? selectedId;
  /// The store the page was opened for (from its store page) is shown first, so it is visible.
  final int? pinFirstId;
  final ValueChanged<int?> onSelect;
  const _StoresStrip({
    required this.campaign,
    required this.selectedId,
    required this.pinFirstId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stores = [...ref.watch(campaignStoresProvider(campaign.slug)).valueOrNull ?? const <CampaignStore>[]];
    if (stores.isEmpty) return const SizedBox.shrink();
    final pinned = stores.indexWhere((s) => s.id == pinFirstId);
    if (pinned > 0) stores.insert(0, stores.removeAt(pinned));
    final isAr = context.isAr;
    return Container(
      color: context.col.surface,
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(context.s.campaignStores,
              style: TextStyle(
                  fontFamily: _font,
                  fontFamilyFallback: _fallback,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: context.col.ink0)),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: stores.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, i) {
              if (i == 0) {
                return _StoreBubble(
                  label: context.s.all,
                  selected: selectedId == null,
                  onTap: () => onSelect(null),
                  child: Container(
                    decoration: campaignBgDecoration(campaign),
                    alignment: Alignment.center,
                    child: Icon(Icons.grid_view_rounded, size: 24, color: campaign.fg),
                  ),
                );
              }
              final s = stores[i - 1];
              final name = s.label(isAr);
              return _StoreBubble(
                label: name,
                selected: selectedId == s.id,
                onTap: () => onSelect(s.id),
                child: s.logo == null
                    ? _Initial(name: name, campaign: campaign)
                    : CachedNetworkImage(
                        imageUrl: s.logo!,
                        fit: BoxFit.contain,
                        memCacheWidth: 160,
                        placeholder: (_, __) => ColoredBox(color: context.col.surfaceSoft),
                        errorWidget: (_, __, ___) => _Initial(name: name, campaign: campaign),
                      ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _StoreBubble extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  const _StoreBubble({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        child: Column(children: [
          Container(
            width: 62,
            height: 62,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? AppColors.adaptive(context) : context.col.border,
                width: selected ? 2.2 : 1,
              ),
            ),
            child: ClipOval(child: ColoredBox(color: Colors.white, child: child)),
          ),
          const SizedBox(height: 6),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: _font,
                  fontFamilyFallback: _fallback,
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  color: selected ? context.col.ink0 : context.col.ink1)),
        ]),
      ),
    );
  }
}

/// A store with no logo: its first letter on the campaign colour.
class _Initial extends StatelessWidget {
  final String name;
  final Campaign campaign;
  const _Initial({required this.name, required this.campaign});

  @override
  Widget build(BuildContext context) {
    final t = name.trim();
    return Container(
      color: campaign.bg.withValues(alpha: 0.18),
      alignment: Alignment.center,
      child: Text(t.isEmpty ? '?' : t.characters.first.toUpperCase(),
          style: TextStyle(
              fontFamily: _font,
              fontFamilyFallback: _fallback,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: context.col.ink0)),
    );
  }
}

// ── Category cards ────────────────────────────────────────────────────────────

/// One card per category (photo, name, offer count) with the campaign's sticker logo on it, the
/// way product cards carry it. «الكل» is a card in the campaign colours.
class _CategoryCards extends StatefulWidget {
  final Campaign campaign;
  final int? selectedId;
  final ValueChanged<int?> onSelect;
  const _CategoryCards({required this.campaign, required this.selectedId, required this.onSelect});

  @override
  State<_CategoryCards> createState() => _CategoryCardsState();
}

class _CategoryCardsState extends State<_CategoryCards> {
  static const double _w = 104;
  static const double _gap = 10;
  final _row = ScrollController();

  @override
  void dispose() {
    _row.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _revealSelected();
  }

  @override
  void didUpdateWidget(_CategoryCards old) {
    super.didUpdateWidget(old);
    if (old.selectedId != widget.selectedId) _revealSelected();
  }

  /// A filter set from elsewhere (a banner, a link) may pick a card that is off-screen in the row:
  /// centre it. Only this row moves, never the page.
  void _revealSelected() {
    final i = widget.campaign.chips.indexWhere((c) => c.id == widget.selectedId);
    if (i < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_row.hasClients) return;
      final p = _row.position;
      final card = 12 + (i + 1) * (_w + _gap); // after the side padding and «الكل»
      final target = (card - (p.viewportDimension - _w) / 2).clamp(0.0, p.maxScrollExtent);
      _row.animateTo(target, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.isAr;
    final campaign = widget.campaign;
    final selectedId = widget.selectedId;
    final onSelect = widget.onSelect;
    final chips = campaign.chips;
    return Container(
      color: context.col.surface,
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(context.s.campaignCategories,
              style: TextStyle(
                  fontFamily: _font,
                  fontFamilyFallback: _fallback,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: context.col.ink0)),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: _w + 44,
          child: ListView.separated(
            controller: _row,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: chips.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: _gap),
            itemBuilder: (_, i) {
              if (i == 0) {
                return _CategoryCard(
                  width: _w,
                  label: context.s.all,
                  sub: campaign.productsCount > 0 ? context.s.resultsCountN(campaign.productsCount) : null,
                  selected: selectedId == null,
                  onTap: () => onSelect(null),
                  photo: Container(
                    decoration: campaignBgDecoration(campaign),
                    padding: const EdgeInsets.all(12),
                    alignment: Alignment.center,
                    child: CampaignLogo(campaign: campaign, height: 64),
                  ),
                );
              }
              final ch = chips[i - 1];
              return _CategoryCard(
                width: _w,
                label: ch.label(isAr),
                sub: ch.count > 0 ? context.s.resultsCountN(ch.count) : null,
                selected: selectedId == ch.id,
                onTap: () => onSelect(selectedId == ch.id ? null : ch.id),
                sticker: campaign,
                photo: ch.image == null
                    ? Container(
                        color: campaign.bg.withValues(alpha: 0.14),
                        alignment: Alignment.center,
                        child: Icon(Icons.local_offer_outlined, size: 30, color: context.col.ink3),
                      )
                    : CachedNetworkImage(
                        imageUrl: ch.image!,
                        fit: BoxFit.cover,
                        memCacheWidth: 320,
                        placeholder: (_, __) => ColoredBox(color: context.col.surfaceSoft),
                        errorWidget: (_, __, ___) => ColoredBox(color: context.col.surfaceSoft),
                      ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final double width;
  final String label;
  final String? sub;
  final bool selected;
  final VoidCallback onTap;
  final Widget photo;
  /// The campaign whose sticker logo sits on the photo's bottom corner (none on «الكل»).
  final Campaign? sticker;
  const _CategoryCard({
    required this.width,
    required this.label,
    this.sub,
    required this.selected,
    required this.onTap,
    required this.photo,
    this.sticker,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: width,
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Container(
            width: width,
            height: width,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppColors.adaptive(context) : context.col.border,
                width: selected ? 2.2 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(selected ? 9.8 : 11),
              child: Stack(fit: StackFit.expand, children: [
                photo,
                if (sticker != null)
                  PositionedDirectional(
                    bottom: 4,
                    end: 4,
                    child: CampaignLogo(campaign: sticker!, height: 34),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 6),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: _font,
                  fontFamilyFallback: _fallback,
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: context.col.ink0)),
          if (sub != null)
            Text(sub!,
                maxLines: 1,
                style: TextStyle(
                    fontFamily: _font,
                    fontFamilyFallback: _fallback,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: context.col.ink3)),
        ]),
      ),
    );
  }
}

// ── Banners ───────────────────────────────────────────────────────────────────

/// Banner images are 1920 × 700, like the home banners.
const double _bannerRatio = 1920 / 700;

class _BannerTile extends StatelessWidget {
  final CampaignBanner banner;
  final VoidCallback onTap;
  const _BannerTile({required this.banner, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: banner.link != null,
      label: banner.title.isEmpty ? null : banner.title,
      child: GestureDetector(
        onTap: banner.link == null ? null : onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: _bannerRatio,
            child: CachedNetworkImage(
              imageUrl: banner.imageFor(context.isAr),
              fit: BoxFit.cover,
              memCacheWidth: 1100,
              placeholder: (_, __) => ColoredBox(color: context.col.surfaceSoft),
              errorWidget: (_, __, ___) => ColoredBox(color: context.col.surfaceSoft),
            ),
          ),
        ),
      ),
    );
  }
}

/// The "top" banners under the categories: one full-width banner, or a slider that moves on by
/// itself every 5 s when there are several.
class _TopBanners extends StatefulWidget {
  final List<CampaignBanner> banners;
  final ValueChanged<CampaignBanner> onTap;
  const _TopBanners({required this.banners, required this.onTap});

  @override
  State<_TopBanners> createState() => _TopBannersState();
}

class _TopBannersState extends State<_TopBanners> {
  final _ctrl = PageController(viewportFraction: 0.92);
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    if (widget.banners.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!_ctrl.hasClients) return;
        _ctrl.animateToPage((_page + 1) % widget.banners.length,
            duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.banners;
    if (b.length == 1) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: _BannerTile(banner: b.first, onTap: () => widget.onTap(b.first)),
      );
    }
    final w = MediaQuery.sizeOf(context).width;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(children: [
        SizedBox(
          height: (w * 0.92 - 8) / _bannerRatio,
          child: PageView.builder(
            controller: _ctrl,
            itemCount: b.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _BannerTile(banner: b[i], onTap: () => widget.onTap(b[i])),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < b.length; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == _page ? 16 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == _page ? context.col.ink1 : context.col.border,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ]),
      ]),
    );
  }
}

// ── Category chips ────────────────────────────────────────────────────────────

class _ChipsRow extends StatelessWidget {
  final List<CampaignChip> chips;
  final int? selectedId;
  final ValueChanged<int?> onSelect;
  const _ChipsRow({required this.chips, required this.selectedId, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final isAr = context.isAr;
    return Container(
      color: context.col.surface,
      padding: const EdgeInsets.only(top: 6, bottom: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.only(start: 12, end: 4),
        child: Row(children: [
          _Chip(label: context.s.all, selected: selectedId == null, onTap: () => onSelect(null)),
          for (final c in chips)
            _Chip(label: c.label(isAr), selected: selectedId == c.id, onTap: () => onSelect(c.id)),
        ]),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsetsDirectional.only(end: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            // Same look as the store page category carousel: outline; selected = solid tiffany.
            color: AppColors.catTabBg(context, selected),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.catTabBorder(context, selected)),
          ),
          child: Text(label,
              style: TextStyle(
                  fontFamily: _font,
                  fontFamilyFallback: _fallback,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: AppColors.catTabText(context, selected))),
        ),
      );
}

/// «تصفية» next to the sort, with the number of filters on.
class _FilterButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _FilterButton({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(Icons.tune_rounded, size: 18, color: context.col.ink0),
      label: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(context.s.campaignFilter,
            style: TextStyle(
                fontFamily: _font,
                fontFamilyFallback: _fallback,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.col.ink0)),
        if (count > 0) ...[
          const SizedBox(width: 5),
          Container(
            constraints: const BoxConstraints(minWidth: 18),
            height: 18,
            padding: const EdgeInsets.symmetric(horizontal: 5),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.adaptive(context), borderRadius: BorderRadius.circular(9)),
            child: Text('$count',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white, height: 1.0)),
          ),
        ],
      ]),
    );
  }
}

// ── Sort sheet (same look as the search results one) ──────────────────────────

class _SortSheet extends StatelessWidget {
  final List<(String, String)> options;
  final String selected;
  const _SortSheet({required this.options, required this.selected});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: context.col.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                    color: context.col.surfaceSoft, borderRadius: BorderRadius.circular(99)),
                child: Icon(Icons.close_rounded, size: 18, color: context.col.ink1),
              ),
            ),
            const SizedBox(width: 12),
            Text(context.s.sortBy,
                style: const TextStyle(
                    fontFamily: _font,
                    fontFamilyFallback: _fallback,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 8),
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) Divider(height: 1, color: context.col.border),
            InkWell(
              onTap: () => Navigator.of(context).pop(options[i].$1),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(children: [
                  Expanded(
                    child: Text(options[i].$2,
                        style: TextStyle(
                          fontFamily: _font,
                          fontFamilyFallback: _fallback,
                          fontSize: 15,
                          fontWeight:
                              options[i].$1 == selected ? FontWeight.w700 : FontWeight.w500,
                          color: context.col.ink0,
                        )),
                  ),
                  if (options[i].$1 == selected)
                    Icon(Icons.check_rounded, size: 22, color: AppColors.adaptive(context)),
                ]),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

// ── States ────────────────────────────────────────────────────────────────────

class _EmptyBox extends StatelessWidget {
  final bool filtered;
  final VoidCallback onShowAll;
  const _EmptyBox({required this.filtered, required this.onShowAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 24),
      child: Column(children: [
        Icon(Icons.local_offer_outlined, size: 56, color: context.col.ink4),
        const SizedBox(height: 12),
        Text(context.s.campaignEmpty,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: _font,
                fontFamilyFallback: _fallback,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.col.ink1)),
        if (filtered) ...[
          const SizedBox(height: 4),
          Text(context.s.campaignEmptySub,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: _font,
                  fontFamilyFallback: _fallback,
                  fontSize: 13,
                  color: context.col.ink3)),
          const SizedBox(height: 14),
          OutlinedButton(onPressed: onShowAll, child: Text(context.s.campaignShowAll)),
        ],
      ]),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorBox({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 24),
      child: Column(children: [
        Icon(Icons.wifi_off_rounded, size: 52, color: context.col.ink4),
        const SizedBox(height: 12),
        Text(context.s.loadError,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: _font,
                fontFamilyFallback: _fallback,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: context.col.ink1)),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: Text(context.s.retry),
        ),
      ]),
    );
  }
}

class _LoadingPage extends StatelessWidget {
  const _LoadingPage();

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: context.col.bg,
        appBar: AppBar(backgroundColor: context.col.bg, elevation: 0),
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
}

/// The link names a campaign that is not running (ended, or not started yet).
class _EndedPage extends StatelessWidget {
  const _EndedPage();

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: context.col.bg,
        appBar: AppBar(backgroundColor: context.col.bg, elevation: 0),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.local_offer_outlined, size: 56, color: context.col.ink4),
              const SizedBox(height: 12),
              Text(context.s.campaignEnded,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: _font,
                      fontFamilyFallback: _fallback,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: context.col.ink0)),
              const SizedBox(height: 6),
              Text(context.s.campaignEndedSub,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: _font,
                      fontFamilyFallback: _fallback,
                      fontSize: 13,
                      color: context.col.ink3)),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => context.go('/home'),
                child: Text(context.s.backToHome),
              ),
            ]),
          ),
        ),
      );
}
