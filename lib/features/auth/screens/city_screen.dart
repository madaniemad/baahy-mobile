import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/address_provider.dart';
import '../../../core/providers/app_pages_provider.dart';
import '../../../core/providers/shipping_provider.dart';
import '../../../core/utils/arabic_text.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/theme/app_theme.dart';

/// "Change city" (`/city`), opened from the home header city, Settings and Account.
///
/// Redesigned 2026-10-23 (Emad didn't like the full-tiffany page): a plain white page like the rest
/// of the app — standard app bar, outlined search, a full-width list. Tapping a city saves it and
/// goes back; there is no confirm button. Cities come from the live shipping rates. First-run city
/// choice is NOT here — that is the onboarding picker (`onb_city_picker.dart`).
class CityScreen extends ConsumerStatefulWidget {
  const CityScreen({super.key});
  @override
  ConsumerState<CityScreen> createState() => _CityScreenState();
}

class _CityScreenState extends ConsumerState<CityScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<CityEntry> _filter(List<CityEntry> all) {
    if (normalizeArabic(_query).isEmpty) return all;
    return all
        .where((c) => matchesArabic(c.ar, _query) || matchesArabic(c.en, _query))
        .toList();
  }

  Future<void> _pick(CityEntry city) async {
    FocusScope.of(context).unfocus();
    await ref.read(cityProvider.notifier).setCity(city.ar);
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.isAr;
    // The saved city may be stored in Arabic or in English (from a saved address).
    final current = normalizeArabic(ref.watch(cityProvider)).toLowerCase();
    final ratesAsync = ref.watch(shippingRatesProvider);
    final loading = ratesAsync.isLoading && !ratesAsync.hasValue;
    final failed = !loading && ratesAsync.hasError && !ratesAsync.hasValue;
    final all = (ratesAsync.valueOrNull ?? const [])
        .map((r) => CityEntry(ar: r.cityAr, en: r.city))
        .toList();
    final cities = _filter(all);

    bool isCurrent(CityEntry c) =>
        normalizeArabic(c.ar) == current || c.en.toLowerCase() == current;

    return Scaffold(
      backgroundColor: context.col.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: context.col.surface,
        leading: IconButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
          icon: Icon(Icons.arrow_back, color: context.col.ink0),
        ),
        title: Text(isAr ? 'اختر مدينتك' : 'Choose your city',
            style: const TextStyle(
                fontFamily: 'Manrope',
                fontFamilyFallback: ['Tajawal'],
                fontWeight: FontWeight.w800,
                fontSize: 18)),
        centerTitle: true,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Column(children: [
          // Why we ask + search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  isAr
                      ? 'نعرض لك المنتجات وأسعار ومواعيد التوصيل حسب مدينتك.'
                      : 'We show products, delivery prices and times for your city.',
                  style: TextStyle(
                      fontFamily: 'Manrope',
                      fontFamilyFallback: const ['Tajawal'],
                      fontSize: 13,
                      height: 1.5,
                      color: context.col.ink3)),
              const SizedBox(height: 12),
              TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                textInputAction: TextInputAction.search,
                style: TextStyle(
                    fontFamily: 'Manrope',
                    fontFamilyFallback: const ['Tajawal'],
                    fontSize: 14,
                    color: context.col.ink0),
                cursorColor: AppColors.primary,
                decoration: InputDecoration(
                  hintText: isAr ? 'ابحث عن مدينتك' : 'Search for your city',
                  hintStyle: TextStyle(
                      fontFamily: 'Manrope',
                      fontFamilyFallback: const ['Tajawal'],
                      fontSize: 14,
                      color: context.col.ink3),
                  prefixIcon: Icon(Icons.search_rounded, size: 20, color: context.col.ink3),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () => setState(() {
                            _searchCtrl.clear();
                            _query = '';
                          }),
                          icon: Icon(Icons.close_rounded, size: 18, color: context.col.ink3),
                        ),
                  // Clear background, outline only.
                  filled: false,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: context.col.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                ),
              ),
            ]),
          ),
          Divider(height: 1, color: context.col.border),

          // City list
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5))
                : failed
                    ? _Message(
                        icon: Icons.wifi_off_rounded,
                        text: isAr ? 'تعذر تحميل المدن' : "Couldn't load the cities",
                        action: isAr ? 'إعادة المحاولة' : 'Retry',
                        onAction: () => ref.invalidate(shippingRatesProvider),
                      )
                    : cities.isEmpty
                        ? _Message(
                            icon: Icons.location_off_outlined,
                            text: isAr
                                ? 'لا توجد مدينة بهذا الاسم'
                                : 'No city matches your search',
                          )
                        : ListView.separated(
                            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: EdgeInsets.only(
                                bottom: MediaQuery.paddingOf(context).bottom + 16),
                            itemCount: cities.length,
                            separatorBuilder: (_, __) => Divider(
                                height: 1, indent: 52, endIndent: 16, color: context.col.border),
                            itemBuilder: (_, i) => _CityRow(
                              name: isAr ? cities[i].ar : cities[i].en,
                              selected: isCurrent(cities[i]),
                              onTap: () => _pick(cities[i]),
                            ),
                          ),
          ),
        ]),
      ),
    );
  }
}

class _CityRow extends StatelessWidget {
  final String name;
  final bool selected;
  final VoidCallback onTap;
  const _CityRow({required this.name, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(children: [
          Icon(selected ? Icons.location_on_rounded : Icons.location_on_outlined,
              size: 22, color: selected ? AppColors.adaptive(context) : context.col.ink3),
          const SizedBox(width: 14),
          Expanded(
            child: Text(name,
                style: TextStyle(
                    fontFamily: 'Manrope',
                    fontFamilyFallback: const ['Tajawal'],
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: context.col.ink0)),
          ),
          if (selected)
            Icon(Icons.check_rounded, size: 22, color: AppColors.adaptive(context)),
        ]),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onAction;
  const _Message({required this.icon, required this.text, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 44, color: context.col.ink4),
          const SizedBox(height: 10),
          Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Manrope',
                  fontFamilyFallback: const ['Tajawal'],
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.col.ink2)),
          if (action != null) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh_rounded, size: 18, color: AppColors.primary),
              label: Text(action!,
                  style: TextStyle(
                      fontFamily: 'Manrope',
                      fontFamilyFallback: const ['Tajawal'],
                      fontWeight: FontWeight.w700,
                      color: context.col.ink0)),
            ),
          ],
        ]),
      ),
    );
  }
}
