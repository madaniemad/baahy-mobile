String fmtPrice(double n) {
  final isWhole = n == n.roundToDouble();
  // Whole numbers show no decimals; fractional values keep 2 decimals so
  // checkout rows (subtotal/shipping/total) reconcile with the charged amount.
  final fixed = isWhole ? n.toStringAsFixed(0) : n.toStringAsFixed(2);
  final dot = fixed.indexOf('.');
  final intPart = dot == -1 ? fixed : fixed.substring(0, dot);
  final decPart = dot == -1 ? '' : fixed.substring(dot); // includes leading '.'
  if (intPart.length <= 3) return '$intPart$decPart';
  final buf = StringBuffer();
  final start = intPart.length % 3;
  buf.write(intPart.substring(0, start == 0 ? 3 : start));
  for (int j = (start == 0 ? 3 : start); j < intPart.length; j += 3) {
    buf.write(',');
    buf.write(intPart.substring(j, j + 3));
  }
  buf.write(decPart);
  return buf.toString();
}
