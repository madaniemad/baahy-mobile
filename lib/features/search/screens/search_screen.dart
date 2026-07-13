import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/l10n.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers/app_config_provider.dart';
import '../../../core/providers/home_provider.dart';
import '../../../core/utils/navigation.dart';
import '../../../shared/theme/app_theme.dart';

// ── Recent searches persistence ───────────────────────────────────────────────
class _RecentSearches {
  static const _key = 'recent_searches_v1';
  static const _max = 8;

  static Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? [];
  }

  static Future<void> add(String q) async {
    final trimmed = q.trim();
    if (trimmed.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final list = (prefs.getStringList(_key) ?? []).toList();
    list.remove(trimmed);
    list.insert(0, trimmed);
    if (list.length > _max) list.removeRange(_max, list.length);
    await prefs.setStringList(_key, list);
  }

  static Future<void> remove(String q) async {
    final prefs = await SharedPreferences.getInstance();
    final list = (prefs.getStringList(_key) ?? []).toList();
    list.remove(q);
    await prefs.setStringList(_key, list);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

// ── Suggestion model ──────────────────────────────────────────────────────────
class _Suggestion {
  final String type; // 'suggestion' | 'category' | 'brand' | 'product'
  final String text;
  final String? textAr;
  final String q;
  final int? categoryId;
  final String? image;
  final int? productId;
  const _Suggestion({
    required this.type,
    required this.text,
    this.textAr,
    required this.q,
    this.categoryId,
    this.image,
    this.productId,
  });
  factory _Suggestion.fromJson(Map<String, dynamic> j) => _Suggestion(
    type: j['type'] as String? ?? 'product',
    text: j['text_en'] as String? ?? j['text'] as String,
    textAr: j['text_ar'] as String?,
    q: j['q'] as String? ?? j['text'] as String,
    categoryId: j['category_id'] as int?,
    image: j['image'] as String?,
    productId: j['product_id'] as int?,
  );
}

final _searchSuggestionsProvider =
    FutureProvider.family<List<_Suggestion>, String>((ref, q) async {
  if (q.length < 2) return [];
  final res = await ApiClient.instance.dio
      .get('/search-suggestions', queryParameters: {'q': q});
  return (res.data as List?)
          ?.map((s) => _Suggestion.fromJson(s as Map<String, dynamic>))
          .toList() ??
      [];
});

// ── Screen ────────────────────────────────────────────────────────────────────
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  String _query = '';
  String _debouncedQuery = '';
  Timer? _debounce;
  List<String> _recentSearches = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
    _loadRecents();
  }

  Future<void> _loadRecents() async {
    final list = await _RecentSearches.load();
    if (mounted) setState(() => _recentSearches = list);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    setState(() => _query = v);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _debouncedQuery = v);
    });
  }

  void _search(String q) {
    if (q.trim().isEmpty) return;
    _focus.unfocus();
    _RecentSearches.add(q.trim()).then((_) => _loadRecents());
    safePush(context, '/search/results?q=${Uri.encodeComponent(q.trim())}');
  }

  void _onSuggestionTap(_Suggestion s) {
    _focus.unfocus();
    _RecentSearches.add(s.q).then((_) => _loadRecents());
    if (s.productId != null) {
      safePush(context, '/product/${s.productId}');
    } else if (s.type == 'brand') {
      safePush(context, '/search/results?q=${Uri.encodeComponent(s.q)}&brand=${Uri.encodeComponent(s.q)}');
    } else if (s.categoryId != null) {
      safePush(context, '/search/results?q=${Uri.encodeComponent(s.q)}&category=${s.categoryId}');
    } else {
      safePush(context, '/search/results?q=${Uri.encodeComponent(s.q)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _debouncedQuery.trim().length >= 2;
    final suggestionsAsync = hasQuery
        ? ref.watch(_searchSuggestionsProvider(_debouncedQuery.trim()))
        : const AsyncValue<List<_Suggestion>>.data([]);

    final config = ref.watch(appConfigProvider);
    final categories = ref.watch(homeProvider).categories;

    return Scaffold(
      backgroundColor: context.col.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Search bar ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              color: context.col.surface,
              child: Row(children: [
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4, right: 10),
                    child: Icon(Icons.arrow_back_ios_new_rounded,
                        size: 20, color: context.col.ink1),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.col.border, width: 1.2),
                    ),
                    child: Row(children: [
                      Icon(Icons.search_rounded, size: 18, color: context.col.ink3),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _ctrl,
                          focusNode: _focus,
                          style: TextStyle(
                              fontSize: 14,
                              color: context.col.ink0,
                              fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal']),
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: context.s.searchHint,
                            hintStyle: TextStyle(
                                color: context.col.ink3,
                                fontSize: 14,
                                fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal']),
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 13),
                            isDense: true,
                          ),
                          onChanged: _onChanged,
                          onSubmitted: _search,
                        ),
                      ),
                      if (_query.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _ctrl.clear();
                            setState(() {
                              _query = '';
                              _debouncedQuery = '';
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(Icons.close_rounded,
                                size: 16, color: context.col.ink3),
                          ),
                        )
                      else
                        GestureDetector(
                          onTap: () => safePush(context, '/search/camera'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Icon(Icons.camera_alt_outlined, size: 18, color: context.col.ink3),
                          ),
                        ),
                    ]),
                  ),
                ),
              ]),
            ),

            // ── Body ────────────────────────────────────────────────────────
            Expanded(
              child: hasQuery
                  ? _LiveSuggestions(
                      query: _debouncedQuery.trim(),
                      suggestionsAsync: suggestionsAsync,
                      onTap: _onSuggestionTap,
                    )
                  : _EmptyState(
                      // baahy AI is for signed-in users only.
                      aiEnabled: config.aiEnabled && ref.watch(authProvider).isLoggedIn,
                      trending: config.trendingSearches,
                      categories: categories
                          .map((c) => context.isAr ? c.nameAr : c.name)
                          .take(8)
                          .toList(),
                      recentSearches: _recentSearches,
                      onSearch: _search,
                      onRemoveRecent: (q) {
                        _RecentSearches.remove(q).then((_) => _loadRecents());
                      },
                      onClearRecents: () {
                        _RecentSearches.clear().then((_) => _loadRecents());
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Grouped live suggestions ──────────────────────────────────────────────────
class _LiveSuggestions extends StatelessWidget {
  final String query;
  final AsyncValue<List<_Suggestion>> suggestionsAsync;
  final void Function(_Suggestion) onTap;
  const _LiveSuggestions(
      {required this.query,
      required this.suggestionsAsync,
      required this.onTap});

  IconData _iconFor(String type) {
    switch (type) {
      case 'category':
        return Icons.grid_view_rounded;
      case 'brand':
        return Icons.verified_rounded;
      case 'suggestion':
        return Icons.search_rounded;
      default:
        return Icons.search_rounded;
    }
  }

  Color _iconColorFor(String type, BuildContext context) {
    switch (type) {
      case 'category':
        return AppColors.teal;
      case 'brand':
        return context.col.ink2;
      default:
        return context.col.ink3;
    }
  }

  String _headerFor(String type, BuildContext context) {
    switch (type) {
      case 'category':
        return context.isAr ? 'الأقسام' : 'Categories';
      case 'brand':
        return context.isAr ? 'الماركات' : 'Brands';
      case 'suggestion':
        return context.isAr ? 'اقتراحات' : 'Suggestions';
      default:
        return context.isAr ? 'المنتجات' : 'Products';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.isAr;
    return suggestionsAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(
              color: AppColors.teal, strokeWidth: 2)),
      error: (_, __) => const SizedBox.shrink(),
      data: (suggestions) {
        if (suggestions.isEmpty) return const SizedBox.shrink();

        // Group by type preserving order: category → brand → product
        final groups = <String, List<_Suggestion>>{};
        for (final s in suggestions) {
          groups.putIfAbsent(s.type, () => []).add(s);
        }
        final showHeaders = groups.length >= 2;

        // Build flat list of items with optional header widgets
        final items = <Widget>[];
        groups.forEach((type, list) {
          if (showHeaders) {
            if (items.isNotEmpty) {
              items.add(Divider(height: 1, color: context.col.border));
            }
            items.add(_SectionHeader(label: _headerFor(type, context)));
          }
          for (final s in list) {
            final displayText =
                isAr && s.textAr != null ? s.textAr! : s.text;
            items.add(_SuggestionRow(
              icon: _iconFor(type),
              iconColor: _iconColorFor(type, context),
              text: displayText,
              query: query,
              image: s.image,
              showImage: type == 'product',
              onTap: () => onTap(s),
            ));
            if (s != list.last || (showHeaders && type != groups.keys.last)) {
              items.add(Divider(
                  height: 1, color: context.col.border, indent: 64));
            }
          }
        });

        return ListView(children: items);
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: context.col.ink3,
          letterSpacing: 0.6,
          fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
        ),
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;
  final String query;
  final String? image;
  final bool showImage;
  final VoidCallback onTap;
  const _SuggestionRow({
    required this.icon,
    required this.iconColor,
    required this.text,
    required this.query,
    required this.onTap,
    this.image,
    this.showImage = false,
  });

  Widget _boldQuery(String suggestion, String q, BuildContext ctx) {
    final qLen = q.length;
    final sLower = suggestion.toLowerCase();
    final qLower = q.toLowerCase();
    final idx = sLower.indexOf(qLower);
    if (idx < 0) {
      return Text(suggestion,
          style: TextStyle(
              fontSize: 14, fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], color: ctx.col.ink0));
    }
    return Text.rich(TextSpan(
      style: TextStyle(
          fontSize: 14, fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], color: ctx.col.ink0),
      children: [
        if (idx > 0) TextSpan(text: suggestion.substring(0, idx)),
        TextSpan(
            text: suggestion.substring(idx, idx + qLen),
            style: const TextStyle(fontWeight: FontWeight.w700)),
        TextSpan(text: suggestion.substring(idx + qLen)),
      ],
    ));
  }

  @override
  Widget build(BuildContext ctx) {
    final leading = showImage && image != null
        ? ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: image!,
              width: 36,
              height: 36,
              fit: BoxFit.cover,
              memCacheWidth: 72,
              errorWidget: (_, __, ___) =>
                  Icon(icon, size: 16, color: iconColor),
            ),
          )
        : SizedBox(
            width: 36,
            child: Icon(icon, size: 16, color: iconColor),
          );

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          leading,
          const SizedBox(width: 12),
          Expanded(child: _boldQuery(text, query, ctx)),
          const SizedBox(width: 8),
          Icon(Icons.north_west_rounded, size: 14, color: ctx.col.ink3),
        ]),
      ),
    );
  }
}

