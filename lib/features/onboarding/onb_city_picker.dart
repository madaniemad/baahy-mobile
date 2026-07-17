import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../../core/providers/shipping_provider.dart';
import '../../core/providers/address_provider.dart';
import '../../core/utils/l10n.dart';
import 'onb_theme.dart';

/// Screen 01 — language + city. No map: the city is auto-detected in the
/// background (GPS → reverse-geocode) and shown for the user to confirm, or they
/// pick manually. Outside Libya → a message asks them to choose manually.
class OnbCityPicker extends ConsumerStatefulWidget {
  final VoidCallback onContinue;
  const OnbCityPicker({super.key, required this.onContinue});

  @override
  ConsumerState<OnbCityPicker> createState() => _OnbCityPickerState();
}

// palette for this screen
const _navy = Onb.navy;                    // card text
const _ink = Color(0xFF161719);            // main titles — black
const _muted = Color(0xFF4B4E54);          // secondary text — dark grey
const _teal = Color(0xFF3FD6E4);           // brand tiffany
const _boxBg = Color(0xFFF0F6F7);          // inner tint
const _cardShadow = [BoxShadow(color: Color(0x12023A42), blurRadius: 22, offset: Offset(0, 8))];

class _OnbCityPickerState extends ConsumerState<OnbCityPicker> {
  bool _detecting = true;
  bool _denied = false;
  bool _inService = true;
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
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        setState(() { _detecting = false; _denied = true; });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 12));
      await _reverseGeocode(pos.latitude, pos.longitude);
    } catch (_) {
      if (mounted) setState(() { _detecting = false; _denied = true; });
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
        if (mounted) setState(() {
          _inService = inLibya;
          _cityAr = inLibya ? _serviceable(_matchCity(addr, lat, lng)) : '';
          _detecting = false;
        });
      } else {
        if (mounted) setState(() { _inService = true; _cityAr = _serviceable(_nearestCity(lat, lng)); _detecting = false; });
      }
    } catch (_) {
      if (mounted) setState(() { _inService = true; _cityAr = _serviceable(_nearestCity(lat, lng)); _detecting = false; });
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

  void _confirm() {
    if (_cityAr.isEmpty) return;
    ref.read(cityProvider.notifier).setCity(_cityAr);
    widget.onContinue();
  }

  void _pickManual(({String ar, String en}) c) {
    ref.read(cityProvider.notifier).setCity(c.ar);
    setState(() { _sheet = false; _q = ''; _searchCtl.clear(); });
    widget.onContinue();
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

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Colors.white),
        child: Stack(children: [
          SafeArea(child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(30, 20, 30, 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // ── language ──
              Text(t.langTitle, textAlign: TextAlign.center, style: const TextStyle(fontFamily: Onb.font, fontFamilyFallback: Onb.fontFallback, fontSize: 15, fontWeight: FontWeight.w800, color: _ink)),
              const SizedBox(height: 3),
              Text(t.langSub, textAlign: TextAlign.center, style: const TextStyle(fontFamily: Onb.font, fontFamilyFallback: Onb.fontFallback, fontSize: 11.5, fontWeight: FontWeight.w600, color: _muted)),
              const SizedBox(height: 14),
              FractionallySizedBox(widthFactor: 0.72, child: _LangSegment(isAr: isAr, onSelect: (ar) { if (ar != isAr) ref.read(localeProvider.notifier).toggle(); })),
              const SizedBox(height: 52),

              // ── city ──
              Text(t.title, textAlign: TextAlign.center, style: const TextStyle(fontFamily: Onb.font, fontFamilyFallback: Onb.fontFallback, fontSize: 24, fontWeight: FontWeight.w800, color: _navy)),
              const SizedBox(height: 8),
              Text(t.sub, textAlign: TextAlign.center, style: const TextStyle(fontFamily: Onb.font, fontFamilyFallback: Onb.fontFallback, fontSize: 12.5, fontWeight: FontWeight.w500, color: _muted, height: 1.45)),
              const SizedBox(height: 26),

              if (_detecting) ...[ _DetectingRow(t: t), const SizedBox(height: 12) ],

              _CityCard(
                t: t, city: cityLabel, detecting: _detecting, denied: _denied, inService: _inService,
                onConfirm: _confirm, onManual: () => setState(() => _sheet = true), onEnable: _enableLocation,
              ),
              const SizedBox(height: 20),
              _OrDivider(t: t),
              const SizedBox(height: 14),
              _ManualButton(label: t.manual, onTap: () => setState(() => _sheet = true)),
            ]),
          )),

          // ── manual sheet ──
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

// ============================================================ language segment
class _LangSegment extends StatelessWidget {
  final bool isAr; final ValueChanged<bool> onSelect;
  const _LangSegment({required this.isAr, required this.onSelect});
  @override
  Widget build(BuildContext context) {
    Widget label(String s, bool selected, VoidCallback onTap) => Expanded(child: GestureDetector(
      onTap: onTap, behavior: HitTestBehavior.opaque,
      child: Center(child: Text(s, style: TextStyle(fontFamily: Onb.font, fontFamilyFallback: Onb.fontFallback, fontSize: 13,
          fontWeight: FontWeight.w800, color: selected ? Colors.white : _teal))),
    ));
    return SizedBox(height: 42, child: Stack(children: [
      // teal outline track
      Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _teal.withValues(alpha: 0.55), width: 1.5),
      ))),
      // selected teal pill (inset so the outline track shows around it)
      AnimatedAlign(
        duration: const Duration(milliseconds: 200), curve: Curves.easeOut,
        alignment: isAr ? Alignment.centerLeft : Alignment.centerRight,
        child: FractionallySizedBox(widthFactor: 0.53, heightFactor: 1.0,
          child: Container(margin: const EdgeInsets.all(3.5), decoration: BoxDecoration(
            color: _teal, borderRadius: BorderRadius.circular(999),
            boxShadow: [BoxShadow(color: _teal.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3))],
          ))),
      ),
      // labels
      Directionality(textDirection: TextDirection.ltr, child: Row(children: [
        label('العربية', isAr, () => onSelect(true)),
        label('English', !isAr, () => onSelect(false)),
      ])),
    ]));
  }
}

