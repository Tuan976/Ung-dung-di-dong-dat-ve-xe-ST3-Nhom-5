class VisionResult {
  final bool success;
  final String? task;
  final String? model;
  final String? resultText;
  final bool qrDetected;
  final String? qrContent;
  final Map<String, dynamic>? ticketVerification;
  final Map<String, dynamic>? routeAnalysis;
  final bool? isOnRoute;
  final String? routeName;
  final String? statusMessage;
  final String? pickupRecommendation;
  final String? matchedLandmark;
  final String? pickupPointSuggested;
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
    this.routeAnalysis,
    this.isOnRoute,
    this.routeName,
    this.statusMessage,
    this.pickupRecommendation,
    this.matchedLandmark,
    this.pickupPointSuggested,
    this.executionTime,
    this.error,
  });

  factory VisionResult.fromJson(Map<String, dynamic> json) {
    final routeMap = json['route_analysis'] != null
        ? Map<String, dynamic>.from(json['route_analysis'])
        : null;

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
      routeAnalysis: routeMap,
      isOnRoute: routeMap != null && routeMap['has_route'] == true
          ? routeMap['is_on_route'] == true
          : null,
      routeName: routeMap?['route_name'] as String?,
      statusMessage: routeMap?['status_message'] as String?,
      pickupRecommendation: routeMap?['recommendation'] as String?,
      matchedLandmark: (routeMap?['landmark_name'] ?? routeMap?['matched_landmark']) as String?,
      pickupPointSuggested: (routeMap?['pickup_point'] ?? routeMap?['pickup_point_suggested']) as String?,
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
