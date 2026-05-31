import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/address_provider.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/theme/app_theme.dart';

// ── Cities ─────────────────────────────────────────────────────────────────────
const _citiesMain = [
  'طرابلس', 'بنغازي', 'مصراتة', 'الزاوية', 'سبها', 'الخمس', 'زوارة',
];
const _citiesMore = [
  'البيضاء', 'درنة', 'طبرق', 'سرت', 'أجدابيا', 'غريان', 'صبراتة', 'زليتن',
  'جنزور', 'تاجوراء', 'عين زارة', 'سوق الجمعة', 'أبو سليم', 'صلاح الدين',
  'السياحية', 'الأبيار', 'أوباري', 'الجغبوب', 'الزنتان', 'ترهونة',
  'بني وليد', 'صرمان', 'مرزق', 'غدامس', 'الكفرة', 'قصر بن غشير',
];

// ── Colors ──────────────────────────────────────────────────────────────────────
const _navy     = Color(0xFF0E3C46);
const _teal     = AppColors.primary; // #32DDE5
const _cityBase = Color(0xFF38D1E2);

class CityScreen extends ConsumerStatefulWidget {
  const CityScreen({super.key});
  @override
  ConsumerState<CityScreen> createState() => _CityScreenState();
}

class _CityScreenState extends ConsumerState<CityScreen>
    with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  String _query    = '';
  String _selected = 'طرابلس';
  bool _showAll    = false;

  // Entry animation
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
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  List<String> get _filtered {
    final q = _query.trim();
    final list = _showAll ? [..._citiesMain, ..._citiesMore] : _citiesMain;
    if (q.isEmpty) return list;
    return list.where((c) => c.contains(q)).toList();
  }

  Future<void> _proceed() async {
    await ref.read(cityProvider.notifier).setCity(_selected);
    if (mounted) context.go('/onboarding');
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final top    = MediaQuery.of(context).padding.top;
    final isAr   = ref.watch(localeProvider).languageCode == 'ar';

    return Scaffold(
      backgroundColor: _cityBase,
      body: Stack(children: [
        // Background gradient
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.86),
              radius: 1.48,
              colors: [Color(0xFF52D9E8), _cityBase],
              stops: [0.0, 0.40],
            ),
          ),
        ),

        // Scrollable content
        SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(22, top + 72, 22, 160 + bottom),
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
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 34,
                    fontWeight: FontWeight.w900, color: Colors.white,
                    shadows: [Shadow(color: Color(0x2E0E3C46), blurRadius: 14, offset: Offset(0, 3))])),
                const SizedBox(height: 10),
                Text(isAr
                    ? 'لنتمكن من عرض المنتجات والعروض المناسبة لك'
                    : 'To show you relevant products and offers',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 15,
                    fontWeight: FontWeight.w700, color: _navy, height: 1.5)),
                const SizedBox(height: 20),

                // Search bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(
                      color: Colors.black.withValues(alpha: 0.07),
                      blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Row(children: [
                    const SizedBox(width: 16),
                    const Icon(Icons.search_rounded, size: 22, color: Color(0xFF0D6B75)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl,
                        onChanged: (v) => setState(() => _query = v),
                        style: const TextStyle(fontFamily: 'Cairo',
                          fontSize: 16, fontWeight: FontWeight.w700, color: _navy),
                        decoration: InputDecoration(
                          hintText: isAr ? 'ابحث عن مدينتك' : 'Search cities',
                          hintStyle: const TextStyle(fontFamily: 'Cairo',
                            color: Color(0xFF2A6E78), fontSize: 15, fontWeight: FontWeight.w600),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ]),
                ),
                const SizedBox(height: 14),

                // City list card
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(children: [
                    ..._filtered.map((city) => _CityRow(
                      city: city,
                      selected: _selected == city,
                      teal: _teal,
                      onTap: () => setState(() => _selected = city),
                    )),
                    if (_filtered.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Text('—', textAlign: TextAlign.center,
                          style: TextStyle(color: _navy, fontWeight: FontWeight.w700)),
                      ),

                    // Show more / less
                    GestureDetector(
                      onTap: () => setState(() => _showAll = !_showAll),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 2),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text(_showAll
                              ? (isAr ? 'عرض أقل' : 'Show less')
                              : (isAr ? 'عرض كل المدن' : 'Show all cities'),
                            style: const TextStyle(fontFamily: 'Cairo',
                              color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                          const SizedBox(width: 6),
                          AnimatedRotation(
                            turns: _showAll ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: const Icon(Icons.keyboard_arrow_down_rounded,
                              color: Colors.white, size: 20)),
                        ]),
                      ),
                    ),
                  ]),
                ),

                const SizedBox(height: 10),

                // 3D map pin (floating)
                _FloatingMapPin(),
              ],
            ),
          ),
        ),

        // Language pill (top-right)
        Positioned(
          top: top + 12, right: 20,
          child: GestureDetector(
            onTap: () => ref.read(localeProvider.notifier).toggle(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.language_rounded, size: 18, color: _teal),
                const SizedBox(width: 6),
                Text(isAr ? 'English' : 'العربية',
                  style: const TextStyle(fontFamily: 'Cairo',
                    fontSize: 15, fontWeight: FontWeight.w800, color: _navy)),
              ]),
            ),
          ),
        ),

        // Pagination dots
        Positioned(
          bottom: 88 + bottom, left: 0, right: 0,
          child: _OnboardingDots(count: 3, active: 1),
        ),

        // Bottom action bar
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: _BottomBar(
            label: isAr ? 'التالي' : 'Next',
            onTap: _proceed,
            isAr: isAr,
          ),
        ),
      ]),
    );
  }
}

