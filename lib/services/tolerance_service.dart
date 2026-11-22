import 'package:shared_preferences/shared_preferences.dart';

class ToleranceService {
  static double averagePuffsToDizzy = 12.0;
  static bool hasCompletedSetup = false;
  static int hookahVal = 14;
  static int vapeVal = 10;
  static int cigVal = 0;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    hasCompletedSetup = prefs.getBool('tolerance_completed') ?? false;
    averagePuffsToDizzy = prefs.getDouble('tolerance_avg_puffs') ?? 12.0;
    hookahVal = prefs.getInt('tolerance_hookah') ?? 14;
    vapeVal = prefs.getInt('tolerance_vape') ?? 10;
    cigVal = prefs.getInt('tolerance_cig') ?? 0;
  }

  static Future<void> saveCalibration({
    required int hookah,
    required int vape,
    required int cig,
  }) async {
    hookahVal = hookah;
    vapeVal = vape;
    cigVal = cig;

    final List<int> values = [];
    if (hookah > 0) values.add(hookah);
    if (vape > 0) values.add(vape);
    if (cig > 0) values.add(cig);

    if (values.isEmpty) {
      averagePuffsToDizzy = 12.0;
    } else {
      final total = values.reduce((a, b) => a + b);
      averagePuffsToDizzy = (total / values.length).clamp(4.0, 30.0);
    }

    hasCompletedSetup = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tolerance_completed', true);
    await prefs.setDouble('tolerance_avg_puffs', averagePuffsToDizzy);
    await prefs.setInt('tolerance_hookah', hookah);
    await prefs.setInt('tolerance_vape', vape);
    await prefs.setInt('tolerance_cig', cig);
  }

  static double calculateDizzyIncrement(double puffDurationSec) {
    final basePerPuff = 1.0 / averagePuffsToDizzy;
    return (puffDurationSec / 2.0 * basePerPuff).clamp(0.02, 0.45);
  }
}
