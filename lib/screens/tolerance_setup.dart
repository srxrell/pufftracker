import 'package:flutter/material.dart';
import 'package:untitled/screens/main_navigation.dart';
import 'package:untitled/services/locale_service.dart';
import 'package:untitled/services/theme_service.dart';
import 'package:untitled/services/tolerance_service.dart';

class ToleranceSetup extends StatefulWidget {
  final bool isFromSettings;

  const ToleranceSetup({super.key, this.isFromSettings = false});

  @override
  State<ToleranceSetup> createState() => _ToleranceSetupState();
}

class _ToleranceSetupState extends State<ToleranceSetup> {
  int _hookah = ToleranceService.hookahVal;
  int _vape = ToleranceService.vapeVal;
  int _cig = ToleranceService.cigVal;

  double get _calculatedAverage {
    final List<int> values = [];
    if (_hookah > 0) values.add(_hookah);
    if (_vape > 0) values.add(_vape);
    if (_cig > 0) values.add(_cig);

    if (values.isEmpty) return 12.0;
    return (values.reduce((a, b) => a + b) / values.length).clamp(4.0, 30.0);
  }

  Future<void> _save() async {
    await ToleranceService.saveCalibration(
      hookah: _hookah,
      vape: _vape,
      cig: _cig,
    );

    if (!mounted) return;

    if (widget.isFromSettings) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const MainNavigation()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = ThemeService.cardColor(isDark);
    final textPrimary = ThemeService.textPrimary(isDark);
    final textSecondary = ThemeService.textSecondary(isDark);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          tr("Intensity Calibration", "Калибровка «Даст в бошку»"),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              tr("Set your personal threshold", "Настрой свою планку"),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: textPrimary,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr(
                "Select how many puffs usually fill your session intensity meter to 100%.",
                "Отметь, со скольких затяжек тебя обычно накрывает. Мы высчитаем средний порог для твоей шкалы.",
              ),
              style: TextStyle(
                fontSize: 15,
                color: textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),
            _buildDeviceSection(
              title: tr("Hookah", "Кальян"),
              icon: Icons.cloud_outlined,
              cardBg: cardBg,
              textPrimary: textPrimary,
              currentVal: _hookah,
              options: [
                {"label": tr("Don't use", "Не курю"), "val": 0},
                {"label": tr("5–8 puffs", "С 5–8 тяг"), "val": 7},
                {"label": tr("12–15 puffs", "С 12–15 тяг"), "val": 14},
                {"label": tr("25+ puffs", "С 25+ тяг"), "val": 25},
                {"label": tr("High tolerance", "Не дает"), "val": 100}
              ],
              onSelect: (v) => setState(() => _hookah = v),
            ),
            const SizedBox(height: 16),
            _buildDeviceSection(
              title: tr("Pod / Vaporizer", "Ашка / Вейп / Под"),
              icon: Icons.vape_free,
              cardBg: cardBg,
              textPrimary: textPrimary,
              currentVal: _vape,
              options: [
                {"label": tr("Don't use", "Не парю"), "val": 0},
                {"label": tr("3–5 puffs", "С 3–5 тяг"), "val": 4},
                {"label": tr("8–12 puffs", "С 8–12 тяг"), "val": 10},
                {"label": tr("20+ puffs", "С 20+ тяг"), "val": 20},
                {"label": tr("High tolerance", "Не дает"), "val": 100}
              ],
              onSelect: (v) => setState(() => _vape = v),
            ),
            const SizedBox(height: 16),
            _buildDeviceSection(
              title: tr("Traditional Filter", "Сигареты"),
              icon: Icons.smoking_rooms_outlined,
              cardBg: cardBg,
              textPrimary: textPrimary,
              currentVal: _cig,
              options: [
                {"label": tr("Don't use", "Не курю"), "val": 0},
                {"label": tr("4–6 puffs", "С 4–6 тяг"), "val": 5},
                {"label": tr("8–10 puffs", "С 8–10 тяг"), "val": 9},
                {"label": tr("15+ puffs", "С 15+ тяг"), "val": 16},
                {"label": tr("High tolerance", "Не дает"), "val": 100}
              ],
              onSelect: (v) => setState(() => _cig = v),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ThemeService.accentLight(isDark),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.speed,
                      color: ThemeService.primaryColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr("Average intensity threshold:", "Средний порог накура:"),
                          style: TextStyle(fontSize: 13, color: textSecondary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tr(
                            "~${_calculatedAverage.round()} puffs to 100%",
                            "~${_calculatedAverage.round()} затяжек до 100%",
                          ),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
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
                onPressed: _save,
                child: Text(
                  widget.isFromSettings
                      ? tr("Save", "Сохранить")
                      : tr("Apply & Continue", "Применить и начать"),
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
    );
  }

  Widget _buildDeviceSection({
    required String title,
    required IconData icon,
    required Color cardBg,
    required Color textPrimary,
    required int currentVal,
    required List<Map<String, dynamic>> options,
    required Function(int) onSelect,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: ThemeService.primaryColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((opt) {
              final isSelected = currentVal == opt['val'];
              final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
              return ChoiceChip(
                label: Text(opt['label'] as String),
                selected: isSelected,
                elevation: 0,
                side: BorderSide.none,
                labelStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? (isDarkTheme ? Colors.white : Colors.black) : textPrimary,
                ),
                backgroundColor: ThemeService.scaffoldColor(isDarkTheme),
                selectedColor: ThemeService.accentLight(isDarkTheme),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (_) => onSelect(opt['val'] as int),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
