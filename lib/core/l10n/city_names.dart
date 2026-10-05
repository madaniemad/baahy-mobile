import '../models/shipping_rate.dart';
import '../utils/arabic_text.dart';
import 'strings.dart';

/// The city name to DISPLAY for a stored city value (an address's city is saved
/// as whatever the picker returned, normally the Arabic name).
///
/// 1. When the stored text matches a shipping rate's Arabic or English name
///    (normalised), use that rate's name in the current language.
/// 2. Otherwise, in English mode, fall back to the hard-coded translation map.
/// 3. Otherwise show the stored text unchanged.
///
/// Display only: never send the result to the server.
String displayCity(String stored, List<ShippingRate> rates,
    {required bool isAr}) {
  if (stored.isEmpty) return stored;
  final key = normalizeArabic(stored);
  for (final r in rates) {
    if (normalizeArabic(r.cityAr) == key || normalizeArabic(r.city) == key) {
      final name = isAr ? r.cityAr : r.city;
      if (name.isNotEmpty) return name;
      break;
    }
  }
  return isAr ? stored : const AppStrings(false).translateCity(stored);
}
