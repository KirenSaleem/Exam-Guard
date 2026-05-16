import 'package:flutter/material.dart';

import '../services/api_error_handler.dart';
import '../services/api_service.dart';
import 'exam_history_screen.dart';
import 'monitoring_dashboard.dart';
import 'registered_students_screen.dart';
import 'start_exam_screen.dart';
import 'student_registration_form.dart';

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : null,
      ),
    );
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
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colorScheme.primary, colorScheme.primary.withOpacity(0.82)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _classInfoTile(Icons.key_rounded, 'Code', classroomCode)),
                      Container(width: 1, height: 40, color: Colors.white24),
                      Expanded(child: _classInfoTile(Icons.people_rounded, 'Students', '$_studentCount')),
                      Container(width: 1, height: 40, color: Colors.white24),
                      Expanded(child: _classInfoTile(Icons.school_rounded, 'Teachers', '${teachers.length}')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isActive ? Colors.greenAccent : Colors.white54,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isActive ? 'Monitoring Active' : 'Monitoring Inactive',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 10),
              child: Text(
                'CLASSROOM ACTIONS',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.8),
              ),
            ),
            _actionCard(
              context: context,
              icon: isActive ? Icons.monitor_rounded : Icons.play_circle_rounded,
              iconBgColor: isActive ? Colors.green.shade600 : colorScheme.primary,
              title: isActive ? 'Open Monitoring' : 'Start Monitoring',
              subtitle: isActive ? 'Return to the running exam session' : 'Begin AI exam monitoring',
              onTap: _openMonitoring,
            ),
            const SizedBox(height: 10),
            _actionCard(
              context: context,
              icon: Icons.qr_code_2_rounded,
              iconBgColor: Colors.teal.shade600,
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
            _actionCard(
              context: context,
              icon: Icons.people_alt_rounded,
              iconBgColor: Colors.indigo.shade500,
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
            _actionCard(
              context: context,
              icon: Icons.history_rounded,
              iconBgColor: Colors.orange.shade600,
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

  Widget _classInfoTile(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  Widget _actionCard({
    required BuildContext context,
    required IconData icon,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outline.withOpacity(0.12)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: iconBgColor, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: TextStyle(fontSize: 13, color: colorScheme.onSurface.withOpacity(0.5))),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: colorScheme.onSurface.withOpacity(0.3)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
