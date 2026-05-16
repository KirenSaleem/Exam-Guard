import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'classroom_dashboard.dart';
import 'profile_setup_screen.dart';
import '../services/api_error_handler.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

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
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
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
      successMessage: 'Login successful',
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

  Future<void> _googleSignIn() async {
    await _handleAuthAction(
      () => _authService.signInWithGoogle(),
      successMessage: 'Google sign-in successful',
      requireEmailPassword: false,
    );
  }

  Future<void> _handleAuthAction(
    Future<UserCredential?> Function() action, {
    required String successMessage,
    bool requireEmailPassword = true,
  }) async {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();

    if (requireEmailPassword && (email.isEmpty || password.isEmpty)) {
      _showMessage('Email and password are required.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final UserCredential? result = await action();
      if (!mounted) return;
      if (result == null) {
        _showMessage('Google sign-in cancelled.');
        return;
      }
      _showMessage(successMessage);
      final User? user = result.user;
      if (user == null) {
        _showMessage('Could not read user info.');
        return;
      }

      final email = _resolveEmail(user);
      final profile = await _apiService.getTeacherProfile(user.uid);
      if (!mounted) return;

      if (profile != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ClassroomDashboard(firebaseUid: user.uid),
          ),
        );
      } else {
        // MongoDB was cleared — Firebase account exists but no teacher profile yet.
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ProfileSetupScreen(
              firebaseUid: user.uid,
              email: email,
            ),
          ),
        );
      }
    } catch (e) {
      _showMessage(ApiErrorHandler.userMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _resolveEmail(User user) {
    if (user.email != null && user.email!.isNotEmpty) {
      return user.email!;
    }
    for (final info in user.providerData) {
      if (info.email != null && info.email!.isNotEmpty) {
        return info.email!;
      }
    }
    return '${user.uid}@examguard.app';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w500)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Container(
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withOpacity(0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.shield_outlined, color: Colors.white, size: 36),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'ExamGuard',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'AI exam monitoring for teachers',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.55),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                const Text('Email address', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'you@example.com',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Password', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: _isLoading ? null : _login,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Teacher Sign In', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _isLoading ? null : _register,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Create Teacher Account', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: Divider(color: colorScheme.outline.withOpacity(0.3))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'or',
                        style: TextStyle(color: colorScheme.onSurface.withOpacity(0.45)),
                      ),
                    ),
                    Expanded(child: Divider(color: colorScheme.outline.withOpacity(0.3))),
                  ],
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _googleSignIn,
                  icon: const Icon(Icons.language, size: 18),
                  label: const Text('Continue with Google', style: TextStyle(fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
