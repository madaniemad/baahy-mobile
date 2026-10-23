import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../../core/providers/shipping_provider.dart';
import '../../core/providers/address_provider.dart';
import '../../core/utils/l10n.dart';
import 'onb_theme.dart';

/// The whole onboarding (2026-10-23, Noon/Amazon style): language + delivery city
/// on one screen, then "Start shopping" goes straight to home. The city is
/// auto-detected in the background (GPS → reverse-geocode) and pre-filled; tapping
/// the city row opens the search sheet. Outside Libya / location denied → the row
/// stays empty with a one-line reason, and the button opens the sheet.
class OnbCityPicker extends ConsumerStatefulWidget {
  final VoidCallback onContinue;
  const OnbCityPicker({super.key, required this.onContinue});

  @override
  ConsumerState<OnbCityPicker> createState() => _OnbCityPickerState();
}

// palette for this screen
const _navy = Onb.navy;                    // sheet text
const _ink = Color(0xFF14181A);            // values (city, selected language)
const _muted = Color(0xFF6B7578);          // labels and helper lines
const _teal = Color(0xFF1FD7E2);           // brand tiffany — button and icons only
const _line = Color(0xFFE4E7E7);           // field borders (app border token)
const _tint = Color(0xFFE6FAFB);           // selected language

class _OnbCityPickerState extends ConsumerState<OnbCityPicker> {
  bool _detecting = true;
  bool _denied = false;
  bool _inService = true;
  bool _manual = false;                    // picked from the sheet, not detected
  String _cityAr = '';

