import 'package:shared_preferences/shared_preferences.dart';

class ComplianceService {
  static bool hasVerifiedAge = false;
  static bool hasAcceptedLiveTerms = false;
  static Set<String> blockedPeerIds = <String>{};

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    hasVerifiedAge = prefs.getBool('has_verified_age_18') ?? false;
    hasAcceptedLiveTerms = prefs.getBool('has_accepted_live_terms') ?? false;
    final savedBlocked = prefs.getStringList('blocked_peer_ids') ?? [];
    blockedPeerIds = savedBlocked.toSet();
  }

  static Future<void> setAgeVerified() async {
    hasVerifiedAge = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_verified_age_18', true);
  }

  static Future<void> setLiveTermsAccepted() async {
    hasAcceptedLiveTerms = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_accepted_live_terms', true);
  }

  static Future<void> blockAndReportPeer(String peerId, String reason) async {
    if (peerId.isNotEmpty) {
      blockedPeerIds.add(peerId);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('blocked_peer_ids', blockedPeerIds.toList());
  }

  static bool isPeerBlocked(String? peerId) {
    if (peerId == null || peerId.isEmpty) return false;
    return blockedPeerIds.contains(peerId);
  }
}
