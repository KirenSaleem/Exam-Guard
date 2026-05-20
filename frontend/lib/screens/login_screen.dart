import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/api_error_handler.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';
import 'classroom_dashboard.dart';
import 'profile_setup_screen.dart';

/// Teacher login: email/password or Google. Supports account switch and cancel.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  User? _cachedFirebaseUser;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _cachedFirebaseUser = _authService.currentUser;
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    await _handleAuthAction(
      () => _authService.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      ),
      successMessage: 'Welcome back!',
    );
  }

  Future<void> _register() async {
    await _handleAuthAction(
      () => _authService.signUpWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      ),
      successMessage: 'Account created successfully',
    );
  }

  Future<void> _googleSignIn({bool switchAccount = false}) async {
    await _handleAuthAction(
      () => _authService.signInWithGoogle(forceAccountPicker: switchAccount),
      successMessage: 'Signed in with Google',
      requireEmailPassword: false,
    );
  }

  /// Shared post-auth navigation: dashboard if profile exists, else setup screen.
  Future<void> _handleAuthAction(
    Future<UserCredential?> Function() action, {
    required String successMessage,
    bool requireEmailPassword = true,
  }) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (requireEmailPassword && (email.isEmpty || password.isEmpty)) {
      AppUi.snack(context, 'Email and password are required.', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await action();
      if (!mounted) return;

      if (result == null) {
        AppUi.snack(context, 'Sign-in cancelled. You can try again or choose another account.');
        return;
      }

      final user = result.user;
      if (user == null) {
        AppUi.snack(context, 'Could not read user info.', isError: true);
        return;
      }

      AppUi.snack(context, successMessage);
      await _navigateAfterAuth(user);
    } catch (e) {
      if (!mounted) return;
      AppUi.snack(context, ApiErrorHandler.userMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _navigateAfterAuth(User user) async {
    final email = _resolveEmail(user);
    final profile = await _apiService.getTeacherProfile(user.uid);
    if (!mounted) return;

    if (profile != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ClassroomDashboard(firebaseUid: user.uid)),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ProfileSetupScreen(firebaseUid: user.uid, email: email),
        ),
      );
    }
  }

  Future<void> _continueWithCachedUser() async {
    final user = _cachedFirebaseUser;
    if (user == null) return;
    setState(() => _isLoading = true);
    try {
      await _navigateAfterAuth(user);
    } catch (e) {
      if (mounted) AppUi.snack(context, ApiErrorHandler.userMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOutAndReset() async {
    setState(() => _isLoading = true);
    try {
      await _authService.signOut();
      if (!mounted) return;
      setState(() {
        _cachedFirebaseUser = null;
        _emailController.clear();
        _passwordController.clear();
      });
      AppUi.snack(context, 'Signed out. Choose how you want to sign in.');
    } catch (e) {
      if (mounted) AppUi.snack(context, ApiErrorHandler.userMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _resolveEmail(User user) {
    if (user.email != null && user.email!.isNotEmpty) return user.email!;
    for (final info in user.providerData) {
      if (info.email != null && info.email!.isNotEmpty) return info.email!;
    }
    return '${user.uid}@examguard.app';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEEF2FF), Color(0xFFF8FAFC)],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_cachedFirebaseUser != null) _buildCachedUserBanner(),
                  const SizedBox(height: 12),
                  _buildLogo(theme),
                  const SizedBox(height: 32),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Teacher Sign In', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                        const SizedBox(height: 4),
                        Text('Secure access for invigilators', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _isLoading ? null : _login,
                          child: _isLoading
                              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Sign In'),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: _isLoading ? null : _register,
                          child: const Text('Create Account'),
                        ),
                        const SizedBox(height: 20),
                        Row(children: [
                          Expanded(child: Divider(color: Colors.grey.shade300)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('or', style: TextStyle(color: Colors.grey.shade500)),
                          ),
                          Expanded(child: Divider(color: Colors.grey.shade300)),
                        ]),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _isLoading ? null : () => _googleSignIn(),
                          icon: Image.network(
                            'https://www.google.com/favicon.ico',
                            width: 18,
                            height: 18,
                            errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata_rounded, size: 22),
                          ),
                          label: const Text('Continue with Google'),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _isLoading ? null : () => _googleSignIn(switchAccount: true),
                          icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                          label: const Text('Use a different Google account'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCachedUserBanner() {
    final email = _cachedFirebaseUser?.email ?? 'Signed-in account';
    return AppCard(
      gradient: LinearGradient(
        colors: [AppColors.primary.withValues(alpha: 0.12), AppColors.secondary.withValues(alpha: 0.08)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppBadge.ai(label: 'SESSION FOUND'),
          const SizedBox(height: 10),
          Text('Continue as $email', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _isLoading ? null : _continueWithCachedUser,
                  child: const Text('Continue'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _isLoading ? null : _signOutAndReset,
                child: const Text('Sign out'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogo(ThemeData theme) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(Icons.shield_outlined, color: Colors.white, size: 40),
        ),
        const SizedBox(height: 16),
        Text(
          'ExamGuard',
          style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
        const SizedBox(height: 6),
        Text(
          'AI-powered exam monitoring',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
      ],
    );
  }
}
