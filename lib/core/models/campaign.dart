import 'dart:ui' show Color;

/// A sales campaign (e.g. «الجمعة الباهية»), from `GET /campaigns/current`.
///
/// Everything about how it looks comes from the API (name, logo, colours, what to show), so the
/// same screens work for any future campaign without an app update.
class Campaign {
  final int id;
  final String slug;
  final String nameAr;
  final String nameEn;
  final String headlineAr;
  final String headlineEn;
  final String? logo;
  final Color bg;
  final Color fg;
  final Color accent;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final bool showStores;
  final bool showChips;
  final bool showCountdown;
  final int productsCount;
  final int storesCount;
  final List<CampaignChip> chips;
  final String? webUrl;
  /// The raw JSON, kept so the provider can cache exactly what the server sent.
  final Map<String, dynamic> json;

  const Campaign({
    required this.id,
    required this.slug,
    required this.nameAr,
    required this.nameEn,
    this.headlineAr = '',
    this.headlineEn = '',
    this.logo,
    required this.bg,
    required this.fg,
    required this.accent,
    this.startsAt,
    this.endsAt,
    this.showStores = true,
    this.showChips = true,
    this.showCountdown = true,
    this.productsCount = 0,
    this.storesCount = 0,
    this.chips = const [],
    this.webUrl,
    this.json = const {},
  });

  String name(bool isAr) => isAr ? _or(nameAr, nameEn) : _or(nameEn, nameAr);
  String headline(bool isAr) =>
      isAr ? _or(headlineAr, headlineEn) : _or(headlineEn, headlineAr);

  /// Over once [endsAt] has passed (a cached copy can outlive the campaign).
  bool get hasEnded {
    final e = endsAt;
    return e != null && !e.isAfter(DateTime.now());
  }

  /// The in-app route of the campaign page, optionally filtered to one store.
  String route({int? vendorId, int? categoryId}) =>
      campaignRoute(slug, vendorId: vendorId, categoryId: categoryId);

  /// Null when [j] is null or not a usable campaign (no slug).
  static Campaign? tryParse(dynamic j) {
    if (j is! Map) return null;
    try {
      final m = Map<String, dynamic>.from(j);
      final slug = _s(m['slug']);
      if (slug.isEmpty) return null;
      final colors = m['colors'] is Map ? Map<String, dynamic>.from(m['colors']) : const <String, dynamic>{};
      final bg = parseHexColor(colors['bg'], const Color(0xFF1FD7E2));
      final fg = parseHexColor(colors['fg'], const Color(0xFF08122B));
      return Campaign(
        id: (m['id'] as num?)?.toInt() ?? 0,
        slug: slug,
        nameAr: _s(m['name_ar']),
        nameEn: _s(m['name_en']),
        headlineAr: _s(m['headline_ar']),
        headlineEn: _s(m['headline_en']),
        logo: _s(m['logo']).isEmpty ? null : _s(m['logo']),
        bg: bg,
        fg: fg,
        accent: parseHexColor(colors['accent'], fg),
        startsAt: DateTime.tryParse(_s(m['starts_at']))?.toLocal(),
        endsAt: DateTime.tryParse(_s(m['ends_at']))?.toLocal(),
        showStores: m['show_stores'] != false && m['show_stores'] != 0,
        showChips: m['show_chips'] != false && m['show_chips'] != 0,
        showCountdown: m['show_countdown'] != false && m['show_countdown'] != 0,
        productsCount: (m['products_count'] as num?)?.toInt() ?? 0,
        storesCount: (m['stores_count'] as num?)?.toInt() ?? 0,
        chips: (m['chips'] as List? ?? const [])
            .map(CampaignChip.tryParse)
            .whereType<CampaignChip>()
            .toList(),
        webUrl: _s(m['web_url']).isEmpty ? null : _s(m['web_url']),
        json: m,
      );
    } catch (_) {
      return null;
    }
  }
}

