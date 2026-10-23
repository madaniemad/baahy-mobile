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
import '../../../core/utils/arabic_text.dart';
import '../../../core/utils/navigation.dart';
import '../../../core/services/analytics_service.dart';
import '../../../shared/theme/app_theme.dart';

/// Trimmed, inner whitespace collapsed — what we send, key suggestions on and store.
String _cleanQuery(String q) => q.trim().replaceAll(RegExp(r'\s+'), ' ');

// ── Recent searches persistence ───────────────────────────────────────────────
class _RecentSearches {
  static const _key = 'recent_searches_v1';
  static const _max = 8;

  /// Newest first, max [_max]; «Nike», «nike » and «احذيه»/«أحذية» are one entry
  /// (case-insensitive + Arabic-normalised), the newest spelling kept.
  static List<String> _dedupe(Iterable<String> items) {
    final seen = <String>{};
    final out = <String>[];
    for (final raw in items) {
      final q = _cleanQuery(raw);
      if (q.isEmpty || !seen.add(normalizeArabic(q))) continue;
      out.add(q);
      if (out.length == _max) break;
    }
    return out;
  }

  static Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return _dedupe(prefs.getStringList(_key) ?? const []);
  }

  static Future<void> add(String q) async {
    final clean = _cleanQuery(q);
    if (clean.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final list = _dedupe([clean, ...?prefs.getStringList(_key)]);
    await prefs.setStringList(_key, list);
  }

  static Future<void> remove(String q) async {
    final prefs = await SharedPreferences.getInstance();
    final key = normalizeArabic(q);
    final list = (prefs.getStringList(_key) ?? [])
        .where((s) => normalizeArabic(s) != key)
        .toList();
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
  static String? _str(dynamic v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  static int? _int(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');

  // Defensive: a row missing `text` (or with an id sent as a string) must not
  // throw and blank the whole list.
  factory _Suggestion.fromJson(Map<String, dynamic> j) {
    final text = _str(j['text_en']) ?? _str(j['text']) ?? _str(j['text_ar']) ?? _str(j['q']) ?? '';
    return _Suggestion(
      type: _str(j['type']) ?? 'product',
      text: text,
      textAr: _str(j['text_ar']),
      q: _str(j['q']) ?? _str(j['text']) ?? text,
      categoryId: _int(j['category_id']),
      image: _str(j['image']),
      productId: _int(j['product_id']),
    );
  }
}

// autoDispose: a failed fetch is not cached for the session — retyping the query
// asks again.
final _searchSuggestionsProvider =
    FutureProvider.autoDispose.family<List<_Suggestion>, String>((ref, q) async {
  if (q.length < 2) return [];
  final res = await ApiClient.instance.dio
      .get('/search-suggestions', queryParameters: {'q': q});
  final raw = res.data;
  final list = raw is List
      ? raw
      : (raw is Map && raw['data'] is List ? raw['data'] as List : const []);
  final out = <_Suggestion>[];
  for (final item in list) {
    if (item is! Map) continue;
    try {
      final s = _Suggestion.fromJson(Map<String, dynamic>.from(item));
      if (s.text.isNotEmpty) out.add(s);
    } catch (_) {/* skip one bad row, keep the rest */}
  }
  return out;
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
    // Only surrounding / repeated spaces changed: same suggestions, no refetch.
    if (_cleanQuery(v) == _debouncedQuery) return;
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _debouncedQuery = _cleanQuery(v));
    });
  }

  void _search(String q) {
    final clean = _cleanQuery(q);
    if (clean.isEmpty) return;
    _focus.unfocus();
    Analytics.instance.search(clean);
    _RecentSearches.add(clean).then((_) => _loadRecents());
    safePush(context, '/search/results?q=${Uri.encodeComponent(clean)}');
  }

  // A category chip opens the category itself, not a text search for its name,
  // and is not a "recent search".
  void _openCategory(int id, String name) {
    _focus.unfocus();
    safePush(context, '/search/results?q=&category=$id',
        extra: <String, dynamic>{'title': name});
  }

  void _onSuggestionTap(_Suggestion s) {
    _focus.unfocus();
    _RecentSearches.add(s.q).then((_) => _loadRecents());
    if (s.productId != null) {
      safePush(context, '/product/${s.productId}');
    } else if (s.type == 'brand') {
      // Brand filter only — also sending the name as `search` dropped products
      // whose title doesn't repeat the brand. The results title falls back to it.
      safePush(context, '/search/results?q=&brand=${Uri.encodeComponent(s.q)}');
    } else if (s.categoryId != null) {
      safePush(context, '/search/results?q=${Uri.encodeComponent(s.q)}&category=${s.categoryId}');
    } else {
      safePush(context, '/search/results?q=${Uri.encodeComponent(s.q)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _debouncedQuery.length >= 2;
    final suggestionsAsync = hasQuery
        ? ref.watch(_searchSuggestionsProvider(_debouncedQuery))
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
                    padding: const EdgeInsetsDirectional.only(end: 4, start: 10),
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
                            _debounce?.cancel();
                            _ctrl.clear();
                            setState(() {
                              _query = '';
                              _debouncedQuery = '';
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsetsDirectional.only(end: 4),
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
                      query: _debouncedQuery,
                      suggestionsAsync: suggestionsAsync,
                      onTap: _onSuggestionTap,
                      onSearch: _search,
                    )
                  : _EmptyState(
                      // baahy AI is for signed-in users only.
                      aiEnabled: config.aiEnabled && ref.watch(authProvider).isLoggedIn,
                      trending: config.trendingSearches,
                      categories: categories
                          .take(8)
                          .map((c) => (id: c.id, name: context.isAr ? c.nameAr : c.name))
                          .toList(),
                      recentSearches: _recentSearches,
                      onSearch: _search,
                      onCategory: _openCategory,
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
  final void Function(String) onSearch;
  const _LiveSuggestions(
      {required this.query,
      required this.suggestionsAsync,
      required this.onTap,
      required this.onSearch});

  /// No suggestions (or the request failed): one row that runs the search
  /// itself, instead of a blank area.
  Widget _searchForRow(BuildContext context) => ListView(children: [
        _SuggestionRow(
          icon: Icons.search_rounded,
          iconColor: context.col.ink3,
          text: context.s.searchForQuery(query),
          query: query,
          onTap: () => onSearch(query),
        ),
        Divider(height: 1, color: context.col.border, indent: 64),
      ]);

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
      error: (_, __) => _searchForRow(context),
      data: (suggestions) {
        if (suggestions.isEmpty) return _searchForRow(context);

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
          Icon(ctx.isAr ? Icons.north_east_rounded : Icons.north_west_rounded,
              size: 14, color: ctx.col.ink3),
        ]),
      ),
    );
  }
}

// ── Empty state (no query typed yet) ─────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool aiEnabled;
  final List<String> trending;
  final List<({int id, String name})> categories;
  final List<String> recentSearches;
  final void Function(String) onSearch;
  final void Function(int id, String name) onCategory;
  final void Function(String) onRemoveRecent;
  final VoidCallback onClearRecents;

  const _EmptyState({
    required this.aiEnabled,
    required this.trending,
    required this.categories,
    required this.recentSearches,
    required this.onSearch,
    required this.onCategory,
    required this.onRemoveRecent,
    required this.onClearRecents,
  });

  @override
  Widget build(BuildContext context) {
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
                          padding: const EdgeInsetsDirectional.only(end: 8),
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
                      color: AppColors.tealChipBg(context),
                      borderRadius: AppRadius.pillBorder,
                      border: Border.all(color: AppColors.tealChipBorder(context), width: 1),
                    ),
                    child: Text(trending[i],
                        style: TextStyle(
                            fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.tealChipText(context))),
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
                        onTap: () => onCategory(c.id, c.name),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            // Standard tab style (unselected), like `_Tab`.
                            color: AppColors.tealChipBg(context),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(c.name,
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
                child: Image.asset(
                  context.isAr ? 'assets/images/ai_banner.png' : 'assets/images/ai_banner_en.png',
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