class _DetectingRow extends StatelessWidget {
  final _CityStr t;
  const _DetectingRow({required this.t});
  @override
  Widget build(BuildContext context) => Column(children: [
    Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
      const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: _navy)),
      const SizedBox(width: 9),
      Text(t.locating, style: const TextStyle(fontFamily: Onb.font, fontFamilyFallback: Onb.fontFallback, fontSize: 13, fontWeight: FontWeight.w700, color: _navy)),
    ]),
    const SizedBox(height: 3),
    Text(t.locatingSub, style: const TextStyle(fontFamily: Onb.font, fontFamilyFallback: Onb.fontFallback, fontSize: 11.5, fontWeight: FontWeight.w500, color: _muted)),
  ]);
}

// ============================================================ city card
class _CityCard extends StatelessWidget {
  final _CityStr t; final String city;
  final bool detecting, denied, inService;
  final VoidCallback onConfirm, onManual, onEnable;
  const _CityCard({required this.t, required this.city, required this.detecting, required this.denied, required this.inService, required this.onConfirm, required this.onManual, required this.onEnable});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFEDF1F2)), boxShadow: _cardShadow),
    padding: const EdgeInsets.fromLTRB(15, 18, 15, 18),
    child: _inner(),
  );

  Widget _inner() {
    if (!detecting && (denied || !inService)) {
      final title = !inService ? t.outTitle : t.deniedTitle;
      final sub = !inService ? t.outSub : t.deniedSub;
      return Column(children: [
        Container(width: 44, height: 44, decoration: const BoxDecoration(color: Color(0xFFFDECEC), shape: BoxShape.circle),
            child: const Icon(Icons.location_off_rounded, color: Onb.couponRed, size: 22)),
        const SizedBox(height: 10),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(fontFamily: Onb.font, fontFamilyFallback: Onb.fontFallback, fontSize: 15, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 4),
        Text(sub, textAlign: TextAlign.center, style: const TextStyle(fontFamily: Onb.font, fontFamilyFallback: Onb.fontFallback, fontSize: 12, fontWeight: FontWeight.w500, color: _muted, height: 1.4)),
        const SizedBox(height: 14),
        _Cta(label: t.chooseCity, onTap: onManual),
        if (denied) ...[
          const SizedBox(height: 9),
          GestureDetector(onTap: onEnable, child: Text(t.enableLoc, style: const TextStyle(fontFamily: Onb.font, fontFamilyFallback: Onb.fontFallback, fontSize: 13, fontWeight: FontWeight.w700, color: _teal))),
        ],
      ]);
    }

    final ready = !detecting && city.isNotEmpty;
    return Column(children: [
      Container(width: 36, height: 36, decoration: const BoxDecoration(color: Onb.iconTile, shape: BoxShape.circle),
          child: ready
            ? const Icon(Icons.check_rounded, color: _teal, size: 20)
            : const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2, color: _teal))),
      const SizedBox(height: 7),
      Text(t.currentCity, textAlign: TextAlign.center, style: const TextStyle(fontFamily: Onb.font, fontFamilyFallback: Onb.fontFallback, fontSize: 12, fontWeight: FontWeight.w800, color: _navy)),
      const SizedBox(height: 10),
      // inner city box — text right, pin left
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(color: _boxBg, borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            ready
              ? Text(city, style: const TextStyle(fontFamily: Onb.font, fontFamilyFallback: Onb.fontFallback, fontSize: 17, fontWeight: FontWeight.w800, color: _navy))
              : Container(width: 100, height: 18, decoration: BoxDecoration(color: const Color(0xFFE3EAEB), borderRadius: BorderRadius.circular(6))),
            const SizedBox(height: 1),
            Text(t.autoDetected, style: const TextStyle(fontFamily: Onb.font, fontFamilyFallback: Onb.fontFallback, fontSize: 11, fontWeight: FontWeight.w500, color: _muted)),
          ])),
          const SizedBox(width: 9),
          const Icon(Icons.location_on, color: _teal, size: 19),
        ]),
      ),
      const SizedBox(height: 12),
      _Cta(label: t.confirmCity, onTap: onConfirm, disabled: !ready),
    ]);
  }
}