  bool _sheet = false;
  bool _showAll = false;
  String _q = '';
  final _searchCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _detect(); });
  }

  @override
  void dispose() { _searchCtl.dispose(); super.dispose(); }

  List<({String ar, String en})> _cities() {
    final rates = ref.watch(shippingRatesProvider).valueOrNull ?? [];
    if (rates.isNotEmpty) return rates.map((r) => (ar: r.cityAr, en: r.city)).toList();
    return kLibyaCities.map((c) => (ar: c.ar, en: c.en)).toList();
  }

  Future<void> _detect() async {
    setState(() { _detecting = true; _denied = false; });
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (!mounted) return;
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (!_manual) setState(() { _detecting = false; _denied = true; });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 12));
      await _reverseGeocode(pos.latitude, pos.longitude);
    } catch (_) {
      if (mounted && !_manual) setState(() { _detecting = false; _denied = true; });
    }
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse'
          '?format=json&lat=$lat&lon=$lng&accept-language=ar&zoom=12');
      final res = await http.get(url, headers: {'User-Agent': 'baahy-app/1.0'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final addr = data['address'] as Map<String, dynamic>? ?? {};
        final cc = (addr['country_code'] as String?)?.toLowerCase() ?? '';
        final inLibya = cc.isEmpty || cc == 'ly';
        if (mounted && !_manual) setState(() {
          _inService = inLibya;
          _cityAr = inLibya ? _serviceable(_matchCity(addr, lat, lng)) : '';
          _detecting = false;
        });
      } else {
        if (mounted && !_manual) setState(() { _inService = true; _cityAr = _serviceable(_nearestCity(lat, lng)); _detecting = false; });
      }
    } catch (_) {
      if (mounted && !_manual) setState(() { _inService = true; _cityAr = _serviceable(_nearestCity(lat, lng)); _detecting = false; });
    }
  }

  String _matchCity(Map<String, dynamic> addr, double lat, double lng) {
    final cands = [addr['city'], addr['town'], addr['village'], addr['county'], addr['state_district'], addr['state']].whereType<String>();
    for (final raw in cands) {
      for (final c in kLibyaCities) {
        if (raw.contains(c.ar) || c.ar.contains(raw)) return c.ar;
      }
    }
    return _nearestCity(lat, lng);
  }

  String _nearestCity(double lat, double lng) {
    double min = double.infinity;
    String best = kLibyaCities.first.ar;
    for (final c in kLibyaCities) {
      final d = (lat - c.lat) * (lat - c.lat) + (lng - c.lng) * (lng - c.lng);
      if (d < min) { min = d; best = c.ar; }
    }
    return best;
  }

  String _serviceable(String detected) {
    for (final c in _cities()) {
      if (c.ar == detected || detected.contains(c.ar) || c.ar.contains(detected)) return c.ar;
    }
    return detected;
  }

  // No city yet (still detecting, denied, outside Libya) → the button opens the
  // sheet instead of sitting disabled.
  void _start() {
    if (_cityAr.isEmpty) { _openSheet(); return; }
    ref.read(cityProvider.notifier).setCity(_cityAr);
    widget.onContinue();
  }

  void _openSheet() {
    FocusScope.of(context).unfocus();
    setState(() => _sheet = true);
  }

  // Picking fills the row and closes the sheet; the user still taps Start shopping,
  // so they can switch language after choosing.
  void _pickManual(({String ar, String en}) c) {
    FocusScope.of(context).unfocus();
    setState(() {
      _manual = true; _cityAr = c.ar; _detecting = false; _denied = false; _inService = true;
      _sheet = false; _q = ''; _searchCtl.clear();
    });
  }

  Future<void> _enableLocation() async {
    await Geolocator.openAppSettings();
    if (mounted) _detect();
  }

  @override
  Widget build(BuildContext context) {
    final isAr = ref.watch(localeProvider).languageCode == 'ar';
    final t = _CityStr(isAr);
    final cityLabel = _cityAr.isNotEmpty ? (isAr ? _cityAr : _cityEn(_cityAr)) : '';
    final botPad = MediaQuery.of(context).padding.bottom;

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: ColoredBox(
        color: Colors.white,
        child: Stack(children: [
          SafeArea(bottom: false, child: Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, botPad + 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // Controls sit low, just above the button, with the empty space on top
              // (Emad, 2026-10-23). Still scrolls on short screens.
              Expanded(child: LayoutBuilder(builder: (context, box) => SingleChildScrollView(child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // No logo (Emad, 2026-10-23): the splash just showed it.
                const SizedBox(height: 24),

                _Label(t.language),
                const SizedBox(height: 12),
                _LangSegment(isAr: isAr, onSelect: (ar) { if (ar != isAr) ref.read(localeProvider.notifier).toggle(); }),
                const SizedBox(height: 40),

                _Label(t.deliverTo),
                const SizedBox(height: 12),
                _CityRow(city: cityLabel, placeholder: t.choose, action: cityLabel.isEmpty ? null : t.change, onTap: _openSheet),
                const SizedBox(height: 12),
                // Fixed height: the note changes as detection runs, and with the column
                // bottom-aligned a growing note would push everything above it up.
                SizedBox(height: 44, child: Align(alignment: AlignmentDirectional.topStart, child: _Helper(
                  t: t, detecting: _detecting, manual: _manual, hasCity: _cityAr.isNotEmpty,
                  denied: _denied, inService: _inService, onEnable: _enableLocation,
                ))),
                const SizedBox(height: 16),
              ]))))),
              _Cta(label: t.start, onTap: _start),
            ]),
          )),

          // ── city sheet ──
          if (_sheet) Positioned.fill(child: GestureDetector(onTap: () => setState(() => _sheet = false), child: Container(color: const Color(0x33000000)))),
          AnimatedSlide(
            duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic,
            offset: _sheet ? Offset.zero : const Offset(0, 1.25),
            child: Align(alignment: Alignment.bottomCenter, child: _ManualSheet(
              t: t, isAr: isAr, query: _q, controller: _searchCtl, cities: _cities(), showAll: _showAll,
              onClose: () => setState(() => _sheet = false), onQuery: (v) => setState(() => _q = v),
              onPick: _pickManual, onToggleAll: () => setState(() => _showAll = !_showAll))),
          ),
        ]),
      ),
    );
  }

  String _cityEn(String ar) {
    for (final c in kLibyaCities) { if (c.ar == ar) return c.en; }
    for (final c in _cities()) { if (c.ar == ar) return c.en; }
    return ar;
  }
}

const _labelStyle = TextStyle(fontFamily: Onb.font, fontFamilyFallback: Onb.fontFallback, fontSize: 15, fontWeight: FontWeight.w500, color: _muted);

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: _labelStyle);
}

// ============================================================ language segment
class _LangSegment extends StatelessWidget {
  final bool isAr; final ValueChanged<bool> onSelect;
  const _LangSegment({required this.isAr, required this.onSelect});
  @override
  Widget build(BuildContext context) {
    Widget option(String s, bool selected, VoidCallback onTap) => Expanded(child: GestureDetector(
      onTap: onTap, behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.all(4),
        alignment: Alignment.center,
        // Fade to a clear tint, not Colors.transparent (clear BLACK): lerping to that
        // flashes grey mid-animation.
        decoration: BoxDecoration(color: selected ? _tint : _tint.withValues(alpha: 0), borderRadius: BorderRadius.circular(10)),
        child: Text(s, style: TextStyle(fontFamily: Onb.font, fontFamilyFallback: Onb.fontFallback, fontSize: 17.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? _ink : _muted)),
      ),
    ));
    // Arabic first in reading order either way: the row follows the screen direction.
    return Container(
      height: 64,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: _line)),
      child: Row(children: [
        option('العربية', isAr, () => onSelect(true)),
        option('English', !isAr, () => onSelect(false)),
      ]),
    );
  }
}

