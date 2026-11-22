import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:untitled/services/locale_service.dart';
import 'package:untitled/services/theme_service.dart';

class StyleAndColorsSheet extends StatefulWidget {
  const StyleAndColorsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const StyleAndColorsSheet(),
    );
  }

  @override
  State<StyleAndColorsSheet> createState() => _StyleAndColorsSheetState();
}

class _StyleAndColorsSheetState extends State<StyleAndColorsSheet> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = ThemeService.scaffoldColor(isDark);
    final cardBg = ThemeService.cardColor(isDark);
    final textPrimary = ThemeService.textPrimary(isDark);
    final textSecondary = ThemeService.textSecondary(isDark);

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: textSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr("Style & Colors", "Стиль и цвета"),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tr("Launcher icon and app color theme", "Иконка на рабочем столе и тема приложения"),
                      style: TextStyle(fontSize: 13, color: textSecondary),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: ThemeService.primaryColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.palette_outlined, color: ThemeService.primaryColor, size: 20),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ValueListenableBuilder<AppStyle>(
              valueListenable: ThemeService.currentStyleNotifier,
              builder: (context, activeStyle, _) {
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: ThemeService.styles.length,
                  itemBuilder: (context, index) {
                    final style = ThemeService.styles[index];
                    final isSelected = activeStyle.id == style.id;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: isSelected ? style.primaryColor : Colors.transparent,
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: style.primaryColor.withValues(alpha: 0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                )
                              ]
                            : null,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: () async {
                            HapticFeedback.mediumImpact();
                            if (isSelected) return;

                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) => AlertDialog(
                                backgroundColor: bg,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                title: Text(
                                  tr("Switch style to «${style.name}»?", "Сменить стиль на «${style.name}»?"),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: textPrimary,
                                  ),
                                ),
                                content: Text(
                                  tr(
                                    "The app will briefly minimize to your home screen to update the launcher icon and reopen with the new color theme.",
                                    "Приложение свернётся на главный экран смартфона для обновления иконки лаунчера (как в Telegram), после чего откроется с новым стилем.",
                                  ),
                                  style: TextStyle(fontSize: 14, color: textSecondary, height: 1.35),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text(
                                      tr("Cancel", "Отмена"),
                                      style: TextStyle(color: textSecondary),
                                    ),
                                  ),
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: style.primaryColor,
                                      foregroundColor: style.onPrimaryColor,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    onPressed: () async {
                                      Navigator.pop(context);
                                      await ThemeService.applyStyle(style, restart: true);
                                    },
                                    child: Text(
                                      tr("Apply", "Применить"),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: style.onPrimaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                // Icon preview
                                Container(
                                  width: 68,
                                  height: 68,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: style.primaryColor.withValues(alpha: 0.4),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.15),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.asset(
                                      style.iconPath,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                // Style Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            style.name,
                                            style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w800,
                                              color: textPrimary,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: style.primaryColor,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: textSecondary.withValues(alpha: 0.35),
                                                width: 1,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        style.description,
                                        style: TextStyle(fontSize: 12.5, color: textSecondary, height: 1.25),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Selected status or action
                                if (isSelected)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: style.primaryColor,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.check,
                                          size: 16,
                                          color: style.onPrimaryColor,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          tr("Active", "Активен"),
                                          style: TextStyle(
                                            color: style.onPrimaryColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: 14,
                                    color: textSecondary.withValues(alpha: 0.6),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
