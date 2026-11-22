import 'package:flutter/material.dart';
import 'package:untitled/screens/main_navigation.dart';
import 'package:untitled/screens/tolerance_setup.dart';
import 'package:untitled/services/auth_service.dart';
import 'package:untitled/services/locale_service.dart';
import 'package:untitled/services/theme_service.dart';
import 'package:untitled/services/tolerance_service.dart';

class Authenticator extends StatefulWidget {
  const Authenticator({super.key});

  @override
  State<Authenticator> createState() => _AuthenticatorState();
}

class _AuthenticatorState extends State<Authenticator> {
  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = false;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nicknameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _proceedNext() {
    if (!ToleranceService.hasCompletedSetup) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const ToleranceSetup()),
        (route) => false,
      );
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const MainNavigation()),
        (route) => false,
      );
    }
  }

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    String? error;
    if (_isLogin) {
      error = await AuthService.signIn(
        login: _emailController.text,
        password: _passwordController.text,
      );
    } else {
      error = await AuthService.signUp(
        username: _nicknameController.text,
        email: _emailController.text,
        password: _passwordController.text,
      );
    }

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _isLoading = false;
        _errorMessage = error;
      });
    } else {
      _proceedNext();
    }
  }

  void _continueAsGuest() {
    _proceedNext();
  }

  InputDecoration _inputDecoration(
    String hint,
    IconData icon, {
    Widget? suffix,
    required bool isDark,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: isDark ? const Color(0xFF777777) : const Color(0xFF888888),
        fontSize: 16,
      ),
      prefixIcon: Icon(
        icon,
        color: isDark ? const Color(0xFFAAAAAA) : const Color(0xFF555555),
      ),
      suffixIcon: suffix,
      filled: true,
      fillColor: isDark ? const Color(0xFF242220) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: ThemeService.primaryColor, width: 1.5),
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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isLogin
                    ? tr("Welcome back\nto PuffTrack", "С возвращением\nв PuffTrack")
                    : tr("Create your\nprofile", "Создай свой\nпрофиль"),
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: textPrimary,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _isLogin
                    ? tr("Sign in to sync your session stats", "Войди, чтобы продолжить бить рекорды")
                    : tr("Join the leaderboard and sync your sessions", "Попади в таблицу лидеров и сохраняй свои сессии"),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  color: textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 32),
              if (_errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF441818) : const Color(0xFFFFE5E5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: isDark ? const Color(0xFFFF8B8B) : const Color(0xFFD32F2F),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (!_isLogin) ...[
                TextField(
                  controller: _nicknameController,
                  style: TextStyle(color: textPrimary, fontSize: 16),
                  decoration: _inputDecoration(tr("Username", "Никнейм"), Icons.person_outline, isDark: isDark),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: textPrimary, fontSize: 16),
                decoration: _inputDecoration(
                  _isLogin ? tr("Email or username", "Почта или никнейм") : tr("Email", "Почта"),
                  Icons.alternate_email,
                  isDark: isDark,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: TextStyle(color: textPrimary, fontSize: 16),
                decoration: _inputDecoration(
                  tr("Password", "Пароль"),
                  Icons.lock_outline,
                  isDark: isDark,
                  suffix: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: isDark ? const Color(0xFFAAAAAA) : const Color(0xFF555555),
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: ThemeService.primaryColor,
                    foregroundColor: ThemeService.onPrimaryColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: ThemeService.onPrimaryColor, strokeWidth: 2.5),
                        )
                      : Text(
                          _isLogin ? tr("Sign In", "Войти") : tr("Sign Up", "Зарегистрироваться"),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: ThemeService.onPrimaryColor,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: cardBg,
                    foregroundColor: textPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _isLoading ? null : _continueAsGuest,
                  child: Text(
                    tr("Continue as Guest", "Продолжить как гость"),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isLogin = !_isLogin;
                      _errorMessage = null;
                    });
                  },
                  child: Text.rich(
                    TextSpan(
                      text: _isLogin
                          ? tr("Don't have an account? ", "Нет аккаунта? ")
                          : tr("Already have an account? ", "Уже есть аккаунт? "),
                      style: TextStyle(fontSize: 15, color: textSecondary),
                      children: [
                        TextSpan(
                          text: _isLogin ? tr("Create one", "Создать") : tr("Sign In", "Войти"),
                          style: TextStyle(
                            color: ThemeService.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
