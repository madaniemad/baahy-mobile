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
    badgeText: j['badge_text'] as String?,
    titleAr: j['title_ar'] as String?,
    titleEn: j['title_en'] as String?,
    subtitleAr: j['subtitle_ar'] as String?,
    subtitleEn: j['subtitle_en'] as String?,
    buttonText: j['button_text'] as String?,
    buttonLink: j['button_link'] as String?,
    sortOrder: (j['sort_order'] as num?)?.toInt() ?? 0,
    showOverlay: (j['show_overlay'] == true || j['show_overlay'] == 1),
    textSide: j['text_side'] as String? ?? 'right',
  );

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

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
  final List<AppBanner> promoStrip;
  final List<AppBanner> promoLeft;
  final List<AppBanner> promoRight;
  final List<AppBanner> midBanner;
  final List<AppBanner> fashionBanner;
  final List<AppBanner> tile1;
  final List<AppBanner> tile2;
  final List<AppBanner> tile3;

  const BannersData({
    this.initialized = false,
    this.hero = const [],
    this.heroSide = const [],
    this.subHero = const [],
    this.promoStrip = const [],
    this.promoLeft = const [],
    this.promoRight = const [],
    this.midBanner = const [],
    this.fashionBanner = const [],
    this.tile1 = const [],
    this.tile2 = const [],
    this.tile3 = const [],
  });

  BannersData copyWith({bool? initialized}) => BannersData(
    initialized: initialized ?? this.initialized,
    hero: hero, heroSide: heroSide, subHero: subHero,
    promoStrip: promoStrip, promoLeft: promoLeft, promoRight: promoRight,
    midBanner: midBanner, fashionBanner: fashionBanner,
    tile1: tile1, tile2: tile2, tile3: tile3,
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
      promoStrip: _parse('promo_strip'),
      promoLeft: _parse('promo_left'),
      promoRight: _parse('promo_right'),
      midBanner: _parse('mid_banner'),
      fashionBanner: _parse('fashion_banner'),
      tile1: _parse('tile_1'),
      tile2: _parse('tile_2'),
      tile3: _parse('tile_3'),
    );
  }
}
