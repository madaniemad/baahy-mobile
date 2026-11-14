import 'package:flutter/foundation.dart';
import '../models/campaign.dart';

/// DEBUG-ONLY campaign preview, so the campaign UI can be checked before a campaign is live:
///
///     flutter run --dart-define=FAKE_CAMPAIGN=1
///
/// `kDebugMode` is a compile-time `false` in profile/release builds, so this constant is `false`
/// there and every `if (kFakeCampaign)` branch is removed by the compiler: a store build can never
/// show the fake campaign, whatever is passed to `--dart-define`. Without the define nothing changes
/// in debug either.
const bool kFakeCampaign = kDebugMode &&
    (String.fromEnvironment('FAKE_CAMPAIGN') == '1' ||
        String.fromEnvironment('FAKE_CAMPAIGN') == 'true');

/// The sample `/campaigns/current` payload (Baahy Friday). The chips are real root categories so
/// the chip filter can be tried against live products.
const Map<String, dynamic> kFakeCampaignJson = {
  'id': 1,
  'slug': 'baahyfriday-2026',
  'name_ar': 'الجمعة الباهية',
  'name_en': 'Baahy Friday',
  'headline_ar': 'أسبوع كامل من التخفيضات',
  'headline_en': 'A whole week of deals',
  'logo': 'https://baahy.com/lp/aljumaa-albahya/img/logo.webp',
  'colors': {'bg': '#1FD7E2', 'fg': '#08122B', 'accent': '#FDF602'},
  'starts_at': '2026-11-21T00:00:00+02:00',
  'ends_at': '2026-11-27T23:59:59+02:00',
  'show_stores': true,
  'show_chips': true,
  'show_countdown': true,
  'products_count': 120,
  'stores_count': 14,
  'chips': [
    {'id': 1, 'name': 'Women', 'name_ar': 'نساء', 'count': 40},
    {'id': 25, 'name': 'Men', 'name_ar': 'رجال', 'count': 22},
    {'id': 90, 'name': 'Electronics', 'name_ar': 'إلكترونيات', 'count': 18},
    {'id': 64, 'name': 'Beauty', 'name_ar': 'الجمال', 'count': 15},
    {'id': 61, 'name': 'Perfumes', 'name_ar': 'عطور', 'count': 12},
    {'id': 119, 'name': 'Home', 'name_ar': 'البيت', 'count': 13},
  ],
  'web_url': 'https://baahy.com/offers/baahyfriday-2026',
};

/// While faking, every discounted product wears the campaign tag (the live API sets
/// `product.campaign` itself). Null when not faking or the product has no discount.
ProductCampaign? fakeProductCampaign(Map<String, dynamic> productJson) {
  if (!kFakeCampaign) return null;
  double? d(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
  final price = d(productJson['price']);
  final sale = d(productJson['sale_price']);
  if (price == null || sale == null || sale >= price) return null;
  return ProductCampaign.tryParse(const {
    'slug': 'baahyfriday-2026',
    'name_ar': 'الجمعة الباهية',
    'name_en': 'Baahy Friday',
    'bg': '#1FD7E2',
    'fg': '#08122B',
  });
}
