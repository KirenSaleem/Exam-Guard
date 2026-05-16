import 'package:flutter/material.dart';

import '../services/api_error_handler.dart';
import '../services/api_service.dart';
import 'monitoring_dashboard.dart';

class StartExamScreen extends StatefulWidget {
  final String classroomId;
  final String classroomName;
  final String teacherUid;
  final int studentCount;

  const StartExamScreen({
    super.key,
    required this.classroomId,
    required this.classroomName,
    required this.teacherUid,
    this.studentCount = 0,
  });

  @override
  State<StartExamScreen> createState() => _StartExamScreenState();
}

class _StartExamScreenState extends State<StartExamScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _examNameController = TextEditingController();
  bool _isLoading = false;
  bool _checkingActive = true;

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
  }

  @override
  void dispose() {
    _examNameController.dispose();
    super.dispose();
  }

  Future<void> _checkExistingSession() async {
    try {
      final active = await _apiService.getActiveExamSession(widget.classroomId);
      if (!mounted) return;
      if (active != null) {
        await _resumeSession(active);
        return;
      }
    } catch (e) {
      if (mounted) {
        _showMessage(ApiErrorHandler.userMessage(e), isError: true);
      }
    } finally {
      if (mounted) setState(() => _checkingActive = false);
    }
  }

  Future<void> _resumeSession(Map<String, dynamic> session) async {
    final students = await _apiService.getRegisteredStudents(widget.classroomId);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MonitoringDashboard(
          session: session,
          classroomId: widget.classroomId,
          classroomName: widget.classroomName,
          students: students,
          teacherUid: widget.teacherUid,
        ),
      ),
    );
  }

  Future<void> _startMonitoring() async {
    final examName = _examNameController.text.trim();
    if (examName.isEmpty) {
      _showMessage('Please enter exam name.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final result = await _apiService.startExamSession(
        classroomId: widget.classroomId,
        examName: examName,
        startedBy: widget.teacherUid,
      );

      if (!mounted) return;

      if (result.alreadyActive) {
        _showMessage('Resuming existing exam session.');
        await _resumeSession(result.session);
        return;
      }

      final students = await _apiService.getRegisteredStudents(widget.classroomId);
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MonitoringDashboard(
            session: result.session,
            classroomId: widget.classroomId,
            classroomName: widget.classroomName,
            students: students,
            teacherUid: widget.teacherUid,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage(ApiErrorHandler.userMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade600,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_checkingActive) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        title: const Text('Start Monitoring', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.class_rounded, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.classroomName, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(
                          '${widget.studentCount} students registered',
                          style: TextStyle(fontSize: 13, color: colorScheme.onSurface.withOpacity(0.55)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('Exam Name', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextField(
              controller: _examNameController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'e.g. Midterm Exam 2025',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _isLoading ? null : _startMonitoring,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.play_circle_rounded),
              label: Text(_isLoading ? 'Starting...' : 'Start Monitoring'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
