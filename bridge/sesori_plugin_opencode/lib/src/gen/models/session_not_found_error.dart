// GENERATED FILE - DO NOT EDIT BY HAND


class SessionNotFoundError {
  const SessionNotFoundError({
    required this.tag,
    required this.sessionID,
    required this.message,
  });

  factory SessionNotFoundError.fromJson(Map<String, dynamic> json) {
    return SessionNotFoundError(
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
