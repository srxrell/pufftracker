import 'package:flutter/material.dart';
import 'package:untitled/screens/age_gate_screen.dart';
import 'package:untitled/screens/main_navigation.dart';
import 'package:untitled/screens/onboarding.dart';
import 'package:untitled/screens/tolerance_setup.dart';
import 'package:untitled/services/auth_service.dart';
import 'package:untitled/services/compliance_service.dart';
import 'package:untitled/services/locale_service.dart';
import 'package:untitled/services/theme_service.dart';
import 'package:untitled/services/tolerance_service.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  Widget _getPostAgeGateScreen() {
    if (AuthService.currentUser != null) {
      if (ToleranceService.hasCompletedSetup) {
        return const MainNavigation();
      }
      return const ToleranceSetup();
    }
    return const Onboarding();
  }

  Widget _getInitialScreen() {
    final next = _getPostAgeGateScreen();
    if (!ComplianceService.hasVerifiedAge) {
      return AgeGateScreen(nextScreen: next);
    }
    return next;
  }

  SegmentedButtonThemeData _buildSegmentedTheme(AppStyle style, bool isDark) {
    return SegmentedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return isDark ? style.primaryColor : const Color(0xFF141312);
          }
          return isDark ? const Color(0xFFA8A39D) : const Color(0xFF635F59);
        }),
        iconColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return isDark ? style.primaryColor : const Color(0xFF141312);
          }
          return isDark ? const Color(0xFFA8A39D) : const Color(0xFF635F59);
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LocaleService.localeNotifier,
      builder: (context, locale, _) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: ThemeService.themeMode,
          builder: (context, mode, child) {
            return ValueListenableBuilder<AppStyle>(
              valueListenable: ThemeService.currentStyleNotifier,
              builder: (context, style, _) {
                return MaterialApp(
                  debugShowCheckedModeBanner: false,
                  title: 'PuffTrack',
                  themeMode: mode,
                  theme: ThemeData(
                    useMaterial3: true,
                    brightness: Brightness.light,
                    segmentedButtonTheme: _buildSegmentedTheme(style, false),
                    scaffoldBackgroundColor: style.lightScaffold,
                    colorScheme: ColorScheme.fromSeed(
                      seedColor: style.primaryColor,
                      primary: style.primaryColor,
                      onPrimary: style.onPrimaryColor,
                      surface: style.lightScaffold,
                      brightness: Brightness.light,
                    ),
                  ),
                  darkTheme: ThemeData(
                    useMaterial3: true,
                    brightness: Brightness.dark,
                    segmentedButtonTheme: _buildSegmentedTheme(style, true),
                    scaffoldBackgroundColor: style.darkScaffold,
                    colorScheme: ColorScheme.fromSeed(
                      seedColor: style.primaryColor,
                      primary: style.primaryColor,
                      onPrimary: style.onPrimaryColor,
                      surface: style.darkCard,
                      brightness: Brightness.dark,
                    ),
                  ),
                  home: _getInitialScreen(),
                );
              },
            );
          },
        );
      },
    );
  }
}
