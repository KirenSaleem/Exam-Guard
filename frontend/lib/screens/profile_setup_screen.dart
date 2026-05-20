import 'package:flutter/material.dart';

import 'classroom_dashboard.dart';
import '../services/api_error_handler.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';

/// First-time teacher profile in MongoDB after Firebase sign-up.
class ProfileSetupScreen extends StatefulWidget {
  final String firebaseUid;
  final String email;

  const ProfileSetupScreen({
    super.key,
    required this.firebaseUid,
    required this.email,
  });

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final ApiService _apiService = ApiService();

  bool _isLoading = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final String name = _nameController.text.trim();
    if (name.isEmpty) {
      AppUi.snack(context, 'Please enter your full name', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final email = widget.email.trim().isEmpty
          ? '${widget.firebaseUid}@examguard.app'
          : widget.email.trim();

      await _apiService.createTeacherProfile(
        firebaseUid: widget.firebaseUid,
        email: email,
        name: name,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ClassroomDashboard(firebaseUid: widget.firebaseUid),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      AppUi.snack(context, ApiErrorHandler.userMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Teacher Setup'),
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: AppColors.heroGradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.cast_for_education_rounded, size: 36, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Complete Your Profile',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'ExamGuard is for teachers and invigilators',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.5),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              const SizedBox(height: 32),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Full Name', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: 'Enter your full name',
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Email: ${widget.email}',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isLoading ? null : _saveProfile,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  minimumSize: const Size.fromHeight(52),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text('Save & Continue', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
