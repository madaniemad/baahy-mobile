import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── Baahy theme extension — context-aware color tokens ───────────────────────
class BaahyColors extends ThemeExtension<BaahyColors> {
  final Color bg;
  final Color surface;
  final Color surfaceSoft;
  final Color cardImageBg;
  final Color border;
  final Color borderStrong;
  final Color ink0;
  final Color ink1;
  final Color ink2;
  final Color ink3;
  final Color ink4;
  final Color hilite;

  const BaahyColors({
    required this.bg,
    required this.surface,
    required this.surfaceSoft,
    required this.cardImageBg,
    required this.border,
    required this.borderStrong,
    required this.ink0,
    required this.ink1,
    required this.ink2,
    required this.ink3,
    required this.ink4,
    required this.hilite,
  });

  static const light = BaahyColors(
    bg:            Color(0xFFFFFFFF),
    surface:       Color(0xFFFFFFFF),
    surfaceSoft:   Color(0xFFF8F9F9),
    cardImageBg:   Color(0xFFF4F5F5),
    border:        Color(0xFFE4E7E7),
    borderStrong:  Color(0xFFD8DDDD),
    ink0:          Color(0xFF0A1A1A),
    ink1:          Color(0xFF1A2A2A),
    ink2:          Color(0xFF4A5A5A),
    ink3:          Color(0xFF8A9899),
    ink4:          Color(0xFFC4CCCE),
    hilite:        Color(0xFFFFF8D6),
  );

  static const dark = BaahyColors(
    bg:            Color(0xFF0F1717),
    // Dark mode = "outline" style: card surfaces match the scaffold (no visible
    // fill) and are defined by a white border instead. surfaceSoft stays a hair
    // lighter so inputs / inner boxes remain legible.
    surface:       Color(0xFF0F1717),
    surfaceSoft:   Color(0xFF17201F),
    cardImageBg:   Color(0xFFEDEFEF),
    border:        Color(0x80FFFFFF),
    borderStrong:  Color(0xB3FFFFFF),
    ink0:          Color(0xFFF2F2F2),
    ink1:          Color(0xFFD2D2D2),
    ink2:          Color(0xFFB8BDBF),
    ink3:          Color(0xFFAAB5B7),
    ink4:          Color(0xFF506060),
    hilite:        Color(0xFF2A2518),
  );

  @override
  BaahyColors copyWith({
    Color? bg, Color? surface, Color? surfaceSoft, Color? cardImageBg,
    Color? border, Color? borderStrong,
    Color? ink0, Color? ink1, Color? ink2, Color? ink3, Color? ink4,
    Color? hilite,
  }) => BaahyColors(
    bg:           bg           ?? this.bg,
    surface:      surface      ?? this.surface,
    surfaceSoft:  surfaceSoft  ?? this.surfaceSoft,
    cardImageBg:  cardImageBg  ?? this.cardImageBg,
    border:       border       ?? this.border,
    borderStrong: borderStrong ?? this.borderStrong,
    ink0:         ink0         ?? this.ink0,
    ink1:         ink1         ?? this.ink1,
    ink2:         ink2         ?? this.ink2,
    ink3:         ink3         ?? this.ink3,
    ink4:         ink4         ?? this.ink4,
    hilite:       hilite       ?? this.hilite,
  );

  @override
  BaahyColors lerp(BaahyColors? other, double t) {
    if (other is! BaahyColors) return this;
    return BaahyColors(
      bg:           Color.lerp(bg,           other.bg,           t)!,
      surface:      Color.lerp(surface,      other.surface,      t)!,
      surfaceSoft:  Color.lerp(surfaceSoft,  other.surfaceSoft,  t)!,
      cardImageBg:  Color.lerp(cardImageBg,  other.cardImageBg,  t)!,
      border:       Color.lerp(border,       other.border,       t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      ink0:         Color.lerp(ink0,         other.ink0,         t)!,
      ink1:         Color.lerp(ink1,         other.ink1,         t)!,
      ink2:         Color.lerp(ink2,         other.ink2,         t)!,
      ink3:         Color.lerp(ink3,         other.ink3,         t)!,
      ink4:         Color.lerp(ink4,         other.ink4,         t)!,
      hilite:       Color.lerp(hilite,       other.hilite,       t)!,
    );
  }
}

// ── Baahy design tokens ───────────────────────────────────────────────────────
class AppColors {
  // Brand primary — tiffany cyan for buttons/CTAs
  static const primary     = Color(0xFF1FD7E2);
  // Slightly muted tiffany for use on dark backgrounds (text/icons on dark bg)
  static const primaryDim  = Color(0xFF26C0C7);

