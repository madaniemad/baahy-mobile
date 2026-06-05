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
      backgroundColor: context.col.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Search bar
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              decoration: BoxDecoration(
                color: context.col.surface,
                border: Border(bottom: BorderSide(color: context.col.border)),
              ),
              child: Row(children: [
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: context.col.surfaceSoft, shape: BoxShape.circle),
                    child: Icon(Icons.arrow_back, size: 18, color: context.col.ink0),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: context.col.surfaceSoft,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: context.col.border, width: 1.2),
                    ),
                    child: Row(children: [
                      const SizedBox(width: 12),
                      Icon(Icons.search, size: 18, color: context.col.ink3),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _ctrl,
                          focusNode: _focus,
                          style: TextStyle(fontSize: 14, color: context.col.ink0),
                          decoration: InputDecoration(
                            hintText: context.s.searchHint,
                            hintStyle: TextStyle(color: context.col.ink3, fontSize: 14),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          onChanged: _onChanged,
                          onSubmitted: _search,
                        ),
                      ),
                      if (_query.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _ctrl.clear();
                            setState(() { _query = ''; _debouncedQuery = ''; });
                          },
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Icon(Icons.close, size: 16, color: context.col.ink3),
                          ),
                        ),
                    ]),
                  ),
                ),
              ]),
            ),

            // Body
            Expanded(
              child: hasQuery
                  ? _LiveResults(
                      query: _debouncedQuery,
                      suggestionsAsync: suggestionsAsync,
                      onSearch: _search,
                    )
                  : _EmptyState(
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
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 48, height: 48,
                        child: p.firstImage != null
                            ? CachedNetworkImage(
                                imageUrl: p.firstImage!, fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Container(
                                  color: context.col.surfaceSoft,
                                  child: Icon(Icons.image_outlined, color: context.col.ink4, size: 20)),
                              )
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
                  style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary),
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
  final List<String> trending;
  final List<String> categories;
  final void Function(String) onSearch;
  const _EmptyState({required this.trending, required this.categories, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trending
          Text(context.s.trendingNow,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
              color: context.col.ink2, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          ...List.generate(trending.length, (i) => InkWell(
            onTap: () => onSearch(trending[i]),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(children: [
                SizedBox(
                  width: 22,
                  child: Text('0${i + 1}',
                    style: TextStyle(fontFamily: 'PlusJakartaSans',
                      fontWeight: FontWeight.w700, color: context.col.ink3, fontSize: 13)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(trending[i],
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                ),
                Icon(Icons.arrow_forward_ios, size: 14, color: context.col.ink3),
              ]),
            ),
          )),

          if (categories.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(context.s.categories,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                color: context.col.ink2, letterSpacing: 0.5)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: categories.map((c) => GestureDetector(
                onTap: () => onSearch(c),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    color: context.col.surfaceSoft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.col.border),
                  ),
                  child: Text(c, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                ),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
