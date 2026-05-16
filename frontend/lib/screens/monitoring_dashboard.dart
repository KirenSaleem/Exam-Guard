import 'package:flutter/material.dart';
import 'dart:io';

import '../services/api_error_handler.dart';
import '../services/api_service.dart';
import 'monitoring_camera_screen.dart';

class MonitoringDashboard extends StatefulWidget {
  final Map<String, dynamic> session;
  final String classroomId;
  final String classroomName;
  final List<dynamic> students;
  final String teacherUid;

  const MonitoringDashboard({
    super.key,
    required this.session,
    required this.classroomId,
    required this.classroomName,
    required this.students,
    required this.teacherUid,
  });

  @override
  State<MonitoringDashboard> createState() => _MonitoringDashboardState();
}

class _MonitoringDashboardState extends State<MonitoringDashboard> {
  final ApiService _apiService = ApiService();
  bool _isEnding = false;
  bool _isLoadingAlerts = false;
  late Map<String, dynamic> _session;
  List<Map<String, dynamic>> _alerts = [];

  @override
  void initState() {
    super.initState();
    _session = Map<String, dynamic>.from(widget.session);
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() => _isLoadingAlerts = true);
    try {
      final alerts = await _apiService.getMonitoringAlerts(_session['session_id'] as String);
      if (!mounted) return;
      setState(() => _alerts = alerts);
    } catch (_) {
      // Keep dashboard usable even if alerts fail to load.
    } finally {
      if (mounted) setState(() => _isLoadingAlerts = false);
    }
  }

  Future<void> _endMonitoring() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('End Monitoring?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('This will close the current exam session. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('End Session'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isEnding = true);
    try {
      final updated = await _apiService.endExamSession(
        sessionId: _session['session_id'] as String,
        endedBy: widget.teacherUid,
      );
      if (!mounted) return;
      setState(() => _session = updated);
      _showMessage('Monitoring ended successfully.');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showMessage(ApiErrorHandler.userMessage(e));
    } finally {
      if (mounted) setState(() => _isEnding = false);
    }
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

  String _studentName(dynamic student) {
    if (student is Map<String, dynamic>) {
      final name = student['name'] as String?;
      if (name != null && name.isNotEmpty) return name;
    }
    if (student is String) {
      for (final item in widget.students) {
        if (item is Map<String, dynamic> &&
            (item['student_id'] == student || item['firebase_uid'] == student)) {
          return item['name'] as String? ?? 'Student';
        }
      }
    }
    return 'Student';
  }

  String _studentRoll(dynamic student) {
    if (student is Map<String, dynamic>) {
      return (student['roll_number'] ?? student['roll_no']) as String? ?? '-';
    }
    if (student is String) {
      for (final item in widget.students) {
        if (item is Map<String, dynamic> &&
            (item['student_id'] == student || item['firebase_uid'] == student)) {
          return (item['roll_number'] ?? item['roll_no']) as String? ?? '-';
        }
      }
    }
    return '-';
  }

  ImageProvider? _studentImage(dynamic student) {
    String? imagePath;
    if (student is Map<String, dynamic>) {
      imagePath = student['profile_image'] as String?;
    } else if (student is String) {
      for (final item in widget.students) {
        if (item is Map<String, dynamic> &&
            (item['student_id'] == student || item['firebase_uid'] == student)) {
          imagePath = item['profile_image'] as String?;
          break;
        }
      }
    }
    if (imagePath == null || imagePath.isEmpty) return null;
    if (imagePath.startsWith('/') || imagePath.startsWith('http')) {
      final url = _apiService.buildAbsoluteUrl(imagePath);
      return NetworkImage(url);
    }
    return FileImage(File(imagePath));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final monitoredStudents = (_session['monitored_students'] as List<dynamic>? ?? widget.students);
    final status = (_session['status'] as String?) ?? 'unknown';
    final isActive = status == 'active';

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        title: const Text('Monitoring Dashboard', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Session status card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isActive
                      ? [Colors.green.shade600, Colors.green.shade500]
                      : [Colors.grey.shade600, Colors.grey.shade500],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: (isActive ? Colors.green : Colors.grey).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isActive ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _session['exam_name'] ?? '-',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 6, height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.white70,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '${status[0].toUpperCase()}${status.substring(1)}  ·  ${widget.classroomName}',
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Camera button
            if (isActive)
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MonitoringCameraScreen(
                          classroomId: widget.classroomId,
                          sessionId: _session['session_id'] as String,
                        ),
                      ),
                    ).then((_) => _loadAlerts()),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Open Live Camera',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                SizedBox(height: 1),
                                Text('Monitor student activity in real time',
                                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded,
                              color: colorScheme.onSurface.withOpacity(0.3)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // Students section
            Row(
              children: [
                Text(
                  'Students',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${monitoredStudents.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            if (monitoredStudents.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colorScheme.outline.withOpacity(0.12)),
                ),
                child: Text(
                  'No students in this session.',
                  style: TextStyle(color: colorScheme.onSurface.withOpacity(0.4), fontSize: 14),
                ),
              )
            else
              ...monitoredStudents.take(5).map((student) {
                final name = _studentName(student);
                final image = _studentImage(student);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorScheme.outline.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: colorScheme.primaryContainer,
                        backgroundImage: image,
                        child: image == null
                            ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'S',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: colorScheme.onPrimaryContainer))
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13)),
                            Text('Roll No: ${_studentRoll(student)}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.onSurface.withOpacity(0.45))),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),

            if (monitoredStudents.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Text(
                  '+ ${monitoredStudents.length - 5} more students',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface.withOpacity(0.4),
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // Alert History section
            Row(
              children: [
                const Text('Alert History',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _loadAlerts,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Refresh', style: TextStyle(fontSize: 13)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            if (_isLoadingAlerts)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_alerts.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.green.shade100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.green.shade500, size: 20),
                    const SizedBox(width: 8),
                    Text('No suspicious alerts detected',
                        style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w500)),
                  ],
                ),
              )
            else
              ..._alerts.take(4).map((alert) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_rounded, color: Colors.red.shade600, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          (alert['alert_type'] as String? ?? 'alert').replaceAll('_', ' '),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Colors.red.shade800,
                          ),
                        ),
                      ),
                      Text(
                        '${alert['confidence'] ?? '-'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade400,
                        ),
                      ),
                    ],
                  ),
                );
              }),

            if (_alerts.length > 4)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+ ${_alerts.length - 4} more alerts',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: colorScheme.onSurface.withOpacity(0.4)),
                ),
              ),

            const SizedBox(height: 24),

            // End session button
            if (isActive)
              OutlinedButton.icon(
                onPressed: _isEnding ? null : _endMonitoring,
                icon: _isEnding
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.stop_circle_rounded),
                label: Text(
                  _isEnding ? 'Ending...' : 'End Monitoring Session',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade600,
                  side: BorderSide(color: Colors.red.shade300),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  minimumSize: const Size.fromHeight(52),
                ),
              ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
