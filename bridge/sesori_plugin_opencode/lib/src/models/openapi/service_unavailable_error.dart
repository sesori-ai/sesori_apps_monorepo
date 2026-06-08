// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T13:40:29.631120Z


class ServiceUnavailableError {
  const ServiceUnavailableError({
    required this.tag,
    required this.message,
    this.service,
  });

  factory ServiceUnavailableError.fromJson(Map<String, dynamic> json) {
    return ServiceUnavailableError(
      tag: json["_tag"] as String,
      message: json["message"] as String,
      service: json["service"] as String?,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "_tag": tag,
      "message": message,
      "service": ?service,
    };
  }

  final String tag;
  final String message;
  final String? service;
}
