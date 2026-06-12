import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/l10n.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/product.dart';
import '../../../core/providers/app_config_provider.dart';
import '../../../core/providers/home_provider.dart';
import '../../../core/utils/navigation.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/mic_button.dart';

final _searchSuggestionsProvider = FutureProvider.family<List<Product>, String>((ref, q) async {
  if (q.length < 2) return [];
  final res = await ApiClient.instance.dio.get('/products',
    queryParameters: {'search': q, 'per_page': 6});
  return (res.data['data']['data'] as List?)
      ?.map((p) => Product.fromJson(p)).toList() ?? [];
});

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
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
    safePush(context, '/search/results?q=${Uri.encodeComponent(q.trim())}');
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _debouncedQuery.trim().length >= 2;
    final suggestionsAsync = hasQuery
        ? ref.watch(_searchSuggestionsProvider(_debouncedQuery.trim()))
        : const AsyncValue<List<Product>>.data([]);

    final config = ref.watch(appConfigProvider);
    final categories = ref.watch(homeProvider).categories;

    return Scaffold(
      backgroundColor: context.col.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Search bar ────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              color: context.col.surface,
              child: Row(children: [
                // Back arrow (outside the input box)
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4, right: 10),
                    child: Icon(Icons.arrow_back_ios_new_rounded,
                      size: 20, color: context.col.ink1),
                  ),
                ),
                // Input box — white fill, single border, matching home screen style
                Expanded(
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: context.col.border, width: 1.2),
                    ),
                    child: Row(children: [
                      Icon(Icons.search_rounded, size: 18, color: context.col.ink3),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _ctrl,
                          focusNode: _focus,
                          style: TextStyle(fontSize: 14, color: context.col.ink0, fontFamily: 'Cairo'),
                          textDirection: TextDirection.rtl,
                          decoration: InputDecoration(
                            hintText: context.s.searchHint,
                            hintStyle: TextStyle(color: context.col.ink3, fontSize: 14, fontFamily: 'Cairo'),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 13),
                            isDense: true,
                          ),
                          onChanged: _onChanged,
                          onSubmitted: _search,
                        ),
                      ),
                      if (_query.isNotEmpty)
                        GestureDetector(
                          onTap: () { _ctrl.clear(); setState(() { _query = ''; _debouncedQuery = ''; }); },
                          child: Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(Icons.close_rounded, size: 16, color: context.col.ink3),
                          ),
                        )
                      else
                        MicButton(color: context.col.ink3, size: 18),
                    ]),
                  ),
                ),
              ]),
            ),

            // ── Body ──────────────────────────────────────────────────────
            Expanded(
              child: hasQuery
                  ? _LiveResults(
                      query: _debouncedQuery,
                      suggestionsAsync: suggestionsAsync,
                      onSearch: _search,
                    )
                  : _EmptyState(
                      aiEnabled: config.aiEnabled,
                      trending: config.trendingSearches,
                      categories: categories.map((c) => context.isAr ? c.nameAr : c.name).take(8).toList(),
                      onSearch: _search,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveResults extends StatelessWidget {
  final String query;
  final AsyncValue<List<Product>> suggestionsAsync;
  final void Function(String) onSearch;
  const _LiveResults({required this.query, required this.suggestionsAsync, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    return suggestionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(
        color: AppColors.primary, strokeWidth: 2)),
      error: (_, __) => const SizedBox.shrink(),
      data: (products) {
        if (products.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search, size: 48, color: context.col.ink4),
                  const SizedBox(height: 12),
                  Text('${context.s.noResults} "$query"',
                    style: TextStyle(fontSize: 14, color: context.col.ink2),
                    textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => onSearch(query),
                    child: Text(context.s.searchAnyway,
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView(
          children: [
            ...products.map((p) {
              final isAr = Localizations.localeOf(context).languageCode == 'ar';
              return InkWell(
                onTap: () => safePush(context, '/product/${p.id}'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        width: 48, height: 48,
                        child: p.firstImage != null
                            ? CachedNetworkImage(imageUrl: p.firstImage!, fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Container(
                                  color: context.col.surfaceSoft,
                                  child: Icon(Icons.image_outlined, color: context.col.ink4, size: 20)))
                            : Container(color: context.col.surfaceSoft,
                                child: Icon(Icons.image_outlined, color: context.col.ink4, size: 20)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(isAr ? p.nameAr : p.name,
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.3),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                        if (p.vendor != null)
                          Text(isAr ? p.vendor!.storeNameAr : p.vendor!.storeName,
                            style: TextStyle(fontSize: 11.5, color: context.col.ink2)),
                      ]),
                    ),
                    Text('${fmtPrice(p.displayPrice)} ${context.s.lydUnit}',
                      style: const TextStyle(fontFamily: 'PlusJakartaSans',
                        fontWeight: FontWeight.w700, fontSize: 13)),
                  ]),
                ),
              );
            }),
            InkWell(
              onTap: () => onSearch(query),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('${context.s.seeAllResultsFor} "$query" ${context.isAr ? "←" : "→"}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary),
                  textAlign: TextAlign.center),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool aiEnabled;
  final List<String> trending;
  final List<String> categories;
  final void Function(String) onSearch;
  const _EmptyState({required this.aiEnabled, required this.trending,
    required this.categories, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    final isAr = context.isAr;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Trending ─────────────────────────────────────────────────
          if (trending.isNotEmpty) ...[
            Text(context.s.trendingNow,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                color: context.col.ink2, letterSpacing: 0.6)),
            const SizedBox(height: 6),
            ...List.generate(trending.length, (i) => InkWell(
              onTap: () => onSearch(trending[i]),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Row(children: [
                  SizedBox(width: 24,
                    child: Text('${(i + 1).toString().padLeft(2, '0')}',
                      style: TextStyle(fontFamily: 'PlusJakartaSans',
                        fontWeight: FontWeight.w700, color: context.col.ink4, fontSize: 12))),
                  const SizedBox(width: 10),
                  Expanded(child: Text(trending[i],
                    style: const TextStyle(fontFamily: 'Cairo',
                      fontSize: 14, fontWeight: FontWeight.w500))),
                  Icon(isAr ? Icons.arrow_back_ios_rounded : Icons.arrow_forward_ios_rounded,
                    size: 12, color: context.col.ink3),
                ]),
              ),
            )),
          ],

          // ── Categories ───────────────────────────────────────────────
          if (categories.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(context.s.categories,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                color: context.col.ink2, letterSpacing: 0.6)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: categories.map((c) => GestureDetector(
                onTap: () => onSearch(c),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: context.col.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.col.border),
                  ),
                  child: Text(c, style: const TextStyle(
                    fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w500)),
                ),
              )).toList(),
            ),
          ],

          // ── AI assistant card (bottom) ────────────────────────────────
          if (aiEnabled) ...[
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => safePush(context, '/chat'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1BBFBC), Color(0xFF32DDE5), Color(0xFF6AECF0)],
                    stops: [0.0, 0.55, 1.0],
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(
                    color: const Color(0xFF32DDE5).withValues(alpha: 0.30),
                    blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Row(children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded,
                      color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('baahyAi',
                        style: TextStyle(fontFamily: 'Cairo',
                          fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                      const SizedBox(height: 2),
                      Text(isAr
                          ? 'تحتاج مساعدة اضافية؟ اسال مساعدك الذكي'
                          : 'Need more help? Ask your AI assistant',
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 12,
                          color: Color(0xFF004D54))),
                    ],
                  )),
                  Icon(isAr ? Icons.arrow_back_ios_rounded : Icons.arrow_forward_ios_rounded,
                    size: 14, color: Colors.white.withValues(alpha: 0.80)),
                ]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
