import 'package:flutter/material.dart';

/// Design tokens for the onboarding flow — taken verbatim from the design handoff
/// (design_handoff_baahy_onboarding/README.md). Keep in sync with the PNG designs.
class Onb {
  // Brand
  static const teal = Color(0xFF1FD7E2); // brand / "Tiffany"
  static const tealDeep = Color(0xFF0FA9B8); // buttons, active text, icons
  static const navy = Color(0xFF0E3C46); // headings & primary text
  static const inkMuted = Color(0xFF8A9591); // secondary text
  static const inkMuted2 = Color(0xFF5E6B6E); // map labels
  static const gpsBlue = Color(0xFF1C74E0); // live-location dot
  static const couponRed = Color(0xFFE5342B);
  static const coinGold = Color(0xFFF7B500);

  // Surfaces
  static const surface = Color(0xFFFFFFFF);
  static const hairline = Color(0xFFEEF1F2);
  static const hairline2 = Color(0xFFF1F3F4);
  static const fieldBg = Color(0xFFF4F6F7);
  static const iconTile = Color(0xFFE1F6F8); // teal-tint tile

  // CTA — brand tiffany #1FD7E2 (flat, per brand spec)
  static const ctaGradient = LinearGradient(colors: [Color(0xFF1FD7E2), Color(0xFF1FD7E2)]);

  // City-picker background (punchy radial). RadialGradient approximates
  // radial-gradient(125% 55% at 50% 2%, #47E1EA 0%, #1FD7E2 48%, #1AC6D2 100%)
  static const cityBg = RadialGradient(
    center: Alignment(0, -0.96),
    radius: 1.25,
    colors: [Color(0xFF47E1EA), Color(0xFF1FD7E2), Color(0xFF1AC6D2)],
    stops: [0.0, 0.48, 1.0],
  );

  // Promo-slide background: teal top fading to near-white bottom third.
  static const promoBg = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF33D3DE), Color(0xFF1FD7E2), Color(0xFFEAF9FB)],
    stops: [0.0, 0.42, 1.0],
  );

  static const cardShadow = [
    BoxShadow(color: Color(0x24073C46), blurRadius: 30, offset: Offset(0, -12)),
  ];
  static const calloutShadow = [
    BoxShadow(color: Color(0x2E073C46), blurRadius: 24, offset: Offset(0, 10)),
  ];
  static const ctaShadow = [
    BoxShadow(color: Color(0x521FD7E2), blurRadius: 26, offset: Offset(0, 12)),
  ];

  static const font = 'Cairo';

  static TextStyle h1(Color c) => const TextStyle(
        fontFamily: font, fontSize: 30, fontWeight: FontWeight.w800, height: 1.15,
      ).copyWith(color: c);
  static TextStyle sub(Color c) => const TextStyle(
        fontFamily: font, fontSize: 15, fontWeight: FontWeight.w500, height: 1.5,
      ).copyWith(color: c);
}

/// The 10 serviceable Libyan cities with coordinates — used to map a GPS fix to
/// the nearest city (ShippingRate has no lat/lng). Names match the city list.
class LibyaCity {
  final String ar, en;
  final double lat, lng;
  const LibyaCity(this.ar, this.en, this.lat, this.lng);
}

const kLibyaCities = <LibyaCity>[
  LibyaCity('طرابلس', 'Tripoli', 32.8872, 13.1913),
  LibyaCity('بنغازي', 'Benghazi', 32.1167, 20.0667),
  LibyaCity('مصراتة', 'Misrata', 32.3775, 15.0925),
  LibyaCity('الزاوية', 'Zawiya', 32.7522, 12.7278),
  LibyaCity('الخمس', 'Khoms', 32.6486, 14.2619),
  LibyaCity('زليتن', 'Zliten', 32.4674, 14.5687),
  LibyaCity('زوارة', 'Zuwara', 32.9312, 12.0820),
  LibyaCity('سبها', 'Sabha', 27.0377, 14.4283),
  LibyaCity('أجدابيا', 'Ajdabiya', 30.7554, 20.2263),
  LibyaCity('طبرق', 'Tobruk', 32.0836, 23.9764),
];
