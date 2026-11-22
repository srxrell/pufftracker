import 'package:flutter/material.dart';
import 'package:untitled/screens/mascot_boost_sheet.dart';
import 'package:untitled/services/auth_service.dart';
import 'package:untitled/services/locale_service.dart';
import 'package:untitled/services/mascot_service.dart';
import 'package:untitled/services/theme_service.dart';

class LeaderBoard extends StatefulWidget {
  final int currentPuffs;

  const LeaderBoard({super.key, this.currentPuffs = 0});

  @override
  State<LeaderBoard> createState() => _LeaderBoardState();
}

class _LeaderBoardState extends State<LeaderBoard> {
  int _mainTab = 0;
  bool _isLoading = true;
  List<Map<String, dynamic>> _cloudLeaders = [];

  @override
  void initState() {
    super.initState();
    _loadLeaders();
  }

  Future<void> _loadLeaders() async {
    setState(() => _isLoading = true);
    final data = await AuthService.fetchLeaderboard();
    if (!mounted) return;
    setState(() {
      _cloudLeaders = data;
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> _getDisplayList() {
    final list = List<Map<String, dynamic>>.from(_cloudLeaders);
    final currentUser = AuthService.currentUser;
    final effectivePuffs = widget.currentPuffs > 0
        ? widget.currentPuffs
        : (currentUser?.pcounter ?? AuthService.localPuffs);

    if (currentUser == null) {
      list.add({
        'id': 'guest',
        'name': tr('You (Guest)', 'Ты (Гость)'),
        'puffs': effectivePuffs,
        'isMe': true,
      });
      list.sort((a, b) => (b['puffs'] as int).compareTo(a['puffs'] as int));
    } else {
      bool hasMe = false;
      for (final u in list) {
        if (u['id'] == currentUser.id) {
          hasMe = true;
          u['isMe'] = true;
          u['name'] = '${u['name']}';
          if (effectivePuffs > (u['puffs'] as int)) {
            u['puffs'] = effectivePuffs;
          }
          break;
        }
      }
      if (!hasMe) {
        list.add({
          'id': currentUser.id,
          'name': '${currentUser.username}',
          'puffs': effectivePuffs > currentUser.pcounter ? effectivePuffs : currentUser.pcounter,
          'isMe': true,
        });
        list.sort((a, b) => (b['puffs'] as int).compareTo(a['puffs'] as int));
      }
    }

    return list;
  }

  List<Map<String, dynamic>> _getAchievements() {
    final total = AuthService.currentUser?.pcounter ?? AuthService.localPuffs;
    final isRegistered = AuthService.currentUser != null;

    return [
      {
        'title': tr('First Draw', 'Первая тяга'),
        'desc': tr('Track your very first puff', 'Сделать хотя бы одну затяжку'),
        'icon': Icons.play_circle_outline,
        'unlocked': total >= 1,
        'progress': '$total / 1',
      },
      {
        'title': tr('Club Member', 'Член клуба'),
        'desc': tr('Create a cloud account in PuffTrack', 'Зарегистрировать профиль в Supabase'),
        'icon': Icons.verified_user_outlined,
        'unlocked': isRegistered,
        'progress': isRegistered ? tr('Completed', 'Выполнено') : tr('Sign in', 'Войди в аккаунт'),
      },
      {
        'title': tr('Cloud Chaser', 'Паровоз'),
        'desc': tr('Track 50 puffs in your profile', 'Набрать 50 затяжек в аккаунте'),
        'icon': Icons.train_outlined,
        'unlocked': total >= 50,
        'progress': '$total / 50',
      },
      {
        'title': tr('Century Mark', 'Градирня'),
        'desc': tr('Reach 100 tracked puffs', 'Набрать 100 затяжек в аккаунте'),
        'icon': Icons.factory_outlined,
        'unlocked': total >= 100,
        'progress': '$total / 100',
      },
      {
        'title': tr('Session Pro', 'Оптовик'),
        'desc': tr('Reach 500 cumulative puffs', 'Пробить 500 затяжек суммарно'),
        'icon': Icons.all_inclusive,
        'unlocked': total >= 500,
        'progress': '$total / 500',
      },
      {
        'title': tr('Lounge Legend', 'Легенда кальянной'),
        'desc': tr('Reach 1,000 tracked puffs', 'Сделать 1000 затяжек'),
        'icon': Icons.workspace_premium_outlined,
        'unlocked': total >= 1000,
        'progress': '$total / 1000',
      },
      {
        'title': tr('Deep Diver', 'Фридайвер'),
        'desc': tr('Complete a draw longer than 4.5s', 'Затяжка длительностью более 4.5 сек'),
        'icon': Icons.scuba_diving_outlined,
        'unlocked': false,
        'progress': tr('In progress', 'В процессе'),
      },
      {
        'title': tr('Turbo Boost', 'Турбонаддув'),
        'desc': tr('Hold a single draw for 6+ seconds', 'Удержать затяжку 6+ секунд'),
        'icon': Icons.speed_outlined,
        'unlocked': false,
        'progress': tr('In progress', 'В процессе'),
      },
      {
        'title': tr('Peak Intensity', 'Поймал бледного'),
        'desc': tr('Fill the session intensity meter to 100%', 'Заполнить шкалу «даст в бошку» до 100%'),
        'icon': Icons.warning_amber_rounded,
        'unlocked': false,
        'progress': tr('In progress', 'В процессе'),
      },
      {
        'title': tr('AI Vision Master', 'Дымовая завеса'),
        'desc': tr('Detect a puff automatically via AI camera', 'Зафиксировать облако пара в объектив'),
        'icon': Icons.cloud_outlined,
        'unlocked': false,
        'progress': tr('In progress', 'В процессе'),
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = ThemeService.cardColor(isDark);
    final textPrimary = ThemeService.textPrimary(isDark);
    final textSecondary = ThemeService.textSecondary(isDark);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(surfaceTintColor: Colors.transparent,
        title: Text(
          _mainTab == 0 ? tr("Leaderboard", "Таблица лидеров") : tr("Achievements", "Достижения"),
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
        actions: [
          ValueListenableBuilder<int>(
            valueListenable: MascotService.pointsNotifier,
            builder: (context, pts, _) {
              return TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: ThemeService.primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                onPressed: () {
                  MascotBoostSheet.show(
                    context,
                    currentPuffs: widget.currentPuffs > 0
                        ? widget.currentPuffs
                        : (AuthService.currentUser?.pcounter ?? AuthService.localPuffs),
                    onPuffsBoosted: (_) {
                      _loadLeaders();
                    },
                  );
                },
                icon: const Icon(Icons.bolt, size: 16),
                label: Text(
                  "$pts 🚀",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            },
          ),
          if (_mainTab == 0)
            IconButton(
              icon: Icon(Icons.refresh, color: textPrimary),
              onPressed: _loadLeaders,
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
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
                  ButtonSegment<int>(
                    value: 0,
                    label: Text(tr("Leaders", "Лидеры")),
                    icon: const Icon(Icons.leaderboard_outlined),
                  ),
                  ButtonSegment<int>(
                    value: 1,
                    label: Text(tr("Achievements", "Ачивки")),
                    icon: const Icon(Icons.military_tech_outlined),
                  ),
                ],
                selected: {_mainTab},
                onSelectionChanged: (set) {
                  setState(() {
                    _mainTab = set.first;
                  });
                },
              ),
            ),
          ),
          Expanded(
            child: _mainTab == 0
                ? _buildLeaderboardTab(cardBg, textPrimary, textSecondary, isDark)
                : _buildAchievementsTab(cardBg, textPrimary, textSecondary, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardTab(Color cardBg, Color textPrimary, Color textSecondary, bool isDark) {
    final leaders = _getDisplayList();

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: ThemeService.primaryColor),
      );
    }

    return RefreshIndicator(
      color: ThemeService.primaryColor,
      onRefresh: _loadLeaders,
      child: leaders.isEmpty
          ? Center(
              child: Text(
                tr("No puffs tracked yet.\nTrack your first one!", "Пока нет затяжек.\nСделай первую!"),
                textAlign: TextAlign.center,
                style: TextStyle(color: textSecondary, fontSize: 16),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: leaders.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = leaders[index];
                final rank = index + 1;
                final isMe = item['isMe'] == true;

                final itemBg = isMe
                    ? ThemeService.accentLight(isDark)
                    : cardBg;

                return Container(
                  decoration: BoxDecoration(
                    color: itemBg,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    leading: _buildRankBadge(rank),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(
                            item['name'],
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isMe ? FontWeight.w900 : FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                        ),
                        if (rank == 1) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.whatshot, size: 18, color: Colors.orange),
                        ],
                      ],
                    ),
                    trailing: Text(
                      "${item['puffs']}",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: isMe ? ThemeService.primaryColor : textPrimary,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildAchievementsTab(Color cardBg, Color textPrimary, Color textSecondary, bool isDark) {
    final achievements = _getAchievements();

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: achievements.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final a = achievements[index];
        final unlocked = a['unlocked'] as bool;

        final badgeBg = unlocked
            ? ThemeService.accentLight(isDark)
            : (isDark ? const Color(0xFF33312E) : const Color(0xFFECE6DA));
        final iconColor = unlocked ? ThemeService.primaryColor : textSecondary;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  a['icon'] as IconData,
                  color: iconColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a['title'] as String,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      a['desc'] as String,
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: unlocked
                      ? (isDark ? const Color(0xFF2C3E2D) : const Color(0xFFE8F5E9))
                      : (isDark ? const Color(0xFF1E1D1B) : const Color(0xFFF6F2EA)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      unlocked ? Icons.check_circle_outline : Icons.lock_outline,
                      size: 14,
                      color: unlocked ? const Color(0xFF2E7D32) : textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      a['progress'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: unlocked ? const Color(0xFF2E7D32) : textSecondary,
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
  }

  Widget _buildRankBadge(int rank) {
    Color badgeColor = const Color(0xFFECE6DA);
    Color textColor = const Color(0xFF555555);

    if (rank == 1) {
      badgeColor = const Color(0xFFFFD54F);
      textColor = const Color(0xFF5D4037);
    } else if (rank == 2) {
      badgeColor = const Color(0xFFCFD8DC);
      textColor = const Color(0xFF37474F);
    } else if (rank == 3) {
      badgeColor = const Color(0xFFFFCCBC);
      textColor = const Color(0xFF4E342E);
    }

    return CircleAvatar(
      radius: 17,
      backgroundColor: badgeColor,
      child: Text(
        "#$rank",
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }
}
