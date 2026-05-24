import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
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

// Libya bounds
const _libyaCenter = LatLng(27.0, 17.0);
const _triploli    = LatLng(32.9, 13.18);

const _libyanCityCoords = <String, LatLng>{
  'طرابلس':   LatLng(32.9045, 13.1808),
  'بنغازي':   LatLng(32.1218, 20.0665),
  'مصراتة':   LatLng(32.3754, 15.0925),
  'الزاوية':  LatLng(32.7530, 12.7278),
  'الخمس':    LatLng(32.6495, 14.2619),
  'سرت':      LatLng(31.2089, 16.5887),
  'زليتن':    LatLng(32.4674, 14.5686),
  'ترهونة':   LatLng(32.4350, 13.6397),
  'طبرق':     LatLng(32.0838, 23.9756),
  'درنة':     LatLng(32.7664, 22.6388),
  'البيضاء':  LatLng(32.7624, 21.7551),
  'أجدابيا':  LatLng(30.7554, 20.2255),
  'سبها':     LatLng(27.0377, 14.4284),
  'غريان':    LatLng(32.1721, 13.0205),
  'يفرن':     LatLng(32.0630, 12.5229),
  'نالوت':    LatLng(31.8741, 10.9839),
  'الكفرة':   LatLng(24.1877, 23.3099),
  'مرزق':     LatLng(25.9180, 13.8962),
  'غدامس':    LatLng(30.1327, 9.5006),
  'بني وليد': LatLng(31.7619, 13.9844),
  'صبراتة':   LatLng(32.7938, 12.4882),
  'صرمان':    LatLng(32.7554, 13.0057),
  'جنزور':    LatLng(32.9019, 13.0219),
  'تاجوراء':  LatLng(32.8859, 13.3549),
  'قصر بن غشير': LatLng(32.7897, 13.2718),
};

class MapLocationPicker extends StatefulWidget {
  /// If provided, map opens centered here; otherwise uses GPS or Tripoli.
  final LatLng? initial;

  const MapLocationPicker({this.initial, super.key});

  @override
  State<MapLocationPicker> createState() => _MapLocationPickerState();
}

class _MapLocationPickerState extends State<MapLocationPicker> {
  late final MapController _mapCtrl = MapController();

  LatLng _center    = _triploli;
  bool   _locating  = false; // GPS fetch in progress (shown in my-location btn)
  bool   _geocoding = false; // reverse geocoding in progress
  String _city     = 'طرابلس'; // default city until user moves map or taps GPS
  String _address  = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _center = widget.initial!;
      _city = '';
      _reverseGeocode(_center);
    }
    // No auto-GPS — map opens on Tripoli (or initial), user taps button to locate
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  // ── GPS ─────────────────────────────────────────────────────────────────────

  Future<void> _goToMyLocation({bool init = false}) async {
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
      setState(() {
        _center  = ll;
        _locating = false;
      });
      _mapCtrl.move(ll, 14);
      _reverseGeocode(ll);
    } catch (_) {
      setState(() => _locating = false);
      if (mounted && !init) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تعذّر تحديد الموقع'),
            backgroundColor: AppColors.ink1,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  // ── Reverse geocode via Nominatim ────────────────────────────────────────────

  void _onMapMove(MapCamera camera, bool hasGesture) {
    if (!hasGesture) return;
    setState(() => _center = camera.center);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), () {
      _reverseGeocode(camera.center);
    });
  }

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
        final data  = jsonDecode(res.body) as Map<String, dynamic>;
        final addr  = data['address'] as Map<String, dynamic>? ?? {};
        final display = data['display_name'] as String? ?? '';

        // Build short address string
        final parts = [
          addr['road'] ?? addr['pedestrian'] ?? addr['residential'],
          addr['suburb'] ?? addr['neighbourhood'] ?? addr['quarter'],
          addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['county'],
        ].whereType<String>().where((s) => s.isNotEmpty).toList();

        final shortAddr = parts.take(3).join('، ');

        // Match to known Libyan city
        final city = _matchCity(addr, display, ll);
        setState(() {
          _address = shortAddr.isNotEmpty ? shortAddr : display.split(',').first;
          _city    = city;
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
    // Fallback: nearest by distance
    return _nearestCity(ll);
  }

  String _nearestCity(LatLng ll) {
    final dist = const Distance();
    double min  = double.infinity;
    String best = 'طرابلس';
    for (final entry in _libyanCityCoords.entries) {
      final d = dist.as(LengthUnit.Kilometer, ll, entry.value);
      if (d < min) { min = d; best = entry.key; }
    }
    return best;
  }

  // ── Confirm ──────────────────────────────────────────────────────────────────

  void _confirm() {
    if (_city.isEmpty) return;
    Navigator.of(context).pop(MapPickResult(
      city: _city,
      address: _address,
      lat: _center.latitude,
      lng: _center.longitude,
    ));
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final top    = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: Stack(
        children: [
          // ── Map ─────────────────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 15,
              onPositionChanged: _onMapMove,
              minZoom: 5,
              maxZoom: 18,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.baahy.customer',
                maxZoom: 19,
              ),
            ],
          ),

          // ── Center pin ──────────────────────────────────────────────────────
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

          // ── Top bar ─────────────────────────────────────────────────────────
          Positioned(
            top: top + 12, left: 16, right: 16,
            child: Row(children: [
              _MapBtn(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Row(children: [
                    const Icon(Icons.search_rounded,
                      color: AppColors.ink3, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      _geocoding ? 'جاري تحديد الموقع…' :
                      (_address.isNotEmpty ? _address : 'حرّك الخريطة لتحديد موقعك'),
                      style: TextStyle(
                        fontSize: 13.5,
                        color: _address.isNotEmpty
                            ? AppColors.ink0 : AppColors.ink3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ]),
                ),
              ),
            ]),
          ),

          // ── Bottom panel ─────────────────────────────────────────────────────
          Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                  boxShadow: [BoxShadow(
                    color: Colors.black12,
                    blurRadius: 20, offset: Offset(0, -4))],
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // Handle
                  Container(
                    width: 36, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(99)),
                  ),

                  // Location info
                  Row(children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(10),
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
                                  _city.isNotEmpty ? _city : '—',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 15)),
                                if (_address.isNotEmpty)
                                  Text(_address,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12, color: AppColors.ink2)),
                              ],
                            ),
                    ),
                  ]),
                  const SizedBox(height: 14),

                  // My location + Confirm
                  Row(children: [
                    _locating
                        ? Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 8, offset: const Offset(0, 2))],
                            ),
                            child: const Center(
                              child: SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.primary),
                              ),
                            ),
                          )
                        : _MapBtn(
                            icon: Icons.my_location_rounded,
                            onTap: _goToMyLocation,
                          ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: _city.isNotEmpty && !_geocoding ? _confirm : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: _city.isNotEmpty && !_geocoding
                                ? const LinearGradient(
                                    colors: [Color(0xFF0E9E96), Color(0xFF14B8AE)])
                                : null,
                            color: _city.isEmpty || _geocoding
                                ? AppColors.border : null,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'تأكيد الموقع',
                            style: TextStyle(
                              color: _city.isNotEmpty && !_geocoding
                                  ? Colors.white : AppColors.ink3,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Small helpers ─────────────────────────────────────────────────────────────

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
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Icon(icon, color: AppColors.ink0, size: 20),
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
      color: AppColors.border,
      borderRadius: BorderRadius.circular(4)),
  );
}
