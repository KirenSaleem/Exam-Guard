import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'screens/backend_error_screen.dart';
import 'screens/classroom_dashboard.dart';
import 'screens/login_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'services/api_error_handler.dart';
import 'services/api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const ExamGuardApp());
}

class ExamGuardApp extends StatelessWidget {
  const ExamGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ExamGuard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const SessionGate(),
    );
  }
}

class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  final ApiService _apiService = ApiService();
  late Future<_SessionResult> _sessionFuture;

  @override
  void initState() {
    super.initState();
    _sessionFuture = _resolveSession();
  }

  void _retry() {
    setState(() {
      _sessionFuture = _resolveSession();
    });
  }

  Future<_SessionResult> _resolveSession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return _SessionResult.login();
    }

    final profile = await _apiService.getTeacherProfile(user.uid);
    if (profile == null) {
      return _SessionResult.profileSetup(
        firebaseUid: user.uid,
        email: _resolveEmail(user),
      );
    }

    return _SessionResult.dashboard(firebaseUid: user.uid);
  }

  String _resolveEmail(User user) {
    if (user.email != null && user.email!.isNotEmpty) {
      return user.email!;
    }
    for (final info in user.providerData) {
      if (info.email != null && info.email!.isNotEmpty) {
        return info.email!;
      }
    }
    return '${user.uid}@examguard.app';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_SessionResult>(
      future: _sessionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return BackendErrorScreen(
            message: ApiErrorHandler.userMessage(snapshot.error!),
            onRetry: _retry,
          );
        }

        final result = snapshot.data;
        if (result == null) {
          return const LoginScreen();
        }

        switch (result.type) {
          case _SessionType.login:
            return const LoginScreen();
          case _SessionType.profileSetup:
            return ProfileSetupScreen(
              firebaseUid: result.firebaseUid!,
              email: result.email!,
            );
          case _SessionType.dashboard:
            return ClassroomDashboard(firebaseUid: result.firebaseUid!);
        }
      },
    );
  }
}

enum _SessionType { login, profileSetup, dashboard }

class _SessionResult {
  final _SessionType type;
  final String? firebaseUid;
  final String? email;

  _SessionResult._(this.type, {this.firebaseUid, this.email});

  factory _SessionResult.login() => _SessionResult._(_SessionType.login);

  factory _SessionResult.profileSetup({
    required String firebaseUid,
    required String email,
  }) =>
      _SessionResult._(
        _SessionType.profileSetup,
        firebaseUid: firebaseUid,
        email: email,
      );

  factory _SessionResult.dashboard({required String firebaseUid}) =>
      _SessionResult._(_SessionType.dashboard, firebaseUid: firebaseUid);
}
