import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../core/utils/l10n.dart';
import '../../shared/theme/app_theme.dart';

class MapPickResult {
  final String city;
  final String address;
  final double lat;
  final double lng;
  const MapPickResult({
    required this.city,
    required this.address,
    required this.lat,
    required this.lng,
  });
}

const _tripoli = LatLng(32.9, 13.18);

const _libyanCityCoords = <String, LatLng>{
  'طرابلس':      LatLng(32.9045, 13.1808),
  'بنغازي':      LatLng(32.1218, 20.0665),
  'مصراتة':      LatLng(32.3754, 15.0925),
  'الزاوية':     LatLng(32.7530, 12.7278),
  'الخمس':       LatLng(32.6495, 14.2619),
  'سرت':         LatLng(31.2089, 16.5887),
  'زليتن':       LatLng(32.4674, 14.5686),
  'ترهونة':      LatLng(32.4350, 13.6397),
  'طبرق':        LatLng(32.0838, 23.9756),
  'درنة':        LatLng(32.7664, 22.6388),
  'البيضاء':     LatLng(32.7624, 21.7551),
  'أجدابيا':     LatLng(30.7554, 20.2255),
  'سبها':        LatLng(27.0377, 14.4284),
  'غريان':       LatLng(32.1721, 13.0205),
  'يفرن':        LatLng(32.0630, 12.5229),
  'نالوت':       LatLng(31.8741, 10.9839),
  'الكفرة':      LatLng(24.1877, 23.3099),
  'مرزق':        LatLng(25.9180, 13.8962),
  'غدامس':       LatLng(30.1327,  9.5006),
  'بني وليد':    LatLng(31.7619, 13.9844),
  'صبراتة':      LatLng(32.7938, 12.4882),
  'صرمان':       LatLng(32.7554, 13.0057),
  'جنزور':       LatLng(32.9019, 13.0219),
  'تاجوراء':     LatLng(32.8859, 13.3549),
  'قصر بن غشير': LatLng(32.7897, 13.2718),
};


const _darkStyle = '[{"elementType":"geometry","stylers":[{"color":"#212121"}]},'
    '{"elementType":"labels.icon","stylers":[{"visibility":"off"}]},'
    '{"elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},'
    '{"elementType":"labels.text.stroke","stylers":[{"color":"#212121"}]},'
    '{"featureType":"administrative.country","elementType":"labels.text.fill","stylers":[{"color":"#9e9e9e"}]},'
    '{"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#bdbdbd"}]},'
    '{"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},'
    '{"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#181818"}]},'
    '{"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#616161"}]},'
    '{"featureType":"poi.park","elementType":"labels.text.stroke","stylers":[{"color":"#1b1b1b"}]},'
    '{"featureType":"road","elementType":"geometry.fill","stylers":[{"color":"#2c2c2c"}]},'
    '{"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#8a8a8a"}]},'
    '{"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#373737"}]},'
    '{"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#3c3c3c"}]},'
    '{"featureType":"road.highway.controlled_access","elementType":"geometry","stylers":[{"color":"#4e4e4e"}]},'
    '{"featureType":"road.local","elementType":"labels.text.fill","stylers":[{"color":"#616161"}]},'
    '{"featureType":"transit","elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},'
    '{"featureType":"water","elementType":"geometry","stylers":[{"color":"#000000"}]},'
    '{"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#3d3d3d"}]}]';

class MapLocationPicker extends StatefulWidget {
  final LatLng? initial;
  const MapLocationPicker({this.initial, super.key});

  @override
  State<MapLocationPicker> createState() => _MapLocationPickerState();
}

class _MapLocationPickerState extends State<MapLocationPicker> {
  GoogleMapController? _ctrl;

  LatLng _center   = _tripoli;
  bool   _locating = false;
  bool   _geocoding = false;
  String _city     = 'طرابلس';
  String _address  = '';