// ============================================================ city row
class _CityRow extends StatelessWidget {
  final String city, placeholder;
  final String? action;
  final VoidCallback onTap;
  const _CityRow({required this.city, required this.placeholder, required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap, behavior: HitTestBehavior.opaque,
    child: Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: _line)),
      child: Row(children: [
        const Icon(Icons.location_on_outlined, color: _teal, size: 26),
        const SizedBox(width: 12),
        Expanded(child: Text(city.isEmpty ? placeholder : city, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontFamily: Onb.font, fontFamilyFallback: Onb.fontFallback, fontSize: 18,
              fontWeight: city.isEmpty ? FontWeight.w500 : FontWeight.w700, color: city.isEmpty ? _muted : _ink))),
        if (action != null)
          // Grey, not tiffany (Emad, 2026-10-23): the link is secondary to the city.
          Text(action!, style: const TextStyle(fontFamily: Onb.font, fontFamilyFallback: Onb.fontFallback, fontSize: 15, fontWeight: FontWeight.w600, color: _muted))
        else
          const Icon(Icons.keyboard_arrow_down_rounded, color: _muted, size: 26),
      ]),
    ),
  );
}

// One quiet line under the city row: what we know about the location.
class _Helper extends StatelessWidget {
  final _CityStr t;
  final bool detecting, manual, hasCity, denied, inService;
  final VoidCallback onEnable;
  const _Helper({required this.t, required this.detecting, required this.manual, required this.hasCity, required this.denied, required this.inService, required this.onEnable});

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontFamily: Onb.font, fontFamilyFallback: Onb.fontFallback, fontSize: 13.5, fontWeight: FontWeight.w500, color: _muted, height: 1.4);
    if (manual) return const SizedBox(height: 18);
    if (detecting) {
      return Row(children: [
        const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.6, color: _muted)),
        const SizedBox(width: 8),
        Text(t.locating, style: style),
      ]);
    }
    if (!inService) return Text(t.outside, style: style);
    if (denied) {
      return Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text('${t.denied} ', style: style),
        GestureDetector(onTap: onEnable, child: Text(t.enableLoc, style: style.copyWith(color: _teal, fontWeight: FontWeight.w600))),
      ]);
    }
    if (hasCity) return Text(t.detected, style: style);
    return const SizedBox(height: 18);
  }
}

// Primary button — flat brand tiffany, no shadow.
class _Cta extends StatelessWidget {
  final String label; final VoidCallback onTap;
  const _Cta({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 56, width: double.infinity, alignment: Alignment.center,
      decoration: BoxDecoration(color: _teal, borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: const TextStyle(fontFamily: Onb.font, fontFamilyFallback: Onb.fontFallback, fontSize: 16.5, fontWeight: FontWeight.w700, color: Colors.white)),
    ),
  );
}

// ============================================================ strings
class _CityStr {
  final bool ar;
  _CityStr(this.ar);
  String get language => ar ? 'اللغة' : 'Language';
  String get deliverTo => ar ? 'التوصيل إلى' : 'Deliver to';
  String get choose => ar ? 'اختر مدينتك' : 'Choose your city';
  String get change => ar ? 'تغيير' : 'Change';
  String get start => ar ? 'ابدأ التسوق' : 'Start shopping';
  String get locating => ar ? 'جاري تحديد موقعك…' : 'Finding your location…';
  String get detected => ar ? 'تم تحديدها من موقعك' : 'Based on your location';
  String get outside => ar ? 'لا نوصّل لموقعك الحالي، اختر مدينتك من القائمة' : "We don't deliver to your current location. Choose your city from the list";
  String get denied => ar ? 'تعذّر تحديد موقعك.' : "Couldn't find your location.";
  String get enableLoc => ar ? 'فعّل الموقع' : 'Turn on location';
  String get sheetTitle => ar ? 'اختر المدينة' : 'Choose city';
  String get search => ar ? 'ابحث عن مدينة' : 'Search for a city';
  String get mainCities => ar ? 'المدن الرئيسية' : 'Main cities';
  String get showAll => ar ? 'عرض جميع المدن' : 'Show all cities';
  String get showLess => ar ? 'عرض أقل' : 'Show less';
  String get noResults => ar ? 'لا توجد نتائج' : 'No results';
}

