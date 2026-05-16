import 'package:flutter/material.dart';

import '../services/api_error_handler.dart';
import '../services/api_service.dart';

/// Teachers view all students who submitted the registration form.
class RegisteredStudentsScreen extends StatefulWidget {
  final String classroomId;
  final String classroomName;
  final String classroomCode;

  const RegisteredStudentsScreen({
    super.key,
    required this.classroomId,
    required this.classroomName,
    required this.classroomCode,
  });

  @override
  State<RegisteredStudentsScreen> createState() => _RegisteredStudentsScreenState();
}

class _RegisteredStudentsScreenState extends State<RegisteredStudentsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _students = [];

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    try {
      final students = await _apiService.getRegisteredStudents(widget.classroomId);
      if (!mounted) return;
      setState(() => _students = students);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiErrorHandler.userMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
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
            const Text('Registered Students', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
            Text(
              widget.classroomName,
              style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withOpacity(0.5)),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            onPressed: _loadStudents,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStudents,
              child: _students.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.5,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.school_outlined, size: 64, color: colorScheme.onSurface.withOpacity(0.2)),
                                const SizedBox(height: 16),
                                const Text('No students registered yet', style: TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 8),
                                Text(
                                  'Share code ${widget.classroomCode} with students',
                                  style: TextStyle(color: colorScheme.onSurface.withOpacity(0.45)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _students.length,
                      itemBuilder: (context, index) {
                        final student = _students[index];
                        final name = student['name'] as String? ?? 'Student';
                        final roll = student['roll_number'] as String? ?? '-';
                        final imageUrl = _apiService.buildAbsoluteUrl(student['profile_image'] as String?);
                        final submitted = _formatDate(student['submitted_at'] as String?);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: colorScheme.outline.withOpacity(0.12)),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            leading: CircleAvatar(
                              radius: 26,
                              backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                              child: imageUrl.isEmpty
                                  ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'S')
                                  : null,
                            ),
                            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text('Roll: $roll', style: const TextStyle(fontWeight: FontWeight.w500)),
                                const SizedBox(height: 2),
                                Text(
                                  'Submitted: $submitted',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.onSurface.withOpacity(0.45),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
