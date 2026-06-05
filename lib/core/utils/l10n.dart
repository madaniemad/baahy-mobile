import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/strings.dart';
import '../../shared/theme/app_theme.dart';

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('ar')) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final lang = prefs.getString('lang') ?? 'ar';
    state = Locale(lang);
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lang', locale.languageCode);
  }

  bool get isAr => state.languageCode == 'ar';
  void toggle() => setLocale(isAr ? const Locale('en') : const Locale('ar'));
}

extension LocaleExt on BuildContext {
  bool get isAr => Localizations.localeOf(this).languageCode == 'ar';
  String tr(String ar, String en) => isAr ? ar : en;
  AppStrings get s => AppStrings(isAr);
  BaahyColors get col => Theme.of(this).extension<BaahyColors>()!;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

// ── Theme mode ────────────────────────────────────────────────────────────────

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('theme_mode') ?? 'system';
    state = saved == 'dark'  ? ThemeMode.dark
          : saved == 'light' ? ThemeMode.light
          : ThemeMode.system;
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.name);
  }

  void toggle() => setMode(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
}
