/// Normalises text for forgiving Arabic (and Latin) search: typing 'اجدابيا'
/// must find 'أجدابيا', and 'مصراته' must find 'مصراتة'.
///
/// - lower-cases Latin letters, trims, collapses runs of whitespace
/// - strips tashkeel (U+064B-U+0652) and tatweel (U+0640)
/// - unifies alef forms أ إ آ ٱ -> ا
/// - ة -> ه, ى -> ي, ؤ -> و, ئ -> ي
/// - maps Arabic-Indic digits ٠-٩ to 0-9
String normalizeArabic(String s) {
  if (s.isEmpty) return s;
  final buf = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    if ((r >= 0x064B && r <= 0x0652) || r == 0x0640) continue;
    if (r >= 0x0660 && r <= 0x0669) {
      buf.writeCharCode(0x30 + (r - 0x0660));
      continue;
    }
    switch (r) {
      case 0x0623: // أ
      case 0x0625: // إ
      case 0x0622: // آ
      case 0x0671: // ٱ
        buf.writeCharCode(0x0627); // ا
      case 0x0629: // ة
        buf.writeCharCode(0x0647); // ه
      case 0x0649: // ى
      case 0x0626: // ئ
        buf.writeCharCode(0x064A); // ي
      case 0x0624: // ؤ
        buf.writeCharCode(0x0648); // و
      default:
        buf.writeCharCode(r);
    }
  }
  return buf.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
}

/// True when [haystack] contains [needle] after normalisation. An empty
/// (or whitespace-only) needle matches everything.
bool matchesArabic(String haystack, String needle) {
  final n = normalizeArabic(needle);
  if (n.isEmpty) return true;
  return normalizeArabic(haystack).contains(n);
}
