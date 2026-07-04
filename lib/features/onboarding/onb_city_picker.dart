import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../../core/providers/shipping_provider.dart';
import '../../core/providers/address_provider.dart';
import '../../core/utils/l10n.dart';
import 'onb_theme.dart';

/// City Picker — screen 01 of onboarding. REAL Google Map that centers on and
/// pins the user's actual location, live reverse-geocoded to their city, with a
/// manual city list as an alternative. Matches the onboarding design chrome.
class OnbCityPicker extends ConsumerStatefulWidget {
  final VoidCallback onContinue; // advance the carousel after a city is chosen
  const OnbCityPicker({super.key, required this.onContinue});

  @override
  ConsumerState<OnbCityPicker> createState() => _OnbCityPickerState();
}

const _tripoli = LatLng(32.8872, 13.1913);

// Arabic city name → coords (superset of serviceable cities), for nearest-match.
const _libyanCityCoords = <String, LatLng>{
  'طرابلس': LatLng(32.9045, 13.1808), 'بنغازي': LatLng(32.1218, 20.0665),
  'مصراتة': LatLng(32.3754, 15.0925), 'الزاوية': LatLng(32.7530, 12.7278),
  'الخمس': LatLng(32.6495, 14.2619), 'سرت': LatLng(31.2089, 16.5887),
  'زليتن': LatLng(32.4674, 14.5686), 'ترهونة': LatLng(32.4350, 13.6397),
  'طبرق': LatLng(32.0838, 23.9756), 'درنة': LatLng(32.7664, 22.6388),
  'البيضاء': LatLng(32.7624, 21.7551), 'أجدابيا': LatLng(30.7554, 20.2255),
  'سبها': LatLng(27.0377, 14.4284), 'غريان': LatLng(32.1721, 13.0205),
  'زوارة': LatLng(32.9312, 12.0820), 'صبراتة': LatLng(32.7938, 12.4882),
  'صرمان': LatLng(32.7554, 13.0057), 'جنزور': LatLng(32.9019, 13.0219),
  'تاجوراء': LatLng(32.8859, 13.3549), 'بني وليد': LatLng(31.7619, 13.9844),
};

