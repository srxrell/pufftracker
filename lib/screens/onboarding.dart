import 'package:flutter/material.dart';
import 'package:untitled/screens/authenticator.dart';
import 'package:untitled/services/locale_service.dart';
import 'package:untitled/services/theme_service.dart';

class Onboarding extends StatefulWidget {
  const Onboarding({super.key});

  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = ThemeService.textPrimary(isDark);
    final textSecondary = ThemeService.textSecondary(isDark);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: Image.asset(
                  "assets/images/onboarding_photo.jpg",
                  fit: BoxFit.cover,
                  alignment: Alignment.bottomCenter,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(
                      "Track every puff\nautomatically\nwith AI",
                      "Отслеживай каждую\nзатяжку автоматически\nс помощью ИИ",
                    ),
                    style: TextStyle(
                      fontSize: 33,
                      fontWeight: FontWeight.w900,
                      color: textPrimary,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    tr(
                      "Smart habit analytics & real-time session tracking powered by on-device computer vision.",
                      "Умная аналитика привычек и учёт сессий через локальное компьютерное зрение.",
                    ),
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w400,
                      color: textSecondary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 26),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: ThemeService.primaryColor,
                        foregroundColor: ThemeService.onPrimaryColor,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (context) => const Authenticator()),
                        );
                      },
                      child: Text(
                        tr("Get Started", "Начать"),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: ThemeService.onPrimaryColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
