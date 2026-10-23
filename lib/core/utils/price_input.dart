// Price fields in the filter sheets (search results + store page) share these helpers.

/// Parses a price typed with Western or Arabic-Indic digits, "1,000" / "١٬٠٠٠" separators
/// and an Arabic decimal mark; null when empty or invalid.
double? parsePriceInput(String raw) {
  const ar = '٠١٢٣٤٥٦٧٨٩';
  var t =
      raw.trim().replaceAll('٫', '.').replaceAll(',', '').replaceAll('٬', '');
  for (var i = 0; i < ar.length; i++) {
    t = t.replaceAll(ar[i], '$i');
  }
  return double.tryParse(t);
}

/// Both fields parsed; a min typed above the max is swapped rather than sent as-is.
(double?, double?) parsePriceRange(String minRaw, String maxRaw) {
  var lo = parsePriceInput(minRaw);
  var hi = parsePriceInput(maxRaw);
  if (lo != null && hi != null && lo > hi) {
    final t = lo;
    lo = hi;
    hi = t;
  }
  return (lo, hi);
}

/// Shows a stored price back in its field without rounding: 100.0 -> "100", 99.5 -> "99.5".
String formatPriceInput(double? v) {
  if (v == null) return '';
  return v == v.truncateToDouble() ? v.toStringAsFixed(0) : v.toString();
}
