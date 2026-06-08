// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T13:43:24.188324Z


class SessionErrorUnknown {
  const SessionErrorUnknown({
    required this.type,
    required this.message,
  });

  factory SessionErrorUnknown.fromJson(Map<String, dynamic> json) {
    return SessionErrorUnknown(
      type: json["type"] as String,
      message: json["message"] as String,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": type,
      "message": message,
    };
  }

  final String type;
  final String message;
}
