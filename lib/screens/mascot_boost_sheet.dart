import 'package:flutter/material.dart';
import 'package:untitled/services/locale_service.dart';
import 'package:untitled/services/mascot_service.dart';
import 'package:untitled/services/theme_service.dart';

class MascotBoostSheet extends StatefulWidget {
  final int currentPuffs;
  final Function(int newTotal) onPuffsBoosted;

  const MascotBoostSheet({
    super.key,
    required this.currentPuffs,
    required this.onPuffsBoosted,
  });

  static Future<void> show(
    BuildContext context, {
    required int currentPuffs,
    required Function(int newTotal) onPuffsBoosted,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MascotBoostSheet(
        currentPuffs: currentPuffs,
        onPuffsBoosted: onPuffsBoosted,
      ),
    );
  }

  @override
  State<MascotBoostSheet> createState() => _MascotBoostSheetState();
}

class _MascotBoostSheetState extends State<MascotBoostSheet> {
  late int _localPuffs;

  @override
  void initState() {
    super.initState();
    _localPuffs = widget.currentPuffs;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? ThemeService.currentStyle.darkCard : ThemeService.currentStyle.lightCard;
    final cardBg = isDark ? ThemeService.currentStyle.darkScaffold : const Color(0xFFF7F4EE);
    final textPrimary = ThemeService.textPrimary(isDark);
    final textSecondary = ThemeService.textSecondary(isDark);
    final primaryColor = ThemeService.primaryColor;
    final onPrimary = ThemeService.onPrimaryColor;

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
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
                      tr("Leaderboard Turbo Boost", "Турбо-Буст Лидерборда"),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr("Trade Puffy points for leaderboard puffs", "Обменяй очки Паффи на затяжки в топ"),
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
                        color: primaryColor.withValues(alpha: isDark ? 0.22 : 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: primaryColor, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.bolt, color: primaryColor, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            "$pts",
                            style: TextStyle(
                              color: primaryColor,
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
          // User current standing pill
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.leaderboard, color: ThemeService.primaryColor, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      tr("Current total:", "Текущий рекорд:"),
                      style: TextStyle(color: textSecondary, fontSize: 14),
                    ),
                  ],
                ),
                Text(
                  tr("$_localPuffs puffs", "$_localPuffs затяжек"),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 18),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: MascotService.boosts.length,
              itemBuilder: (context, index) {
                final boost = MascotService.boosts[index];

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: ThemeService.primaryColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ThemeService.primaryColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(boost.icon, color: ThemeService.primaryColor, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              boost.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tr(
                                "New total: ${_localPuffs + boost.puffsToAdd} puffs",
                                "Станет: ${_localPuffs + boost.puffsToAdd} затяжек в топе",
                              ),
                              style: TextStyle(fontSize: 12, color: textSecondary),
                            ),
                          ],
                        ),
                      ),
                      ValueListenableBuilder<int>(
                        valueListenable: MascotService.pointsNotifier,
                        builder: (context, currentPts, _) {
                          final canAfford = currentPts >= boost.pointsCost;

                          return FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: canAfford
                                  ? primaryColor
                                  : (isDark ? const Color(0xFF3E3C39) : Colors.grey.shade400),
                              foregroundColor: canAfford ? onPrimary : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                            onPressed: !canAfford
                                ? null
                                : () async {
                                    final success = await MascotService.buyBoost(
                                      boost: boost,
                                      onPuffsUpdated: (newCount) {
                                        setState(() {
                                          _localPuffs = newCount;
                                        });
                                        widget.onPuffsBoosted(newCount);
                                      },
                                    );

                                    if (!context.mounted) return;
                                    if (success) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              const Icon(Icons.trending_up, color: Colors.white),
                                              const SizedBox(width: 8),
                                              Text(
                                                tr(
                                                  "Boost +${boost.puffsToAdd} applied! Total: $_localPuffs",
                                                  "Буст +${boost.puffsToAdd} применен! Теперь в топе $_localPuffs",
                                                ),
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                          backgroundColor: Colors.green.shade700,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.bolt, size: 14, color: canAfford ? onPrimary : Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  "${boost.pointsCost}",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: canAfford ? onPrimary : Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
