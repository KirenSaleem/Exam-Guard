import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'api_service.dart';

/// Builds a professional PDF report for a completed exam session.
class ExamReportService {
  final ApiService _apiService;

  ExamReportService({ApiService? apiService}) : _apiService = apiService ?? ApiService();

  Future<Uint8List> buildReport({
    required Map<String, dynamic> session,
    required String classroomName,
    required List<Map<String, dynamic>> alerts,
  }) async {
    final examName = session['exam_name'] as String? ?? 'Exam';
    final startTime = _formatDateTime(session['start_time'] as String?);
    final endTime = _formatDateTime(session['end_time'] as String?);
    final alertCount = alerts.length;
    final suspiciousCount = alertCount;

    final pdf = pw.Document();
    final generatedAt = _formatDateTime(DateTime.now().toIso8601String());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          _header(examName, classroomName, generatedAt),
          pw.SizedBox(height: 20),
          _summaryBox(
            examName: examName,
            classroomName: classroomName,
            startTime: startTime,
            endTime: endTime,
            alertCount: alertCount,
            suspiciousCount: suspiciousCount,
          ),
          pw.SizedBox(height: 24),
          pw.Text(
            'Alert Summary',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          if (alerts.isEmpty)
            pw.Text(
              'No suspicious activity was recorded during this exam.',
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: ['#', 'Time', 'Alert Type', 'Confidence'],
              data: List.generate(alerts.length, (i) {
                final a = alerts[i];
                return [
                  '${i + 1}',
                  _formatDateTime(a['created_at'] as String?),
                  _formatAlertType(a['alert_type'] as String?),
                  _confidenceLabel(a['confidence']),
                ];
              }),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo100),
              cellAlignment: pw.Alignment.centerLeft,
            ),
        ],
      ),
    );

    for (var i = 0; i < alerts.length; i++) {
      final alert = alerts[i];
      final imageBytes = await _loadEvidenceImage(alert['evidence_image_url'] as String?);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Evidence ${i + 1} of ${alerts.length}',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'Time: ${_formatDateTime(alert['created_at'] as String?)}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.Text(
                  'Type: ${_formatAlertType(alert['alert_type'] as String?)}  •  '
                  'Confidence: ${_confidenceLabel(alert['confidence'])}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 16),
                if (imageBytes != null)
                  pw.Expanded(
                    child: pw.Center(
                      child: pw.Image(
                        pw.MemoryImage(imageBytes),
                        fit: pw.BoxFit.contain,
                      ),
                    ),
                  )
                else
                  pw.Expanded(
                    child: pw.Center(
                      child: pw.Text(
                        'Evidence image could not be loaded.',
                        style: pw.TextStyle(color: PdfColors.grey600, fontSize: 12),
                      ),
                    ),
                  ),
                pw.SizedBox(height: 12),
                pw.Text(
                  'ExamGuard — Confidential monitoring report',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
              ],
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  pw.Widget _header(String examName, String classroomName, String generatedAt) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'ExamGuard Monitoring Report',
          style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
        ),
        pw.SizedBox(height: 6),
        pw.Text(examName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.Text('Classroom: $classroomName', style: const pw.TextStyle(fontSize: 11)),
        pw.Text('Generated: $generatedAt', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.Divider(thickness: 1, color: PdfColors.indigo300),
      ],
    );
  }

  pw.Widget _summaryBox({
    required String examName,
    required String classroomName,
    required String startTime,
    required String endTime,
    required int alertCount,
    required int suspiciousCount,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.indigo200),
        borderRadius: pw.BorderRadius.circular(8),
        color: PdfColors.indigo50,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _summaryRow('Exam Name', examName),
          _summaryRow('Classroom', classroomName),
          _summaryRow('Start Time', startTime),
          _summaryRow('End Time', endTime),
          _summaryRow('Total Alerts', '$alertCount'),
          _summaryRow('Suspicious Activity', '$suspiciousCount'),
        ],
      ),
    );
  }

  pw.Widget _summaryRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 130,
            child: pw.Text(label, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Expanded(child: pw.Text(value, style: const pw.TextStyle(fontSize: 10))),
        ],
      ),
    );
  }

  Future<Uint8List?> _loadEvidenceImage(String? evidenceUrl) async {
    final url = _apiService.buildAbsoluteUrl(evidenceUrl);
    if (url.isEmpty) return null;
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: const {'ngrok-skip-browser-warning': '69420'},
      );
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        return response.bodyBytes;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  String _formatDateTime(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    final dt = DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return raw;
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/${dt.year} $h:$min';
  }

  String _formatAlertType(String? raw) {
    if (raw == null || raw.isEmpty) return 'Unknown';
    return raw.replaceAll('_', ' ').split(' ').map((w) {
      if (w.isEmpty) return w;
      return '${w[0].toUpperCase()}${w.substring(1)}';
    }).join(' ');
  }

  String _confidenceLabel(dynamic confidence) {
    final val = double.tryParse(confidence?.toString() ?? '') ?? 0;
    if (val <= 1) return '${(val * 100).toStringAsFixed(0)}%';
    return '${val.toStringAsFixed(0)}%';
  }
}
