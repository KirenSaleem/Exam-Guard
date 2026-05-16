import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/api_config.dart';
import '../services/auth_service.dart';

/// Shown when Firebase is signed in but the app cannot reach the Python backend.
class BackendErrorScreen extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const BackendErrorScreen({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(Icons.cloud_off_rounded, size: 64, color: colorScheme.error),
              const SizedBox(height: 16),
              Text(
                'Cannot connect to backend',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.onSurface.withOpacity(0.65), height: 1.4),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Trying: ${ApiConfig.baseUrl}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () async {
                  await AuthService().signOut();
                  await FirebaseAuth.instance.signOut();
                  onRetry();
                },
                child: const Text('Sign out and try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