// ── Empty state (no query typed yet) ─────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool aiEnabled;
  final List<String> trending;
  final List<String> categories;
  final List<String> recentSearches;
  final void Function(String) onSearch;
  final void Function(String) onRemoveRecent;
  final VoidCallback onClearRecents;

  const _EmptyState({
    required this.aiEnabled,
    required this.trending,
    required this.categories,
    required this.recentSearches,
    required this.onSearch,
    required this.onRemoveRecent,
    required this.onClearRecents,
  });

  @override
  Widget build(BuildContext context) {
    final isAr = context.isAr;
    return LayoutBuilder(builder: (context, constraints) {
      return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
        child: IntrinsicHeight(
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Recent searches ───────────────────────────────────────────
          if (recentSearches.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(context.s.recentSearches,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: context.col.ink2,
                        letterSpacing: 0.6)),
                GestureDetector(
                  onTap: onClearRecents,
                  child: Text(context.s.clearAll,
                      style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
                          color: AppColors.teal,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ...recentSearches.map((q) => InkWell(
                  onTap: () => onSearch(q),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    child: Row(children: [
                      Icon(Icons.history_rounded,
                          size: 16, color: context.col.ink3),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(q,
                              style: TextStyle(
                                  fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
                                  fontSize: 14,
                                  color: context.col.ink1))),
                      GestureDetector(
                        onTap: () => onRemoveRecent(q),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Icon(Icons.close_rounded,
                              size: 15, color: context.col.ink4),
                        ),
                      ),
                    ]),
                  ),
                )),
            const SizedBox(height: 10),
            Divider(color: context.col.border),
            const SizedBox(height: 10),
          ],

          // ── Trending ──────────────────────────────────────────────────
          if (trending.isNotEmpty) ...[
            Row(children: [
              Icon(Icons.local_fire_department_rounded,
                  size: 14, color: AppColors.teal),
              const SizedBox(width: 5),
              Text(context.s.trendingNow,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: context.col.ink2,
                      letterSpacing: 0.6)),
            ]),
            const SizedBox(height: 10),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: trending.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) => GestureDetector(
                  onTap: () => onSearch(trending[i]),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.teal50,
                      borderRadius: AppRadius.pillBorder,
                      border: Border.all(color: AppColors.teal100, width: 1),
                    ),
                    child: Text(trending[i],
                        style: TextStyle(
                            fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.teal700)),
                  ),
                ),
              ),
            ),
          ],

          // ── Categories ────────────────────────────────────────────────
          if (categories.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(context.s.categories,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.col.ink2,
                    letterSpacing: 0.6)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories
                  .map((c) => GestureDetector(
                        onTap: () => onSearch(c),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: context.col.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.col.border),
                          ),
                          child: Text(c,
                              style: const TextStyle(
                                  fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                        ),
                      ))
                  .toList(),
            ),
          ],

          // ── AI assistant card ─────────────────────────────────────────
          // Pushes the AI banner to the bottom of the screen.
          const Spacer(),
          if (aiEnabled) ...[
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => safePush(context, '/chat'),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.col.border),
                  boxShadow: AppShadows.shadowCard,
                ),
                child: Image.asset('assets/images/ai_banner.png',
                  width: double.infinity, fit: BoxFit.cover),
              ),
            ),
          ],
        ],
        ),
        ),
        ),
      );
    });
  }
}