// ── City row ───────────────────────────────────────────────────────────────────
class _CityRow extends StatelessWidget {
  final String city;
  final bool selected;
  final Color teal;
  final VoidCallback onTap;
  const _CityRow({required this.city, required this.selected,
    required this.teal, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withValues(alpha: 0.32),
          border: Border.all(
            color: selected ? teal : Colors.white.withValues(alpha: 0.55),
            width: selected ? 2 : 1.5),
          borderRadius: BorderRadius.circular(16),
          boxShadow: selected
              ? [const BoxShadow(color: Color(0x280E3C46), blurRadius: 20, offset: Offset(0, 8))]
              : [],
        ),
        child: Row(children: [
          // Radio dot
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 26, height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? teal : Colors.transparent,
              border: selected ? null
                  : Border.all(color: const Color(0x590E3C46), width: 2),
            ),
            child: selected
                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(city, textAlign: TextAlign.right,
              style: TextStyle(fontFamily: 'Cairo', fontSize: 18,
                fontWeight: FontWeight.w700,
                color: selected ? _navy : const Color(0xFF13474F))),
          ),
          const SizedBox(width: 8),
          Icon(Icons.location_on_outlined, size: 20,
            color: selected ? teal : const Color(0xFF3A8E98)),
        ]),
      ),
    );
  }
}

// ── Floating map pin ────────────────────────────────────────────────────────────
class _FloatingMapPin extends StatefulWidget {
  @override
  State<_FloatingMapPin> createState() => _FloatingMapPinState();
}
class _FloatingMapPinState extends State<_FloatingMapPin>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _y;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 5000))
      ..repeat(reverse: true);
    _y = Tween<double>(begin: 0, end: -9).animate(
        CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _y,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, _y.value), child: child),
      child: ShaderMask(
        shaderCallback: (r) => const RadialGradient(
          center: Alignment.center, radius: 0.5,
          colors: [Colors.black, Colors.transparent],
        ).createShader(r),
        blendMode: BlendMode.dstIn,
        child: Image.asset('assets/images/onb-mappin.png',
          width: MediaQuery.of(context).size.width * 0.82,
          alignment: Alignment.center),
      ),
    );
  }
}

// ── Pagination dots ─────────────────────────────────────────────────────────────
class _OnboardingDots extends StatelessWidget {
  final int count;
  final int active;
  const _OnboardingDots({required this.count, required this.active});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      for (int i = 0; i < count; i++)
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 8,
          width: i == active ? 26 : 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: i == active
                ? Colors.white
                : Colors.white.withValues(alpha: 0.45),
          ),
        ),
    ]);
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
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(18, 0, 18, 26 + bottom),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            boxShadow: const [BoxShadow(
              color: Color(0x330E3C46), blurRadius: 30, offset: Offset(0, 14))],
          ),
          child: Stack(alignment: Alignment.center, children: [
            Text(label, style: const TextStyle(fontFamily: 'Cairo',
              fontSize: 19, fontWeight: FontWeight.w900, color: _navy)),
            // Simple faint arrow — right side for Arabic (forward = right in RTL)
            Positioned(
              right: 0,
              child: Opacity(
                opacity: 0.45,
                child: Icon(
                  isAr ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_new_rounded,
                  size: 18, color: _teal),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