  // Returns brightness-appropriate primary: muted on dark, full on light
  static Color adaptive(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? primaryDim : primary;

  // Tiffany — highlight/accent only (active nav, links, selections, spinner)
  static const teal        = Color(0xFF4ECDC4);
  static const teal600     = Color(0xFF3BBDB5);
  static const teal700     = Color(0xFF2A9D94);
  static const teal50      = Color(0xFFEAF9F8);
  static const teal50bg    = Color(0xFFEAF9F8);
  static const teal100     = Color(0xFFC5F0ED);
  static const teal100bg   = Color(0xFFC5F0ED);

  // Ink (text hierarchy)
  static const ink0        = Color(0xFF0A1A1A); // primary text
  static const ink1        = Color(0xFF1A2A2A); // secondary text
  static const ink2        = Color(0xFF4A5A5A); // tertiary text
  static const ink3        = Color(0xFF8A9899); // placeholder
  static const ink4        = Color(0xFFC4CCCE); // hairline

  // Surface
  static const bg          = Color(0xFFFFFFFF);
  static const surface     = Color(0xFFFFFFFF);
  static const surfaceSoft = Color(0xFFF8F9F9);  // lighter containers (search box, etc.)
  static const cardImageBg = Color(0xFFF4F5F5);  // card image section — distinct from white info
  static const border      = Color(0xFFE4E7E7);
  static const borderStrong= Color(0xFFD8DDDD);

  // Semantic
  static const danger      = Color(0xFFf64242); // red  — cancelled, errors, badges
  static const success     = Color(0xFF1F8A5B); // green — delivered, in-stock
  static const warn        = Color(0xFFD97757); // amber — pending, low-stock
  static const info        = Color(0xFF3B82F6); // blue  — shipped/in-delivery
  static const gold        = Color(0xFFD4A82E); // gold  — stars, rating
  static const hilite      = Color(0xFFFFF8D6);
}

class AppRadius {
  static const sm  = Radius.circular(12);
  static const md  = Radius.circular(12);
  static const lg  = Radius.circular(12);
  static const xl  = Radius.circular(20);
  static const pill= Radius.circular(9999);

  static const double card = 12; // used as double in ClipRRect
  static const cardRadius  = BorderRadius.all(Radius.circular(card));