class _OrDivider extends StatelessWidget {
  final _CityStr t;
  const _OrDivider({required this.t});
  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: Container(height: 1, color: _navy.withValues(alpha: 0.12))),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(t.or, style: const TextStyle(fontFamily: Onb.font, fontFamilyFallback: Onb.fontFallback, fontSize: 13, fontWeight: FontWeight.w600, color: _muted))),
    Expanded(child: Container(height: 1, color: _navy.withValues(alpha: 0.12))),
  ]);
}

class _ManualButton extends StatelessWidget {
  final String label; final VoidCallback onTap;
  const _ManualButton({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap, behavior: HitTestBehavior.opaque,
    child: Container(
      height: 52, alignment: Alignment.center,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: _teal, width: 1.6)),
      child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(label, style: const TextStyle(fontFamily: Onb.font, fontFamilyFallback: Onb.fontFallback, fontSize: 14.5, fontWeight: FontWeight.w700, color: _teal)),
        const SizedBox(width: 10),
        const Icon(Icons.search, color: _teal, size: 20),
      ]),
    ),
  );
}

class _Cta extends StatefulWidget {
  final String label; final VoidCallback onTap; final bool disabled;
  const _Cta({required this.label, required this.onTap, this.disabled = false});
  @override
  State<_Cta> createState() => _CtaState();
}

class _CtaState extends State<_Cta> with SingleTickerProviderStateMixin {
  // "breathing" pulse so the primary action clearly draws the eye
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 620))..repeat(reverse: true);

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final btn = GestureDetector(
      onTap: widget.disabled ? null : widget.onTap,
      child: Opacity(opacity: widget.disabled ? 0.5 : 1, child: Container(
        height: 46, width: double.infinity, alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _teal, borderRadius: BorderRadius.circular(18),
          boxShadow: widget.disabled ? null : [BoxShadow(color: _teal.withValues(alpha: 0.38), blurRadius: 16, offset: const Offset(0, 6))]),
        child: Text(widget.label, style: const TextStyle(fontFamily: Onb.font, fontFamilyFallback: Onb.fontFallback, fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
      )),
    );
    if (widget.disabled) return btn;
    return AnimatedBuilder(
      animation: _c,
      child: btn,
      builder: (context, ch) => Transform.scale(
        scale: 1 + Curves.easeInOut.transform(_c.value) * 0.06, // breathe 1.0 → 1.06
        child: ch,
      ),
    );
  }
}

// ============================================================ strings
class _CityStr {
  final bool ar;
  _CityStr(this.ar);
  String get langTitle => ar ? 'اختر لغتك المفضلة' : 'Choose your preferred language';
  String get langSub => ar ? 'Choose your preferred language' : 'اختر لغتك المفضلة';
  String get title => ar ? 'اختر مدينتك' : 'Choose your city';
  String get sub => ar ? 'لعرض المنتجات ومعلومات التوصيل المناسبة لك' : 'To show the right products and delivery info for you';
  String get locating => ar ? 'جاري تحديد موقعك بدقة…' : 'Pinpointing your location…';
  String get locatingSub => ar ? 'يتم ذلك في الخلفية' : 'This happens in the background';
  String get currentCity => ar ? 'مدينتك الحالية' : 'Your current city';
  String get autoDetected => ar ? 'تم تحديدها تلقائياً' : 'Detected automatically';
  String get confirmCity => ar ? 'تأكيد المدينة' : 'Confirm city';
  String get or => ar ? 'أو' : 'or';
  String get manual => ar ? 'اختر المدينة يدوياً' : 'Choose city manually';
  String get outTitle => ar ? 'خارج نطاق التوصيل' : 'Outside our service area';
  String get outSub => ar ? 'لا نخدم موقعك الحالي — اختر مدينتك من القائمة' : "We don't serve your location — pick your city from the list";
  String get deniedTitle => ar ? 'تعذّر تحديد موقعك' : "Couldn't detect your location";
  String get deniedSub => ar ? 'اختر مدينتك من القائمة، أو فعّل صلاحية الموقع' : 'Pick your city from the list, or enable location access';
  String get enableLoc => ar ? 'فعّل صلاحية الموقع' : 'Enable location access';
  String get chooseCity => ar ? 'اختر المدينة يدوياً' : 'Choose city manually';
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
          Align(alignment: isAr ? Alignment.centerRight : Alignment.centerLeft, child: Padding(
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
