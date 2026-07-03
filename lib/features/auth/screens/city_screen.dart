import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers/address_provider.dart';
import '../../../core/providers/app_pages_provider.dart';
import '../../../core/providers/shipping_provider.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/theme/app_theme.dart';

// ── Colors ──────────────────────────────────────────────────────────────────────
const _navy     = Color(0xFF0E3C46);
const _teal     = AppColors.primary; // #1FD7E2
const _cityBase = Color(0xFF38D1E2);

class CityScreen extends ConsumerStatefulWidget {
  const CityScreen({super.key});
  @override
  ConsumerState<CityScreen> createState() => _CityScreenState();
}

class _CityScreenState extends ConsumerState<CityScreen>
    with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  String _query      = '';
  String _selected   = 'طرابلس';
  bool _isReturning  = false;

  late AnimationController _entryCtrl;
  late Animation<double> _slideY;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 600))
      ..forward();
    _fade   = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideY = Tween<double>(begin: 14, end: 0).animate(
        CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _checkReturning();
  }

  Future<void> _checkReturning() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _isReturning = prefs.getBool('onboarding_v2_done') ?? false;
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  List<CityEntry> _filterCities(List<CityEntry> all) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((c) =>
      c.ar.contains(q) || c.en.toLowerCase().contains(q)).toList();
  }

  Future<void> _proceed() async {
    await ref.read(cityProvider.notifier).setCity(_selected);
    if (!mounted) return;
    context.go(_isReturning ? '/home' : '/rewards-intro');
  }

  @override
  Widget build(BuildContext context) {
    final isAr      = ref.watch(localeProvider).languageCode == 'ar';
    final ratesAsync = ref.watch(shippingRatesProvider);
    final loading   = ratesAsync.isLoading;
    final rates     = ratesAsync.valueOrNull ?? const [];
    final allCities = rates.map((r) => CityEntry(ar: r.cityAr, en: r.city)).toList();
    final filtered  = _filterCities(allCities);

    return Scaffold(
      backgroundColor: _cityBase,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.86),
            radius: 1.48,
            colors: [Color(0xFF52D9E8), _cityBase],
            stops: [0.0, 0.40],
          ),
        ),
        child: SafeArea(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.translucent,
            child: Column(
              children: [
                // Language pill
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: () => ref.read(localeProvider.notifier).toggle(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 16, offset: const Offset(0, 6))],
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.language_rounded, size: 16, color: _teal),
                            const SizedBox(width: 6),
                            Text(isAr ? 'English' : 'العربية',
                              style: const TextStyle(fontFamily: 'Cairo',
                                fontSize: 13, fontWeight: FontWeight.w800, color: _navy)),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),

                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                    physics: const BouncingScrollPhysics(),
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_slideY, _fade]),
                      builder: (_, child) => Opacity(
                        opacity: _fade.value,
                        child: Transform.translate(
                          offset: Offset(0, _slideY.value), child: child)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Heading
                          Text(isAr ? 'اختار مدينتك' : 'Choose Your City',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontFamily: 'Cairo', fontSize: 26,
                              fontWeight: FontWeight.w900, color: Colors.white,
                              shadows: [Shadow(color: Color(0x2E0E3C46), blurRadius: 14, offset: Offset(0, 3))])),
                          const SizedBox(height: 5),
                          Text(isAr
                              ? 'لنتمكن من عرض المنتجات والعروض المناسبة لك'
                              : 'To show you relevant products and offers',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontFamily: 'Cairo', fontSize: 13,
                              fontWeight: FontWeight.w700, color: _navy, height: 1.4)),
                          const SizedBox(height: 12),

                          // Search bar
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [BoxShadow(
                                color: Colors.black.withValues(alpha: 0.07),
                                blurRadius: 12, offset: const Offset(0, 4))],
                            ),
                            child: Row(children: [
                              const SizedBox(width: 14),
                              const Icon(Icons.search_rounded, size: 20, color: Color(0xFF0D6B75)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _searchCtrl,
                                  autofocus: false,
                                  textAlign: isAr ? TextAlign.right : TextAlign.left,
                                  textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                                  onChanged: (v) => setState(() => _query = v),
                                  style: const TextStyle(fontFamily: 'Cairo',
                                    fontSize: 13.5, fontWeight: FontWeight.w600, color: _navy),
                                  decoration: InputDecoration(
                                    hintText: isAr ? 'ابحث عن مدينتك' : 'Search cities',
                                    hintStyle: const TextStyle(fontFamily: 'Cairo',
                                      color: Color(0xFF2A6E78), fontSize: 13.5, fontWeight: FontWeight.w500),
                                    border: InputBorder.none,
                                    filled: true,
                                    fillColor: Colors.transparent,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 9),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                            ]),
                          ),
                          const SizedBox(height: 10),

                          // City list
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.20),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.all(6),
                            child: loading
                                ? const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 32),
                                    child: Center(child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2.5)),
                                  )
                                : Column(children: [
                                    ...filtered.map((city) => _CityRow(
                                      cityAr: city.ar,
                                      cityEn: city.en,
                                      selected: _selected == city.ar,
                                      isAr: isAr,
                                      teal: _teal,
                                      onTap: () => setState(() => _selected = city.ar),
                                    )),
                                    if (filtered.isEmpty)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        child: Text(isAr ? 'لا توجد نتائج' : 'No results',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(color: _navy, fontWeight: FontWeight.w700)),
                                      ),
                                  ]),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom action bar — always visible, never overlaps list
                _BottomBar(
                  label: _isReturning
                      ? (isAr ? 'تأكيد' : 'Confirm')
                      : (isAr ? 'التالي' : 'Next'),
                  onTap: _proceed,
                  isAr: isAr,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── City row ───────────────────────────────────────────────────────────────────
class _CityRow extends StatelessWidget {
  final String cityAr;
  final String cityEn;
  final bool selected;
  final bool isAr;
  final Color teal;
  final VoidCallback onTap;
  const _CityRow({required this.cityAr, required this.cityEn,
    required this.selected, required this.isAr,
    required this.teal, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withValues(alpha: 0.35),
          border: Border.all(
            color: selected ? teal : Colors.white.withValues(alpha: 0.35),
            width: selected ? 2 : 1.5),
          borderRadius: BorderRadius.circular(11),
          boxShadow: selected
              ? [const BoxShadow(color: Color(0x280E3C46), blurRadius: 20, offset: Offset(0, 8))]
              : [],
        ),
        child: Row(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 18, height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? teal : Colors.transparent,
              border: selected ? null
                  : Border.all(color: const Color(0x590E3C46), width: 2),
            ),
            child: selected
                ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(isAr ? cityAr : cityEn,
              textAlign: isAr ? TextAlign.right : TextAlign.left,
              style: TextStyle(fontFamily: 'Cairo', fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: selected ? _navy : const Color(0xFF13474F))),
          ),
          const SizedBox(width: 8),
          Icon(Icons.location_on_outlined, size: 17,
            color: selected ? teal : const Color(0xFF3A8E98)),
        ]),
      ),
    );
  }
}

// ── Bottom action bar ───────────────────────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isAr;
  const _BottomBar({required this.label, required this.onTap, required this.isAr});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            boxShadow: const [BoxShadow(
              color: Color(0x330E3C46), blurRadius: 30, offset: Offset(0, 14))],
          ),
          child: Stack(alignment: Alignment.center, children: [
            Text(label, style: const TextStyle(fontFamily: 'Cairo',
              fontSize: 15, fontWeight: FontWeight.w900, color: _navy)),
            Positioned(
              right: 0,
              child: Opacity(
                opacity: 0.45,
                child: Icon(
                  isAr ? Icons.arrow_forward_ios : Icons.arrow_back_ios_new_rounded,
                  size: 16, color: _teal),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
