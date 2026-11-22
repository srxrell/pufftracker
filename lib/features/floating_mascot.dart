import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:untitled/screens/mascot_boost_sheet.dart';
import 'package:untitled/screens/mascot_wardrobe_sheet.dart';
import 'package:untitled/services/locale_service.dart';
import 'package:untitled/services/mascot_service.dart';
import 'package:untitled/services/theme_service.dart';

class FloatingMascot extends StatefulWidget {
  final int currentPuffs;
  final Function(int newTotal) onPuffsBoosted;

  const FloatingMascot({
    super.key,
    required this.currentPuffs,
    required this.onPuffsBoosted,
  });

  @override
  State<FloatingMascot> createState() => _FloatingMascotState();
}

class _FloatingMascotState extends State<FloatingMascot>
    with TickerProviderStateMixin {
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  bool _isBubbleExpanded = true;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: -3.0, end: 3.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOutSine),
    );

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _bounceAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _floatController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  void _onTapMascot() {
    HapticFeedback.lightImpact();
    _bounceController.forward().then((_) => _bounceController.reverse());
    MascotService.triggerRandomRemark();
    if (!_isBubbleExpanded) {
      setState(() => _isBubbleExpanded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bubbleBg = ThemeService.cardColor(isDark);
    final textPrimary = ThemeService.textPrimary(isDark);
    final textSecondary = ThemeService.textSecondary(isDark);
    final primaryColor = ThemeService.primaryColor;

    return ValueListenableBuilder<MascotSkin>(
      valueListenable: MascotService.currentSkinNotifier,
      builder: (context, currentSkin, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: _isBubbleExpanded
                      ? Container(
                          margin: const EdgeInsets.only(bottom: 6, right: 8),
                          padding: const EdgeInsets.fromLTRB(12, 9, 10, 8),
                          decoration: BoxDecoration(
                            color: bubbleBg,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(18),
                              topRight: Radius.circular(18),
                              bottomLeft: Radius.circular(18),
                              bottomRight: Radius.circular(4),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ValueListenableBuilder<PuffComment>(
                            valueListenable: MascotService.lastCommentNotifier,
                            builder: (context, comment, _) {
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    comment.text,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: textPrimary,
                                      height: 1.25,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      _buildMiniAction(
                                        icon: Icons.checkroom_rounded,
                                        label: tr("Skins", "Скины"),
                                        color: textSecondary,
                                        bgColor: isDark
                                            ? Colors.white.withValues(alpha: 0.06)
                                            : Colors.black.withValues(alpha: 0.05),
                                        onTap: () => MascotWardrobeSheet.show(context),
                                      ),
                                      const SizedBox(width: 6),
                                      _buildMiniAction(
                                        icon: Icons.bolt_rounded,
                                        label: tr("Boost", "Буст"),
                                        color: primaryColor,
                                        bgColor: primaryColor.withValues(alpha: 0.14),
                                        onTap: () => MascotBoostSheet.show(
                                          context,
                                          currentPuffs: widget.currentPuffs,
                                          onPuffsBoosted: widget.onPuffsBoosted,
                                        ),
                                      ),
                                      if (comment.pointsAwarded > 0) ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          "+${comment.pointsAwarded}⚡",
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: primaryColor,
                                          ),
                                        ),
                                      ],
                                      const Spacer(),
                                      GestureDetector(
                                        onTap: () => setState(() => _isBubbleExpanded = false),
                                        child: Icon(Icons.close_rounded, size: 14, color: textSecondary),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
              GestureDetector(
                onTap: _onTapMascot,
                child: AnimatedBuilder(
                  animation: _floatAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _floatAnimation.value),
                      child: child,
                    );
                  },
                  child: ScaleTransition(
                    scale: _bounceAnimation,
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: Image.asset(
                        currentSkin.imagePath,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.cloud,
                          size: 44,
                          color: currentSkin.accentColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMiniAction({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
