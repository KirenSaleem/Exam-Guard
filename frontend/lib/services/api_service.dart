import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'api_error_handler.dart';
import 'api_exception.dart';

/// HTTP client for ExamGuard backend (classrooms, exams, monitoring, students).
/// All routes use [ApiConfig.baseUrl]; errors are mapped via [ApiErrorHandler].
class ApiService {
  String get baseUrl => ApiConfig.baseUrl;

  String buildAbsoluteUrl(String? pathOrUrl) {
    if (pathOrUrl == null || pathOrUrl.isEmpty) {
      return '';
    }
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      return pathOrUrl;
    }
    if (pathOrUrl.startsWith('/')) {
      return '$baseUrl$pathOrUrl';
    }
    return '$baseUrl/$pathOrUrl';
  }

  Future<http.Response> _get(Uri url) async {
    try {
      return await http.get(url).timeout(const Duration(seconds: 15));
    } on SocketException catch (e) {
      if (kDebugMode) debugPrint('[ExamGuard] GET $url → $e');
      throw ApiException('Unable to connect to server. Please check your connection and try again.');
    } on TimeoutException catch (e) {
      if (kDebugMode) debugPrint('[ExamGuard] GET timeout $url → $e');
      throw ApiException('Network issue detected. Please try again later.');
    }
  }

  Future<http.Response> _post(Uri url, {Object? body}) async {
    try {
      return await http
          .post(url, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 15));
    } on SocketException catch (e) {
      if (kDebugMode) debugPrint('[ExamGuard] POST $url → $e');
      throw ApiException('Unable to connect to server. Please check your connection and try again.');
    } on TimeoutException catch (e) {
      if (kDebugMode) debugPrint('[ExamGuard] POST timeout $url → $e');
      throw ApiException('Network issue detected. Please try again later.');
    }
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    throw ApiException(ApiErrorHandler.messageForHttpStatus(response.statusCode, response.body));
  }

  Future<void> createTeacherProfile({
    required String firebaseUid,
    required String email,
    required String name,
    String profileImage = '',
  }) async {
    final response = await _post(
      Uri.parse('$baseUrl/teachers/create'),
      body: jsonEncode({
        'firebase_uid': firebaseUid,
        'email': email,
        'name': name,
        'profile_image': profileImage.isEmpty ? null : profileImage,
      }),
    );
    _ensureSuccess(response);
  }

  Future<Map<String, dynamic>?> getTeacherProfile(String firebaseUid) async {
    final response = await _get(Uri.parse('$baseUrl/teachers/$firebaseUid'));
    if (response.statusCode == 404) {
      return null;
    }
    _ensureSuccess(response);
    final Map<String, dynamic> data = jsonDecode(response.body);
    return data['teacher'] as Map<String, dynamic>?;
  }

  Future<Map<String, dynamic>> createClassroom({
    required String classroomName,
    required String createdBy,
  }) async {
    final response = await _post(
      Uri.parse('$baseUrl/classrooms/create'),
      body: jsonEncode({
        'classroom_name': classroomName,
        'created_by': createdBy,
      }),
    );
    _ensureSuccess(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> joinClassroom({
    required String firebaseUid,
    required String classroomCode,
  }) async {
    final response = await _post(
      Uri.parse('$baseUrl/classrooms/join'),
      body: jsonEncode({
        'firebase_uid': firebaseUid,
        'classroom_code': classroomCode,
      }),
    );
    _ensureSuccess(response);
  }

  Future<List<Map<String, dynamic>>> getTeacherClassrooms(String firebaseUid) async {
    final response = await _get(Uri.parse('$baseUrl/classrooms/teacher/$firebaseUid'));
    _ensureSuccess(response);
    final Map<String, dynamic> data = jsonDecode(response.body);
    return (data['classrooms'] as List<dynamic>)
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  Future<Map<String, dynamic>> getClassroom(String classroomId) async {
    final response = await _get(Uri.parse('$baseUrl/classrooms/$classroomId'));
    _ensureSuccess(response);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['classroom'] as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getRegisteredStudents(String classroomId) async {
    final response = await _get(Uri.parse('$baseUrl/students/classroom/$classroomId'));
    _ensureSuccess(response);
    final Map<String, dynamic> data = jsonDecode(response.body);
    return (data['students'] as List<dynamic>)
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  Future<Map<String, dynamic>?> getActiveExamSession(String classroomId) async {
    final response = await _get(Uri.parse('$baseUrl/exam/active/$classroomId'));
    _ensureSuccess(response);
    final Map<String, dynamic> data = jsonDecode(response.body);
    return data['session'] as Map<String, dynamic>?;
  }

  /// Starts monitoring. If an active session exists, returns it with [alreadyActive] true.
  Future<({Map<String, dynamic> session, bool alreadyActive})> startExamSession({
    required String classroomId,
    required String examName,
    required String startedBy,
  }) async {
    final response = await _post(
      Uri.parse('$baseUrl/exam/start'),
      body: jsonEncode({
        'classroom_id': classroomId,
        'exam_name': examName,
        'started_by': startedBy,
      }),
    );

    if (response.statusCode == 409) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final session = data['session'] as Map<String, dynamic>?;
      if (session != null) {
        return (session: session, alreadyActive: true);
      }
    }

    _ensureSuccess(response);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (session: data['session'] as Map<String, dynamic>, alreadyActive: false);
  }

  Future<Map<String, dynamic>> endExamSession({
    required String sessionId,
    required String endedBy,
  }) async {
    final response = await _post(
      Uri.parse('$baseUrl/exam/end'),
      body: jsonEncode({
        'session_id': sessionId,
        'ended_by': endedBy,
      }),
    );
    _ensureSuccess(response);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['session'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> checkMonitoringFrame({
    required File frameFile,
    required String classroomId,
    required String sessionId,
  }) async {
    final Uri url = Uri.parse('$baseUrl/monitoring/check-frame');
    try {
      final request = http.MultipartRequest('POST', url)
        ..fields['classroom_id'] = classroomId
        ..fields['session_id'] = sessionId
        ..files.add(await http.MultipartFile.fromPath('frame', frameFile.path));

      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);
      _ensureSuccess(response);
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on SocketException catch (e) {
      if (kDebugMode) debugPrint('[ExamGuard] frame upload → $e');
      throw ApiException('Unable to connect to server. Please check your connection and try again.');
    } on TimeoutException catch (e) {
      if (kDebugMode) debugPrint('[ExamGuard] frame timeout → $e');
      throw ApiException('Network issue detected. Please try again later.');
    }
  }

  Future<List<Map<String, dynamic>>> getMonitoringAlerts(String sessionId) async {
    final response = await _get(Uri.parse('$baseUrl/monitoring/alerts/$sessionId'));
    _ensureSuccess(response);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['alerts'] as List<dynamic>)
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  Future<List<Map<String, dynamic>>> getExamHistory(String classroomId) async {
    final response = await _get(Uri.parse('$baseUrl/exam-history/$classroomId'));
    _ensureSuccess(response);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['history'] as List<dynamic>)
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  Future<List<Map<String, dynamic>>> getExamNotifications(String sessionId) async {
    final response = await _get(Uri.parse('$baseUrl/exam-notifications/$sessionId'));
    _ensureSuccess(response);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['notifications'] as List<dynamic>)
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }
}
