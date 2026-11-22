import 'package:flutter/material.dart';
import 'package:untitled/screens/home.dart';
import 'package:untitled/screens/leaderboard.dart';
import 'package:untitled/screens/settings.dart';
import 'package:untitled/services/locale_service.dart';
import 'package:untitled/services/theme_service.dart';

class MainNavigation extends StatefulWidget {
  final int initialIndex;
  const MainNavigation({super.key, this.initialIndex = 0});

  static final ValueNotifier<int> currentIndex = ValueNotifier<int>(0);

  static void toTab(int index) {
    currentIndex.value = index;
  }

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  final List<Widget> _screens = const [
    Home(),
    LeaderBoard(),
    Settings(),
  ];

  @override
  void initState() {
    super.initState();
    MainNavigation.currentIndex.value = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final navBg = isDark ? ThemeService.currentStyle.darkCard : ThemeService.currentStyle.lightCard;

    return ValueListenableBuilder<AppStyle>(
      valueListenable: ThemeService.currentStyleNotifier,
      builder: (context, style, _) {
        final selectedIconColor = (!isDark && style.id == AppStyleId.gold)
            ? const Color(0xFF1A1400)
            : style.primaryColor;
        final destinations = [
          NavigationDestination(
            icon: Icon(Icons.home_outlined, color: ThemeService.textSecondary(isDark)),
            selectedIcon: Icon(Icons.home, color: selectedIconColor),
            label: tr("Home", "Главная"),
          ),
          NavigationDestination(
            icon: Icon(Icons.leaderboard_outlined, color: ThemeService.textSecondary(isDark)),
            selectedIcon: Icon(Icons.leaderboard, color: selectedIconColor),
            label: tr("Leaders", "Лидеры"),
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined, color: ThemeService.textSecondary(isDark)),
            selectedIcon: Icon(Icons.settings, color: selectedIconColor),
            label: tr("Settings", "Настройки"),
          ),
        ];

        return ValueListenableBuilder<int>(
          valueListenable: MainNavigation.currentIndex,
          builder: (context, activeIndex, _) {
            final safeIndex = (activeIndex >= 0 && activeIndex < _screens.length)
                ? activeIndex
                : 0;

            return Scaffold(
              backgroundColor: theme.scaffoldBackgroundColor,
              body: IndexedStack(
                index: safeIndex,
                children: _screens,
              ),
              bottomNavigationBar: Container(
                decoration: BoxDecoration(
                  color: navBg,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: NavigationBar(
                    elevation: 0,
                    backgroundColor: navBg,
                    indicatorColor: isDark
                        ? style.primaryColor.withValues(alpha: 0.2)
                        : style.accentLight,
                    selectedIndex: safeIndex,
                    onDestinationSelected: (index) {
                      MainNavigation.currentIndex.value = index;
                    },
                    destinations: destinations,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