class _OnbCityPickerState extends ConsumerState<OnbCityPicker> {
  GoogleMapController? _ctrl;
  LatLng _center = _tripoli;
  bool _locating = false;
  bool _geocoding = false;
  bool _inService = true; // false when the GPS fix is outside Libya
  bool _denied = false;   // true when the user declined the location permission
  String _cityAr = '';
  bool _sheet = false;
  bool _showAll = false;
  String _q = '';
  final _searchCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _goToMyLocation(showError: false);
    });
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    _searchCtl.dispose();
    super.dispose();
  }

  // ---- serviceable cities (live) for the manual list ----
  List<({String ar, String en})> _cities() {
    final rates = ref.watch(shippingRatesProvider).valueOrNull ?? [];
    if (rates.isNotEmpty) return rates.map((r) => (ar: r.cityAr, en: r.city)).toList();
    return kLibyaCities.map((c) => (ar: c.ar, en: c.en)).toList();
  }

  Future<void> _goToMyLocation({bool showError = true}) async {
    setState(() => _locating = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        setState(() { _locating = false; _denied = true; });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 12));
      final ll = LatLng(pos.latitude, pos.longitude);
      _ctrl?.animateCamera(CameraUpdate.newLatLngZoom(ll, 12));
      setState(() { _center = ll; _locating = false; _denied = false; });
      _reverseGeocode(ll);
    } catch (_) {
      if (mounted) setState(() => _locating = false);
    }
  }

  // Deep-link to Settings so the user can grant location, then retry.
  Future<void> _enableLocation() async {
    await Geolocator.openAppSettings();
    if (mounted) _goToMyLocation(showError: false);
  }

  Future<void> _reverseGeocode(LatLng ll) async {
    setState(() => _geocoding = true);
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse'
          '?format=json&lat=${ll.latitude}&lon=${ll.longitude}&accept-language=ar&zoom=12');
      final res = await http.get(url, headers: {'User-Agent': 'baahy-app/1.0'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final addr = data['address'] as Map<String, dynamic>? ?? {};
        final cc = (addr['country_code'] as String?)?.toLowerCase() ?? '';
        final inLibya = cc.isEmpty || cc == 'ly';
        setState(() {
          _inService = inLibya;
          _cityAr = inLibya ? _matchCity(addr, ll) : '';
          _geocoding = false;
        });
      } else {
        setState(() { _geocoding = false; _inService = true; _cityAr = _nearestCity(ll); });
      }
    } catch (_) {
      if (mounted) setState(() { _geocoding = false; _inService = true; _cityAr = _nearestCity(ll); });
    }
  }

  String _matchCity(Map<String, dynamic> addr, LatLng ll) {
    final cands = [addr['city'], addr['town'], addr['village'], addr['county'], addr['state_district'], addr['state']].whereType<String>();
    for (final raw in cands) {
      for (final name in _libyanCityCoords.keys) {
        if (raw.contains(name) || name.contains(raw)) return name;
      }
    }
    return _nearestCity(ll);
  }

  String _nearestCity(LatLng ll) {
    double min = double.infinity;
    String best = 'طرابلس';
    for (final e in _libyanCityCoords.entries) {
      final dLat = ll.latitude - e.value.latitude, dLng = ll.longitude - e.value.longitude;
      final d = dLat * dLat + dLng * dLng;
      if (d < min) { min = d; best = e.key; }
    }
    return best;
  }

  // map serviceable-city name (may differ) — snap detected city to a serviceable one.
  String _serviceable(String detected) {
    final list = _cities();
    for (final c in list) { if (c.ar == detected || detected.contains(c.ar) || c.ar.contains(detected)) return c.ar; }
    return detected;
  }

  void _confirmDetected() {
    if (_geocoding || _cityAr.isEmpty) return;
    ref.read(cityProvider.notifier).setCity(_serviceable(_cityAr));
    widget.onContinue();
  }

  void _pickManual(({String ar, String en}) c) {
    ref.read(cityProvider.notifier).setCity(c.ar);
    final coord = _libyanCityCoords[c.ar];
    if (coord != null) _ctrl?.animateCamera(CameraUpdate.newLatLngZoom(coord, 12));
    setState(() { _sheet = false; _q = ''; _searchCtl.clear(); });
    widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    final isAr = ref.watch(localeProvider).languageCode == 'ar';
    final t = _CityStr(isAr);
    final topPad = MediaQuery.of(context).padding.top;
    final calloutCity = _geocoding
        ? (isAr ? 'جاري تحديد موقعك…' : 'Locating…')
        : (_cityAr.isNotEmpty ? _cityAr : (isAr ? 'حرّك الخريطة' : 'Move the map'));

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Stack(
        children: [
          // ---- REAL map ----
          Positioned.fill(child: GoogleMap(
            initialCameraPosition: const CameraPosition(target: _tripoli, zoom: 11),
            onMapCreated: (c) => _ctrl = c,
            onCameraMove: (p) => _center = p.target,
            onCameraIdle: () { if (!_denied) _reverseGeocode(_center); },
            myLocationButtonEnabled: false,
            myLocationEnabled: true,
            zoomControlsEnabled: false,
            compassEnabled: false,
            mapToolbarEnabled: false,
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,
          )),

          // ---- fixed center pin (teal) sitting above the bottom card ----
          IgnorePointer(child: Align(
            alignment: const Alignment(0, -0.12),
            child: Column(mainAxisSize: MainAxisSize.min, children: const [
              Icon(Icons.location_on, color: Onb.tealDeep, size: 46, shadows: [Shadow(color: Color(0x330E3C46), blurRadius: 6, offset: Offset(0, 3))]),
            ]),
          )),

          // ---- top teal scrim for header legibility ----
          IgnorePointer(child: Container(height: topPad + 220, decoration: const BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xE61FD7E2), Color(0x001FD7E2)])))),

          // ---- header ----
          Positioned(top: topPad + 58, left: 24, right: 24, child: Column(children: [
            Text(t.title, textAlign: TextAlign.center, style: Onb.h1(Colors.white).copyWith(
              shadows: const [Shadow(color: Color(0x59073C46), blurRadius: 14, offset: Offset(0, 3))])),
            const SizedBox(height: 8),
            ConstrainedBox(constraints: const BoxConstraints(maxWidth: 300),
              child: Text(t.sub, textAlign: TextAlign.center, style: Onb.sub(Colors.white).copyWith(
                shadows: const [Shadow(color: Color(0x40073C46), blurRadius: 8)]))),
          ])),

          // ---- language pill ----
          Positioned(top: topPad + 6, right: 20, child: _LangPill(isAr: isAr, onTap: () => ref.read(localeProvider.notifier).toggle())),

          // ---- my-location recenter FAB ----
          Positioned(right: 18, bottom: 320, child: GestureDetector(onTap: _locating ? null : _goToMyLocation, child: Container(
            width: 46, height: 46, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
              boxShadow: const [BoxShadow(color: Color(0x24073C46), blurRadius: 10, offset: Offset(0, 3))]),
            child: _locating
              ? const Padding(padding: EdgeInsets.all(13), child: CircularProgressIndicator(strokeWidth: 2.2, color: Onb.tealDeep))
              : const Icon(Icons.my_location, color: Onb.tealDeep, size: 22)))),

          // ---- bottom card ----
          if (!_sheet) Positioned(left: 0, right: 0, bottom: 0, child: _HomeCard(
            t: t, cityLabel: calloutCity, geocoding: _geocoding, inService: _inService, denied: _denied,
            onConfirm: _confirmDetected, onManual: () => setState(() => _sheet = true), onEnable: _enableLocation)),

          // ---- manual sheet ----
          if (_sheet) Positioned.fill(child: GestureDetector(onTap: () => setState(() => _sheet = false), child: Container(color: const Color(0x33000000)))),
          AnimatedSlide(
            duration: const Duration(milliseconds: 340), curve: Curves.easeOutCubic,
            offset: _sheet ? Offset.zero : const Offset(0, 1.2),
            child: Align(alignment: Alignment.bottomCenter, child: _ManualSheet(
              t: t, isAr: isAr, query: _q, controller: _searchCtl, cities: _cities(), showAll: _showAll,
              onClose: () => setState(() => _sheet = false), onQuery: (v) => setState(() => _q = v),
              onPick: _pickManual, onToggleAll: () => setState(() => _showAll = !_showAll))),
          ),
        ],
      ),
    );
  }
}

