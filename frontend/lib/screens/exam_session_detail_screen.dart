import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../services/api_error_handler.dart';
import '../services/api_service.dart';
import '../services/exam_report_service.dart';

/// Exam session details: summary, all monitoring alerts, and PDF report (completed exams).
class ExamSessionDetailScreen extends StatefulWidget {
  final String sessionId;
  final String examName;
  final String classroomName;
  final Map<String, dynamic> session;
  final bool canGenerateReport;

  const ExamSessionDetailScreen({
    super.key,
    required this.sessionId,
    required this.examName,
    required this.classroomName,
    required this.session,
    this.canGenerateReport = true,
  });

  @override
  State<ExamSessionDetailScreen> createState() => _ExamSessionDetailScreenState();
}

class _ExamSessionDetailScreenState extends State<ExamSessionDetailScreen> {
  final ApiService _apiService = ApiService();
  final ExamReportService _reportService = ExamReportService();

  bool _isLoading = true;
  bool _isGeneratingPdf = false;
  List<Map<String, dynamic>> _alerts = [];

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() => _isLoading = true);
    try {
      final alerts = await _apiService.getExamNotifications(widget.sessionId);
      if (!mounted) return;
      setState(() => _alerts = alerts);
    } catch (e) {
      if (!mounted) return;
      _showSnack(ApiErrorHandler.userMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: isError ? Colors.red.shade700 : null),
    );
  }

  bool get _isCompleted {
    final s = (widget.session['status'] as String?)?.toLowerCase();
    return s == 'completed' || s == 'ended';
  }

  Future<Uint8List> _buildPdfBytes() {
    return _reportService.buildReport(
      session: widget.session,
      classroomName: widget.classroomName,
      alerts: _alerts,
    );
  }

  Future<void> _previewReport() async {
    if (!_isCompleted) {
      _showSnack('PDF report is available after the exam is completed.', isError: true);
      return;
    }
    setState(() => _isGeneratingPdf = true);
    try {
      final bytes = await _buildPdfBytes();
      if (!mounted) return;
      await Printing.layoutPdf(
        name: 'ExamGuard_${widget.examName.replaceAll(' ', '_')}.pdf',
        onLayout: (_) async => bytes,
      );
    } catch (e) {
      if (mounted) _showSnack(ApiErrorHandler.userMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  Future<void> _shareReport() async {
    if (!_isCompleted) {
      _showSnack('PDF report is available after the exam is completed.', isError: true);
      return;
    }
    setState(() => _isGeneratingPdf = true);
    try {
      final bytes = await _buildPdfBytes();
      if (!mounted) return;
      final fileName = 'ExamGuard_${widget.examName.replaceAll(RegExp(r'[^\w]+'), '_')}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: fileName);
    } catch (e) {
      if (mounted) _showSnack(ApiErrorHandler.userMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  String _formatDateTime(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    final dt = DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return raw;
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/${dt.year}  $hour:$min';
  }

  String _formatAlertType(String? raw) {
    if (raw == null || raw.isEmpty) return 'Unknown Alert';
    return raw.replaceAll('_', ' ').split(' ').map((w) {
      if (w.isEmpty) return w;
      return '${w[0].toUpperCase()}${w.substring(1)}';
    }).join(' ');
  }

  Color _severityColor(dynamic confidence) {
    final val = double.tryParse(confidence?.toString() ?? '') ?? 0;
    final normalized = val <= 1 ? val : val / 100;
    if (normalized >= 0.8) return Colors.red.shade600;
    if (normalized >= 0.5) return Colors.orange.shade600;
    return Colors.amber.shade600;
  }

  String _confidenceText(dynamic confidence) {
    final val = double.tryParse(confidence?.toString() ?? '') ?? 0;
    if (val <= 1) return '${(val * 100).toStringAsFixed(0)}%';
    return '${val.toStringAsFixed(0)}%';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final alertCount = _alerts.length;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.examName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
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
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadAlerts,
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            _summaryCard(colorScheme),
                            if (_isCompleted && widget.canGenerateReport) ...[
                              const SizedBox(height: 12),
                              _pdfActions(colorScheme),
                            ],
                            const SizedBox(height: 16),
                            Text(
                              'Monitoring Alerts ($alertCount)',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            if (_alerts.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(24),
                                alignment: Alignment.center,
                                child: Column(
                                  children: [
                                    Icon(Icons.verified_outlined,
                                        size: 48, color: Colors.green.withOpacity(0.5)),
                                    const SizedBox(height: 8),
                                    Text(
                                      'No alerts recorded',
                                      style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5)),
                                    ),
                                  ],
                                ),
                              )
                            else
                              ..._alerts.map((alert) => _alertCard(alert, colorScheme)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
          if (_isGeneratingPdf)
            Container(
              color: Colors.black45,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 12),
                    Text('Building PDF report...', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _summaryCard(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outline.withOpacity(0.12)),
      ),
      child: Column(
        children: [
          _summaryRow(Icons.assignment_outlined, 'Exam', widget.examName),
          _summaryRow(Icons.class_outlined, 'Classroom', widget.classroomName),
          _summaryRow(Icons.play_arrow_rounded, 'Start', _formatDateTime(widget.session['start_time'] as String?)),
          _summaryRow(Icons.stop_rounded, 'End', _formatDateTime(widget.session['end_time'] as String?)),
          _summaryRow(Icons.notifications_rounded, 'Total Alerts', '${_alerts.length}'),
          _summaryRow(Icons.warning_rounded, 'Suspicious', '${_alerts.length}'),
        ],
      ),
    );
  }

  Widget _summaryRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.indigo),
          const SizedBox(width: 10),
          SizedBox(width: 100, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _pdfActions(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withOpacity(0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.picture_as_pdf_rounded, color: colorScheme.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('PDF Report', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Includes exam summary, alert times, and evidence screenshots.',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withOpacity(0.55)),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _isGeneratingPdf ? null : _previewReport,
            icon: const Icon(Icons.visibility_outlined, size: 18),
            label: const Text('Preview Report'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _isGeneratingPdf ? null : _shareReport,
            icon: const Icon(Icons.share_rounded, size: 18),
            label: const Text('Download / Share PDF'),
          ),
        ],
      ),
    );
  }

  Widget _alertCard(Map<String, dynamic> alert, ColorScheme colorScheme) {
    final severityColor = _severityColor(alert['confidence']);
    final imageUrl = _apiService.buildAbsoluteUrl(alert['evidence_image_url'] as String?);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: severityColor.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: severityColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_formatAlertType(alert['alert_type'] as String?),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                        _formatDateTime(alert['created_at'] as String?),
                        style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withOpacity(0.5)),
                      ),
                    ],
                  ),
                ),
                Text(
                  _confidenceText(alert['confidence']),
                  style: TextStyle(fontWeight: FontWeight.w800, color: severityColor),
                ),
              ],
            ),
          ),
          if (imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
              child: Image.network(
                imageUrl,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                headers: const {'ngrok-skip-browser-warning': '69420'},
                errorBuilder: (_, __, ___) => Container(
                  height: 80,
                  alignment: Alignment.center,
                  color: colorScheme.surfaceContainerHighest,
                  child: const Text('Evidence image unavailable'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
