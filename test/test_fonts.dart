import 'package:flutter/services.dart';

/// Flutter's test runner draws every glyph as a square as wide as the font size unless real fonts
/// are loaded, which makes long Arabic text look several times wider than it is and produces
/// false overflow failures. Load the app's own fonts so layout tests measure what users see.
Future<void> loadAppFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(rootBundle.load(f));
    }
    await loader.load();
  }

  await load('Manrope', ['assets/fonts/Manrope-VF.ttf']);
  await load('Tajawal', [
    'assets/fonts/Tajawal-Regular.ttf',
    'assets/fonts/Tajawal-Medium.ttf',
    'assets/fonts/Tajawal-Bold.ttf',
    'assets/fonts/Tajawal-ExtraBold.ttf',
  ]);
  await load('PlusJakartaSans', [
    'assets/fonts/PlusJakartaSans-Regular.ttf',
    'assets/fonts/PlusJakartaSans-SemiBold.ttf',
    'assets/fonts/PlusJakartaSans-Bold.ttf',
  ]);
}
