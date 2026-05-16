import 'dart:io';

import 'package:flutter/material.dart';

class ClassroomParticipantsScreen extends StatelessWidget {
  final String classroomName;
  final List<dynamic> teachers;
  final List<dynamic> students;

  const ClassroomParticipantsScreen({
    super.key,
    required this.classroomName,
    required this.teachers,
    required this.students,
  });

  ImageProvider? _imageProvider(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return NetworkImage(path);
    return FileImage(File(path));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final teacherItems = teachers.whereType<Map<String, dynamic>>().toList();
    final studentItems = students.whereType<Map<String, dynamic>>().toList();

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Participants', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
            Text(
              classroomName,
              style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withOpacity(0.5)),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader(
            context,
            'Teachers',
            Icons.cast_for_education_rounded,
            Colors.indigo.shade500,
            teacherItems.length,
          ),
          const SizedBox(height: 10),
          if (teacherItems.isEmpty)
            _emptyState(context, 'No teachers added yet')
          else
            ...teacherItems.map((t) => _memberCard(context, t, isTeacher: true)),

          const SizedBox(height: 20),

          _sectionHeader(
            context,
            'Students',
            Icons.school_rounded,
            colorScheme.primary,
            studentItems.length,
          ),
          const SizedBox(height: 10),
          if (studentItems.isEmpty)
            _emptyState(context, 'No students have joined yet')
          else
            ...studentItems.map((s) => _memberCard(context, s, isTeacher: false)),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _sectionHeader(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    int count,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
      ],
    );
  }

  Widget _memberCard(BuildContext context, Map<String, dynamic> member, {required bool isTeacher}) {
    final colorScheme = Theme.of(context).colorScheme;
    final name = member['name'] as String? ?? (isTeacher ? 'Teacher' : 'Student');
    final rollNo = (member['roll_number'] ?? member['roll_no']) as String?;
    final image = _imageProvider(member['profile_image'] as String?);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outline.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: isTeacher
                  ? Colors.indigo.shade50
                  : colorScheme.primaryContainer,
              backgroundImage: image,
              child: image == null
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'U',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isTeacher ? Colors.indigo.shade600 : colorScheme.onPrimaryContainer,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 2),
                  if (!isTeacher && rollNo != null && rollNo.isNotEmpty)
                    Text(
                      'Roll No: $rollNo',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withOpacity(0.45),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context, String message) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outline.withOpacity(0.12)),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: colorScheme.onSurface.withOpacity(0.35),
          fontSize: 14,
        ),
      ),
    );
  }
}
