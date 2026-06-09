String fmtPrice(double n) {
  final intPart = n.round().toString();
  if (intPart.length <= 3) return intPart;
  final buf = StringBuffer();
  final start = intPart.length % 3;
  buf.write(intPart.substring(0, start == 0 ? 3 : start));
  for (int j = (start == 0 ? 3 : start); j < intPart.length; j += 3) {
    buf.write(',');
    buf.write(intPart.substring(j, j + 3));
  }
  return buf.toString();
}