  static const smBorder  = BorderRadius.all(sm);
  static const mdBorder  = BorderRadius.all(md);
  static const lgBorder  = BorderRadius.all(lg);
  static const xlBorder  = BorderRadius.all(xl);
  static const pillBorder= BorderRadius.all(pill);
}

class AppShadows {
  static const shadowCard = [ // alias for product/content cards
    BoxShadow(color: Color(0x0A0F1E1E), blurRadius: 8, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x070F1E1E), blurRadius: 2, offset: Offset(0, 1)),
  ];
  static const shadow1 = shadowCard;
  static const shadow2 = [
    BoxShadow(color: Color(0x140F1E1E), blurRadius: 12, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x0A0F1E1E), blurRadius: 3, offset: Offset(0, 1)),
  ];
  static const shadowPop = [
    BoxShadow(color: Color(0x140F1E1E), blurRadius: 30, offset: Offset(0, -8)),
  ];
  // Lifted card shadow — 3D depth effect used across all main page cards
  static const shadowLifted = [
    BoxShadow(color: Color(0x11000000), blurRadius: 16, offset: Offset(0, 5), spreadRadius: -1),
    BoxShadow(color: Color(0x07000000), blurRadius:  4, offset: Offset(0, 1)),
  ];
  // Matching border for lifted cards (lighter than theme border)
  static const liftedBorderColor = Color(0xFFF1F3F3);
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    extensions: const [BaahyColors.light],
    colorScheme: ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.ink0,
      onSecondary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.ink0,
      error: AppColors.danger,
      // ignore: deprecated_member_use
      background: AppColors.bg,
    ),
    scaffoldBackgroundColor: AppColors.bg,
    fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
    textTheme: const TextTheme(
      displayLarge : TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.ink0, letterSpacing: -0.5),
      headlineLarge: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.ink0),
      headlineMedium:TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink0),
      titleLarge   : TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink0),
      titleMedium  : TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink0),
      bodyLarge    : TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.ink1),
      bodyMedium   : TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.ink1),
      bodySmall    : TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 11, fontWeight: FontWeight.w400, color: AppColors.ink2),
      labelLarge   : TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink0),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.ink0,
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 15, fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink1,
        side: const BorderSide(color: AppColors.borderStrong, width: 1.5),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 15, fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceSoft,
      border: OutlineInputBorder(
        borderRadius: AppRadius.smBorder,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.smBorder,
        borderSide: const BorderSide(color: AppColors.borderStrong),
      ),
      hintStyle: const TextStyle(color: AppColors.ink3, fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal']),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.ink0,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink0,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.transparent,
      selectedItemColor: AppColors.ink0,
      unselectedItemColor: AppColors.ink3,
      selectedLabelStyle: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 10, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 10, fontWeight: FontWeight.w600),
      type: BottomNavigationBarType.fixed,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, space: 0, thickness: 1),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}

ThemeData buildDarkTheme() {
  const d = BaahyColors.dark;
  return ThemeData(
    useMaterial3: true,
    extensions: const [BaahyColors.dark],
    colorScheme: ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: d.ink0,
      onSecondary: d.surface,
      surface: d.surface,
      onSurface: d.ink0,
      error: AppColors.danger,
    ),
    scaffoldBackgroundColor: d.bg,
    fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
    textTheme: TextTheme(
      displayLarge : TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 32, fontWeight: FontWeight.w800, color: d.ink0, letterSpacing: -0.5),
      headlineLarge: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 24, fontWeight: FontWeight.w700, color: d.ink0),
      headlineMedium:TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 20, fontWeight: FontWeight.w700, color: d.ink0),
      titleLarge   : TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 17, fontWeight: FontWeight.w700, color: d.ink0),
      titleMedium  : TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 15, fontWeight: FontWeight.w600, color: d.ink0),
      bodyLarge    : TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 15, fontWeight: FontWeight.w400, color: d.ink1),
      bodyMedium   : TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 13, fontWeight: FontWeight.w400, color: d.ink1),
      bodySmall    : TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 11, fontWeight: FontWeight.w400, color: d.ink2),
      labelLarge   : TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 15, fontWeight: FontWeight.w700, color: d.ink0),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 15, fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: d.ink1,
        side: BorderSide(color: d.borderStrong, width: 1.5),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 15, fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: d.surfaceSoft,
      border: OutlineInputBorder(
        borderRadius: AppRadius.smBorder,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.smBorder,
        borderSide: BorderSide(color: d.borderStrong),
      ),
      hintStyle: TextStyle(color: d.ink3, fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal']),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: d.surface,
      foregroundColor: d.ink0,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 17, fontWeight: FontWeight.w700, color: d.ink0,
      ),
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Colors.transparent,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: d.ink3,
      selectedLabelStyle: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 10, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 10, fontWeight: FontWeight.w600),
      type: BottomNavigationBarType.fixed,
    ),
    dividerTheme: DividerThemeData(color: d.border, space: 0, thickness: 1),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
