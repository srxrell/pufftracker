import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:untitled/services/device_service.dart';

class AppUser {
  final String id;
  final String username;
  final String email;
  int pcounter;

  AppUser({
    required this.id,
    required this.username,
    required this.email,
    required this.pcounter,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'email': email,
    'pcounter': pcounter,
  };
}

class AuthService {
  static AppUser? currentUser;
  static int localPuffs = 0;

  static SupabaseClient get _client => Supabase.instance.client;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    localPuffs = prefs.getInt('local_puffs') ?? 0;
    final savedId = prefs.getString('user_id');
    final savedName = prefs.getString('user_name');
    final savedEmail = prefs.getString('user_email');
    final savedPcounter = prefs.getInt('user_pcounter') ?? 0;

    if (savedId != null && savedName != null && savedEmail != null) {
      currentUser = AppUser(
        id: savedId,
        username: savedName,
        email: savedEmail,
        pcounter: savedPcounter,
      );

      try {
        final data = await _client
            .from('accounts')
            .select()
            .eq('id', savedId)
            .maybeSingle();

        if (data != null) {
          final cloudPuff = int.tryParse(data['pcounter']?.toString() ?? '0') ?? 0;
          currentUser = AppUser(
            id: data['id'],
            username: data['username'] ?? savedName,
            email: data['email'] ?? savedEmail,
            pcounter: cloudPuff,
          );
          await _saveUserToPrefs(currentUser!);
          if (data['devices'] != null) {
            DeviceService.loadFromCloud(data['devices']);
          } else {
            DeviceService.syncCurrentToCloud();
          }
        }
      } catch (_) {}
    }
  }

  static Future<String?> signUp({
    required String username,
    required String email,
    required String password,
  }) async {
    final cleanUsername = username.trim();
    final cleanEmail = email.trim().toLowerCase();
    final cleanPassword = password.trim();

    if (cleanUsername.isEmpty) return 'Введите имя пользователя';
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) return 'Введите корректный email';
    if (cleanPassword.length < 4) return 'Пароль должен быть от 4 символов';

    try {
      final existingEmail = await _client
          .from('accounts')
          .select('id')
          .eq('email', cleanEmail)
          .maybeSingle();
      if (existingEmail != null) return 'Пользователь с таким email уже существует';

      final existingName = await _client
          .from('accounts')
          .select('id')
          .eq('username', cleanUsername)
          .maybeSingle();
      if (existingName != null) return 'Никнейм уже занят';

      final initialPuff = localPuffs > 0 ? localPuffs.toString() : '0';

      final inserted = await _client.from('accounts').insert({
        'username': cleanUsername,
        'email': cleanEmail,
        'password': cleanPassword,
        'pcounter': initialPuff,
      }).select().single();

      final cloudPuffs = int.tryParse(inserted['pcounter']?.toString() ?? '0') ?? 0;

      currentUser = AppUser(
        id: inserted['id'],
        username: inserted['username'],
        email: inserted['email'],
        pcounter: cloudPuffs,
      );

      await _saveUserToPrefs(currentUser!);
      if (inserted['devices'] != null) {
        DeviceService.loadFromCloud(inserted['devices']);
      } else {
        DeviceService.syncCurrentToCloud();
      }
      return null;
    } on PostgrestException catch (e) {
      if (e.code == '555' || e.code == '500') {
        return 'База данных еще синхронизируется, нажми еще раз';
      }
      return e.message;
    } catch (e) {
      final str = e.toString();
      if (str.contains('555') || str.contains('500') || str.contains('Internal server error')) {
        return 'База данных еще синхронизируется, нажми еще раз';
      }
      return 'Ошибка при регистрации: $e';
    }
  }

  static Future<String?> signIn({
    required String login,
    required String password,
  }) async {
    final cleanLogin = login.trim();
    final cleanPassword = password.trim();

    if (cleanLogin.isEmpty) return 'Введите email или никнейм';
    if (cleanPassword.isEmpty) return 'Введите пароль';

    try {
      final data = await _client
          .from('accounts')
          .select()
          .or('email.eq.$cleanLogin,username.eq.$cleanLogin')
          .eq('password', cleanPassword)
          .maybeSingle();

      if (data == null) {
        return 'Неверный логин или пароль';
      }

      final cloudPuff = int.tryParse(data['pcounter']?.toString() ?? '0') ?? 0;

      currentUser = AppUser(
        id: data['id'],
        username: data['username'] ?? cleanLogin,
        email: data['email'] ?? '',
        pcounter: cloudPuff,
      );

      await _saveUserToPrefs(currentUser!);
      if (data['devices'] != null) {
        DeviceService.loadFromCloud(data['devices']);
      } else {
        DeviceService.syncCurrentToCloud();
      }
      return null;
    } on PostgrestException catch (e) {
      if (e.code == '555' || e.code == '500') {
        return 'База данных еще синхронизируется, нажми еще раз';
      }
      return e.message;
    } catch (e) {
      final str = e.toString();
      if (str.contains('555') || str.contains('500') || str.contains('Internal server error')) {
        return 'База данных еще синхронизируется, нажми еще раз';
      }
      return 'Ошибка входа: $e';
    }
  }

  static Future<void> signOut() async {
    currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('user_name');
    await prefs.remove('user_email');
    await prefs.remove('user_pcounter');
  }

  static Future<void> updatePuffs(int count) async {
    localPuffs = count;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('local_puffs', count);

    if (currentUser != null) {
      currentUser!.pcounter = count;
      await prefs.setInt('user_pcounter', count);

      try {
        await _client
            .from('accounts')
            .update({'pcounter': count.toString()})
            .eq('id', currentUser!.id);
      } catch (_) {}
    }
  }

  static Future<List<Map<String, dynamic>>> fetchLeaderboard() async {
    try {
      final data = await _client
          .from('accounts')
          .select('id, username, pcounter');

      final List<Map<String, dynamic>> list = [];
      for (final item in data) {
        final pVal = int.tryParse(item['pcounter']?.toString() ?? '0') ?? 0;
        list.add({
          'id': item['id'],
          'name': item['username'] ?? 'Аноним',
          'puffs': pVal,
          'isMe': currentUser != null && item['id'] == currentUser!.id,
        });
      }

      list.sort((a, b) => (b['puffs'] as int).compareTo(a['puffs'] as int));
      return list;
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveUserToPrefs(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', user.id);
    await prefs.setString('user_name', user.username);
    await prefs.setString('user_email', user.email);
    await prefs.setInt('user_pcounter', user.pcounter);
  }
}
