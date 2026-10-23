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
///   /products?featured=true              → featured products (featured=1)
///   /products?max_price=100              → price-capped
///   /products?category_id=5&max_price=100&featured=true  → combined
///   /vendors/7                           → vendor shop
///   /vendor/register                     → vendor registration page (web)
///   /cart                                → cart
///   /wishlist                            → wishlist
///   /rewards                             → loyalty rewards hub
///   https://...                          → open in browser
class BannerLink {
  BannerLink._();

  static void navigate(BuildContext context, String? link, {String fallback = '/browse'}) {
    final dest = link?.trim() ?? '';
    if (dest.isEmpty) { safePush(context, fallback); return; }

    // Full Baahy URLs — strip host and treat as internal path
    if (dest.startsWith('http://') || dest.startsWith('https://')) {
      final uri = Uri.tryParse(dest);
      const baahyHosts = {
        'baahy.com', 'www.baahy.com',
        'baahy-web.vercel.app', 'api.baahy.com',
      };
      if (uri != null && baahyHosts.contains(uri.host)) {
        final internal = uri.path + (uri.hasQuery ? '?${uri.query}' : '');
        navigate(context, internal.isEmpty ? '/' : internal, fallback: fallback);
      } else {
        launchUrl(Uri.parse(dest), mode: LaunchMode.externalApplication);
      }
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

    // /vendors/7 — vendor shop: the store page itself (the results route has no store scope)
    final vendorMatch = RegExp(r'^/vendors/(\d+)$').firstMatch(path);
    if (vendorMatch != null) {
      safePush(context, '/vendors/${vendorMatch.group(1)}');
      return;
    }

    // /products or /products?... — map query params to search results
    if (path == '/products') {
      // Uri encodes the values (a brand like "H&M" or one with spaces stays intact).
      final params = <String, String>{
        'q': '',
        if (q['category_id'] != null) 'category': q['category_id']!,
        if (q['brand'] != null)       'brand': q['brand']!,
        if (q['max_price'] != null)   'max_price': q['max_price']!,
        if (q['min_price'] != null)   'min_price': q['min_price']!,
        // "featured" is a filter (featured=1), not a sort the server knows.
        if (q['featured'] == 'true' || q['featured'] == '1') 'featured': '1',
        if (q['on_sale'] == 'true' || q['on_sale'] == '1') 'on_sale': '1',
        if (q['sort'] != null && q['sort'] != 'featured') 'sort': q['sort']!,
      };
      safePush(context,
          Uri(path: '/search/results', queryParameters: params).toString());
      return;
    }

    // /rewards or /rewards-hub → loyalty hub
    if (path == '/rewards' || path == '/rewards-hub') {
      safePush(context, '/rewards-hub');
      return;
    }

    // Direct app routes that match 1:1
    const directRoutes = {'/cart', '/wishlist', '/notifications', '/account', '/browse', '/friends', '/referral'};
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
