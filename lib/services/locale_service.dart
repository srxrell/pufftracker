import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleService {
  /// Default language is English ('en'). Users can switch to Russian ('ru') in Settings.
  static final ValueNotifier<String> localeNotifier = ValueNotifier<String>('en');

  static String get currentLocale => localeNotifier.value;
  static bool get isEn => localeNotifier.value == 'en';

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('app_locale') ?? 'en';
    localeNotifier.value = (saved == 'ru') ? 'ru' : 'en';
  }

  static Future<void> setLocale(String langCode) async {
    final normalized = (langCode == 'ru') ? 'ru' : 'en';
    localeNotifier.value = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_locale', normalized);
  }
}

/// Global helper to return English or Russian string based on current locale.
String tr(String en, String ru) {
  return LocaleService.isEn ? en : ru;
}
