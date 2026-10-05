import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_fonts.dart';
import 'package:baahy_customer/features/vendor/widgets/sell_banner.dart';
import 'package:baahy_customer/shared/theme/app_theme.dart';

/// The banner sits on Home and in the Stores list: it must never overflow, at the narrowest phone,
/// in either language, nor with large system text.
void main() {
  setUpAll(loadAppFonts);
  Future<void> pump(WidgetTester t, {required Locale locale, required Size size, double scale = 1.0}) async {
    await t.binding.setSurfaceSize(size);
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      locale: locale,
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(16), child: const SellOnBaahyBanner()),
      ),
    ));
    await t.pumpAndSettle();
  }

  for (final size in const [Size(320, 568), Size(375, 812), Size(430, 932)]) {
    for (final locale in const [Locale('ar'), Locale('en')]) {
      for (final scale in const [1.0, 1.5]) {
        testWidgets('no overflow ${size.width.toInt()}pt ${locale.languageCode} x$scale', (t) async {
          await pump(t, locale: locale, size: size, scale: scale);
          expect(t.takeException(), isNull);
          expect(find.text(locale.languageCode == 'ar' ? 'افتح متجرك الآن' : 'Open your store now'),
              findsOneWidget);
        });
      }
    }
  }
}
