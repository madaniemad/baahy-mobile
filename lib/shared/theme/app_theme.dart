import 'package:flutter/material.dart';

// ── Baahy design tokens ───────────────────────────────────────────────────────
class AppColors {
  // Brand primary — tiffany cyan for buttons/CTAs
  static const primary     = Color(0xFF32DDE5);

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
  static const bg          = Color(0xFFFAFBFC);  // slightly lighter than gray-50
  static const surface     = Color(0xFFFFFFFF);
  static const surfaceSoft = Color(0xFFF6F7F7);  // lighter containers (search box, etc.)
  static const cardImageBg = Color(0xFFEDEFEF);  // card image section — distinct from white info
  static const border      = Color(0xFFECEFEF);
  static const borderStrong= Color(0xFFD8DDDD);

  // Semantic
  static const danger      = Color(0xFFE2553F); // red  — cancelled, errors, badges
  static const success     = Color(0xFF1F8A5B); // green — delivered, in-stock
  static const warn        = Color(0xFFD97757); // amber — pending, low-stock
  static const info        = Color(0xFF3B82F6); // blue  — shipped/in-delivery
  static const gold        = Color(0xFFD4A82E); // gold  — stars, rating
  static const hilite      = Color(0xFFFFF8D6);
}

class AppRadius {
  static const sm  = Radius.circular(10);
  static const md  = Radius.circular(10);
  static const lg  = Radius.circular(10);
  static const xl  = Radius.circular(10);
  static const pill= Radius.circular(9999);

  static const double card = 10; // used as double in ClipRRect
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
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.ink0,
      secondary: AppColors.ink0,
      onSecondary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.ink0,
      error: AppColors.danger,
      // ignore: deprecated_member_use
      background: AppColors.bg,
    ),
    scaffoldBackgroundColor: AppColors.bg,
    fontFamily: 'Cairo',
    textTheme: const TextTheme(
      displayLarge : TextStyle(fontFamily: 'Cairo', fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.ink0, letterSpacing: -0.5),
      headlineLarge: TextStyle(fontFamily: 'Cairo', fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.ink0),
      headlineMedium:TextStyle(fontFamily: 'Cairo', fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink0),
      titleLarge   : TextStyle(fontFamily: 'Cairo', fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink0),
      titleMedium  : TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink0),
      bodyLarge    : TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.ink1),
      bodyMedium   : TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.ink1),
      bodySmall    : TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.w400, color: AppColors.ink2),
      labelLarge   : TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink0),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.ink0,
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink1,
        side: const BorderSide(color: AppColors.borderStrong, width: 1.5),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w700),
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
      hintStyle: const TextStyle(color: AppColors.ink3, fontFamily: 'Cairo'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.ink0,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Cairo', fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink0,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.transparent,
      selectedItemColor: AppColors.ink0,
      unselectedItemColor: AppColors.ink3,
      selectedLabelStyle: TextStyle(fontFamily: 'Cairo', fontSize: 10, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontFamily: 'Cairo', fontSize: 10, fontWeight: FontWeight.w600),
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
