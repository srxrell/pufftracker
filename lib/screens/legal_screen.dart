import 'package:flutter/material.dart';
import 'package:untitled/services/locale_service.dart';
import 'package:untitled/services/theme_service.dart';

enum LegalDocType { privacy, terms }

class LegalScreen extends StatelessWidget {
  final LegalDocType initialTab;

  const LegalScreen({super.key, this.initialTab = LegalDocType.privacy});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = ThemeService.scaffoldColor(isDark);
    final cardBg = ThemeService.cardColor(isDark);
    final textPrimary = ThemeService.textPrimary(isDark);
    final textSecondary = ThemeService.textSecondary(isDark);
    final primaryColor = ThemeService.primaryColor;

    return DefaultTabController(
      length: 2,
      initialIndex: initialTab == LegalDocType.privacy ? 0 : 1,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: Text(
            "puff.gg • Legal & Privacy",
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: textPrimary,
            ),
          ),
          bottom: TabBar(
            indicatorColor: primaryColor,
            labelColor: textPrimary,
            unselectedLabelColor: textSecondary,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
            tabs: [
              Tab(text: tr("Privacy Policy", "Политика конфиденциальности")),
              Tab(text: tr("Terms of Use", "Условия использования")),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildDocList(
              cardBg: cardBg,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              primaryColor: primaryColor,
              sections: [
                _LegalSection(
                  title: "1. On-Device Camera & Computer Vision (CV) Processing",
                  body:
                      "PuffTrack uses on-device Computer Vision (Google ML Kit) to detect puff gestures automatically. "
                      "All camera frames used for AI puff tracking are processed 100% locally in your device's volatile memory (RAM) in real time. "
                      "Camera video for CV tracking is NEVER recorded, NEVER saved to disk, and NEVER uploaded or stored on puff.gg servers.",
                  highlight: true,
                ),
                _LegalSection(
                  title: "2. Information We Collect",
                  body:
                      "• Account Data (Optional): If you create a cloud profile, we store your nickname, email address, and puff counter in Supabase.\n"
                      "• Guest Mode: You can use PuffTrack without registering; all statistics remain stored locally on your device.\n"
                      "• Live Co-Session (Optional): If you voluntarily join the Live Roulette or Split-Screen room, transient low-resolution frames and chat messages are relayed peer-to-peer in real time and are never archived or stored.",
                ),
                _LegalSection(
                  title: "3. Data Retention & Account Deletion",
                  body:
                      "You can reset your session statistics or log out at any time in Settings. "
                      "No camera recordings or biometric identifiers are ever retained by PuffTrack.",
                ),
                _LegalSection(
                  title: "4. Contact & Domain Information",
                  body:
                      "Official domain: https://puff.gg\n"
                      "Privacy Policy URL: https://puff.gg/privacy.html\n"
                      "Support contact: support@puff.gg",
                ),
              ],
            ),
            _buildDocList(
              cardBg: cardBg,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              primaryColor: primaryColor,
              sections: [
                _LegalSection(
                  title: "1. Age Restriction (18+ Only)",
                  body:
                      "PuffTrack is strictly intended for adults aged 18 years or older. "
                      "The app is a habit tracker and analytics utility and does not sell, promote, or distribute any tobacco, nicotine, or vaping hardware.",
                  highlight: true,
                ),
                _LegalSection(
                  title: "2. User-Generated Content (UGC) & Live Rules",
                  body:
                      "When using the Live Split-Screen or Roulette feature, you agree not to broadcast or transmit:\n"
                      "• Nudity, sexually explicit, or violent content;\n"
                      "• Harassment, hate speech, threats, or bullying;\n"
                      "• Any content involving minors or illegal activities.\n\n"
                      "Zero-Tolerance Policy: Users can report or block any participant in one tap using the Report/Block button on the Live screen. Reported sessions are immediately terminated and blocked peers are permanently filtered out.",
                ),
                _LegalSection(
                  title: "3. Neutral Habit Tracking Disclaimer",
                  body:
                      "PuffTrack provides personal usage counters and session analytics for informational purposes only. "
                      "All device names and presets in the default catalog are generic categories.",
                ),
                _LegalSection(
                  title: "4. Terms URL",
                  body:
                      "Official Terms URL: https://puff.gg/terms.html\n"
                      "Last updated: November 2026",
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocList({
    required Color cardBg,
    required Color textPrimary,
    required Color textSecondary,
    required Color primaryColor,
    required List<_LegalSection> sections,
  }) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sections.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, idx) {
        final s = sections[idx];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: s.highlight
                ? Border.all(color: primaryColor.withValues(alpha: 0.5), width: 1.5)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (s.highlight) ...[
                    Icon(Icons.verified_user_outlined, color: primaryColor, size: 18),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      s.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                s.body,
                style: TextStyle(
                  fontSize: 13.5,
                  color: textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LegalSection {
  final String title;
  final String body;
  final bool highlight;

  const _LegalSection({
    required this.title,
    required this.body,
    this.highlight = false,
  });
}
