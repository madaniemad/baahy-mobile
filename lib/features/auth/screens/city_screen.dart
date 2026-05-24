import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import '../../../core/providers/address_provider.dart';
import '../../../shared/theme/app_theme.dart';

// Ordered by population/relevance
const _allCities = [
  'طرابلس',   'جنزور',     'تاجوراء',
  'عين زارة', 'سوق الجمعة','أبو سليم',
  'بنغازي',   'صلاح الدين','مصراتة',
  'الزاوية',  'الخمس',     'زليتن',
  'سرت',      'سبها',      'أجدابيا',
  'البيضاء',  'الأبيار',   'أوباري',
  'الجغبوب',  'الزنتان',   'السياحية',
  'ترهونة',   'بني وليد',  'صبراتة',
  'صرمان',    'طبرق',      'درنة',
  'غريان',    'يفرن',      'نالوت',
  'مرزق',     'غدامس',     'الكفرة',
  'قصر بن غشير',
];

class CityScreen extends ConsumerStatefulWidget {
  const CityScreen({super.key});
  @override
  ConsumerState<CityScreen> createState() => _CityScreenState();
}

class _CityScreenState extends ConsumerState<CityScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _detecting = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<String> get _filtered {
    if (_query.isEmpty) return _allCities;
    return _allCities
        .where((c) => c.contains(_query))
        .toList();
  }

  Future<void> _detectCity() async {
    setState(() => _detecting = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _showSnack('يرجى السماح بالوصول للموقع في الإعدادات');
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      final city = await _reverseGeocodeCity(pos.latitude, pos.longitude);

      if (city != null) {
        await _selectCity(city);
      } else {
        _showSnack('الموقع خارج ليبيا أو تعذّر التحديد — اختر مدينتك يدوياً');
      }
    } catch (_) {
      _showSnack('تعذّر تحديد الموقع، اختر مدينتك يدوياً');
    } finally {
      if (mounted) setState(() => _detecting = false);
    }
  }

  // Libya rough bounding box — rejects simulator/fake GPS outside country
  bool _isInLibya(double lat, double lng) =>
      lat >= 19.5 && lat <= 33.5 && lng >= 9.3 && lng <= 25.3;

  Future<String?> _reverseGeocodeCity(double lat, double lng) async {
    if (!_isInLibya(lat, lng)) return null; // outside Libya → don't guess

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=json&lat=$lat&lon=$lng&accept-language=ar&zoom=10',
      );
      final res = await http
          .get(url, headers: {'User-Agent': 'baahy-app/1.0'})
          .timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) return _nearestCity(lat, lng);

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final addr = data['address'] as Map<String, dynamic>? ?? {};
      final display = data['display_name'] as String? ?? '';

      // Try progressively broader fields
      final candidates = [
        addr['city'],
        addr['town'],
        addr['municipality'],
        addr['county'],
        addr['state_district'],
        addr['suburb'],
        addr['neighbourhood'],
        addr['quarter'],
        addr['village'],
      ].whereType<String>().toList();

      for (final raw in candidates) {
        for (final city in _allCities) {
          if (raw == city || raw.contains(city) || city.contains(raw)) {
            return city;
          }
        }
      }

      // Try display_name
      for (final city in _allCities) {
        if (display.contains(city)) return city;
      }

      return _nearestCity(lat, lng);
    } catch (_) {
      return _nearestCity(lat, lng);
    }
  }

  // Haversine distance fallback
  String _nearestCity(double lat, double lng) {
    const coords = <String, List<double>>{
      'طرابلس':        [32.9045, 13.1808],
      'بنغازي':        [32.1218, 20.0665],
      'مصراتة':        [32.3754, 15.0925],
      'الزاوية':       [32.7530, 12.7278],
      'الخمس':         [32.6495, 14.2619],
      'سرت':           [31.2089, 16.5887],
      'زليتن':         [32.4674, 14.5686],
      'ترهونة':        [32.4350, 13.6397],
      'طبرق':          [32.0838, 23.9756],
      'درنة':          [32.7664, 22.6388],
      'البيضاء':       [32.7624, 21.7551],
      'أجدابيا':       [30.7554, 20.2255],
      'سبها':          [27.0377, 14.4284],
      'غريان':         [32.1721, 13.0205],
      'يفرن':          [32.0630, 12.5229],
      'نالوت':         [31.8741, 10.9839],
      'الكفرة':        [24.1877, 23.3099],
      'مرزق':          [25.9180, 13.8962],
      'غدامس':         [30.1327,  9.5006],
      'بني وليد':      [31.7619, 13.9844],
      'صبراتة':        [32.7938, 12.4882],
      'صرمان':         [32.7554, 13.0057],
      'جنزور':         [32.9019, 13.0219],
      'تاجوراء':       [32.8859, 13.3549],
      'قصر بن غشير':  [32.7897, 13.2718],
      'عين زارة':      [32.8300, 13.2200],
      'سوق الجمعة':    [32.8700, 13.1900],
      'أبو سليم':      [32.8600, 13.2000],
      'صلاح الدين':    [32.8200, 13.1700],
      'السياحية':      [32.8400, 13.1500],
      'الأبيار':       [32.1700, 21.5700],
      'أوباري':        [26.5900, 12.7600],
      'الجغبوب':       [29.7500, 24.5100],
      'الزنتان':       [31.9300, 12.2800],
    };

    double minDist = double.infinity;
    String best = 'طرابلس';
    for (final e in coords.entries) {
      final dlat = lat - e.value[0];
      final dlng = lng - e.value[1];
      final d = dlat * dlat + dlng * dlng;
      if (d < minDist) { minDist = d; best = e.key; }
    }
    return best;
  }

  Future<void> _selectCity(String city) async {
    await ref.read(cityProvider.notifier).setCity(city);
    if (mounted) context.go('/home');
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: const Color(0xFF1A1A1A),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final top    = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;
    final canGoBack = context.canPop();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top area ────────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(20, top + 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (canGoBack) ...[
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 17, color: Color(0xFF1A1A1A)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ] else
                  const SizedBox(height: 8),

                const Text('إلى أي مدينة نوصّل؟',
                  style: TextStyle(
                    fontFamily: 'Cairo', fontSize: 24,
                    fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                const SizedBox(height: 4),
                const Text('اختر مدينتك لنعرض لك الأسعار والشحن الصحيح',
                  style: TextStyle(
                    fontSize: 13.5, color: AppColors.ink2, height: 1.4)),
                const SizedBox(height: 20),

                // ── GPS button ─────────────────────────────────────────
                GestureDetector(
                  onTap: _detecting ? null : _detectCity,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14, horizontal: 18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0E9E96), Color(0xFF14B8AE)]),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 14, offset: const Offset(0, 5))],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: _detecting
                              ? const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white))
                              : const Icon(Icons.my_location_rounded,
                                  color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _detecting ? 'جاري تحديد موقعك…' : 'استخدم موقعي الحالي',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15)),
                            const Text('ضغطة واحدة · تحديد تلقائي',
                              style: TextStyle(
                                color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Search ─────────────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    textAlign: TextAlign.right,
                    onChanged: (v) => setState(() => _query = v.trim()),
                    decoration: const InputDecoration(
                      hintText: 'ابحث عن مدينة...',
                      hintStyle: TextStyle(
                        color: AppColors.ink3, fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded,
                        color: AppColors.ink3, size: 20),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        vertical: 13, horizontal: 4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // ── City grid ────────────────────────────────────────────────
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.3,
              ),
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final city = _filtered[i];
                return GestureDetector(
                  onTap: () => _selectCity(city),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(city,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A))),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
