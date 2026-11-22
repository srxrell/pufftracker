import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:untitled/app.dart';
import 'package:untitled/services/auth_service.dart';
import 'package:untitled/services/compliance_service.dart';
import 'package:untitled/services/deep_link_service.dart';
import 'package:untitled/services/device_service.dart';
import 'package:untitled/services/locale_service.dart';
import 'package:untitled/services/mascot_service.dart';
import 'package:untitled/services/sound_service.dart';
import 'package:untitled/services/theme_service.dart';
import 'package:untitled/services/tolerance_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await LocaleService.init();
  } catch (_) {}
  try {
    await ComplianceService.init();
  } catch (_) {}
  try {
    await Supabase.initialize(
      url: 'https://etvrubthnqxvhbnneyww.supabase.co',
      publishableKey: 'sb_publishable_cktJK3Ag7gMi8ivkPLyXnw_NOSpcAna',
    );
  } catch (_) {}
  try {
    await AuthService.init();
  } catch (_) {}
  try {
    await ThemeService.init();
  } catch (_) {}
  try {
    await ToleranceService.init();
  } catch (_) {}
  try {
    await DeviceService.init();
  } catch (_) {}
  try {
    await MascotService.init();
  } catch (_) {}
  try {
    await SoundService.init();
  } catch (_) {}
  try {
    await DeepLinkService.init();
  } catch (_) {}
  runApp(const App());
}
