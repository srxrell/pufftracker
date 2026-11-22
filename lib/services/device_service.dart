import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:untitled/data_models/device_model.dart';
import 'package:untitled/services/auth_service.dart';

class DeviceService {
  /// Neutral brand-free default devices for Google Play & Landing showcase compliance
  static const DeviceModel defaultHookah = DeviceModel(
    id: 'hookah_default',
    type: 'hookah',
    name: 'Classic Hookah',
    brand: 'Standard Setup',
    subtitle: 'Berry Mint & Citrus Mix',
    image: 'assets/images/devices/hookah.png',
    tobacco: 'Berry Mint & Citrus Mix',
    strength: 3.0,
  );

  static const List<DeviceModel> cigaretteCatalog = [
    DeviceModel(
      id: 'cig_classic_regular',
      type: 'cigarettes',
      name: 'Classic Filter Regular',
      brand: 'Standard Series',
      subtitle: 'Traditional Blend • 0.6 mg',
      image: 'assets/images/devices/chapman_classic.png',
      strength: 3.0,
    ),
    DeviceModel(
      id: 'cig_cherry_aroma',
      type: 'cigarettes',
      name: 'Aromatic Cherry Filter',
      brand: 'Aroma Series',
      subtitle: 'Ripe Cherry Note • 0.5 mg',
      image: 'assets/images/devices/chapman_cherry.png',
      flavor: 'Cherry',
      strength: 2.8,
    ),
    DeviceModel(
      id: 'cig_light_smooth',
      type: 'cigarettes',
      name: 'Smooth Gold Filter',
      brand: 'Light Series',
      subtitle: 'Mild Blend • 0.4 mg',
      image: 'assets/images/devices/marlboro_gold.png',
      strength: 2.2,
    ),
  ];

  static const List<DeviceModel> vapeCatalog = [
    DeviceModel(
      id: 'vape_standard_pod',
      type: 'vape',
      name: 'Standard Pod System',
      brand: 'Generic Pod',
      subtitle: 'Compact Ribbed Body • Mesh Coil',
      image: 'assets/images/devices/lost_mary_os5000.png',
      flavor: 'Blueberry Ice',
      strength: 2.0,
    ),
    DeviceModel(
      id: 'vape_mini_pocket',
      type: 'vape',
      name: 'Mini Pocket Vaporizer',
      brand: 'Compact Series',
      subtitle: 'Gradient Body • Smooth Draw',
      image: 'assets/images/devices/elf_bar_bc5000.png',
      flavor: 'Watermelon Mint',
      strength: 2.0,
    ),
    DeviceModel(
      id: 'vape_smart_dual',
      type: 'vape',
      name: 'Smart Dual Vaporizer',
      brand: 'Pro Series',
      subtitle: 'Dual Mesh + Indicator Screen',
      image: 'assets/images/devices/waka_sopro_10000.png',
      flavor: 'Dark Cherry',
      strength: 2.8,
    ),
    DeviceModel(
      id: 'vape_pulse_display',
      type: 'vape',
      name: 'Pulse LED Vaporizer',
      brand: 'Smart Series',
      subtitle: 'LED Display • Boost Mode',
      image: 'assets/images/devices/geek_bar_pulse.png',
      flavor: 'Tropical Fruit',
      strength: 2.8,
    ),
    DeviceModel(
      id: 'vape_metal_stick',
      type: 'vape',
      name: 'Metal Stick Pod',
      brand: 'Refillable Series',
      subtitle: 'Aluminum Frame • Refillable Pod',
      image: 'assets/images/devices/vaporesso_xros.png',
      flavor: 'Custom Liquid',
      strength: 2.5,
    ),
    DeviceModel(
      id: 'vape_resin_mini',
      type: 'vape',
      name: 'Resin Panel Mini Pod',
      brand: 'Compact Series',
      subtitle: 'Metal + Resin Frame • Replaceable Coil',
      image: 'assets/images/devices/smoant_charon.png',
      flavor: 'Custom Liquid',
      strength: 2.5,
    ),
    DeviceModel(
      id: 'vape_outdoor_gear',
      type: 'vape',
      name: 'Outdoor Gear Vaporizer',
      brand: 'Rugged Series',
      subtitle: 'Carabiner Clip + Protective Cap',
      image: 'assets/images/devices/vozol_gear.png',
      flavor: 'Forest Berries',
      strength: 2.5,
    ),
  ];

