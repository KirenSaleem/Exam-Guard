class ApiConfig {
  /// Public backend URL (ngrok or LAN). Used by the teacher app and registration links.
  static const String baseUrl =
      'https://frosting-abrasion-constant.ngrok-free.dev';

  /// Browser registration page for students (no app login).
  static String studentRegistrationUrl(String classroomCode) {
    final code = Uri.encodeQueryComponent(classroomCode.trim().toUpperCase());
    return '$baseUrl/register?code=$code';
  }
}