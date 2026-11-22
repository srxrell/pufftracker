import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:untitled/services/auth_service.dart';
import 'package:untitled/services/device_service.dart';
import 'package:untitled/services/locale_service.dart';

class MascotSkin {
  final String id;
  final String nameEn;
  final String nameRu;
  final String titleEn;
  final String titleRu;
  final String descriptionEn;
  final String descriptionRu;
  final String imagePath;
  final int price;
  final Color accentColor;
  final double multiplier;
  final String perkTextEn;
  final String perkTextRu;

  const MascotSkin({
    required this.id,
    required this.nameEn,
    required this.nameRu,
    required this.titleEn,
    required this.titleRu,
    required this.descriptionEn,
    required this.descriptionRu,
    required this.imagePath,
    required this.price,
    required this.accentColor,
    required this.multiplier,
    required this.perkTextEn,
    required this.perkTextRu,
  });

  String get name => tr(nameEn, nameRu);
  String get title => tr(titleEn, titleRu);
  String get description => tr(descriptionEn, descriptionRu);
  String get perkText => tr(perkTextEn, perkTextRu);
}

class PuffComment {
  final String text;
  final int pointsAwarded;
  final double durationSec;
  final String styleCategory;
  final int stars;

  const PuffComment({
    required this.text,
    required this.pointsAwarded,
    required this.durationSec,
    required this.styleCategory,
    required this.stars,
  });
}

class LeaderboardBoost {
  final String id;
  final int puffsToAdd;
  final int pointsCost;
  final String titleEn;
  final String titleRu;
  final String badgeEn;
  final String badgeRu;
  final IconData icon;

  const LeaderboardBoost({
    required this.id,
    required this.puffsToAdd,
    required this.pointsCost,
    required this.titleEn,
    required this.titleRu,
    required this.badgeEn,
    required this.badgeRu,
    required this.icon,
  });

  String get title => tr(titleEn, titleRu);
  String get badge => tr(badgeEn, badgeRu);
}

class MascotService {
  static const List<MascotSkin> skins = [
    MascotSkin(
      id: 'classic',
      nameEn: 'Classic',
      nameRu: 'Классик',
      titleEn: 'Original Puffy',
      titleRu: 'Оригинальный Паффи',
      descriptionEn: 'Fluffy cloud companion in signature PuffTrack shades.',
      descriptionRu: 'Мягкое пушистое облако в фирменных очках PuffTrack.',
      imagePath: 'assets/images/mascot/puffy_classic.png',
      price: 0,
      accentColor: Color(0xFFFF5959),
      multiplier: 1.0,
      perkTextEn: 'Base score multiplier (x1.0)',
      perkTextRu: 'Базовый прирост очков (x1.0)',
    ),
    MascotSkin(
      id: 'chill',
      nameEn: 'Chill Street',
      nameRu: 'Чилл-Стрит',
      titleEn: 'Street Chiller',
      titleRu: 'Уличный Чиллер',
      descriptionEn: 'Relaxed Puffy in an oversized hoodie and beanie.',
      descriptionRu: 'Расслабленный Паффи в оверсайз-худи и тёплой шапке.',
      imagePath: 'assets/images/mascot/puffy_chill.png',
      price: 350,
      accentColor: Color(0xFF64B5F6),
      multiplier: 1.2,
      perkTextEn: '+20% points for smooth puffs (x1.2)',
      perkTextRu: '+20% очков за плавные затяжки (x1.2)',
    ),
    MascotSkin(
      id: 'cyber',
      nameEn: 'Cyber Neon',
      nameRu: 'Кибер-Неон',
      titleEn: 'Neuro-Puffy 2077',
      titleRu: 'Нейро-Паффи 2077',
      descriptionEn: 'Cyberpunk mascot with a HUD visor and neural headset.',
      descriptionRu: 'Киберпанковский маскот с HUD-визором и нейро-гарнитурой.',
      imagePath: 'assets/images/mascot/puffy_cyber.png',
      price: 850,
      accentColor: Color(0xFF00E5FF),
      multiplier: 1.4,
      perkTextEn: '+40% points on all tracked puffs (x1.4)',
      perkTextRu: '+40% очков за любые затяжки (x1.4)',
    ),
    MascotSkin(
      id: 'gold',
      nameEn: 'Golden Boss',
      nameRu: 'Золотой Босс',
      titleEn: 'Leaderboard King',
      titleRu: 'Король Лидерборда',
      descriptionEn: 'Luxury Puffy with a golden crown and heavy chain.',
      descriptionRu: 'Роскошный Паффи в золотой короне и массивной цепи.',
      imagePath: 'assets/images/mascot/puffy_gold.png',
      price: 1800,
      accentColor: Color(0xFFFFD700),
      multiplier: 1.75,
      perkTextEn: '+75% points & golden leader aura (x1.75)',
      perkTextRu: '+75% очков + золотая аура лидера (x1.75)',
    ),
  ];

