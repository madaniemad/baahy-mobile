import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/strings.dart';
import '../../shared/theme/app_theme.dart';
import '../api/api_client.dart';

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
    // Reconcile the server on startup so users who set their language before this
    // sync existed (or on a reinstall) get it recorded for push notifications.
    _syncLangToBackend(lang);
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lang', locale.languageCode);
    // Keep users.language in sync on the server so PUSH NOTIFICATIONS match the
    // in-app language. Fire-and-forget: only lands when authenticated (the Dio
    // instance attaches the token); a 401/offline is harmless and swallowed.
    _syncLangToBackend(locale.languageCode);
  }

  Future<void> _syncLangToBackend(String lang) async {
    try {
      await ApiClient.instance.dio.put('/auth/profile', data: {'language': lang});
    } catch (_) {/* not logged in / offline — will sync on next toggle or registration */}
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
