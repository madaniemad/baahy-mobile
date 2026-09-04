/// Same-day dispatch cutoff, in local time.
///
/// Orders placed before this hour go out the same day; after it they go out the
/// next working day. Friday is not a working day.
///
/// This lived as a bare `16` in three separate files — the cart countdown, the
/// product-page delivery range, and the order-confirmed screen — which is exactly
/// how the three of them end up promising different things. Change it here.
const int kDispatchCutoffHour = 14;

/// Friday is not a delivery day.
DateTime deliveryNextWorkingDay(DateTime d) {
  while (d.weekday == DateTime.friday) {
    d = d.add(const Duration(days: 1));
  }
  return d;
}

DateTime deliveryAddWorkingDays(DateTime d, int n) {
  for (var i = 0; i < n; i++) {
    d = deliveryNextWorkingDay(d.add(const Duration(days: 1)));
  }
  return d;
}

/// The dispatch this order will ride: today's if we are still before the cutoff,
/// otherwise the next working day's.
DateTime deliveryDispatch(DateTime now) {
  var c = DateTime(now.year, now.month, now.day, kDispatchCutoffHour);
  if (!now.isBefore(c)) c = c.add(const Duration(days: 1));
  while (c.weekday == DateTime.friday) {
    c = c.add(const Duration(days: 1));
  }
  return c;
}

/// One date, not a range. Each city has a delivery time (`delivery_days`); day 1
/// means it arrives on the dispatch day itself, so the arrival is dispatch plus
/// `days - 1` working days. Quoting a two-day window instead just tells the
/// customer we do not know.
DateTime deliveryArrival(DateTime now, int deliveryDays) =>
    deliveryAddWorkingDays(deliveryDispatch(now), (deliveryDays < 1 ? 1 : deliveryDays) - 1);

const _arDeliveryDays = ['', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
const _enDeliveryDays = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const _arDeliveryMonths = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
const _enDeliveryMonths = ['January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'];

/// "اليوم" / "غداً" when it is that close, otherwise the weekday *and* the date —
/// "الثلاثاء 9 سبتمبر" — because a bare weekday is ambiguous more than a week out.
String deliveryDayLabel(DateTime date, DateTime now, bool isAr) {
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(date.year, date.month, date.day);
  if (d == today) return isAr ? 'اليوم' : 'today';
  if (d == today.add(const Duration(days: 1))) return isAr ? 'غداً' : 'tomorrow';
  return isAr
      ? '${_arDeliveryDays[d.weekday]} ${d.day} ${_arDeliveryMonths[d.month - 1]}'
      : '${_enDeliveryDays[d.weekday]} ${d.day} ${_enDeliveryMonths[d.month - 1]}';
}
