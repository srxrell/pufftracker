import 'package:flutter/material.dart';
import 'package:untitled/services/locale_service.dart';
import 'package:untitled/services/mascot_service.dart';
import 'package:untitled/services/theme_service.dart';

class MascotWardrobeSheet extends StatefulWidget {
  const MascotWardrobeSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const MascotWardrobeSheet(),
    );
  }

  @override
  State<MascotWardrobeSheet> createState() => _MascotWardrobeSheetState();
}

class _MascotWardrobeSheetState extends State<MascotWardrobeSheet> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = ThemeService.scaffoldColor(isDark);
    final cardBg = ThemeService.cardColor(isDark);
    final textPrimary = ThemeService.textPrimary(isDark);
    final textSecondary = ThemeService.textSecondary(isDark);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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
                      tr("Puffy's Wardrobe", "Гардероб Паффи"),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr("Skins multiply your puff style points", "Скины дают буст к очкам затяжек"),
                      style: TextStyle(fontSize: 13, color: textSecondary),
                    ),
                  ],
                ),
                ValueListenableBuilder<int>(
                  valueListenable: MascotService.pointsNotifier,
                  builder: (context, pts, _) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: ThemeService.accentLight(isDark),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: ThemeService.primaryColor, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.bolt, color: ThemeService.primaryColor, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            "$pts",
                            style: TextStyle(
                              color: ThemeService.primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ValueListenableBuilder<MascotSkin>(
              valueListenable: MascotService.currentSkinNotifier,
              builder: (context, activeSkin, _) {
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: MascotService.skins.length,
                  itemBuilder: (context, index) {
                    final skin = MascotService.skins[index];
                    final isUnlocked = MascotService.unlockedSkinIds.contains(skin.id);
                    final isSelected = activeSkin.id == skin.id;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: isSelected ? skin.accentColor : Colors.transparent,
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: skin.accentColor.withValues(alpha: 0.25),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 82,
                            height: 82,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF171614) : Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: skin.accentColor.withValues(alpha: 0.5),
                                width: 1.5,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.asset(
                                skin.imagePath,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Icon(
                                  Icons.cloud,
                                  size: 42,
                                  color: skin.accentColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      skin.name,
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        color: textPrimary,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: skin.accentColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        "x${skin.multiplier}",
                                        style: TextStyle(
                                          color: skin.accentColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  skin.description,
                                  style: TextStyle(fontSize: 12, color: textSecondary, height: 1.25),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  skin.perkText,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: skin.accentColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isSelected)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: skin.accentColor,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check,
                                    size: 16,
                                    color: skin.accentColor.computeLuminance() > 0.5
                                        ? const Color(0xFF111111)
                                        : Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    tr("Active", "Выбран"),
                                    style: TextStyle(
                                      color: skin.accentColor.computeLuminance() > 0.5
                                          ? const Color(0xFF111111)
                                          : Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (isUnlocked)
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: skin.accentColor),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              onPressed: () {
                                MascotService.selectSkin(skin);
                                setState(() {});
                              },
                              child: Text(
                                tr("Equip", "Надеть"),
                                style: TextStyle(
                                  color: skin.accentColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          else
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: ThemeService.primaryColor,
                                foregroundColor: ThemeService.onPrimaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                              onPressed: () async {
                                final success = await MascotService.unlockSkin(skin);
                                if (!context.mounted) return;
                                if (!success) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        tr(
                                          "Not enough points! Need ${skin.price}",
                                          "Не хватает очков! Нужно ${skin.price}",
                                        ),
                                      ),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                } else {
                                  setState(() {});
                                }
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.lock_open, size: 14, color: ThemeService.onPrimaryColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    "${skin.price}",
                                    style: TextStyle(
                                      color: ThemeService.onPrimaryColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
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