  static const List<LeaderboardBoost> boosts = [
    LeaderboardBoost(
      id: 'boost_starter',
      puffsToAdd: 5,
      pointsCost: 200,
      titleEn: '+5 Puffs Boost',
      titleRu: '+5 затяжек в топ',
      badgeEn: 'Quick Push',
      badgeRu: 'Быстрый рывок',
      icon: Icons.rocket_launch_outlined,
    ),
    LeaderboardBoost(
      id: 'boost_pro',
      puffsToAdd: 15,
      pointsCost: 550,
      titleEn: '+15 Puffs Boost',
      titleRu: '+15 затяжек в топ',
      badgeEn: 'Popular',
      badgeRu: 'Популярный',
      icon: Icons.flash_on_outlined,
    ),
    LeaderboardBoost(
      id: 'boost_turbo',
      puffsToAdd: 40,
      pointsCost: 1300,
      titleEn: '+40 Puffs Boost',
      titleRu: '+40 затяжек в топ',
      badgeEn: 'Turbo Surge',
      badgeRu: 'Турбо-прорыв',
      icon: Icons.trending_up,
    ),
    LeaderboardBoost(
      id: 'boost_legend',
      puffsToAdd: 100,
      pointsCost: 2800,
      titleEn: '+100 Puffs Boost',
      titleRu: '+100 затяжек в топ',
      badgeEn: 'Legendary Push',
      badgeRu: 'Легендарный пуш',
      icon: Icons.military_tech_outlined,
    ),
  ];

  static int points = 250;
  static String currentSkinId = 'classic';
  static Set<String> unlockedSkinIds = {'classic'};

  static final ValueNotifier<int> pointsNotifier = ValueNotifier<int>(250);
  static final ValueNotifier<MascotSkin> currentSkinNotifier =
      ValueNotifier<MascotSkin>(skins[0]);
  static final ValueNotifier<PuffComment> lastCommentNotifier =
      ValueNotifier<PuffComment>(_defaultWelcomeComment());

  static PuffComment _defaultWelcomeComment() {
    return PuffComment(
      text: tr(
        "Hey! I'm Puffy, your AI coach. Track a puff via camera or tap + to rate your session!",
        "Йоу! Я твой ИИ-тренер Паффи. Сделай затяжку через камеру или кнопку — оценю твой стиль!",
      ),
      pointsAwarded: 0,
      durationSec: 0.0,
      styleCategory: tr('Ready to Track', 'Готов к затяжкам'),
      stars: 5,
    );
  }

  static void refreshLanguageComment() {
    lastCommentNotifier.value = _defaultWelcomeComment();
  }

