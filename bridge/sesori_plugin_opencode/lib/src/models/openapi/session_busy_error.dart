// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T07:51:40.002079Z


class SessionBusyError {
  const SessionBusyError({
    required this.tag,
    required this.sessionID,
    required this.message,
  });

  factory SessionBusyError.fromJson(Map<String, dynamic> json) {
    return SessionBusyError(
      tag: json["_tag"] as String,
      sessionID: json["sessionID"] as String,
      message: json["message"] as String,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "_tag": tag,
      "sessionID": sessionID,
      "message": message,
    };
  }

  final String tag;
  final String sessionID;
  final String message;
}
