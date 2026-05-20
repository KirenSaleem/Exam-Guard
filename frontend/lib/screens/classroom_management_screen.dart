import 'package:flutter/material.dart';

import '../services/api_error_handler.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';
import 'exam_history_screen.dart';
import 'monitoring_dashboard.dart';
import 'registered_students_screen.dart';
import 'start_exam_screen.dart';
import 'student_registration_form.dart';

/// Classroom hub: monitoring, registration link, students, exam history.
class ClassroomManagementScreen extends StatefulWidget {
  final Map<String, dynamic> classroom;
  final Map<String, dynamic>? activeSession;
  final String teacherUid;

  const ClassroomManagementScreen({
    super.key,
    required this.classroom,
    required this.activeSession,
    required this.teacherUid,
  });

  @override
  State<ClassroomManagementScreen> createState() => _ClassroomManagementScreenState();
}

class _ClassroomManagementScreenState extends State<ClassroomManagementScreen> {
  final ApiService _apiService = ApiService();
  late Map<String, dynamic> _classroom;
  Map<String, dynamic>? _activeSession;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _classroom = Map<String, dynamic>.from(widget.classroom);
    _activeSession = widget.activeSession;
    _refreshClassroom();
  }

  Future<void> _refreshClassroom() async {
    final classroomId = _classroom['classroom_id'] as String?;
    if (classroomId == null) return;

    setState(() => _isRefreshing = true);
    try {
      final fresh = await _apiService.getClassroom(classroomId);
      final active = await _apiService.getActiveExamSession(classroomId);
      if (!mounted) return;
      setState(() {
        _classroom = fresh;
        _activeSession = active;
      });
    } catch (e) {
      if (!mounted) return;
      _showSnack(ApiErrorHandler.userMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    AppUi.snack(context, message, isError: isError);
  }

  int get _studentCount {
    final count = _classroom['student_count'];
    if (count is int) return count;
    if (count is num) return count.toInt();
    return (_classroom['students_details'] as List?)?.length ?? 0;
  }

  Future<void> _openMonitoring() async {
    final classroomId = _classroom['classroom_id'] as String? ?? '';
    final classroomName = _classroom['classroom_name'] as String? ?? 'Classroom';
    final students = _classroom['students_details'] as List<dynamic>? ?? [];

    if (_activeSession != null) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MonitoringDashboard(
            session: _activeSession!,
            classroomId: classroomId,
            classroomName: classroomName,
            students: students,
            teacherUid: widget.teacherUid,
          ),
        ),
      );
      if (mounted) {
        await _refreshClassroom();
        if (result == true) Navigator.pop(context, true);
      }
      return;
    }

    final active = await _apiService.getActiveExamSession(classroomId);
    if (!mounted) return;

    if (active != null) {
      setState(() => _activeSession = active);
      final resume = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Exam Already Active'),
          content: Text(
            '“${active['exam_name'] ?? 'Exam'}” is still running.\n\n'
            'Resume the existing session instead of starting a new one.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Resume Exam')),
          ],
        ),
      );
      if (resume == true && mounted) {
        setState(() => _activeSession = active);
        await _openMonitoring();
      }
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StartExamScreen(
          classroomId: classroomId,
          classroomName: classroomName,
          teacherUid: widget.teacherUid,
          studentCount: _studentCount,
        ),
      ),
    );
    if (mounted) await _refreshClassroom();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final classroomId = _classroom['classroom_id'] as String? ?? '';
    final classroomName = _classroom['classroom_name'] as String? ?? 'Classroom';
    final classroomCode = _classroom['classroom_code'] as String? ?? '';
    final teachers = _classroom['teachers_details'] as List<dynamic>? ?? [];
    final isActive = _activeSession != null;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        title: Text(classroomName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context, true),
        ),
        actions: [
          if (_isRefreshing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              onPressed: _refreshClassroom,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppGradientHeader(
              title: classroomName,
              subtitle: 'Class code: $classroomCode',
              chips: [
                AppBadge(
                  label: isActive ? 'MONITORING LIVE' : 'INACTIVE',
                  background: isActive ? AppColors.success : Colors.grey.shade600,
                ),
                AppBadge.ai(label: 'AI READY'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _miniStat('Students', '$_studentCount', Icons.people_rounded)),
                const SizedBox(width: 8),
                Expanded(child: _miniStat('Teachers', '${teachers.length}', Icons.school_rounded)),
              ],
            ),
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 10),
              child: Text(
                'CLASSROOM ACTIONS',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.8),
              ),
            ),
            AppActionTile(
              icon: isActive ? Icons.monitor_rounded : Icons.play_circle_rounded,
              iconColor: isActive ? AppColors.success : AppColors.primary,
              title: isActive ? 'Open Monitoring' : 'Start Monitoring',
              subtitle: isActive ? 'Return to the running exam session' : 'Begin AI exam monitoring',
              onTap: _openMonitoring,
            ),
            const SizedBox(height: 10),
            AppActionTile(
              icon: Icons.qr_code_2_rounded,
              iconColor: AppColors.secondary,
              title: 'Generate Registration Form',
              subtitle: 'Share link or QR for student browser registration',
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GenerateRegistrationFormScreen(
                      classroomName: classroomName,
                      classroomCode: classroomCode,
                    ),
                  ),
                );
                if (mounted) await _refreshClassroom();
              },
            ),
            const SizedBox(height: 10),
            AppActionTile(
              icon: Icons.people_alt_rounded,
              iconColor: AppColors.primary,
              title: 'View Registered Students',
              subtitle: '$_studentCount students registered',
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RegisteredStudentsScreen(
                      classroomId: classroomId,
                      classroomName: classroomName,
                      classroomCode: classroomCode,
                    ),
                  ),
                );
                if (mounted) await _refreshClassroom();
              },
            ),
            const SizedBox(height: 10),
            AppActionTile(
              icon: Icons.history_rounded,
              iconColor: AppColors.warning,
              title: 'Exam History',
              subtitle: 'Sessions, alerts, suspicious activity & PDF reports',
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ExamHistoryScreen(
                      classroomId: classroomId,
                      classroomName: classroomName,
                      teacherUid: widget.teacherUid,
                    ),
                  ),
                );
                if (mounted) await _refreshClassroom();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value, IconData icon) {
    return AppCard(
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ],
          ),
        ],
      ),
    );
  }
}
