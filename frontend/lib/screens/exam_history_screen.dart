import 'package:flutter/material.dart';

import '../services/api_error_handler.dart';
import '../services/api_service.dart';
import 'exam_session_detail_screen.dart';
import 'monitoring_dashboard.dart';

class ExamHistoryScreen extends StatefulWidget {
  final String classroomId;
  final String classroomName;
  final String teacherUid;

  const ExamHistoryScreen({
    super.key,
    required this.classroomId,
    required this.classroomName,
    required this.teacherUid,
  });

  @override
  State<ExamHistoryScreen> createState() => _ExamHistoryScreenState();
}

class _ExamHistoryScreenState extends State<ExamHistoryScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  bool _actionLoading = false;
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final history = await _apiService.getExamHistory(widget.classroomId);
      if (!mounted) return;
      setState(() => _history = history);
    } catch (e) {
      if (!mounted) return;
      _showSnack(ApiErrorHandler.userMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: isError ? Colors.red.shade700 : null),
    );
  }

  bool _isActiveStatus(String? status) {
    final s = status?.toLowerCase();
    return s == 'active';
  }

  String _displayStatus(String? status) {
    final s = status?.toLowerCase();
    if (s == 'active') return 'Monitoring Active';
    if (s == 'completed' || s == 'ended') return 'Completed';
    return status ?? '-';
  }

  String _formatDateTime(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    final dt = DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return raw;
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/${dt.year}  $hour:$min';
  }

  Color _statusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
      case 'ended':
        return Colors.green.shade600;
      case 'active':
        return Colors.blue.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  Future<void> _resumeExam(Map<String, dynamic> exam) async {
    setState(() => _actionLoading = true);
    try {
      final students = await _apiService.getRegisteredStudents(widget.classroomId);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MonitoringDashboard(
            session: exam,
            classroomId: widget.classroomId,
            classroomName: widget.classroomName,
            students: students,
            teacherUid: widget.teacherUid,
          ),
        ),
      );
      if (mounted) await _loadHistory();
    } catch (e) {
      if (mounted) _showSnack(ApiErrorHandler.userMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  void _openSessionDetail(Map<String, dynamic> exam, {bool? allowPdf}) {
    final sessionId = exam['session_id'] as String?;
    if (sessionId == null) return;
    final isActive = _isActiveStatus(exam['status'] as String?);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExamSessionDetailScreen(
          sessionId: sessionId,
          examName: exam['exam_name'] as String? ?? 'Exam',
          classroomName: widget.classroomName,
          session: exam,
          canGenerateReport: allowPdf ?? !isActive,
        ),
      ),
    );
  }

  Future<void> _endExam(Map<String, dynamic> exam) async {
    final sessionId = exam['session_id'] as String?;
    if (sessionId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Exam?'),
        content: Text(
          'End “${exam['exam_name'] ?? 'Exam'}” now?\n\n'
          'Students will no longer be monitored for this session.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            child: const Text('End Exam'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _actionLoading = true);
    try {
      await _apiService.endExamSession(sessionId: sessionId, endedBy: widget.teacherUid);
      if (!mounted) return;
      _showSnack('Exam ended successfully.');
      await _loadHistory();
    } catch (e) {
      if (mounted) _showSnack(ApiErrorHandler.userMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Exam History', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
            Text(
              widget.classroomName,
              style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withOpacity(0.5)),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context, true),
        ),
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _history.isEmpty
                  ? Center(
                      child: Text(
                        'No exams yet',
                        style: TextStyle(color: colorScheme.onSurface.withOpacity(0.4)),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadHistory,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _history.length,
                        itemBuilder: (context, index) {
                          final exam = _history[index];
                          final status = exam['status'] as String?;
                          final isActive = _isActiveStatus(status);
                          final alertCount = exam['total_alerts_count'] ?? 0;
                          final suspiciousCount = exam['suspicious_activity_count'] ?? 0;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isActive
                                    ? Colors.green.shade400
                                    : colorScheme.outline.withOpacity(0.12),
                                width: isActive ? 2 : 1,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              exam['exam_name'] as String? ?? 'Exam',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: _statusColor(status).withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                _displayStatus(status),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: _statusColor(status),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isActive)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.sensors, size: 14, color: Colors.green.shade700),
                                              const SizedBox(width: 4),
                                              Text(
                                                'LIVE',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.green.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  _timeRow(
                                    Icons.play_arrow_rounded,
                                    'Start',
                                    _formatDateTime(exam['start_time'] as String?),
                                    colorScheme,
                                  ),
                                  const SizedBox(height: 6),
                                  _timeRow(
                                    Icons.stop_rounded,
                                    'End',
                                    isActive
                                        ? 'In progress'
                                        : _formatDateTime(exam['end_time'] as String?),
                                    colorScheme,
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      _statBadge(
                                        Icons.notifications_rounded,
                                        '$alertCount',
                                        'Alerts',
                                        Colors.orange.shade600,
                                      ),
                                      const SizedBox(width: 8),
                                      _statBadge(
                                        Icons.warning_rounded,
                                        '$suspiciousCount',
                                        'Suspicious',
                                        Colors.red.shade600,
                                      ),
                                    ],
                                  ),
                                  if (isActive) ...[
                                    const SizedBox(height: 14),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: _actionLoading
                                                ? null
                                                : () => _resumeExam(exam),
                                            icon: const Icon(Icons.play_arrow_rounded, size: 18),
                                            label: const Text('Resume Exam'),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: FilledButton.icon(
                                            onPressed: _actionLoading
                                                ? null
                                                : () => _endExam(exam),
                                            style: FilledButton.styleFrom(
                                              backgroundColor: Colors.red.shade600,
                                            ),
                                            icon: const Icon(Icons.stop_rounded, size: 18),
                                            label: const Text('End Exam'),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: () => _openSessionDetail(exam, allowPdf: false),
                                        icon: const Icon(Icons.notifications_outlined, size: 18),
                                        label: const Text('View Alerts So Far'),
                                      ),
                                    ),
                                  ] else ...[
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () => _openSessionDetail(exam),
                                            icon: const Icon(Icons.list_alt_rounded, size: 18),
                                            label: const Text('Alerts & Details'),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: FilledButton.icon(
                                            onPressed: () => _openSessionDetail(exam),
                                            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                                            label: const Text('PDF Report'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
          if (_actionLoading)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _timeRow(IconData icon, String label, String value, ColorScheme colorScheme) {
    return Row(
      children: [
        Icon(icon, size: 16, color: colorScheme.onSurface.withOpacity(0.45)),
        const SizedBox(width: 6),
        Text('$label: ', style: TextStyle(fontSize: 13, color: colorScheme.onSurface.withOpacity(0.5))),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _statBadge(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(value, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color.withOpacity(0.85))),
        ],
      ),
    );
  }
}
