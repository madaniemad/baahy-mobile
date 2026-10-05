import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_fonts.dart';

import 'package:baahy_customer/core/models/product.dart';
import 'package:baahy_customer/features/vendor/widgets/sell_banner.dart';
import 'package:baahy_customer/features/vendor/widgets/stores_tab.dart';
import 'package:baahy_customer/shared/theme/app_theme.dart';

/// The "open your store" invite sits in the middle of the stores list, once.
void main() {
  setUpAll(loadAppFonts);
  List<StoreEntry> stores(int n) => [
        for (int i = 1; i <= n; i++)
          StoreEntry(
            Vendor(id: i, storeName: 'Store $i', storeNameAr: 'متجر $i'),
            10,
            departments: const [('نساء', 'Women')],
          ),
      ];

  Future<void> pump(WidgetTester t, int n) async {
    await t.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(ProviderScope(
      overrides: [
        storesProvider.overrideWith((ref, id) async => stores(n)),
        storePreviewProvider.overrideWith((ref, key) async => <String>[]),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const Scaffold(body: StoresTab(categories: [], query: '')),
      ),
    ));
    await t.pumpAndSettle();
  }

  testWidgets('banner appears once, between the stores, for a long list',
      (t) async {
    await pump(t, 10);
    final banner = find.byType(SellOnBaahyBanner);
    // Not at the top of the list, and not duplicated: it is reached by scrolling down.
    expect(banner, findsNothing);
    await t.scrollUntilVisible(banner, 400,
        scrollable: find.byType(Scrollable).first);
    expect(banner, findsOneWidget);
  });

  testWidgets('banner still shows for a very short list', (t) async {
    await pump(t, 1);
    expect(find.byType(SellOnBaahyBanner), findsOneWidget);
  });

  // Long names with no / many departments on the narrowest phone, both languages: no overflow.
  for (final loc in const [Locale('ar'), Locale('en')]) {
    testWidgets('store cards do not overflow at 320pt (${loc.languageCode})', (t) async {
      await t.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => t.binding.setSurfaceSize(null));
      final long = [
        StoreEntry(
          const Vendor(
              id: 1,
              storeName: 'An Extremely Long Store Name That Keeps Going And Going',
              storeNameAr: 'متجر باسم طويل جداً جداً يستمر في الطول بلا نهاية أبداً'),
          10,
        ),
        StoreEntry(
          const Vendor(
              id: 2,
              storeName: 'Another Quite Long Store Name Here Too',
              storeNameAr: 'متجر آخر باسم طويل أيضاً هنا'),
          10,
          reviewsCount: 12,
          departments: const [
            ('الجمال والعناية الشخصية', 'Beauty and Personal Care'),
            ('البيت والأجهزة المنزلية', 'Home and Appliances'),
            ('نساء', 'Women'),
            ('رجال', 'Men'),
          ],
        ),
      ];
      await t.pumpWidget(ProviderScope(
        overrides: [
          storesProvider.overrideWith((ref, id) async => long),
          storePreviewProvider.overrideWith((ref, key) async => <String>[]),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          locale: loc,
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const Scaffold(body: StoresTab(categories: [], query: '')),
        ),
      ));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  }
}
