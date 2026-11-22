import 'package:flutter/material.dart';
import 'package:untitled/data_models/device_model.dart';
import 'package:untitled/screens/authenticator.dart';
import 'package:untitled/screens/legal_screen.dart';
import 'package:untitled/screens/style_and_colors_sheet.dart';
import 'package:untitled/screens/tolerance_setup.dart';
import 'package:untitled/services/auth_service.dart';
import 'package:untitled/services/device_service.dart';
import 'package:untitled/services/image_search_service.dart';
import 'package:untitled/services/locale_service.dart';
import 'package:untitled/services/mascot_service.dart';
import 'package:untitled/services/sound_service.dart';
import 'package:untitled/services/theme_service.dart';
import 'package:untitled/services/tolerance_service.dart';

Widget _buildSafeDeviceImage(
  String image, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.contain,
}) {
  if (image.startsWith('http://') || image.startsWith('https://')) {
    return Image.network(
      image,
      width: width,
      height: height,
      fit: fit,
      headers: const {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
              color: ThemeService.primaryColor,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Icon(
          Icons.vape_free,
          size: (height ?? 40) * 0.6,
          color: ThemeService.primaryColor,
        );
      },
    );
  }
  return Image.asset(
    image,
    width: width,
    height: height,
    fit: fit,
    errorBuilder: (context, error, stackTrace) {
      return Icon(
        Icons.vape_free,
        size: (height ?? 40) * 0.6,
        color: ThemeService.primaryColor,
      );
    },
  );
}

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = ThemeService.cardColor(isDark);
    final textPrimary = ThemeService.textPrimary(isDark);
    final textSecondary = ThemeService.textSecondary(isDark);
    final dividerColor = isDark ? const Color(0xFF33312E) : const Color(0xFFF0EAE1);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        title: Text(
          tr("Settings", "Настройки"),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: textPrimary,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // 1. Profile card
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              onTap: user == null
                  ? () {
                      Navigator.of(context)
                          .push(MaterialPageRoute(builder: (context) => const Authenticator()))
                          .then((_) {
                            if (mounted) setState(() {});
                          });
                    }
                  : null,
              leading: CircleAvatar(
                radius: 22,
                backgroundColor: user != null
                    ? ThemeService.primaryColor
                    : (isDark ? const Color(0xFF33312E) : const Color(0xFFF6F2EA)),
                child: Text(
                  user != null && user.username.isNotEmpty
                      ? user.username[0].toUpperCase()
                      : "?",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: user != null ? ThemeService.onPrimaryColor : textSecondary,
                  ),
                ),
              ),
              title: Text(
                user?.username ?? tr("Sign In to Account", "Войти в аккаунт"),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              subtitle: Text(
                user != null
                    ? tr("${user.pcounter} puffs tracked", "${user.pcounter} затяжек")
                    : tr("Cloud profile sync", "Синхронизация профиля"),
                style: TextStyle(fontSize: 13, color: textSecondary),
              ),
              trailing: user != null
                  ? IconButton(
                      icon: const Icon(Icons.logout_rounded, color: Color(0xFFD32F2F), size: 20),
                      onPressed: () async {
                        await AuthService.signOut();
                        if (mounted) setState(() {});
                      },
                    )
                  : Icon(Icons.chevron_right, color: textSecondary),
            ),
          ),
          const SizedBox(height: 12),

          // 2. Active Device compact card
          _buildActiveDeviceCard(cardBg, textPrimary, textSecondary, isDark),
          const SizedBox(height: 12),

          // 3. Unified minimal settings card
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                // Language Switcher (English default / Русский)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  leading: Icon(Icons.language_rounded, color: ThemeService.primaryColor, size: 22),
                  title: Text(
                    tr("Language", "Язык"),
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary),
                  ),
                  trailing: SegmentedButton<String>(
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    segments: const [
                      ButtonSegment(value: 'en', label: Text('EN')),
                      ButtonSegment(value: 'ru', label: Text('RU')),
                    ],
                    selected: {LocaleService.currentLocale},
                    onSelectionChanged: (set) async {
                      await LocaleService.setLocale(set.first);
                      MascotService.refreshLanguageComment();
                      if (mounted) setState(() {});
                    },
                  ),
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: dividerColor),
                ValueListenableBuilder<AppStyle>(
                  valueListenable: ThemeService.currentStyleNotifier,
                  builder: (context, currentStyle, _) {
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: Image.asset(
                          currentStyle.iconPath,
                          width: 34,
                          height: 34,
                          fit: BoxFit.cover,
                        ),
                      ),
                      title: Text(
                        tr("Style & Colors", "Стиль и цвета"),
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            currentStyle.name,
                            style: TextStyle(fontSize: 13, color: textSecondary),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.chevron_right, color: textSecondary, size: 18),
                        ],
                      ),
                      onTap: () => StyleAndColorsSheet.show(context),
                    );
                  },
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: dividerColor),
                SwitchListTile(
                  overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  title: Text(
                    tr("Dark Mode", "Тёмная тема"),
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary),
                  ),
                  value: ThemeService.isDark,
                  activeThumbColor: ThemeService.primaryColor,
                  activeTrackColor: ThemeService.accentLight(isDark),
                  onChanged: (val) async {
                    await ThemeService.setDarkTheme(val);
                    if (mounted) setState(() {});
                  },
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: dividerColor),
                ValueListenableBuilder<bool>(
                  valueListenable: SoundService.soundEnabledNotifier,
                  builder: (context, soundEnabled, _) {
                    return SwitchListTile(
                      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      title: Text(
                        tr("Puff Sound Effect", "Звук затяжки"),
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary),
                      ),
                      value: soundEnabled,
                      activeThumbColor: ThemeService.primaryColor,
                      activeTrackColor: ThemeService.accentLight(isDark),
                      onChanged: (value) {
                        SoundService.toggleSound(value);
                      },
                    );
                  },
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: dividerColor),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  title: Text(
                    tr("Intensity Calibration", "Калибровка накура"),
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tr(
                          "~${ToleranceService.averagePuffsToDizzy.round()} puffs",
                          "~${ToleranceService.averagePuffsToDizzy.round()} тяг",
                        ),
                        style: TextStyle(fontSize: 13, color: textSecondary),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right, color: textSecondary, size: 18),
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context)
                        .push(MaterialPageRoute(builder: (context) => const ToleranceSetup(isFromSettings: true)))
                        .then((_) {
                          if (mounted) setState(() {});
                        });
                  },
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: dividerColor),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  leading: Icon(Icons.privacy_tip_outlined, color: textSecondary, size: 20),
                  title: Text(
                    tr("Privacy Policy & Terms (puff.gg)", "Конфиденциальность и условия"),
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: textPrimary),
                  ),
                  trailing: Icon(Icons.chevron_right, color: textSecondary, size: 18),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LegalScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 4. Reset session
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              leading: const Icon(Icons.refresh_rounded, color: Color(0xFFD32F2F), size: 20),
              title: Text(
                tr("Reset Puff Counter", "Сбросить счётчик"),
                style: const TextStyle(color: Color(0xFFD32F2F), fontWeight: FontWeight.w700, fontSize: 15),
              ),
              onTap: () async {
                await AuthService.updatePuffs(0);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(tr("Counter reset to 0", "Счётчик сброшен на 0")),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
                setState(() {});
              },
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildActiveDeviceCard(Color cardBg, Color textPrimary, Color textSecondary, bool isDark) {
    return ValueListenableBuilder<DeviceModel>(
      valueListenable: DeviceService.activeDevice,
      builder: (context, device, _) {
        return Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            onTap: () => _openDeviceSelectorModal(context),
            leading: Container(
              width: 52,
              height: 52,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1D1B) : const Color(0xFFF7F3EC),
                borderRadius: BorderRadius.circular(14),
              ),
              child: _buildSafeDeviceImage(device.image, fit: BoxFit.contain),
            ),
            title: Text(
              device.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
            subtitle: Text(
              device.subtitle.isNotEmpty ? device.subtitle : device.brand,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: textSecondary),
            ),
            trailing: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: ThemeService.primaryColor,
                foregroundColor: ThemeService.onPrimaryColor,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: const Size(0, 34),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _openDeviceSelectorModal(context),
              child: Text(
                tr("Change", "Сменить"),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: ThemeService.onPrimaryColor,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openDeviceSelectorModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _DeviceSelectorSheet(),
    );
  }
}