  static const List<String> hookahTobaccos = [
    'Berry Mint Mix',
    'Supernova Ice & Citrus',
    'Classic Cola & Lime',
    'Ice Berry Blend',
    'Cane Mint Herbal',
    'Blueberry Crumble',
    'White Tea & Jasmine',
    'Wild Cherry',
    'Fresh Mint & Grapefruit',
  ];

  static List<String> customHookahTobaccos = [];
  static List<DeviceModel> customVapes = [];

  static List<String> get allHookahTobaccos => [
        ...customHookahTobaccos,
        ...hookahTobaccos,
      ];

  static List<DeviceModel> get allVapes => [
        ...customVapes,
        ...vapeCatalog,
      ];

  static final ValueNotifier<DeviceModel> activeDevice =
      ValueNotifier<DeviceModel>(vapeCatalog[0]);

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedJson = prefs.getString('active_device_json');
    if (savedJson != null) {
      try {
        final map = jsonDecode(savedJson) as Map<String, dynamic>;
        activeDevice.value = DeviceModel.fromJson(map);
      } catch (_) {}
    }

    final savedTobaccos = prefs.getStringList('custom_hookah_tobaccos');
    if (savedTobaccos != null) {
      customHookahTobaccos = savedTobaccos;
    }

    final savedVapesJson = prefs.getString('custom_vapes_json');
    if (savedVapesJson != null) {
      try {
        final list = jsonDecode(savedVapesJson) as List<dynamic>;
        customVapes = list
            .map((e) => DeviceModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (_) {}
    }

    if (AuthService.currentUser != null) {
      _syncToCloud();
    }
  }

  static Future<void> syncCurrentToCloud() async {
    await _syncToCloud();
  }

  static Future<void> selectDevice(DeviceModel device) async {
    activeDevice.value = device;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_device_json', jsonEncode(device.toJson()));
    await _syncToCloud();
  }

  static Future<void> updateHookahTobacco(String tobacco) async {
    final clean = tobacco.trim();
    if (clean.isEmpty) return;
    final baseDevice =
        activeDevice.value.type == 'hookah' ? activeDevice.value : defaultHookah;
    final updated = baseDevice.copyWith(
      tobacco: clean,
      subtitle: clean,
    );
    await selectDevice(updated);
  }

  static Future<void> addCustomTobacco(String tobacco) async {
    final clean = tobacco.trim();
    if (clean.isEmpty) return;
    if (!customHookahTobaccos.contains(clean) && !hookahTobaccos.contains(clean)) {
      customHookahTobaccos.insert(0, clean);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('custom_hookah_tobaccos', customHookahTobaccos);
    }
    await updateHookahTobacco(clean);
  }

  static Future<void> addCustomVape(DeviceModel vape) async {
    customVapes.insert(0, vape);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'custom_vapes_json',
      jsonEncode(customVapes.map((e) => e.toJson()).toList()),
    );
    await selectDevice(vape);
  }

  static void loadFromCloud(dynamic rawDevices) {
    if (rawDevices == null) return;
    try {
      List<dynamic> list = [];
      if (rawDevices is List) {
        list = rawDevices;
      } else if (rawDevices is String) {
        list = jsonDecode(rawDevices) as List<dynamic>;
      }
      if (list.isNotEmpty) {
        final firstMap = Map<String, dynamic>.from(list.first as Map);
        final model = DeviceModel.fromJson(firstMap);
        activeDevice.value = model;

        final List<DeviceModel> loadedCustomVapes = [];
        for (int i = 1; i < list.length; i++) {
          final m = Map<String, dynamic>.from(list[i] as Map);
          final dev = DeviceModel.fromJson(m);
          if (dev.type == 'vape') {
            loadedCustomVapes.add(dev);
          }
        }
        if (loadedCustomVapes.isNotEmpty) {
          customVapes = loadedCustomVapes;
        }

        SharedPreferences.getInstance().then((prefs) {
          prefs.setString('active_device_json', jsonEncode(model.toJson()));
          prefs.setString(
            'custom_vapes_json',
            jsonEncode(customVapes.map((e) => e.toJson()).toList()),
          );
        });
      }
    } catch (_) {}
  }

  static Future<void> _syncToCloud() async {
    final user = AuthService.currentUser;
    if (user == null) return;
    try {
      final list = [
        activeDevice.value.toJson(),
        ...customVapes.map((e) => e.toJson()),
      ];
      await Supabase.instance.client
          .from('accounts')
          .update({'devices': list})
          .eq('id', user.id);
    } catch (_) {}
  }
}