// ============================================================ strings
class _CityStr {
  final bool ar;
  _CityStr(this.ar);
  String get title => ar ? 'اختر مدينتك' : 'Choose your city';
  String get sub => ar ? 'لنتمكن من عرض المنتجات وتكاليف التوصيل المناسبة لك' : 'So we can show the right products and delivery rates for you';
  String get useTitle => ar ? 'موقعك الحالي' : 'Your current location';
  String get confirm => ar ? 'تأكيد الموقع الحالي' : 'Confirm this location';
  String get or => ar ? 'أو' : 'or';
  String get manual => ar ? 'اختر المدينة يدوياً' : 'Choose city manually';
  String get outTitle => ar ? 'خارج نطاق التوصيل' : 'Outside our service area';
  String get outSub => ar ? 'لا نخدم موقعك الحالي — اختر مدينتك من القائمة' : "We don't serve your location — pick your city from the list";
  String get chooseCity => ar ? 'اختر المدينة' : 'Choose city';
  String get deniedTitle => ar ? 'الموقع غير مُفعّل' : 'Location is off';
  String get deniedSub => ar ? 'اختر مدينتك من القائمة، أو فعّل صلاحية الموقع' : 'Pick your city from the list, or enable location access';
  String get enableLoc => ar ? 'فعّل صلاحية الموقع' : 'Enable location access';
  String get secure => ar ? 'موقعك آمن ولا يتم مشاركته مع أي جهة خارجية' : 'Your location is safe and never shared with third parties';
  String get sheetTitle => ar ? 'اختر المدينة' : 'Choose city';
  String get search => ar ? 'ابحث عن مدينة' : 'Search for a city';
  String get mainCities => ar ? 'المدن الرئيسية' : 'Main cities';
  String get showAll => ar ? 'عرض جميع المدن' : 'Show all cities';
  String get showLess => ar ? 'عرض أقل' : 'Show less';
  String get noResults => ar ? 'لا توجد نتائج' : 'No results';
}

// ============================================================ language pill
class _LangPill extends StatelessWidget {
  final bool isAr; final VoidCallback onTap;
  const _LangPill({required this.isAr, required this.onTap});
  @override
  Widget build(BuildContext context) {
    Widget opt(String label, bool on) => Text(label, style: TextStyle(fontFamily: Onb.font, fontSize: 15, fontWeight: on ? FontWeight.w800 : FontWeight.w600, color: on ? Onb.tealDeep : const Color(0xFF9AA6A9)));
    return GestureDetector(onTap: onTap, child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999), boxShadow: const [BoxShadow(color: Color(0x29073C46), blurRadius: 16, offset: Offset(0, 6))]),
      child: Directionality(textDirection: TextDirection.ltr, child: Row(mainAxisSize: MainAxisSize.min, children: [
        opt('English', !isAr),
        Container(width: 1, height: 16, margin: const EdgeInsets.symmetric(horizontal: 8), color: const Color(0xFFDCE2E4)),
        opt('العربية', isAr),
      ])),
    ));
  }
}