  static MascotSkin get currentSkin {
    return skins.firstWhere(
      (s) => s.id == currentSkinId,
      orElse: () => skins[0],
    );
  }

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    points = prefs.getInt('mascot_points') ?? 250;
    currentSkinId = prefs.getString('mascot_current_skin') ?? 'classic';
    final savedUnlocked = prefs.getStringList('mascot_unlocked_skins');
    if (savedUnlocked != null && savedUnlocked.isNotEmpty) {
      unlockedSkinIds = savedUnlocked.toSet();
      unlockedSkinIds.add('classic');
    }

    pointsNotifier.value = points;
    currentSkinNotifier.value = currentSkin;
    lastCommentNotifier.value = _defaultWelcomeComment();
  }

  static Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('mascot_points', points);
    await prefs.setString('mascot_current_skin', currentSkinId);
    await prefs.setStringList('mascot_unlocked_skins', unlockedSkinIds.toList());
  }

  static Future<bool> unlockSkin(MascotSkin skin) async {
    if (unlockedSkinIds.contains(skin.id)) return true;
    if (points < skin.price) return false;

    points -= skin.price;
    unlockedSkinIds.add(skin.id);
    currentSkinId = skin.id;

    pointsNotifier.value = points;
    currentSkinNotifier.value = skin;
    await _saveState();
    return true;
  }

  static Future<void> selectSkin(MascotSkin skin) async {
    if (!unlockedSkinIds.contains(skin.id)) return;
    currentSkinId = skin.id;
    currentSkinNotifier.value = skin;
    await _saveState();
  }

  static Future<void> addPoints(int amount) async {
    points += amount;
    pointsNotifier.value = points;
    await _saveState();
  }

  static Future<bool> buyBoost({
    required LeaderboardBoost boost,
    required Function(int newTotal) onPuffsUpdated,
  }) async {
    if (points < boost.pointsCost) return false;

    points -= boost.pointsCost;
    pointsNotifier.value = points;
    await _saveState();

    final currentTotal = AuthService.currentUser?.pcounter ?? AuthService.localPuffs;
    final newTotal = currentTotal + boost.puffsToAdd;
    await AuthService.updatePuffs(newTotal);
    onPuffsUpdated(newTotal);
    return true;
  }

  static PuffComment evaluatePuff({
    required double durationSec,
    required double dizzyProgress,
  }) {
    final skin = currentSkin;
    final device = DeviceService.activeDevice.value;
    final deviceName = device.name;

    int base = (durationSec * 50).round().clamp(40, 260);
    int riskBonus = 0;
    if (dizzyProgress >= 0.75) {
      riskBonus = 60;
    } else if (dizzyProgress >= 0.5) {
      riskBonus = 30;
    }

    int awarded = ((base + riskBonus) * skin.multiplier).round();
    points += awarded;
    pointsNotifier.value = points;
    _saveState();

    String category;
    int stars;
    String comment;
    final rand = Random();

    if (durationSec < 1.1) {
      category = tr('Quick Micro-Puff', 'Снайперский напас');
      stars = 3;
      final comments = LocaleService.isEn
          ? [
              'Quick ${durationSec}s draw on $deviceName! Clean and controlled.',
              'Light puff on $deviceName. Keeping the pace steady.',
              'Precision draw! Minimal vapor, maximum control.',
            ]
          : [
              'Быстрый щелчок на $durationSec с! Аккуратно, на опыте.',
              'Легкий напас на $deviceName. Чисто освежить рецепторы.',
              'Снайперская затяжка! Без лишнего шума и пара.',
            ];
      comment = comments[rand.nextInt(comments.length)];
    } else if (durationSec < 2.5) {
      category = tr('Balanced Standard', 'Золотой стандарт');
      stars = 4;
      final comments = LocaleService.isEn
          ? [
              'Smooth ${durationSec}s draw on $deviceName! Great rhythm.',
              'Clean technique! Steady, balanced session.',
              'Solid balance of duration and flow. 10/10!',
            ]
          : [
              'Идеальная тяга $durationSec с! Бархатный пар на $deviceName.',
              'Техника на высоте! Ровная, уверенная затяжка.',
              'Вот это баланс вкуса и пара. Стиль 10 из 10!',
            ];
      comment = comments[rand.nextInt(comments.length)];
    } else if (durationSec < 4.2) {
      category = tr('Deep Cloud Mode', 'Паровоз-мод');
      stars = 5;
      final comments = LocaleService.isEn
          ? [
              'Powerful ${durationSec}s draw on $deviceName! Dense cloud!',
              'Deep draw detected! Climbing up the session ranks!',
              'Impressive lung capacity! Long, steady puff.',
            ]
          : [
              'Мощнейший напас $durationSec с на $deviceName! Дым столбом!',
              'Паровоз вошел в чат! Глубокая тяга, рекордный стиль!',
              'Ого, легкие из титана! Шикарный напас, бро.',
            ];
      comment = comments[rand.nextInt(comments.length)];
    } else {
      category = tr('Ultra Long Draw', 'Драконий вихрь');
      stars = 5;
      final comments = LocaleService.isEn
          ? [
              'A ${durationSec}s draw?! Unbelievable lung capacity!',
              'Record-breaking ${durationSec}s duration! Don\'t forget to breathe!',
              'Massive cloud! Easily the longest draw of the session!',
            ]
          : [
              'Тяга $durationSec с?! Ты дракон или компрессор?! Безумный напас!',
              'Рекордная глубина $durationSec с! Ты там вообще дышишь кислородом?!',
              'Абсолютный зверь! Вся комната в тумане, чистый хайп!',
            ];
      comment = comments[rand.nextInt(comments.length)];
    }

    if (dizzyProgress >= 0.75) {
      final dangerAddons = LocaleService.isEn
          ? [
              ' ⚠️ High intensity reached — take a break and drink water!',
              ' ⚠️ Head-rush meter is near 100%, slow down a bit!',
            ]
          : [
              ' ⚠️ Осторожно, шкала на пике — сделай паузу!',
              ' ⚠️ Присядь и сделай глоток воды, уровень высокий!',
            ];
      comment += dangerAddons[rand.nextInt(dangerAddons.length)];
    }

    if (skin.id == 'cyber') {
      comment = LocaleService.isEn ? '⚡ [Cyber-HUD]: $comment' : '⚡ [Нейро-визор]: $comment';
    } else if (skin.id == 'gold') {
      comment = LocaleService.isEn ? '👑 [Boss]: $comment' : '👑 [Босс]: $comment';
    } else if (skin.id == 'chill') {
      comment = LocaleService.isEn ? '☁️ [Chill]: $comment' : '☁️ [Чилл]: $comment';
    }

    final result = PuffComment(
      text: comment,
      pointsAwarded: awarded,
      durationSec: durationSec,
      styleCategory: category,
      stars: stars,
    );

    lastCommentNotifier.value = result;
    return result;
  }

  static void triggerRandomRemark() {
    final quotes = LocaleService.isEn
        ? [
            'Tap "Camera" to track your puffs automatically with on-device AI!',
            'Use your style points in "Boost" to climb the global leaderboard!',
            'Select your active setup in Settings for personalized tracking.',
            'How is your session going? Remember to stay hydrated!',
            'All AI camera processing runs locally on your phone for 100% privacy.',
          ]
        : [
            'Нажми "Камера" и отслеживай затяжки автоматически через локальный ИИ!',
            'За очки стиля можно прокачать позицию в лидерборде. Загляни в "Буст"!',
            'Выбирай свой девайс в настройках для точного учёта.',
            'Не забывай пить воду и делать перерывы!',
            'Видео с камеры обрабатывается строго локально на телефоне.',
          ];
    final comment = quotes[Random().nextInt(quotes.length)];

    lastCommentNotifier.value = PuffComment(
      text: comment,
      pointsAwarded: 0,
      durationSec: 0.0,
      styleCategory: tr('Puffy Tip', 'Совет от Паффи'),
      stars: 5,
    );
  }
}
