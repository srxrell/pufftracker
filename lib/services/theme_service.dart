import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:untitled/services/locale_service.dart';

enum AppStyleId { red, dark, light, gold }

class AppStyle {
  final AppStyleId id;
  final String nameEn;
  final String nameRu;
  final String descriptionEn;
  final String descriptionRu;
  final String iconPath;
  final String alias;
  final Color primaryColor;
  final Color onPrimaryColor;
  final Color accentLight;
  final Color darkScaffold;
  final Color darkCard;
  final Color lightScaffold;
  final Color lightCard;

  const AppStyle({
    required this.id,
    required this.nameEn,
    required this.nameRu,
    required this.descriptionEn,
    required this.descriptionRu,
    required this.iconPath,
    required this.alias,
    required this.primaryColor,
    required this.onPrimaryColor,
    required this.accentLight,
    required this.darkScaffold,
    required this.darkCard,
    required this.lightScaffold,
    required this.lightCard,
  });

  String get name => tr(nameEn, nameRu);
  String get description => tr(descriptionEn, descriptionRu);
}

class ThemeService {
  static const MethodChannel _channel = MethodChannel('com.pufftrack.app/icon');

  static const List<AppStyle> styles = [
    AppStyle(
      id: AppStyleId.red,
      nameEn: 'Coral Red',
      nameRu: 'Красная',
      descriptionEn: 'Signature PuffTrack coral theme',
      descriptionRu: 'Фирменный коралловый стиль PuffTrack',
      iconPath: 'assets/images/icons/icon_red.png',
      alias: 'com.caelis.pufftrack.MainActivityRed',
      primaryColor: Color(0xFFFF5959),
      onPrimaryColor: Colors.white,
      accentLight: Color(0xFFFFEAEA),
      darkScaffold: Color(0xFF171614),
      darkCard: Color(0xFF242220),
      lightScaffold: Color(0xFFF6F2EA),
      lightCard: Colors.white,
    ),
    AppStyle(
      id: AppStyleId.dark,
      nameEn: 'Obsidian Dark',
      nameRu: 'Тёмная',
      descriptionEn: 'Sleek midnight monochrome style',
      descriptionRu: 'Скрытный обсидиановый стиль Midnight',
      iconPath: 'assets/images/icons/icon_dark.png',
      alias: 'com.caelis.pufftrack.MainActivityDark',
      primaryColor: Color(0xFFF0F0F2),
      onPrimaryColor: Color(0xFF111111),
      accentLight: Color(0xFFE5E5EA),
      darkScaffold: Color(0xFF0D0D0E),
      darkCard: Color(0xFF1A1A1D),
      lightScaffold: Color(0xFFE8E8ED),
      lightCard: Colors.white,
    ),
    AppStyle(
      id: AppStyleId.light,
      nameEn: 'Cream Light',
      nameRu: 'Светлая',
      descriptionEn: 'Clean minimalist warm cream aesthetic',
      descriptionRu: 'Чистый лаконичный кремовый минимализм',
      iconPath: 'assets/images/icons/icon_light.png',
      alias: 'com.caelis.pufftrack.MainActivityLight',
      primaryColor: Color(0xFFFF5959),
      onPrimaryColor: Colors.white,
      accentLight: Color(0xFFFFECEC),
      darkScaffold: Color(0xFF1E1D1B),
      darkCard: Color(0xFF2A2724),
      lightScaffold: Color(0xFFFAF7F2),
      lightCard: Colors.white,
    ),
    AppStyle(
      id: AppStyleId.gold,
      nameEn: 'Royal Gold',
      nameRu: 'Золотая',
      descriptionEn: 'VIP gold aesthetic for leaderboard leaders',
      descriptionRu: 'Королевский VIP стиль для лидеров',
      iconPath: 'assets/images/icons/icon_gold.png',
      alias: 'com.caelis.pufftrack.MainActivityGold',
      primaryColor: Color(0xFFFFC107),
      onPrimaryColor: Color(0xFF1A1400),
      accentLight: Color(0xFFFFF3CD),
      darkScaffold: Color(0xFF14120B),
      darkCard: Color(0xFF241F14),
      lightScaffold: Color(0xFFFAF7EE),
      lightCard: Colors.white,
    ),
  ];

  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.light);
  static final ValueNotifier<AppStyle> currentStyleNotifier = ValueNotifier(styles[0]);

  static AppStyle get currentStyle => currentStyleNotifier.value;
  static bool get isDark => themeMode.value == ThemeMode.dark;

  static Color get primaryColor => currentStyle.primaryColor;
  static Color get onPrimaryColor => currentStyle.onPrimaryColor;

  static Color scaffoldColor(bool isDarkMode) {
    return isDarkMode ? currentStyle.darkScaffold : currentStyle.lightScaffold;
  }

  static Color cardColor(bool isDarkMode) {
    return isDarkMode ? currentStyle.darkCard : currentStyle.lightCard;
  }

  static Color textPrimary(bool isDarkMode) {
    return isDarkMode ? const Color(0xFFF6F3EE) : const Color(0xFF141312);
  }

  static Color textSecondary(bool isDarkMode) {
    return isDarkMode ? const Color(0xFFA8A39D) : const Color(0xFF635F59);
  }

  static Color accentLight(bool isDarkMode) {
    return isDarkMode
        ? currentStyle.primaryColor.withValues(alpha: 0.22)
        : currentStyle.accentLight;
  }

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDark = prefs.getBool('app_dark_theme') ?? false;
    themeMode.value = savedDark ? ThemeMode.dark : ThemeMode.light;

    final savedStyleId = prefs.getString('app_style_id') ?? 'red';
    currentStyleNotifier.value = styles.firstWhere(
      (s) => s.id.name == savedStyleId,
      orElse: () => styles[0],
    );
  }

  static Future<void> setDarkTheme(bool enabled) async {
    themeMode.value = enabled ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_dark_theme', enabled);
  }

  static Future<void> applyStyle(AppStyle style, {bool restart = true}) async {
    currentStyleNotifier.value = style;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_style_id', style.id.name);

    try {
      await _channel.invokeMethod('changeIcon', {'alias': style.alias});
    } catch (_) {}

    if (restart) {
      try {
        await _channel.invokeMethod('restartApp');
      } catch (_) {}
    }
  }
}