// ============================================================ bottom card
class _HomeCard extends StatelessWidget {
  final _CityStr t; final String cityLabel; final bool geocoding; final bool inService; final bool denied;
  final VoidCallback onConfirm, onManual, onEnable;
  const _HomeCard({required this.t, required this.cityLabel, required this.geocoding, required this.inService, required this.denied, required this.onConfirm, required this.onManual, required this.onEnable});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28)), boxShadow: Onb.cardShadow),
      padding: EdgeInsets.fromLTRB(18, 22, 18, 18 + MediaQuery.of(context).padding.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), border: Border.all(color: Onb.hairline, width: 1.5)),
          child: denied
            ? Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Container(width: 54, height: 54, decoration: BoxDecoration(color: const Color(0xFFF3F5F5), borderRadius: BorderRadius.circular(16)),
                      child: const Icon(Icons.location_disabled, color: Color(0xFF8A9591), size: 26)),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(t.deniedTitle, style: const TextStyle(fontFamily: Onb.font, fontSize: 16, fontWeight: FontWeight.w800, color: Onb.navy)),
                    const SizedBox(height: 3),
                    Text(t.deniedSub, style: const TextStyle(fontFamily: Onb.font, fontSize: 13, fontWeight: FontWeight.w500, color: Onb.inkMuted, height: 1.35)),
                  ])),
                ]),
                const SizedBox(height: 16),
                _Cta(label: t.chooseCity, onTap: onManual),
                const SizedBox(height: 12),
                GestureDetector(onTap: onEnable, child: Text(t.enableLoc, style: const TextStyle(fontFamily: Onb.font, fontSize: 14.5, fontWeight: FontWeight.w700, color: Onb.tealDeep))),
              ])
            : inService
            ? Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Container(width: 54, height: 54, decoration: BoxDecoration(color: Onb.iconTile, borderRadius: BorderRadius.circular(16)),
                      child: const Icon(Icons.location_on, color: Onb.tealDeep, size: 26)),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(t.useTitle, style: const TextStyle(fontFamily: Onb.font, fontSize: 13.5, fontWeight: FontWeight.w600, color: Onb.inkMuted)),
                    const SizedBox(height: 2),
                    geocoding
                      ? Container(width: 120, height: 20, decoration: BoxDecoration(color: Onb.hairline, borderRadius: BorderRadius.circular(6)))
                      : Text(cityLabel, style: const TextStyle(fontFamily: Onb.font, fontSize: 20, fontWeight: FontWeight.w800, color: Onb.navy)),
                  ])),
                ]),
                const SizedBox(height: 16),
                _Cta(label: t.confirm, onTap: onConfirm, disabled: geocoding),
                Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Row(children: [
                  const Expanded(child: Divider(color: Color(0xFFEDEFF0), height: 1)),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(t.or, style: const TextStyle(fontFamily: Onb.font, fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF9AA39F)))),
                  const Expanded(child: Divider(color: Color(0xFFEDEFF0), height: 1)),
                ])),
                GestureDetector(onTap: onManual, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFFE4E8EA), width: 1.5)),
                  child: Row(children: [
                    const Icon(Icons.location_on_outlined, color: Color(0xFF9AA8A5), size: 20),
                    const SizedBox(width: 11),
                    Expanded(child: Text(t.manual, style: const TextStyle(fontFamily: Onb.font, fontSize: 15.5, fontWeight: FontWeight.w700, color: Onb.navy))),
                    const Icon(Icons.chevron_left, color: Color(0xFFC2CACB), size: 22),
                  ]),
                )),
              ])
            : Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Container(width: 54, height: 54, decoration: BoxDecoration(color: const Color(0xFFFDECEC), borderRadius: BorderRadius.circular(16)),
                      child: const Icon(Icons.location_off, color: Onb.couponRed, size: 26)),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(t.outTitle, style: const TextStyle(fontFamily: Onb.font, fontSize: 16, fontWeight: FontWeight.w800, color: Onb.navy)),
                    const SizedBox(height: 3),
                    Text(t.outSub, style: const TextStyle(fontFamily: Onb.font, fontSize: 13, fontWeight: FontWeight.w500, color: Onb.inkMuted, height: 1.35)),
                  ])),
                ]),
                const SizedBox(height: 16),
                _Cta(label: t.chooseCity, onTap: onManual),
              ]),
        ),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.verified_user_outlined, size: 16, color: Color(0xFF9AA8A5)),
          const SizedBox(width: 7),
          Flexible(child: Text(t.secure, textAlign: TextAlign.center, style: const TextStyle(fontFamily: Onb.font, fontSize: 12.5, fontWeight: FontWeight.w500, color: Color(0xFF9AA8A5)))),
        ]),
      ]),
    );
  }
}

