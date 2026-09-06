/// Same-day dispatch cutoff, in local time.
///
/// Orders placed before this hour go out the same day; after it they go out the
/// next working day.
///
/// This lived as a bare `16` in three separate files — the cart countdown, the
/// product-page delivery range, and the order-confirmed screen — which is exactly
/// how the three of them end up promising different things.
///
/// This is now only the FALLBACK. The live value arrives in `/app-config` under
/// `delivery` and lands in [deliveryRules]; these compiled defaults are what the
/// app uses before that response arrives, and if it is missing or malformed.
const int kDispatchCutoffHour = 14;

/// Backend-controlled delivery rules, so a cutoff change or a holiday closure is
/// an admin edit rather than an app release.
///
/// Holidays are the reason this exists: with Friday hard-coded as the only closed
/// day, the app kept promising next-day delivery straight through Eid.
class DeliveryRules {
  final int cutoffHour;

  /// ISO-8601 weekday numbers, matching `DateTime.friday == 5`.
  final Set<int> closedWeekdays;

  /// One-off closures as `YYYY-MM-DD` — public holidays, Eid, a stocktake day.
  final Set<String> closedDates;

  const DeliveryRules({
    this.cutoffHour = kDispatchCutoffHour,
    this.closedWeekdays = const {DateTime.friday},
    this.closedDates = const {},
  });
}

/// Current rules. Replaced once `/app-config` loads; never null, so every caller
/// has a working promise from the first frame.
DeliveryRules deliveryRules = const DeliveryRules();

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// A day we do not dispatch or deliver on: a closed weekday, or a listed holiday.
bool deliveryIsClosed(DateTime d) =>
    deliveryRules.closedWeekdays.contains(d.weekday) || deliveryRules.closedDates.contains(_ymd(d));

/// Skips forward over closed days (Friday by default, plus any holiday).
DateTime deliveryNextWorkingDay(DateTime d) {
  var guard = 0;
  while (deliveryIsClosed(d) && guard++ < 30) {
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
  var c = DateTime(now.year, now.month, now.day, deliveryRules.cutoffHour);
  if (!now.isBefore(c)) c = c.add(const Duration(days: 1));
  var guard = 0;
  while (deliveryIsClosed(c) && guard++ < 30) {
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

String _fmtLeft(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final h = d.inHours;
  return h > 0
      ? '$h:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}'
      : '${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
}

/// The cart's delivery line. [now] is injected so the wording is testable at any
/// hour without waiting for the clock.
///
/// The countdown only runs while today's dispatch is still catchable — that is the
/// only window where it is a deadline. Past the cutoff it would count 23 hours to
/// tomorrow's dispatch, or 47 across a Friday, which reads as "this will take
/// ages" and buries the fact that the order still arrives next day.
///
/// Outside the hub we quote a span, not a date: a calendar date reads as a
/// commitment to the day, and one slipped day makes it a broken promise. The span
/// is [max] of the city's own `delivery_days` and the real gap to arrival, so
/// ordering after the cutoff or across a closed Friday widens it instead of
/// quietly under-quoting.
String cartDeliveryLine(DateTime now, int deliveryDays, bool isAr) {
  final dispatch = deliveryDispatch(now);
  final arrival  = deliveryArrival(now, deliveryDays);
  final today    = DateTime(now.year, now.month, now.day);
  DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  final gap  = dayOf(arrival).difference(today).inDays;
  final span = (deliveryDays < 1 ? 1 : deliveryDays) > gap
      ? (deliveryDays < 1 ? 1 : deliveryDays)
      : gap;

  if (dayOf(dispatch) == today) {
    final left = _fmtLeft(dispatch.difference(now));
    if (dayOf(arrival) == today) {
      return isAr ? 'اطلب خلال $left ليصلك اليوم' : 'Order within $left and get it today';
    }
    return isAr
        ? 'اطلب خلال $left ليصلك في ${dayCountLabel(span, true)}'
        : 'Order within $left and get it in ${dayCountLabel(span, false)}';
  }

  if (arrival.difference(now).inHours <= 24) {
    return isAr ? 'يصلك خلال 24 ساعة' : 'Get it within 24 hours';
  }

  return isAr ? 'يصلك خلال ${dayCountLabel(span, true)}' : 'Get it within ${dayCountLabel(span, false)}';
}

/// Arabic counts days by grammatical number — one, a dual, a plural for 3-10 and
/// a singular again above that. Printing "2 أيام" is the tell of a translated app.
String dayCountLabel(int n, bool isAr) {
  if (!isAr) return n == 1 ? '1 day' : '$n days';
  if (n == 1) return 'يوم واحد';
  if (n == 2) return 'يومين';
  if (n <= 10) return '$n أيام';
  return '$n يوماً';
}

/// Arrival phrased on its own, for screens that report an order already placed
/// (the confirmation screen) rather than urging one. Same spans as the cart, so
/// the customer is never told two different things about the same order.
String deliveryArrivalPhrase(DateTime now, int deliveryDays, bool isAr) {
  final arrival = deliveryArrival(now, deliveryDays);
  final today   = DateTime(now.year, now.month, now.day);
  final aDay    = DateTime(arrival.year, arrival.month, arrival.day);

  if (aDay == today) return isAr ? 'اليوم' : 'Today';
  if (arrival.difference(now).inHours <= 24) {
    return isAr ? 'خلال 24 ساعة' : 'Within 24 hours';
  }
  final gap  = aDay.difference(today).inDays;
  final base = deliveryDays < 1 ? 1 : deliveryDays;
  final span = base > gap ? base : gap;
  return isAr ? 'خلال ${dayCountLabel(span, true)}' : 'Within ${dayCountLabel(span, false)}';
}