// ============================================================ manual sheet
class _ManualSheet extends StatelessWidget {
  final _CityStr t; final bool isAr, showAll; final String query;
  final TextEditingController controller;
  final List<({String ar, String en})> cities;
  final VoidCallback onClose, onToggleAll;
  final ValueChanged<String> onQuery;
  final ValueChanged<({String ar, String en})> onPick;
  const _ManualSheet({required this.t, required this.isAr, required this.showAll, required this.query, required this.controller, required this.cities, required this.onClose, required this.onToggleAll, required this.onQuery, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final base = showAll ? cities : cities.take(6).toList();
    final q = query.trim().toLowerCase();
    final filtered = base.where((c) => c.ar.contains(query.trim()) || c.en.toLowerCase().contains(q)).toList();
    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.62),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + MediaQuery.of(context).padding.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 44, height: 5, margin: const EdgeInsets.only(bottom: 14), decoration: BoxDecoration(color: const Color(0xFFE1E5E7), borderRadius: BorderRadius.circular(3))),
          Row(children: [
            GestureDetector(onTap: onClose, child: const SizedBox(width: 28, height: 28, child: Icon(Icons.close, color: _navy, size: 21))),
            Expanded(child: Text(t.sheetTitle, textAlign: TextAlign.center, style: const TextStyle(fontFamily: Onb.font, fontFamilyFallback: Onb.fontFallback, fontSize: 18, fontWeight: FontWeight.w800, color: _navy))),
            const SizedBox(width: 28),
          ]),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: Onb.fieldBg, borderRadius: BorderRadius.circular(13)),
            child: Row(children: [
              const Icon(Icons.search, color: Color(0xFF9AA39F), size: 19),
              const SizedBox(width: 10),
              Expanded(child: TextField(
                controller: controller, onChanged: onQuery, cursorColor: _teal,
                style: const TextStyle(fontFamily: Onb.font, fontFamilyFallback: Onb.fontFallback, fontSize: 15, fontWeight: FontWeight.w500, color: _navy),
                decoration: InputDecoration(
                  filled: false, fillColor: Colors.transparent,
                  border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
                  isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 13),
                  hintText: t.search, hintStyle: const TextStyle(fontFamily: Onb.font, fontFamilyFallback: Onb.fontFallback, fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF9AA39F)),
                ),
              )),
            ]),
          ),
          Align(alignment: AlignmentDirectional.centerStart, child: Padding(
            padding: const EdgeInsets.fromLTRB(2, 14, 2, 4),
            child: Text(t.mainCities, style: const TextStyle(fontFamily: Onb.font, fontFamilyFallback: Onb.fontFallback, fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF9AA39F))))),
          Flexible(child: filtered.isEmpty
              ? Padding(padding: const EdgeInsets.symmetric(vertical: 22), child: Text(t.noResults, style: const TextStyle(fontFamily: Onb.font, fontFamilyFallback: Onb.fontFallback, fontWeight: FontWeight.w700, color: Color(0xFF9AA39F))))
              : ListView.builder(shrinkWrap: true, itemCount: filtered.length, padding: EdgeInsets.zero, itemBuilder: (_, i) {
                  final c = filtered[i];
                  return GestureDetector(onTap: () => onPick(c), behavior: HitTestBehavior.opaque, child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 2),
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Onb.hairline2))),
                    child: Row(children: [
                      const Icon(Icons.location_on, color: _teal, size: 19),
                      const SizedBox(width: 12),
                      Expanded(child: Text(isAr ? c.ar : c.en, style: const TextStyle(fontFamily: Onb.font, fontFamilyFallback: Onb.fontFallback, fontSize: 16, fontWeight: FontWeight.w700, color: _navy))),
                    ]),
                  ));
                })),
          if (query.trim().isEmpty) GestureDetector(onTap: onToggleAll, child: Padding(
            padding: const EdgeInsets.fromLTRB(2, 14, 2, 2),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(showAll ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: _teal, size: 20),
              const SizedBox(width: 8),
              Text(showAll ? t.showLess : t.showAll, style: const TextStyle(fontFamily: Onb.font, fontFamilyFallback: Onb.fontFallback, fontSize: 14.5, fontWeight: FontWeight.w700, color: _teal)),
            ]))),
        ]),
      ),
    );
  }
}
