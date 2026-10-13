class VisionResult {
  final bool success;
  final String? task;
  final String? model;
  final String? resultText;
  final bool qrDetected;
  final String? qrContent;
  final Map<String, dynamic>? ticketVerification;
  final double? executionTime;
  final String? error;

  VisionResult({
    required this.success,
    this.task,
    this.model,
    this.resultText,
    this.qrDetected = false,
    this.qrContent,
    this.ticketVerification,
    this.executionTime,
    this.error,
  });

  factory VisionResult.fromJson(Map<String, dynamic> json) {
    return VisionResult(
      success: json['success'] == true,
      task: json['task'] as String?,
      model: json['model'] as String?,
      resultText: json['analysis_result'] ?? json['description'] ?? json['extracted_text'],
      qrDetected: json['qr_detected'] == true,
      qrContent: json['qr_code'] ?? json['qr_content'],
      ticketVerification: json['ticket_verification'] != null
          ? Map<String, dynamic>.from(json['ticket_verification'])
          : null,
      executionTime: (json['execution_time_seconds'] as num?)?.toDouble(),
      error: json['error'] as String?,
    );
  }

  factory VisionResult.failure(String errorMessage) {
    return VisionResult(
      success: false,
      error: errorMessage,
    );
  }
}
