/// Natural ordering for product size values.
///
/// The server sorts attribute values alphabetically (every sort_order is 0), which puts "10 Years"
/// before "3-4 Years" and "4 Years" between 39 and 40. Sizes are shown in this order instead:
/// numeric sizes ascending, then the letter run XXS → 5XL (a range like "L/XL" sits between its two
/// ends), then months, then years (by their first number), and anything else (e.g. "Standard") last.
bool isSizeAttribute(String name, String nameAr) {
  final n = '$name $nameAr'.toLowerCase();
  return n.contains('size') ||
      n.contains('حجم') ||
      n.contains('مقاس') ||
      n.contains('قياس');
}

/// True when the attribute type is a colour ("Color", "Colour", "اللون").
bool isColorAttribute(String name, String nameAr) {
  return name.toLowerCase().contains('colo') || nameAr.contains('لون');
}

/// The label shown for an attribute type everywhere (filters, variation picker): sizes are always
/// المقاس / Size (the server calls the same thing size, حجم, قياس…), colours اللون / Color, and any
/// other type uses its own name in the app language, falling back to the other language when blank.
String attrTypeLabel(bool isAr, String name, String nameAr) {
  if (isSizeAttribute(name, nameAr)) return isAr ? 'المقاس' : 'Size';
  if (isColorAttribute(name, nameAr)) return isAr ? 'اللون' : 'Color';
  if (isAr) return nameAr.trim().isNotEmpty ? nameAr : name;
  return name.trim().isNotEmpty ? name : nameAr;
}

/// Arabic-Indic (٠-٩) and extended Arabic-Indic (۰-۹) digits -> 0-9.
String _asciiDigits(String s) {
  final b = StringBuffer();
  for (final c in s.runes) {
    if (c >= 0x0660 && c <= 0x0669) {
      b.writeCharCode(0x30 + c - 0x0660);
    } else if (c >= 0x06F0 && c <= 0x06F9) {
      b.writeCharCode(0x30 + c - 0x06F0);
    } else {
      b.writeCharCode(c);
    }
  }
  return b.toString();
}

// Letter sizes: S = 2, M = 3, L = 4, XL = 5, XXL = 6, XXXL = 7 ... XS = 1, XXS = 0. "2XL" == "XXL",
// "3XL" == "XXXL", so any count of X (or a digit before XL) lands in the right place.
final _letterM = RegExp(r'^m$');
final _letterL = RegExp(r'^(?:(\d+)x|(x*))l$');
final _letterS = RegExp(r'^(?:(\d+)x|(x*))s$');

int? _letterRank(String v) {
  if (_letterM.hasMatch(v)) return 3;
  var m = _letterL.firstMatch(v);
  if (m != null) {
    final count =
        m.group(1) != null ? int.parse(m.group(1)!) : (m.group(2) ?? '').length;
    return count > 100 ? null : 4 + count;
  }
  m = _letterS.firstMatch(v);
  if (m != null) {
    final count =
        m.group(1) != null ? int.parse(m.group(1)!) : (m.group(2) ?? '').length;
    return count > 100 ? null : 2 - count;
  }
  return null;
}

final _rangeSplit = RegExp(r'[/\-\u2013\u2014]');
final _firstNumber = RegExp(r'\d+');
final _monthUnit = RegExp(r'\d\s*(?:m|mo|mos|months?)\b|month|شهر|أشهر|اشهر');
final _yearUnit = RegExp(r'\d\s*(?:y|yr|yrs|years?)\b|year|سنة|سنوات|سنين|سنه');

double _sizeKey(String raw) {
  final v = _asciiDigits(raw).toLowerCase().trim();
  final li = _letterRank(v);
  if (li != null) return 500 + li.toDouble();
  if (_rangeSplit.hasMatch(v)) {
    final parts =
        v.split(_rangeSplit).map((p) => _letterRank(p.trim())).toList();
    if (parts.length == 2 && parts.every((i) => i != null)) {
      return 500 + (parts[0]! + parts[1]!) / 2;
    }
  }
  final m = _firstNumber.firstMatch(v);
  final num = m != null ? (double.tryParse(m.group(0)!) ?? 0) : null;
  if (num != null && _monthUnit.hasMatch(v)) return 700 + num;
  if (num != null && _yearUnit.hasMatch(v)) return 800 + num;
  // Pure numeric sizes (30", 36x32) sort first, by their first number.
  if (num != null) return num;
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
