import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'navigation.dart';

/// Parses the web-canonical button_link format and navigates to the
/// equivalent in-app route (or opens a browser for external URLs).
///
/// Canonical formats (set in admin dashboard):
///   /products                             → all products
///   /products?category_id=5              → category
///   /products/123                        → single product
///   /products?brand=SHEIN                → brand shop
///   /products?featured=true              → deals
///   /products?max_price=100              → price-capped
///   /products?category_id=5&max_price=100&featured=true  → combined
///   /vendors/7                           → vendor shop
///   /vendor/register                     → vendor registration page (web)
///   /cart                                → cart
///   /wishlist                            → wishlist
///   https://...                          → open in browser
class BannerLink {
  BannerLink._();

  static void navigate(BuildContext context, String? link, {String fallback = '/browse'}) {
    final dest = link?.trim() ?? '';
    if (dest.isEmpty) { safePush(context, fallback); return; }

    // External URLs — open in browser
    if (dest.startsWith('http://') || dest.startsWith('https://')) {
      launchUrl(Uri.parse(dest), mode: LaunchMode.externalApplication);
      return;
    }

    final uri = Uri.tryParse(dest);
    if (uri == null) { safePush(context, fallback); return; }
    final path = uri.path;
    final q = uri.queryParameters;

    // /products/123 — single product
    final productIdMatch = RegExp(r'^/products/(\d+)$').firstMatch(path);
    if (productIdMatch != null) {
      safePush(context, '/product/${productIdMatch.group(1)}');
      return;
    }

    // /vendors/7 — vendor shop
    final vendorMatch = RegExp(r'^/vendors/(\d+)$').firstMatch(path);
    if (vendorMatch != null) {
      safePush(context, '/search/results?q=&vendor_id=${vendorMatch.group(1)}');
      return;
    }

    // /products or /products?... — map query params to search results
    if (path == '/products') {
      final params = StringBuffer('q=');
      if (q.containsKey('category_id')) params.write('&category=${q['category_id']}');
      if (q.containsKey('brand'))       params.write('&brand=${q['brand']}');
      if (q.containsKey('max_price'))   params.write('&max_price=${q['max_price']}');
      if (q.containsKey('min_price'))   params.write('&min_price=${q['min_price']}');
      if (q['featured'] == 'true')      params.write('&sort=featured');
      if (q['sort'] != null && q['sort'] != 'featured') params.write('&sort=${q['sort']}');
      safePush(context, '/search/results?$params');
      return;
    }

    // Direct app routes that match 1:1
    const directRoutes = {'/cart', '/wishlist', '/notifications', '/account', '/browse'};
    if (directRoutes.contains(path)) { safePush(context, path); return; }

    // /vendor/register — open web in browser (vendor onboarding is web-only)
    if (path == '/vendor/register') {
      launchUrl(
        Uri.parse('https://baahy.com/vendor/register'),
        mode: LaunchMode.externalApplication,
      );
      return;
    }

    // Unrecognised — fall back
    safePush(context, fallback);
  }
}
