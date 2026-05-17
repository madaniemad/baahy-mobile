import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
}
