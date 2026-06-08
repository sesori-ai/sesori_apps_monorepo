// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T13:32:28.074061Z


class UnauthorizedError {
  const UnauthorizedError({
    required this.tag,
    required this.message,
  });

  factory UnauthorizedError.fromJson(Map<String, dynamic> json) {
    return UnauthorizedError(
      tag: json["_tag"] as String,
      message: json["message"] as String,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "_tag": tag,
      "message": message,
    };
  }

  final String tag;
  final String message;
}