class _HookahTobaccoSheet extends StatefulWidget {
  const _HookahTobaccoSheet();

  @override
  State<_HookahTobaccoSheet> createState() => _HookahTobaccoSheetState();
}

class _HookahTobaccoSheetState extends State<_HookahTobaccoSheet> {
  final _searchController = TextEditingController();
  final _customController = TextEditingController();
  String _selected = DeviceService.activeDevice.value.tobacco ?? DeviceService.hookahTobaccos[0];
  String _searchFilter = '';

  @override
  void dispose() {
    _searchController.dispose();
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = ThemeService.cardColor(isDark);
    final textPrimary = ThemeService.textPrimary(isDark);
    final textSecondary = ThemeService.textSecondary(isDark);

    final filteredTobaccos = DeviceService.allHookahTobaccos.where((t) {
      if (_searchFilter.isEmpty) return true;
      return t.toLowerCase().contains(_searchFilter);
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF44413E) : const Color(0xFFCCCCCC),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tr("Hookah Blend Selection", "Выбор табака для кальяна"),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textPrimary),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            tr("Pick a preset blend or add your own", "Выбери готовый микс или добавь свой"),
            style: TextStyle(fontSize: 13, color: textSecondary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            style: TextStyle(color: textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: tr("Search blend (Berry Mint, Citrus Ice...)", "Поиск микса (Berry Mint, Citrus Ice...)"),
              hintStyle: TextStyle(color: textSecondary, fontSize: 13),
              filled: true,
              fillColor: cardBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              prefixIcon: Icon(Icons.search, color: textSecondary, size: 20),
            ),
            onChanged: (val) {
              setState(() {
                _searchFilter = val.trim().toLowerCase();
              });
            },
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...filteredTobaccos.map((tobacco) {
                      final isChosen = _selected == tobacco;
                      return ChoiceChip(
                        label: Text(tobacco),
                        selected: isChosen,
                        elevation: 0,
                        side: BorderSide.none,
                        labelStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: isChosen ? FontWeight.bold : FontWeight.w500,
                          color: isChosen ? (isDark ? Colors.white : Colors.black) : textPrimary,
                        ),
                        backgroundColor: cardBg,
                        selectedColor: ThemeService.accentLight(isDark),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        onSelected: (_) {
                          setState(() {
                            _selected = tobacco;
                            _customController.clear();
                          });
                        },
                      );
                    }),
                    if (_searchFilter.isNotEmpty &&
                        !filteredTobaccos.any((t) => t.toLowerCase() == _searchFilter))
                      ActionChip(
                        elevation: 0,
                        side: BorderSide(color: ThemeService.primaryColor, width: 1.2),
                        backgroundColor: cardBg,
                        avatar: Icon(Icons.add, size: 16, color: ThemeService.primaryColor),
                        label: Text(
                          tr("Add \"${_searchController.text.trim()}\"", "Добавить «${_searchController.text.trim()}»"),
                          style: TextStyle(
                            color: ThemeService.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        onPressed: () {
                          setState(() {
                            _selected = _searchController.text.trim();
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  tr("Or enter your custom blend:", "Или введи свой кастомный микс:"),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textSecondary),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _customController,
                  style: TextStyle(color: textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: tr("E.g. Cherry + Fresh Mint 50/50", "Например: Вишня + Мята 50/50"),
                    hintStyle: TextStyle(color: textSecondary, fontSize: 13),
                    filled: true,
                    fillColor: cardBg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: Icon(Icons.local_fire_department_outlined, color: ThemeService.primaryColor, size: 20),
                  ),
                  onChanged: (val) {
                    if (val.trim().isNotEmpty) {
                      setState(() {
                        _selected = val.trim();
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: ThemeService.primaryColor,
                foregroundColor: ThemeService.onPrimaryColor,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () async {
                final nav = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                await DeviceService.addCustomTobacco(_selected);
                if (!mounted) return;
                nav.pop();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(tr("Hookah blend saved: $_selected", "Табак кальяна сохранен: $_selected")),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
              child: Text(
                tr("Apply: $_selected", "Применить: $_selected"),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: ThemeService.onPrimaryColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceSelectorSheet extends StatefulWidget {
  const _DeviceSelectorSheet();

  @override
  State<_DeviceSelectorSheet> createState() => _DeviceSelectorSheetState();
}

class _DeviceSelectorSheetState extends State<_DeviceSelectorSheet> {
  String _selectedTab = DeviceService.activeDevice.value.type;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  List<String> _onlineResults = [];
  bool _isSearchingOnline = false;
  String? _lastSearchedOnline;
  ImageSearchSource _selectedSource = ImageSearchSource.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performOnlineSearch([String? overrideQuery]) async {
    final q = (overrideQuery ?? _searchController.text).trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isSearchingOnline = true;
      _lastSearchedOnline = q;
    });
    final results = await ImageSearchService.searchVapeImages(
      q,
      source: _selectedSource,
    );
    if (!mounted) return;
    setState(() {
      _onlineResults = results;
      _isSearchingOnline = false;
    });
  }

  void _confirmSelectOnlineImage(String imageUrl, String query) {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ConfirmOnlineDeviceSheet(
        imageUrl: imageUrl,
        initialName: query,
      ),
    ).then((added) {
      if (added == true && mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  void _openAddCustomVapeModal([String? initialName]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddCustomVapeSheet(initialName: initialName),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = ThemeService.cardColor(isDark);
    final textPrimary = ThemeService.textPrimary(isDark);
    final textSecondary = ThemeService.textSecondary(isDark);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF44413E) : const Color(0xFFCCCCCC),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr("Select Setup", "Выбор сетапа"),
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr("Synced with your cloud profile", "Синхронизируется с твоим аккаунтом в Supabase"),
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                style: ButtonStyle(
                  elevation: WidgetStateProperty.all(0),
                  side: WidgetStateProperty.all(BorderSide.none),
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return ThemeService.accentLight(isDark);
                    }
                    return cardBg;
                  }),
                  foregroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return isDark ? Colors.white : Colors.black;
                    }
                    return textSecondary;
                  }),
                ),
                segments: [
                  ButtonSegment(
                    value: 'hookah',
                    label: Text(tr("Hookah", "Кальян")),
                    icon: const Icon(Icons.cloud_outlined),
                  ),
                  ButtonSegment(
                    value: 'cigarettes',
                    label: Text(tr("Classic", "Сиги")),
                    icon: const Icon(Icons.smoking_rooms_outlined),
                  ),
                  ButtonSegment(
                    value: 'vape',
                    label: Text(tr("Pods", "Ашки")),
                    icon: const Icon(Icons.vape_free),
                  ),
                ],
                selected: {_selectedTab},
                onSelectionChanged: (set) {
                  setState(() {
                    _selectedTab = set.first;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_selectedTab == 'vape') ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(color: textPrimary, fontSize: 14),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (val) => _performOnlineSearch(val),
                      decoration: InputDecoration(
                        hintText: tr("Search device (Pod System, Pocket Mini...)", "Поиск девайса..."),
                        hintStyle: TextStyle(color: textSecondary, fontSize: 13),
                        filled: true,
                        fillColor: cardBg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: Icon(Icons.search, color: textSecondary, size: 20),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_searchQuery.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                    _onlineResults.clear();
                                    _lastSearchedOnline = null;
                                  });
                                },
                              ),
                            IconButton(
                              icon: Icon(Icons.travel_explore, color: ThemeService.primaryColor, size: 20),
                              tooltip: tr("Search photos online", "Искать фото в интернете"),
                              onPressed: () => _performOnlineSearch(),
                            ),
                          ],
                        ),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val.trim().toLowerCase();
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      backgroundColor: cardBg,
                      foregroundColor: ThemeService.primaryColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    ),
                    onPressed: () => _openAddCustomVapeModal(_searchQuery.isNotEmpty ? _searchController.text.trim() : null),
                    child: const Icon(Icons.add, size: 22),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 34,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: ImageSearchSource.values.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, idx) {
                  final src = ImageSearchSource.values[idx];
                  final isSel = _selectedSource == src;
                  return ChoiceChip(
                    label: Text(src.label),
                    selected: isSel,
                    showCheckmark: false,
                    side: BorderSide.none,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    labelStyle: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                      color: isSel ? (isDark ? Colors.white : Colors.black) : textSecondary,
                    ),
                    backgroundColor: cardBg,
                    selectedColor: ThemeService.accentLight(isDark),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    onSelected: (_) {
                      setState(() => _selectedSource = src);
                      if (_searchController.text.trim().isNotEmpty) {
                        _performOnlineSearch();
                      }
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
            if (_searchQuery.isNotEmpty && !_isSearchingOnline)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _performOnlineSearch(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: ThemeService.accentLight(isDark),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: ThemeService.primaryColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.travel_explore, size: 18, color: ThemeService.primaryColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tr(
                              "Find device photo online: \"${_searchController.text.trim()}\"",
                              "Найти фото модели в интернете: «${_searchController.text.trim()}»",
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: ThemeService.primaryColor,
                            ),
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios, size: 12, color: ThemeService.primaryColor),
                      ],
                    ),
                  ),
                ),
              ),
          ],
          Expanded(
            child: _buildTabContent(cardBg, textPrimary, textSecondary, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(Color cardBg, Color textPrimary, Color textSecondary, bool isDark) {
    if (_selectedTab == 'hookah') {
      return _buildHookahView(cardBg, textPrimary, textSecondary, isDark);
    } else if (_selectedTab == 'cigarettes') {
      return _buildCigarettesView(cardBg, textPrimary, textSecondary, isDark);
    } else {
      return _buildVapeView(cardBg, textPrimary, textSecondary, isDark);
    }
  }

  Widget _buildHookahView(Color cardBg, Color textPrimary, Color textSecondary, bool isDark) {
    final active = DeviceService.activeDevice.value;
    final isHookahActive = active.type == 'hookah';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              Container(
                height: 150,
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                child: Image.asset(
                  'assets/images/devices/hookah.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                tr("Hookah Setup", "Кальянный сетап"),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                tr(
                  "Current blend: ${isHookahActive ? (active.tobacco ?? 'Not selected') : 'Berry Mint Mix'}",
                  "Текущий табак: ${isHookahActive ? (active.tobacco ?? 'Не выбран') : 'Berry Mint Mix'}",
                ),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: ThemeService.primaryColor, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: ThemeService.primaryColor, width: 1.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => const _HookahTobaccoSheet(),
                        ).then((_) {
                          if (mounted) setState(() {});
                        });
                      },
                      icon: Icon(Icons.edit_note, color: ThemeService.primaryColor),
                      label: Text(
                        tr("Change Blend", "Сменить табак"),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: ThemeService.primaryColor,
                        foregroundColor: ThemeService.onPrimaryColor,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () async {
                        final nav = Navigator.of(context);
                        final messenger = ScaffoldMessenger.of(context);
                        await DeviceService.selectDevice(DeviceService.defaultHookah);
                        if (!mounted) return;
                        nav.pop();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(tr("Selected setup: Classic Hookah", "Выбран сетап: Кальян Shisha")),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      },
                      child: Text(
                        isHookahActive ? tr("Already Active", "Уже активен") : tr("Select", "Выбрать"),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: ThemeService.onPrimaryColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCigarettesView(Color cardBg, Color textPrimary, Color textSecondary, bool isDark) {
    final active = DeviceService.activeDevice.value;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: DeviceService.cigaretteCatalog.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final cig = DeviceService.cigaretteCatalog[index];
        final isSelected = active.id == cig.id;

        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            final nav = Navigator.of(context);
            final messenger = ScaffoldMessenger.of(context);
            await DeviceService.selectDevice(cig);
            if (!mounted) return;
            nav.pop();
            messenger.showSnackBar(
              SnackBar(
                content: Text(tr("Selected setup: ${cig.name}", "Выбран сетап: ${cig.name}")),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected
                  ? ThemeService.accentLight(isDark)
                  : cardBg,
              borderRadius: BorderRadius.circular(20),
              border: isSelected ? Border.all(color: ThemeService.primaryColor, width: 1.5) : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1D1B) : const Color(0xFFF7F3EC),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _buildSafeDeviceImage(
                    cig.image,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cig.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        cig.subtitle,
                        style: TextStyle(fontSize: 13, color: textSecondary),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: isSelected ? ThemeService.primaryColor : textSecondary,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVapeView(Color cardBg, Color textPrimary, Color textSecondary, bool isDark) {
    final active = DeviceService.activeDevice.value;
    final allList = DeviceService.allVapes;
    final list = allList.where((v) {
      if (_searchQuery.isEmpty) return true;
      return v.name.toLowerCase().contains(_searchQuery) ||
          v.brand.toLowerCase().contains(_searchQuery) ||
          v.subtitle.toLowerCase().contains(_searchQuery);
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        if (_isSearchingOnline)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: ThemeService.primaryColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tr("Searching photo \"$_lastSearchedOnline\" online...", "Ищем фото «$_lastSearchedOnline» в интернете..."),
                    style: TextStyle(fontSize: 13, color: textSecondary),
                  ),
                ),
              ],
            ),
          ),
        if (_onlineResults.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ThemeService.accentLight(isDark),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: ThemeService.primaryColor.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.cloud_done_rounded, color: ThemeService.primaryColor, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          tr("Found online (${_onlineResults.length}):", "Найдено в сети (${_onlineResults.length}):"),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: ThemeService.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(Icons.close, size: 16, color: textSecondary),
                      onPressed: () => setState(() => _onlineResults.clear()),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 136,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _onlineResults.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, idx) {
                      final url = _onlineResults[idx];
                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _confirmSelectOnlineImage(
                          url,
                          _lastSearchedOnline ?? _searchController.text.trim(),
                        ),
                        child: Container(
                          width: 110,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? const Color(0xFF44413E) : const Color(0xFFE5DFD5),
                            ),
                          ),
                          child: Column(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: _buildSafeDeviceImage(url, fit: BoxFit.contain),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                decoration: BoxDecoration(
                                  color: ThemeService.primaryColor,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    tr("Select", "Выбрать"),
                                    style: TextStyle(
                                      color: ThemeService.onPrimaryColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openAddCustomVapeModal(_searchQuery.isNotEmpty ? _searchController.text.trim() : null),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: ThemeService.accentLight(isDark),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: ThemeService.primaryColor.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: ThemeService.primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.add, color: ThemeService.onPrimaryColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _searchQuery.isNotEmpty
                            ? tr("Add custom model \"${_searchController.text.trim()}\"", "Добавить свою модель «${_searchController.text.trim()}»")
                            : tr("Can't find your model? Add custom", "Не нашел свою модель? Добавить"),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: ThemeService.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tr("Custom pod with flavor & shell style", "Кастомная ашка с выбором вкуса и корпуса"),
                        style: TextStyle(fontSize: 12, color: textSecondary),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: ThemeService.primaryColor),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 36),
            child: Center(
              child: Text(
                tr(
                  "Model not found in catalog.\nTap the card above to add it!",
                  "Модель не найдена в каталоге.\nНажми карточку выше, чтобы добавить!",
                ),
                textAlign: TextAlign.center,
                style: TextStyle(color: textSecondary, fontSize: 14),
              ),
            ),
          )
        else
          ...list.map((vape) {
            final isSelected = active.id == vape.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () async {
                  final nav = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  await DeviceService.selectDevice(vape);
                  if (!mounted) return;
                  nav.pop();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(tr("Selected setup: ${vape.name}", "Выбран сетап: ${vape.name}")),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? ThemeService.accentLight(isDark)
                        : cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: isSelected ? Border.all(color: ThemeService.primaryColor, width: 1.5) : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1D1B) : const Color(0xFFF7F3EC),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: _buildSafeDeviceImage(
                          vape.image,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vape.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              vape.subtitle,
                              style: TextStyle(fontSize: 13, color: textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: isSelected ? ThemeService.primaryColor : textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _AddCustomVapeSheet extends StatefulWidget {
  final String? initialName;
  const _AddCustomVapeSheet({this.initialName});

  @override
  State<_AddCustomVapeSheet> createState() => _AddCustomVapeSheetState();
}

class _AddCustomVapeSheetState extends State<_AddCustomVapeSheet> {
  final _nameController = TextEditingController();
  final _flavorController = TextEditingController();
  final _puffsController = TextEditingController();
  final _onlineSearchController = TextEditingController();

  int _selectedImageIndex = 0;
  String? _selectedOnlineImage;
  List<String> _onlineImages = [];
  bool _isSearchingOnline = false;
  ImageSearchSource _selectedSource = ImageSearchSource.all;

  List<Map<String, String>> get _renderOptions => [
    {
      'image': 'assets/images/devices/smoant_charon.png',
      'label': tr('Resin / Metal', 'Resin/Металл'),
    },
    {
      'image': 'assets/images/devices/vozol_gear.png',
      'label': tr('Outdoor Clip', 'Карабин'),
    },
    {
      'image': 'assets/images/devices/lost_mary_os5000.png',
      'label': tr('Box Pod', 'Бокс-мод'),
    },
    {
      'image': 'assets/images/devices/elf_bar_bc5000.png',
      'label': tr('Pocket Mini', 'Флакончик'),
    },
    {
      'image': 'assets/images/devices/waka_sopro_10000.png',
      'label': tr('Smart Dual', 'Смарт'),
    },
    {
      'image': 'assets/images/devices/geek_bar_pulse.png',
      'label': tr('Pulse LED', 'Пульс'),
    },
    {
      'image': 'assets/images/devices/vaporesso_xros.png',
      'label': tr('Stick / Pod', 'Стик / Под'),
    },
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialName != null && widget.initialName!.isNotEmpty) {
      _nameController.text = widget.initialName!;
      _onlineSearchController.text = widget.initialName!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchOnline();
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _flavorController.dispose();
    _puffsController.dispose();
    _onlineSearchController.dispose();
    super.dispose();
  }

  Future<void> _searchOnline() async {
    String q = _onlineSearchController.text.trim();
    if (q.isEmpty) {
      q = _nameController.text.trim();
      if (_flavorController.text.trim().isNotEmpty) {
        q = "$q ${_flavorController.text.trim()}";
      }
    }
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSearchingOnline = true);
    final results = await ImageSearchService.searchVapeImages(
      q,
      source: _selectedSource,
    );
    if (!mounted) return;
    setState(() {
      _onlineImages = results;
      _isSearchingOnline = false;
      if (results.isNotEmpty) {
        _selectedOnlineImage = results.first;
      }
    });
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final flavor = _flavorController.text.trim();
    final puffs = _puffsController.text.trim();
    final chosenAsset = _renderOptions[_selectedImageIndex]['image']!;
    final imageToUse = _selectedOnlineImage ?? chosenAsset;

    String subtitle = "";
    if (flavor.isNotEmpty && puffs.isNotEmpty) {
      subtitle = "$flavor • $puffs";
    } else if (flavor.isNotEmpty) {
      subtitle = flavor;
    } else if (puffs.isNotEmpty) {
      subtitle = puffs;
    } else {
      subtitle = tr("Custom Model", "Кастомная модель");
    }

    final newVape = DeviceModel(
      id: 'vape_custom_${DateTime.now().millisecondsSinceEpoch}',
      type: 'vape',
      name: name,
      brand: tr('Custom', 'Своя модель'),
      subtitle: subtitle,
      image: imageToUse,
      flavor: flavor.isNotEmpty ? flavor : null,
      strength: 2.5,
    );

    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    await DeviceService.addCustomVape(newVape);
    if (!mounted) return;

    nav.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(tr("Added and selected model: $name", "Добавлена и выбрана модель: $name")),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = ThemeService.cardColor(isDark);
    final textPrimary = ThemeService.textPrimary(isDark);
    final textSecondary = ThemeService.textSecondary(isDark);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(16, 14, 16, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF44413E) : const Color(0xFFCCCCCC),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  tr("Add Custom Pod / Device", "Добавить свою ашку / под"),
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textPrimary),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              tr("Device photo from the web:", "Фотография устройства из интернета:"),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textSecondary),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _onlineSearchController,
                    style: TextStyle(color: textPrimary, fontSize: 13),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _searchOnline(),
                    decoration: InputDecoration(
                      hintText: tr("Search photo (Pod Mini, Pocket Vaporizer...)", "Поиск фото..."),
                      hintStyle: TextStyle(color: textSecondary, fontSize: 12),
                      filled: true,
                      fillColor: cardBg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: Icon(Icons.travel_explore, color: ThemeService.primaryColor, size: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: ThemeService.accentLight(isDark),
                    foregroundColor: ThemeService.primaryColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  ),
                  onPressed: _searchOnline,
                  child: _isSearchingOnline
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: ThemeService.primaryColor),
                        )
                      : Text(tr("Search", "Найти"), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: ImageSearchSource.values.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, idx) {
                  final src = ImageSearchSource.values[idx];
                  final isSel = _selectedSource == src;
                  return ChoiceChip(
                    label: Text(src.label),
                    selected: isSel,
                    showCheckmark: false,
                    side: BorderSide.none,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                      color: isSel ? (isDark ? Colors.white : Colors.black) : textSecondary,
                    ),
                    backgroundColor: cardBg,
                    selectedColor: ThemeService.accentLight(isDark),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    onSelected: (_) {
                      setState(() => _selectedSource = src);
                      _searchOnline();
                    },
                  );
                },
              ),
            ),
            if (_onlineImages.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                tr("Found online (tap to select):", "Найдено в сети (нажми, чтобы выбрать):"),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 96,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _onlineImages.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, idx) {
                    final url = _onlineImages[idx];
                    final isSelected = _selectedOnlineImage == url;
                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        setState(() {
                          _selectedOnlineImage = url;
                        });
                      },
                      child: Container(
                        width: 84,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? ThemeService.primaryColor
                                : (isDark ? const Color(0xFF44413E) : const Color(0xFFDDD8CE)),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Stack(
                          children: [
                            Center(
                              child: _buildSafeDeviceImage(url, fit: BoxFit.contain),
                            ),
                            if (isSelected)
                              Positioned(
                                top: 0,
                                right: 0,
                                child: Icon(Icons.check_circle, color: ThemeService.primaryColor, size: 16),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              tr("Or choose a 3D shell preset (offline):", "Или готовая 3D-модель (офлайн):"),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textSecondary),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 94,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _renderOptions.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final isChosen = _selectedOnlineImage == null && _selectedImageIndex == idx;
                  final opt = _renderOptions[idx];
                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      setState(() {
                        _selectedImageIndex = idx;
                        _selectedOnlineImage = null;
                      });
                    },
                    child: Container(
                      width: 84,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      decoration: BoxDecoration(
                        color: isChosen
                            ? ThemeService.accentLight(isDark)
                            : cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: isChosen
                            ? Border.all(color: ThemeService.primaryColor, width: 1.5)
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(opt['image']!, height: 44, fit: BoxFit.contain),
                          const SizedBox(height: 4),
                          Text(
                            opt['label']!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isChosen ? FontWeight.bold : FontWeight.normal,
                              color: isChosen ? ThemeService.primaryColor : textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _nameController,
              style: TextStyle(color: textPrimary, fontSize: 14),
              onChanged: (val) {
                if (_onlineSearchController.text.isEmpty ||
                    _onlineSearchController.text == widget.initialName) {
                  _onlineSearchController.text = val;
                }
              },
              decoration: InputDecoration(
                hintText: tr("Model name (e.g. Pocket Pod Mini, Smart Vaporizer)", "Название модели"),
                hintStyle: TextStyle(color: textSecondary, fontSize: 13),
                filled: true,
                fillColor: cardBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(Icons.vape_free, color: ThemeService.primaryColor, size: 20),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _flavorController,
              style: TextStyle(color: textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: tr("Flavor / blend (e.g. Mango Ice)", "Вкус / аромат (например: Манго Холодок)"),
                hintStyle: TextStyle(color: textSecondary, fontSize: 13),
                filled: true,
                fillColor: cardBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(Icons.bubble_chart_outlined, color: textSecondary, size: 20),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _puffsController,
              style: TextStyle(color: textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: tr("Capacity / puffs (e.g. 10,000 puffs)", "Объем / тяги (например: 10000 тяг)"),
                hintStyle: TextStyle(color: textSecondary, fontSize: 13),
                filled: true,
                fillColor: cardBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(Icons.speed, color: textSecondary, size: 20),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: ThemeService.primaryColor,
                  foregroundColor: ThemeService.onPrimaryColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _submit,
                child: Text(
                  tr("Add & Select Setup", "Добавить и выбрать сетап"),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: ThemeService.onPrimaryColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmOnlineDeviceSheet extends StatefulWidget {
  final String imageUrl;
  final String initialName;

  const _ConfirmOnlineDeviceSheet({
    required this.imageUrl,
    required this.initialName,
  });

  @override
  State<_ConfirmOnlineDeviceSheet> createState() => _ConfirmOnlineDeviceSheetState();
}

class _ConfirmOnlineDeviceSheetState extends State<_ConfirmOnlineDeviceSheet> {
  late final TextEditingController _nameController;
  final _flavorController = TextEditingController();
  final _puffsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _flavorController.dispose();
    _puffsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final flavor = _flavorController.text.trim();
    final puffs = _puffsController.text.trim();

    String subtitle = "";
    if (flavor.isNotEmpty && puffs.isNotEmpty) {
      subtitle = "$flavor • $puffs";
    } else if (flavor.isNotEmpty) {
      subtitle = flavor;
    } else if (puffs.isNotEmpty) {
      subtitle = puffs;
    } else {
      subtitle = tr("My Device", "Мой девайс");
    }

    final newVape = DeviceModel(
      id: 'vape_online_${DateTime.now().millisecondsSinceEpoch}',
      type: 'vape',
      name: name,
      brand: tr('Online', 'Онлайн'),
      subtitle: subtitle,
      image: widget.imageUrl,
      flavor: flavor.isNotEmpty ? flavor : null,
      strength: 2.5,
    );

    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    await DeviceService.addCustomVape(newVape);
    if (!mounted) return;

    nav.pop(true);
    messenger.showSnackBar(
      SnackBar(
        content: Text(tr("Setup selected and linked: $name", "Сетап выбран и привязан: $name")),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = ThemeService.cardColor(isDark);
    final textPrimary = ThemeService.textPrimary(isDark);
    final textSecondary = ThemeService.textSecondary(isDark);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(16, 14, 16, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF44413E) : const Color(0xFFCCCCCC),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  tr("Link to Account", "Привязать к аккаунту"),
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textPrimary),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 100,
                height: 100,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1D1B) : const Color(0xFFF7F3EC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: ThemeService.primaryColor, width: 1.5),
                ),
                child: _buildSafeDeviceImage(widget.imageUrl, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _nameController,
              style: TextStyle(color: textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: tr("Model name (e.g. Pod System, Pocket Vaporizer...)", "Название модели"),
                hintStyle: TextStyle(color: textSecondary, fontSize: 13),
                filled: true,
                fillColor: cardBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(Icons.vape_free, color: ThemeService.primaryColor, size: 20),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _flavorController,
              style: TextStyle(color: textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: tr("Flavor / color (e.g. Green Apple)", "Вкус / цвет (например: Зеленое яблоко)"),
                hintStyle: TextStyle(color: textSecondary, fontSize: 13),
                filled: true,
                fillColor: cardBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(Icons.bubble_chart_outlined, color: textSecondary, size: 20),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _puffsController,
              style: TextStyle(color: textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: tr("Puffs / capacity (e.g. 15,000 puffs)", "Тяги / объем (например: 15000 тяг)"),
                hintStyle: TextStyle(color: textSecondary, fontSize: 13),
                filled: true,
                fillColor: cardBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(Icons.speed, color: textSecondary, size: 20),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: ThemeService.primaryColor,
                  foregroundColor: ThemeService.onPrimaryColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _submit,
                child: Text(
                  tr("Link & Select Setup", "Привязать и выбрать сетап"),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: ThemeService.onPrimaryColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