  // Search
  bool   _searching = false;
  final  _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _suggestions = [];
  bool   _loadingSuggestions = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _center = widget.initial!;
      _city   = '';
      _reverseGeocode(_center);
    } else {
      // Auto-detect GPS on open; suppress error snackbar if silently denied
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _goToMyLocation(showError: false);
      });
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ── Search / Places Autocomplete ──────────────────────────────────────────────

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() { _suggestions = []; _loadingSuggestions = false; });
      return;
    }
    setState(() => _loadingSuggestions = true);
    _debounce = Timer(const Duration(milliseconds: 400), () => _fetchSuggestions(q.trim()));
  }

  Future<void> _fetchSuggestions(String q) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(q)}'
        '&format=json&limit=6&accept-language=ar&addressdetails=1',
      );
      final res = await http
          .get(url, headers: {'User-Agent': 'baahy-app/1.0'})
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final list = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
        setState(() { _suggestions = list; _loadingSuggestions = false; });
      } else {
        setState(() { _suggestions = []; _loadingSuggestions = false; });
      }
    } catch (_) {
      if (mounted) setState(() { _suggestions = []; _loadingSuggestions = false; });
    }
  }

  void _selectSuggestion(Map<String, dynamic> item) {
    final lat  = double.tryParse(item['lat'] as String? ?? '');
    final lng  = double.tryParse(item['lon'] as String? ?? '');
    final name = item['display_name'] as String? ?? '';
    FocusScope.of(context).unfocus();
    setState(() { _searching = false; _searchCtrl.clear(); _suggestions = []; });
    if (lat == null || lng == null) return;
    final ll = LatLng(lat, lng);
    _ctrl?.animateCamera(CameraUpdate.newLatLngZoom(ll, 15.0));
    setState(() { _center = ll; _address = name.split(',').first; });
    _reverseGeocode(ll);
  }

  // ── GPS ───────────────────────────────────────────────────────────────────────

  Future<void> _goToMyLocation({bool showError = true}) async {
    setState(() => _locating = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        setState(() => _locating = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 12),
      );
      final ll = LatLng(pos.latitude, pos.longitude);
      _ctrl?.animateCamera(CameraUpdate.newLatLngZoom(ll, 15.0));
      setState(() { _center = ll; _locating = false; });
      _reverseGeocode(ll);
    } catch (_) {
      setState(() => _locating = false);
      if (showError && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.s.locationFailed),
          backgroundColor: context.col.ink1,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  // ── Camera callbacks ──────────────────────────────────────────────────────────

  void _onCameraMove(CameraPosition pos) {
    setState(() => _center = pos.target);
  }

  void _onCameraIdle() {
    _reverseGeocode(_center);
  }

  // ── Reverse geocode via Nominatim ─────────────────────────────────────────────

  Future<void> _reverseGeocode(LatLng ll) async {
    setState(() => _geocoding = true);
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=json&lat=${ll.latitude}&lon=${ll.longitude}'
        '&accept-language=ar&zoom=14',
      );
      final res = await http
          .get(url, headers: {'User-Agent': 'baahy-app/1.0'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data    = jsonDecode(res.body) as Map<String, dynamic>;
        final addr    = data['address'] as Map<String, dynamic>? ?? {};
        final display = data['display_name'] as String? ?? '';
        final parts   = [
          addr['road'] ?? addr['pedestrian'] ?? addr['residential'],
          addr['suburb'] ?? addr['neighbourhood'] ?? addr['quarter'],
          addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['county'],
        ].whereType<String>().where((s) => s.isNotEmpty).toList();
        final shortAddr = parts.take(3).join('، ');
        setState(() {
          _address   = shortAddr.isNotEmpty ? shortAddr : display.split(',').first;
          _city      = _matchCity(addr, display, ll);
          _geocoding = false;
        });
      } else {
        setState(() { _geocoding = false; _city = _nearestCity(ll); });
      }
    } catch (_) {
      setState(() { _geocoding = false; _city = _nearestCity(ll); });
    }
  }

  String _matchCity(Map<String, dynamic> addr, String display, LatLng ll) {
    final candidates = [
      addr['city'], addr['town'], addr['village'],
      addr['county'], addr['state_district'], addr['state'],
    ].whereType<String>();
    for (final raw in candidates) {
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
      final dLat = ll.latitude  - e.value.latitude;
      final dLng = ll.longitude - e.value.longitude;
      final d    = dLat * dLat + dLng * dLng;
      if (d < min) { min = d; best = e.key; }
    }
    return best;
  }

  // ── Confirm ───────────────────────────────────────────────────────────────────

  void _confirm() {
    if (_city.isEmpty || _geocoding) return;
    Navigator.of(context).pop(MapPickResult(
      city: _city, address: _address,
      lat: _center.latitude, lng: _center.longitude,
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final top    = MediaQuery.of(context).padding.top;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // ── Google Map ─────────────────────────────────────────────────────
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _center,
              zoom: widget.initial != null ? 15 : 12,
            ),
            style: isDark ? _darkStyle : null,
            onMapCreated: (ctrl) => _ctrl = ctrl,
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
            compassEnabled: false,
            mapToolbarEnabled: false,
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,
          ),

          // ── Center pin ────────────────────────────────────────────────────
          Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 180 + bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 12, spreadRadius: 2,
                      )],
                    ),
                    child: const Icon(Icons.location_pin,
                        color: Colors.white, size: 24),
                  ),
                  CustomPaint(
                    size: const Size(2, 12),
                    painter: _PinStemPainter(),
                  ),
                  Container(
                    width: 10, height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Top bar ───────────────────────────────────────────────────────
          Positioned(
            top: top + 12, left: 16, right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  _MapBtn(
                    icon: _searching ? Icons.close_rounded : Icons.arrow_back_rounded,
                    onTap: () {
                      if (_searching) {
                        setState(() {
                          _searching = false;
                          _suggestions = [];
                          _searchCtrl.clear();
                        });
                        FocusScope.of(context).unfocus();
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (!_searching) setState(() => _searching = true);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8, offset: const Offset(0, 2))],
                        ),
                        child: _searching
                            ? Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 4),
                                child: Row(children: [
                                  const Icon(Icons.search_rounded,
                                      color: AppColors.primary, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: _searchCtrl,
                                      autofocus: true,
                                      textDirection: TextDirection.rtl,
                                      style: const TextStyle(fontSize: 13.5),
                                      decoration: InputDecoration(
                                        hintText: 'ابحث عن موقع...',
                                        hintStyle: TextStyle(
                                            color: context.col.ink3,
                                            fontSize: 13.5),
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        filled: false,
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(
                                            vertical: 8),
                                      ),
                                      onChanged: _onSearchChanged,
                                    ),
                                  ),
                                  if (_loadingSuggestions)
                                    const SizedBox(
                                      width: 16, height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 1.5,
                                          color: AppColors.primary),
                                    ),
                                ]),
                              )
                            : Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 11),
                                child: Row(children: [
                                  Icon(Icons.search_rounded,
                                      color: context.col.ink3, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _geocoding ? 'جاري تحديد الموقع…' :
                                      (_address.isNotEmpty
                                          ? _address : 'ابحث أو حرّك الخريطة'),
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        color: _address.isNotEmpty
                                            ? context.col.ink0 : context.col.ink3,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ]),
                              ),
                      ),
                    ),
                  ),
                ]),

                // Suggestions dropdown
                if (_searching && _suggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6, right: 54),
                    constraints: const BoxConstraints(maxHeight: 260),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: _suggestions.length,
                      itemBuilder: (_, i) {
                        final s = _suggestions[i];
                        final parts = (s['display_name'] as String? ?? '').split(',');
                        final main = parts.first.trim();
                        final secondary = parts.length > 1
                            ? parts.skip(1).take(2).map((p) => p.trim()).join('، ')
                            : null;
                        return InkWell(
                          onTap: () => _selectSuggestion(s),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 11),
                            child: Row(children: [
                              Icon(Icons.location_on_outlined,
                                  color: context.col.ink3, size: 16),
                              const SizedBox(width: 10),
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(main,
                                      style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  if (secondary != null && secondary.isNotEmpty)
                                    Text(secondary,
                                        style: TextStyle(
                                            fontSize: 11.5,
                                            color: context.col.ink3),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                ],
                              )),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // ── Bottom panel ──────────────────────────────────────────────────
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
              decoration: BoxDecoration(
                color: context.col.surface,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20)),
                boxShadow: const [BoxShadow(
                  color: Colors.black12,
                  blurRadius: 20, offset: Offset(0, -4))],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Handle
                Container(
                  width: 36, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: context.col.border,
                    borderRadius: BorderRadius.circular(99)),
                ),

                // Location info row
                Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.location_pin,
                        color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _geocoding
                        ? const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _ShimmerLine(width: 120, height: 14),
                              SizedBox(height: 6),
                              _ShimmerLine(width: 200, height: 11),
                            ])
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _city.isNotEmpty ? _city : 'حرّك الخريطة لتحديد موقعك',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: _city.isNotEmpty
                                        ? context.col.ink0 : context.col.ink3)),
                              if (_address.isNotEmpty)
                                Text(_address,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: context.col.ink2)),
                            ],
                          ),
                  ),
                ]),
                const SizedBox(height: 12),

                // "Select my location automatically" pill
                GestureDetector(
                  onTap: _locating ? null : _goToMyLocation,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 13),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2C2C2C)
                          : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_locating)
                          const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary),
                          )
                        else
                          const Icon(Icons.my_location_rounded,
                              size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          _locating
                              ? 'جارٍ تحديد موقعك...'
                              : 'استخدم موقعي الحالي',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _locating
                                ? context.col.ink3 : context.col.ink0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Confirm button
                GestureDetector(
                  onTap: _city.isNotEmpty && !_geocoding ? _confirm : null,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      gradient: _city.isNotEmpty && !_geocoding
                          ? const LinearGradient(colors: [
                              Color(0xFF1AC5CD),
                              AppColors.primary,
                            ])
                          : null,
                      color: _city.isEmpty || _geocoding
                          ? context.col.border : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'تأكيد الموقع',
                      style: TextStyle(
                        color: _city.isNotEmpty && !_geocoding
                            ? Colors.white : context.col.ink3,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _MapBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MapBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF2C2C2C) : Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10, offset: const Offset(0, 2))],
          ),
          child: Icon(icon, color: context.col.ink0, size: 20),
        ),
      );
}

class _PinStemPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(size.width / 2, 0), Offset(size.width / 2, size.height),
      Paint()..color = AppColors.primary..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

class _ShimmerLine extends StatelessWidget {
  final double width;
  final double height;
  const _ShimmerLine({required this.width, required this.height});

  @override
  Widget build(BuildContext context) => Container(
        width: width, height: height,
        decoration: BoxDecoration(
          color: context.col.border,
          borderRadius: BorderRadius.circular(4)),
      );
}
