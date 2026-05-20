import 'dart:io';

import 'package:flutter/material.dart';

import '../services/api_error_handler.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/app_ui.dart';
import '../widgets/text_prompt_dialog.dart';
import 'classroom_management_screen.dart';
import 'login_screen.dart';

/// Main teacher home: list classrooms, active sessions, create/join.
class ClassroomDashboard extends StatefulWidget {
  final String firebaseUid;

  const ClassroomDashboard({super.key, required this.firebaseUid});

  @override
  State<ClassroomDashboard> createState() => _ClassroomDashboardState();
}

class _ClassroomDashboardState extends State<ClassroomDashboard> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  List<Map<String, dynamic>> _classrooms = [];
  Map<String, dynamic>? _currentTeacher;
  final Map<String, Map<String, dynamic>> _activeSessions = {};

  @override
  void initState() {
    super.initState();
    _loadClassrooms();
  }

  Future<void> _loadClassrooms() async {
    setState(() => _isLoading = true);
    try {
      final profile = await _apiService.getTeacherProfile(widget.firebaseUid);
      final data = await _apiService.getTeacherClassrooms(widget.firebaseUid);

      final activeSessions = <String, Map<String, dynamic>>{};
      for (final classroom in data) {
        final classroomId = classroom['classroom_id'] as String?;
        if (classroomId == null) continue;
        final active = await _apiService.getActiveExamSession(classroomId);
        if (active != null) activeSessions[classroomId] = active;
      }

      if (!mounted) return;
      setState(() {
        _currentTeacher = profile;
        _classrooms = data;
        _activeSessions
          ..clear()
          ..addAll(activeSessions);
      });
    } catch (e) {
      if (!mounted) return;
      _showMessage(ApiErrorHandler.userMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await _authService.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    AppUi.snack(context, message, isError: isError);
  }

  Future<void> _createClassroomDialog() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const TextPromptDialog(
        title: 'Create Classroom',
        label: 'Classroom name',
        confirmLabel: 'Create',
      ),
    );

    if (!mounted || name == null || name.isEmpty) return;

    try {
      final response = await _apiService.createClassroom(
        classroomName: name,
        createdBy: widget.firebaseUid,
      );
      if (!mounted) return;
      final classroom = response['classroom'] as Map<String, dynamic>;
      _showMessage('Classroom created · Code: ${classroom['classroom_code']}');
      await _loadClassrooms();
    } catch (e) {
      if (!mounted) return;
      _showMessage(ApiErrorHandler.userMessage(e), isError: true);
    }
  }

  Future<void> _joinClassroomDialog() async {
    final code = await showDialog<String>(
      context: context,
      builder: (context) => const TextPromptDialog(
        title: 'Join Classroom',
        label: 'Classroom code',
        confirmLabel: 'Join',
        textCapitalization: TextCapitalization.characters,
      ),
    );

    if (!mounted || code == null || code.isEmpty) return;

    try {
      await _apiService.joinClassroom(
        firebaseUid: widget.firebaseUid,
        classroomCode: code.toUpperCase(),
      );
      if (!mounted) return;
      _showMessage('Joined classroom as co-teacher.');
      await _loadClassrooms();
    } catch (e) {
      if (!mounted) return;
      _showMessage(ApiErrorHandler.userMessage(e), isError: true);
    }
  }

  int _studentCount(Map<String, dynamic> classroom) {
    final count = classroom['student_count'];
    if (count is int) return count;
    if (count is num) return count.toInt();
    return (classroom['students_details'] as List?)?.length ?? 0;
  }

  Widget _buildHeader() {
    final name = _currentTeacher?['name'] as String? ?? 'Teacher';
    final imagePath = _currentTeacher?['profile_image'] as String?;
    ImageProvider? profileProvider;
    if (imagePath != null && imagePath.isNotEmpty) {
      profileProvider = imagePath.startsWith('http')
          ? NetworkImage(imagePath)
          : FileImage(File(imagePath));
    }
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(bottom: BorderSide(color: colorScheme.outline.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: colorScheme.primaryContainer,
            backgroundImage: profileProvider,
            child: profileProvider == null
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'T',
                    style: TextStyle(fontWeight: FontWeight.w700, color: colorScheme.onPrimaryContainer),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                Text(
                  'Teacher / Invigilator',
                  style: TextStyle(fontSize: 13, color: colorScheme.onSurface.withOpacity(0.5)),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _logout,
            icon: Icon(Icons.logout_rounded, color: colorScheme.onSurface.withOpacity(0.5)),
            tooltip: 'Logout',
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    final activeCount = _activeSessions.length;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primary, colorScheme.primary.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('${_classrooms.length}', 'Classrooms', Icons.class_rounded),
          Container(width: 1, height: 32, color: Colors.white24),
          _statItem('$activeCount', 'Active Sessions', Icons.videocam_rounded),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ],
    );
  }

  Widget _buildClassroomCard(Map<String, dynamic> classroom) {
    final colorScheme = Theme.of(context).colorScheme;
    final classroomId = classroom['classroom_id'] as String?;
    final activeSession = classroomId == null ? null : _activeSessions[classroomId];
    final studentCount = _studentCount(classroom);
    final isActive = activeSession != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? colorScheme.primary.withOpacity(0.4) : colorScheme.outline.withOpacity(0.15),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ClassroomManagementScreen(
                  classroom: classroom,
                  activeSession: activeSession,
                  teacherUid: widget.firebaseUid,
                ),
              ),
            );
            if (result != null) await _loadClassrooms();
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        classroom['classroom_name'] as String? ?? 'Classroom',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Live',
                          style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _infoChip(Icons.key_rounded, classroom['classroom_code'] ?? '-', colorScheme),
                    const SizedBox(width: 8),
                    _infoChip(Icons.people_outline_rounded, '$studentCount students', colorScheme),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Open Classroom',
                      style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios_rounded, size: 13, color: colorScheme.primary),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: colorScheme.onSurface.withOpacity(0.5)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withOpacity(0.65))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        title: const Text('My Classrooms', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [
          PopupMenuButton<String>(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.add_rounded, color: colorScheme.onPrimaryContainer, size: 20),
            ),
            onSelected: (value) {
              if (value == 'create') _createClassroomDialog();
              else if (value == 'join') _joinClassroomDialog();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'create',
                child: Row(
                  children: [
                    Icon(Icons.add_box_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Create Classroom'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'join',
                child: Row(
                  children: [
                    Icon(Icons.login_rounded, size: 18),
                    SizedBox(width: 10),
                    Text('Join Classroom'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const AppLoadingView(message: 'Loading classrooms...')
                : RefreshIndicator(
                    onRefresh: _loadClassrooms,
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(child: _buildStatsBar()),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          sliver: _classrooms.isEmpty
                              ? const SliverFillRemaining(
                                  child: AppEmptyState(
                                    icon: Icons.class_outlined,
                                    title: 'No classrooms yet',
                                    subtitle: 'Create your first classroom to get started',
                                  ),
                                )
                              : SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) => _buildClassroomCard(_classrooms[index]),
                                    childCount: _classrooms.length,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
