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

const String _img = 'https://api.baahy.com/api/storage';

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
  'show_category_cards': true,
  'show_banners': true,
  'banner_every_rows': 3,
  'max_discount': 81,
  'products_count': 120,
  'stores_count': 14,
  'chips': [
    {'id': 1, 'name': 'Women', 'name_ar': 'نساء', 'count': 40, 'image': '$_img/categories/f1b15a19694307ea.webp'},
    {'id': 25, 'name': 'Men', 'name_ar': 'رجال', 'count': 22, 'image': '$_img/categories/039c9b19fd9d6c94.webp'},
    {'id': 90, 'name': 'Electronics', 'name_ar': 'إلكترونيات', 'count': 18, 'image': '$_img/categories/6f674401e5504ec2.webp'},
    {'id': 64, 'name': 'Beauty', 'name_ar': 'الجمال', 'count': 15, 'image': '$_img/categories/d7e81810a6b4ae69.webp'},
    {'id': 61, 'name': 'Perfumes', 'name_ar': 'عطور', 'count': 12, 'image': '$_img/categories/36649a35eb9bdcf9.webp'},
    {'id': 119, 'name': 'Home', 'name_ar': 'البيت', 'count': 13, 'image': '$_img/categories/1c46db6d4b2ddd2d.webp'},
  ],
  // Existing home banners stand in for the store/brand banners staff will upload.
  'banners': [
    {'id': 1, 'title': 'Electronics', 'image': '$_img/home-sections/db35de0f11bb7b4d.webp', 'link': '/offers/baahyfriday-2026?category=90', 'placement': 'top'},
    {'id': 2, 'title': 'Accessories', 'image': '$_img/home-sections/e62ad5581effdbed.webp', 'link': '/products?category_id=21', 'placement': 'grid'},
    {'id': 3, 'title': 'Electronics', 'image': '$_img/home-sections/db35de0f11bb7b4d.webp', 'link': '/offers/baahyfriday-2026?category=90', 'placement': 'grid'},
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
    'logo': 'https://baahy.com/lp/aljumaa-albahya/img/logo.webp',
  });
}
