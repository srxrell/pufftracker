import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:untitled/screens/legal_screen.dart';
import 'package:untitled/services/compliance_service.dart';
import 'package:untitled/services/locale_service.dart';
import 'package:untitled/services/theme_service.dart';

class AgeGateScreen extends StatelessWidget {
  final Widget nextScreen;

  const AgeGateScreen({super.key, required this.nextScreen});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = ThemeService.cardColor(isDark);
    final textPrimary = ThemeService.textPrimary(isDark);
    final textSecondary = ThemeService.textSecondary(isDark);
    final primaryColor = ThemeService.primaryColor;
    final onPrimary = ThemeService.onPrimaryColor;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: ThemeService.accentLight(isDark),
                  shape: BoxShape.circle,
                  border: Border.all(color: primaryColor, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  "18+",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                tr("Age Verification", "Подтверждение возраста"),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                tr(
                  "PuffTrack is an AI habit tracker designed strictly for adults (18 years of age or older).",
                  "PuffTrack — это ИИ-трекер привычек, предназначенный строго для совершеннолетних (18+).",
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15.5,
                  color: textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined, color: primaryColor, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        tr(
                          "On-device AI: Camera video for puff detection is processed locally on your phone and is never stored or uploaded.",
                          "Локальный ИИ: Видео с камеры для детекции обрабатывается локально на устройстве и нигде не сохраняется.",
                        ),
                        style: TextStyle(
                          fontSize: 12.5,
                          color: textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const LegalScreen(initialTab: LegalDocType.privacy),
                        ),
                      );
                    },
                    child: Text(
                      tr("Privacy Policy", "Конфиденциальность"),
                      style: TextStyle(fontSize: 13, color: textSecondary),
                    ),
                  ),
                  Text("•", style: TextStyle(color: textSecondary)),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const LegalScreen(initialTab: LegalDocType.terms),
                        ),
                      );
                    },
                    child: Text(
                      tr("Terms of Use", "Условия (puff.gg)"),
                      style: TextStyle(fontSize: 13, color: textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: onPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () async {
                    await ComplianceService.setAgeVerified();
                    if (!context.mounted) return;
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => nextScreen),
                    );
                  },
                  child: Text(
                    tr("I am 18 or older", "Мне уже есть 18 лет"),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: onPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: () {
                    SystemNavigator.pop();
                  },
                  child: Text(
                    tr("I am under 18 (Exit)", "Мне нет 18 лет (Выйти)"),
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
