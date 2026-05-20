import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

// Libyan cities with bounding boxes [minLat, maxLat, minLng, maxLng]
const _libyanCities = [
  {'name': 'طرابلس',   'lat': 32.90,  'lng': 13.18},
  {'name': 'بنغازي',   'lat': 32.12,  'lng': 20.07},
  {'name': 'مصراتة',   'lat': 32.38,  'lng': 15.09},
  {'name': 'الزاوية',  'lat': 32.75,  'lng': 12.73},
  {'name': 'الخمس',    'lat': 32.65,  'lng': 14.26},
  {'name': 'سرت',      'lat': 31.21,  'lng': 16.59},
  {'name': 'زليتن',    'lat': 32.47,  'lng': 14.57},
  {'name': 'ترهونة',   'lat': 32.43,  'lng': 13.64},
  {'name': 'طبرق',     'lat': 32.08,  'lng': 23.98},
  {'name': 'درنة',     'lat': 32.77,  'lng': 22.64},
  {'name': 'البيضاء',  'lat': 32.76,  'lng': 21.75},
  {'name': 'أجدابيا',  'lat': 30.76,  'lng': 20.22},
  {'name': 'سبها',     'lat': 27.04,  'lng': 14.43},
  {'name': 'غريان',    'lat': 32.17,  'lng': 13.02},
  {'name': 'يفرن',     'lat': 32.06,  'lng': 12.52},
  {'name': 'نالوت',    'lat': 31.87,  'lng': 10.98},
  {'name': 'الكفرة',   'lat': 24.19,  'lng': 23.31},
  {'name': 'مرزق',     'lat': 25.91,  'lng': 13.90},
  {'name': 'غدامس',   'lat': 30.13,  'lng': 9.50},
  {'name': 'بني وليد', 'lat': 31.76,  'lng': 13.98},
];

class LocationService {
  /// Request permission and return the device city name, or null on failure.
  static Future<String?> detectCity() async {
    try {
      // Check/request permission
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 10),
      );

      // Try Nominatim reverse geocode first
      final nominatim = await _nominatimCity(pos.latitude, pos.longitude);
      if (nominatim != null) return nominatim;

      // Fall back to nearest city by straight-line distance
      return _nearestCity(pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _nominatimCity(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=json&lat=$lat&lon=$lng&accept-language=ar',
      );
      final res = await http
          .get(url, headers: {'User-Agent': 'baahy-app/1.0'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final addr = data['address'] as Map<String, dynamic>?;
      if (addr == null) return null;

      // Nominatim returns city/town/county/state depending on zoom
      final raw = (addr['city'] ?? addr['town'] ?? addr['county'] ?? addr['state'])
          as String?;
      if (raw == null) return null;

      // Match against known Libyan cities
      return _matchKnownCity(raw) ?? _nearestCity(lat, lng);
    } catch (_) {
      return null;
    }
  }

  static String? _matchKnownCity(String raw) {
    final lower = raw.toLowerCase();
    for (final c in _libyanCities) {
      final name = c['name'] as String;
      if (raw.contains(name) || name.contains(raw) ||
          lower.contains(_latinApprox(name))) {
        return name;
      }
    }
    return null;
  }

  static String _nearestCity(double lat, double lng) {
    double minDist = double.infinity;
    String nearest = 'طرابلس';
    for (final c in _libyanCities) {
      final d = _dist(lat, lng, c['lat'] as double, c['lng'] as double);
      if (d < minDist) {
        minDist = d;
        nearest = c['name'] as String;
      }
    }
    return nearest;
  }

  static double _dist(double lat1, double lng1, double lat2, double lng2) {
    final dlat = lat1 - lat2;
    final dlng = lng1 - lng2;
    return dlat * dlat + dlng * dlng; // squared distance is fine for comparison
  }

  static String _latinApprox(String ar) {
    const map = {
      'طرابلس': 'tripoli', 'بنغازي': 'benghazi', 'مصراتة': 'misrata',
      'الزاوية': 'zawiya',  'الخمس': 'khoms',     'سرت': 'sirte',
      'زليتن': 'zliten',   'ترهونة': 'tarhuna',   'طبرق': 'tobruk',
      'درنة': 'derna',     'البيضاء': 'bayda',    'أجدابيا': 'ajdabiya',
      'سبها': 'sebha',     'غريان': 'gharyan',    'يفرن': 'yefren',
      'نالوت': 'nalut',    'الكفرة': 'kufra',     'مرزق': 'murzuk',
      'غدامس': 'ghadames', 'بني وليد': 'bani walid',
    };
    return map[ar] ?? '';
  }
}