class _Cta extends StatelessWidget {
  final String label; final VoidCallback onTap; final bool disabled;
  const _Cta({required this.label, required this.onTap, this.disabled = false});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: disabled ? null : onTap,
    child: Opacity(opacity: disabled ? 0.55 : 1, child: Container(
      height: 56, alignment: Alignment.center,
      decoration: BoxDecoration(gradient: Onb.ctaGradient, borderRadius: BorderRadius.circular(15), boxShadow: Onb.ctaShadow),
      child: Text(label, style: const TextStyle(fontFamily: Onb.font, fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
    )),
  );
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
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.66),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [BoxShadow(color: Color(0x2E073C46), blurRadius: 40, offset: Offset(0, -16))]),
      padding: EdgeInsets.fromLTRB(22, 10, 22, 22 + MediaQuery.of(context).padding.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 46, height: 5, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: const Color(0xFFE1E5E7), borderRadius: BorderRadius.circular(3))),
        Row(children: [
          GestureDetector(onTap: onClose, child: const SizedBox(width: 30, height: 30, child: Icon(Icons.close, color: Onb.navy, size: 22))),
          Expanded(child: Text(t.sheetTitle, textAlign: TextAlign.center, style: const TextStyle(fontFamily: Onb.font, fontSize: 20, fontWeight: FontWeight.w800, color: Onb.navy))),
          const SizedBox(width: 30),
        ]),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: Onb.fieldBg, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            const Icon(Icons.search, color: Color(0xFF9AA39F), size: 20),
            const SizedBox(width: 11),
            Expanded(child: TextField(
              controller: controller, onChanged: onQuery, cursorColor: Onb.tealDeep,
              style: const TextStyle(fontFamily: Onb.font, fontSize: 15.5, fontWeight: FontWeight.w500, color: Onb.navy),
              decoration: InputDecoration(
                filled: false, fillColor: Colors.transparent,
                border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
                isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 14),
                hintText: t.search, hintStyle: const TextStyle(fontFamily: Onb.font, fontSize: 15.5, fontWeight: FontWeight.w500, color: Color(0xFF9AA39F)),
              ),
            )),
          ]),
        ),
        Align(alignment: isAr ? Alignment.centerRight : Alignment.centerLeft, child: Padding(
          padding: const EdgeInsets.fromLTRB(2, 16, 2, 4),
          child: Text(t.mainCities, style: const TextStyle(fontFamily: Onb.font, fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF9AA39F))))),
        Flexible(child: filtered.isEmpty
            ? Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Text(t.noResults, style: const TextStyle(fontFamily: Onb.font, fontWeight: FontWeight.w700, color: Color(0xFF9AA39F))))
            : ListView.builder(shrinkWrap: true, itemCount: filtered.length, padding: EdgeInsets.zero, itemBuilder: (_, i) {
                final c = filtered[i];
                return GestureDetector(onTap: () => onPick(c), behavior: HitTestBehavior.opaque, child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 2),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Onb.hairline2))),
                  child: Row(children: [
                    const Icon(Icons.location_on, color: Onb.tealDeep, size: 20),
                    const SizedBox(width: 13),
                    Expanded(child: Text(isAr ? c.ar : c.en, style: const TextStyle(fontFamily: Onb.font, fontSize: 16.5, fontWeight: FontWeight.w700, color: Onb.navy))),
                  ]),
                ));
              })),
        if (query.trim().isEmpty) GestureDetector(onTap: onToggleAll, child: Padding(
          padding: const EdgeInsets.fromLTRB(2, 16, 2, 2),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(showAll ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Onb.tealDeep, size: 20),
            const SizedBox(width: 8),
            Text(showAll ? t.showLess : t.showAll, style: const TextStyle(fontFamily: Onb.font, fontSize: 15, fontWeight: FontWeight.w700, color: Onb.tealDeep)),
          ]))),
      ]),
    );
  }
}
