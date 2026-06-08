// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:24:06.251187Z

import 'package:meta/meta.dart';

@immutable
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionNotFoundError &&
          other.tag == tag &&
          other.sessionID == sessionID &&
          other.message == message);

  @override
  int get hashCode => Object.hash(tag, sessionID, message);

  final String tag;
  final String sessionID;
  final String message;
}