/// A category shortcut on the campaign page (filters the grid by `category_id`).
class CampaignChip {
  final int id;
  final String name;
  final String nameAr;
  final int count;
  const CampaignChip({required this.id, required this.name, required this.nameAr, this.count = 0});

  String label(bool isAr) => isAr ? _or(nameAr, name) : _or(name, nameAr);

  static CampaignChip? tryParse(dynamic j) {
    if (j is! Map) return null;
    final id = (j['id'] as num?)?.toInt();
    if (id == null) return null;
    return CampaignChip(
      id: id,
      name: _s(j['name']),
      nameAr: _s(j['name_ar']),
      count: (j['count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// A store with offers in the campaign right now (`GET /campaigns/{slug}/stores`).
class CampaignStore {
  final int id;
  final String name;
  final String nameAr;
  final String? logo;
  final int count;
  const CampaignStore({required this.id, required this.name, required this.nameAr, this.logo, this.count = 0});

  String label(bool isAr) => isAr ? _or(nameAr, name) : _or(name, nameAr);

  static CampaignStore? tryParse(dynamic j) {
    if (j is! Map) return null;
    final id = (j['id'] as num?)?.toInt();
    if (id == null) return null;
    final logo = _s(j['logo']);
    return CampaignStore(
      id: id,
      name: _s(j['name']),
      nameAr: _s(j['name_ar']),
      logo: logo.isEmpty ? null : logo,
      count: (j['count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// The `campaign` object on a product while it is on campaign price.
class ProductCampaign {
  final String slug;
  final String nameAr;
  final String nameEn;
  final Color bg;
  final Color fg;
  const ProductCampaign({
    required this.slug,
    required this.nameAr,
    required this.nameEn,
    required this.bg,
    required this.fg,
  });

  String name(bool isAr) => isAr ? _or(nameAr, nameEn) : _or(nameEn, nameAr);

  Map<String, dynamic> toJson() => {
        'slug': slug,
        'name_ar': nameAr,
        'name_en': nameEn,
        'bg': colorToHex(bg),
        'fg': colorToHex(fg),
      };

  static ProductCampaign? tryParse(dynamic j) {
    if (j is! Map) return null;
    final slug = _s(j['slug']);
    if (slug.isEmpty) return null;
    return ProductCampaign(
      slug: slug,
      nameAr: _s(j['name_ar']),
      nameEn: _s(j['name_en']),
      bg: parseHexColor(j['bg'], const Color(0xFF1FD7E2)),
      fg: parseHexColor(j['fg'], const Color(0xFF08122B)),
    );
  }
}

/// `/campaign/<slug>` (+ `?vendor=` / `?category=`), the campaign page route.
String campaignRoute(String slug, {int? vendorId, int? categoryId}) {
  final q = <String, String>{
    if (vendorId != null) 'vendor': '$vendorId',
    if (categoryId != null) 'category': '$categoryId',
  };
  return Uri(path: '/campaign/${Uri.encodeComponent(slug)}', queryParameters: q.isEmpty ? null : q)
      .toString();
}

/// The campaign slug of a web offers link: `/offers/<slug>` or `https://baahy.com/offers/<slug>`
/// (also `/campaign/<slug>`). Null for anything else.
String? campaignSlugFromPath(Uri uri) {
  final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segs.length >= 2 && (segs[0] == 'offers' || segs[0] == 'campaign')) return segs[1];
  return null;
}

/// `#RGB`, `#RRGGBB` or `#AARRGGBB` → Color; anything else → [fallback].
Color parseHexColor(dynamic raw, Color fallback) {
  if (raw is! String) return fallback;
  var h = raw.trim().replaceFirst('#', '');
  if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return fallback;
  final v = int.tryParse(h, radix: 16);
  return v == null ? fallback : Color(v);
}

String colorToHex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

String _s(dynamic v) => v == null ? '' : v.toString().trim();
String _or(String a, String b) => a.isNotEmpty ? a : b;
