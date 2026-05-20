import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/api_config.dart';
import '../widgets/app_ui.dart';

/// Teacher-only screen: share browser registration link and QR code.
/// Students open the link on any phone — they do not use the mobile app.
class GenerateRegistrationFormScreen extends StatelessWidget {
  final String classroomName;
  final String classroomCode;

  const GenerateRegistrationFormScreen({
    super.key,
    required this.classroomName,
    required this.classroomCode,
  });

  String get _registrationUrl => ApiConfig.studentRegistrationUrl(classroomCode);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        title: const Text('Registration Form', style: TextStyle(fontWeight: FontWeight.w700)),
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
            AppGradientHeader(
              title: classroomName,
              subtitle: 'Class code: $classroomCode',
              chips: const [AppBadge.ai(label: 'STUDENT REGISTRATION')],
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Text(
                'Students scan the QR or open the link in Chrome/Safari. '
                'They submit name, roll number, and photo — no login.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
              ),
            ),
            const SizedBox(height: 28),
            AppCard(
              child: Center(
                child: QrImageView(
                  data: _registrationUrl,
                  version: QrVersions.auto,
                  size: 220,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Scan to register',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Registration link', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
              ),
              child: SelectableText(
                _registrationUrl,
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _registrationUrl));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copied to clipboard')),
                );
              },
              icon: const Icon(Icons.link_rounded),
              label: const Text('Copy Link'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: classroomCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Classroom code copied')),
                );
              },
              icon: const Icon(Icons.vpn_key_outlined),
              label: Text('Copy Code: $classroomCode'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
