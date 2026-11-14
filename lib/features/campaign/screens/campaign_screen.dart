import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/campaign.dart';
import '../../../core/models/product.dart';
import '../../../core/providers/campaign_provider.dart';
import '../../../core/utils/l10n.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/product_card.dart';
import '../widgets/campaign_widgets.dart';

const _font = 'Manrope';
const _fallback = ['Tajawal'];

/// The campaign page (`/campaign/:slug`, optional `?vendor=` / `?category=`).
///
/// Header in the campaign colours (logo, name, headline, countdown), the stores taking part, the
/// category chips, a sort control and the product grid. Everything comes from the API, so the page
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
  bool _showTitle = false;

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
    final show = pos.pixels > 150;
    if (show != _showTitle) setState(() => _showTitle = show);
    if (pos.pixels > pos.maxScrollExtent - 400) {
      // After a failed page, wait for the Retry tap instead of re-firing on every scroll tick.
      if (!_loadingMore && _hasMore && !_loadMoreError && !_loading) _fetch();
    }
  }

  Future<void> _fetch({bool reset = false}) async {
    if (reset) {
      ++_reqSeq;
      setState(() {
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

  void _selectVendor(int? id) {
    if (_vendorId == id) return;
    setState(() => _vendorId = id);
    _fetch(reset: true);
  }

  void _selectCategory(int? id) {
    if (_categoryId == id) return;
    setState(() => _categoryId = id);
    _fetch(reset: true);
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
    final isAr = context.isAr;
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
            SliverAppBar(
              pinned: true,
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
                child: Text(c.name(isAr),
                    style: TextStyle(
                        fontFamily: _font,
                        fontFamilyFallback: _fallback,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: c.fg)),
              ),
            ),

            // ── Header: logo, name, headline, countdown ──
            SliverToBoxAdapter(child: _Header(campaign: c)),

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

            // ── Category chips ──
            if (c.showChips && c.chips.isNotEmpty)
              SliverToBoxAdapter(
                child: _ChipsRow(
                  chips: c.chips,
                  selectedId: _categoryId,
                  onSelect: _selectCategory,
                ),
              ),

            // ── Count + sort ──
            SliverToBoxAdapter(
              child: Padding(
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
                  filtered: _vendorId != null || _categoryId != null,
                  onShowAll: () {
                    setState(() {
                      _vendorId = null;
                      _categoryId = null;
                    });
                    _fetch(reset: true);
                  },
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => i >= _products.length
                        ? const ProductCardSkeleton()
                        : ProductCard(product: _products[i]),
                    childCount: _products.length + (_loadingMore ? cols : 0),
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: productCellHeight(colW).ceilToDouble(),
                  ),
                ),
              ),

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

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final Campaign campaign;
  const _Header({required this.campaign});

  @override
  Widget build(BuildContext context) {
    final c = campaign;
    final isAr = context.isAr;
    return Container(
      color: c.bg,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(children: [
        CampaignLogo(campaign: c, height: 120),
        const SizedBox(height: 10),
        Text(c.name(isAr),
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: _font,
                fontFamilyFallback: _fallback,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                height: 1.2,
                color: c.fg)),
        if (c.headline(isAr).isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(c.headline(isAr),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: _font,
                  fontFamilyFallback: _fallback,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: c.fg.withValues(alpha: 0.85))),
        ],
        if (c.showCountdown && c.endsAt != null) ...[
          const SizedBox(height: 14),
          FittedBox(fit: BoxFit.scaleDown, child: CampaignCountdown(campaign: c)),
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
                    color: campaign.bg,
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
