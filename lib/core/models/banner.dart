class AppBanner {
  final int id;
  final String slot;
  final String? imageUrl;
  final String? imageUrlEn;
  final String? badgeText;
  final String? titleAr;
  final String? titleEn;
  final String? subtitleAr;
  final String? subtitleEn;
  final String? buttonText;
  final String? buttonLink;
  final int sortOrder;
  final bool showOverlay;
  final String textSide;

  const AppBanner({
    required this.id,
    required this.slot,
    this.imageUrl,
    this.imageUrlEn,
    this.badgeText,
    this.titleAr,
    this.titleEn,
    this.subtitleAr,
    this.subtitleEn,
    this.buttonText,
    this.buttonLink,
    this.sortOrder = 0,
    this.showOverlay = true,
    this.textSide = 'right',
  });

  factory AppBanner.fromJson(Map<String, dynamic> j) => AppBanner(
    id: (j['id'] as num).toInt(),
    slot: j['slot'] as String? ?? '',
    imageUrl: _resolveUrl(j['image_url'] as String?),
    imageUrlEn: _resolveUrl(j['image_url_en'] as String?),
    badgeText: _ne(j['badge_text'] as String?),
    titleAr: _ne(j['title_ar'] as String?),
    titleEn: _ne(j['title_en'] as String?),
    subtitleAr: _ne(j['subtitle_ar'] as String?),
    subtitleEn: _ne(j['subtitle_en'] as String?),
    buttonText: _ne(j['button_text'] as String?),
    buttonLink: _ne(j['button_link'] as String?),
    sortOrder: (j['sort_order'] as num?)?.toInt() ?? 0,
    showOverlay: (j['show_overlay'] == true || j['show_overlay'] == 1),
    textSide: j['text_side'] as String? ?? 'right',
  );

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  static String? _ne(String? v) => (v == null || v.isEmpty) ? null : v;

  static String? _resolveUrl(String? v) {
    if (v == null || v.isEmpty) return null;
    if (v.startsWith('http')) return v;
    return 'https://api.baahy.com/api/storage/${v.replaceFirst(RegExp(r'^/?storage/'), '')}';
  }
}

class BannersData {
  final bool initialized;
  final List<AppBanner> hero;
  final List<AppBanner> heroSide;
  final List<AppBanner> subHero;

  const BannersData({
    this.initialized = false,
    this.hero = const [],
    this.heroSide = const [],
    this.subHero = const [],
  });

  BannersData copyWith({bool? initialized}) => BannersData(
    initialized: initialized ?? this.initialized,
    hero: hero, heroSide: heroSide, subHero: subHero,
  );

  factory BannersData.fromJson(Map<String, dynamic> data) {
    List<AppBanner> _parse(String key) =>
        (data[key] as List? ?? [])
            .map((b) => AppBanner.fromJson(b as Map<String, dynamic>))
            .toList();
    return BannersData(
      initialized: true,
      hero: _parse('hero'),
      heroSide: _parse('hero_side'),
      subHero: _parse('sub_hero'),
    );
  }
}
