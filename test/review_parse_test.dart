import 'package:flutter_test/flutter_test.dart';
import 'package:baahy_customer/core/models/review.dart';

/// The reviews endpoint changed shape over time; the app must read every one of them and never
/// throw on a malformed item (one bad review used to blank the whole list).
void main() {
  Map<String, dynamic> r(int id, {Object? rating = 5, String? comment = 'ok'}) =>
      {'id': id, 'rating': rating, 'comment': comment, 'user': {'name': 'Sara'}};

  test('current shape: data = {reviews: paginator, stats}', () {
    final out = Review.parseList({
      'reviews': {'current_page': 1, 'data': [r(1), r(2)]},
      'stats': {'total': 2},
    });
    expect(out.map((e) => e.id), [1, 2]);
    expect(out.first.reviewerName, 'Sara');
    expect(out.first.body, 'ok');
  });

  test('older shapes: bare list and plain paginator', () {
    expect(Review.parseList([r(1)]).length, 1);
    expect(Review.parseList({'data': [r(1), r(2), r(3)]}).length, 3);
  });

  test('string rating is coerced and a malformed item is skipped, not fatal', () {
    final out = Review.parseList([r(1, rating: '4'), 'garbage', null, r(2)]);
    expect(out.map((e) => e.id), [1, 2]);
    expect(out.first.rating, 4);
  });

  test('empty or unexpected payloads give an empty list', () {
    expect(Review.parseList(null), isEmpty);
    expect(Review.parseList({'reviews': {'data': []}}), isEmpty);
    expect(Review.parseList('nope'), isEmpty);
  });
}
