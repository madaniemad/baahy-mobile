String fmtPrice(double n) {
  final s = n.round().toString();
  if (s.length <= 3) return s;
  final buf = StringBuffer();
  final start = s.length % 3;
  buf.write(s.substring(0, start == 0 ? 3 : start));
  for (int j = (start == 0 ? 3 : start); j < s.length; j += 3) {
    buf.write(',');
    buf.write(s.substring(j, j + 3));
  }
  return buf.toString();
}
