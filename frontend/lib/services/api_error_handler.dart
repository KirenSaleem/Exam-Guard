import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'api_exception.dart';

/// Converts technical errors into short messages for the UI.
/// Full details are printed only in debug mode.
class ApiErrorHandler {
  static String userMessage(Object error) {
    if (kDebugMode) {
      debugPrint('[ExamGuard] $error');
    }

    if (error is ApiException) {
      return _sanitize(error.message);
    }

    return _sanitize(error.toString());
  }

  static String messageForHttpStatus(int statusCode, String? body) {
    if (kDebugMode && body != null && body.isNotEmpty) {
      debugPrint('[ExamGuard] HTTP $statusCode: $body');
    }

    final detail = _extractDetail(body);
    if (detail != null) {
      final friendly = _mapBackendDetail(detail);
      if (friendly != null) return friendly;
    }

    switch (statusCode) {
      case 400:
        return 'Invalid request. Please check your input and try again.';
      case 401:
        return 'You are not authorized. Please sign in again.';
      case 404:
        return 'The requested item was not found.';
      case 409:
        return 'This action conflicts with existing data. Please refresh and try again.';
      case 500:
      case 502:
      case 503:
        return 'Server error. Please try again later.';
      default:
        if (statusCode >= 500) return 'Server error. Please try again later.';
        return 'Something went wrong. Please try again later.';
    }
  }

  static String? _extractDetail(String? body) {
    if (body == null || body.isEmpty) return null;
    try {
      final data = jsonDecode(body);
      if (data is Map && data['detail'] != null) {
        final d = data['detail'];
        if (d is String) return d;
        if (d is List && d.isNotEmpty) {
          return d.map((e) => e['msg'] ?? e.toString()).join(', ');
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static String? _mapBackendDetail(String detail) {
    final lower = detail.toLowerCase();
    if (lower.contains('active exam') || lower.contains('active session')) {
      return 'An exam is already running. Open Exam History to resume or end it.';
    }
    if (lower.contains('roll number')) {
      return 'This roll number is already registered.';
    }
    if (lower.contains('invalid classroom')) {
      return 'Invalid classroom code.';
    }
    if (lower.contains('teacher profile')) {
      return 'Please complete your teacher profile first.';
    }
    if (detail.length < 120 && !detail.contains('Exception') && !detail.contains('Traceback')) {
      return detail;
    }
    return null;
  }

  static String _sanitize(String raw) {
    final text = raw.replaceFirst('Exception: ', '').replaceFirst('ApiException: ', '');
    final lower = text.toLowerCase();

    if (lower.contains('socketexception') ||
        lower.contains('clientexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection refused') ||
        lower.contains('network is unreachable') ||
        lower.contains('cannot reach backend') ||
        lower.contains('unable to connect')) {
      return 'Unable to connect to server. Please check your connection and try again.';
    }
    if (lower.contains('timeout') || lower.contains('timed out')) {
      return 'Network issue detected. Please try again later.';
    }
    if (lower.contains('ngrok') || lower.contains('<!doctype html')) {
      return 'Unable to connect to server. Please try again later.';
    }
    if (lower.contains('backend error') ||
        lower.contains('statuscode') ||
        text.contains('{') ||
        text.length > 100) {
      return 'Something went wrong. Please try again later.';
    }
    return text;
  }
}
