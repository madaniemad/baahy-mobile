import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:baahy_customer/core/models/product.dart';
import 'package:baahy_customer/features/vendor/widgets/sell_banner.dart';
import 'package:baahy_customer/features/vendor/widgets/stores_tab.dart';
import 'package:baahy_customer/shared/theme/app_theme.dart';

/// The "open your store" invite sits in the middle of the stores list, once.
void main() {
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
}
