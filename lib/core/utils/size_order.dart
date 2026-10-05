/// Natural ordering for product size values.
///
/// The server sorts attribute values alphabetically (every sort_order is 0), which puts "10 Years"
/// before "3-4 Years" and "4 Years" between 39 and 40. Sizes are shown in this order instead:
/// numeric sizes ascending, then the letter run XXS → 5XL (a range like "L/XL" sits between its two
/// ends), then months, then years (by their first number), and anything else (e.g. "Standard") last.
bool isSizeAttribute(String name, String nameAr) {
  final n = '$name $nameAr'.toLowerCase();
  return n.contains('size') || n.contains('حجم') || n.contains('مقاس');
}

const _letters = [
  'xxs',
  'xs',
  's',
  'm',
  'l',
  'xl',
  'xxl',
  '2xl',
  '3xl',
  '4xl',
  '5xl'
];

double _sizeKey(String raw) {
  final v = raw.toLowerCase().trim();
  final li = _letters.indexOf(v);
  if (li >= 0) return 500 + li.toDouble();
  if (v.contains('/')) {
    final parts = v.split('/').map((p) => _letters.indexOf(p.trim())).toList();
    if (parts.length == 2 && parts.every((i) => i >= 0)) {
      return 500 + (parts[0] + parts[1]) / 2;
    }
  }
  final m = RegExp(r'\d+').firstMatch(v);
  final num = m != null ? (double.tryParse(m.group(0)!) ?? 0) : null;
  if (num != null && v.contains('month')) return 700 + num;
  if (num != null && v.contains('year')) return 800 + num;
  if (num != null) return num; // pure numeric sizes sort first
  return 900;
}

List<T> sortSizeValues<T>(List<T> values, String Function(T) labelOf) {
  final list = [...values];
  list.sort((a, b) {
    final la = labelOf(a), lb = labelOf(b);
    final ka = _sizeKey(la), kb = _sizeKey(lb);
    return ka != kb ? ka.compareTo(kb) : la.compareTo(lb);
  });
  return list;
}
