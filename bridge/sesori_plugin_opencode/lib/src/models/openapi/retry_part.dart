// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:04:07.988345Z

import 'package:meta/meta.dart';
import 'apierror.dart';
import 'part.dart';

@immutable
class RetryPart implements Part {
  const RetryPart({
    required this.id,
    required this.sessionID,
    required this.messageID,
    required this.attempt,
    required this.error,
    required this.time,
  });

  factory RetryPart.fromJson(Map<String, dynamic> json) {
    return RetryPart(
      id: json["id"] as String,
      sessionID: json["sessionID"] as String,
      messageID: json["messageID"] as String,
      attempt: (json["attempt"] as num).toInt(),
      error: APIError.fromJson(json["error"] as Map<String, dynamic>),
      time: json["time"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "sessionID": sessionID,
      "messageID": messageID,
      "type": "retry",
      "attempt": attempt,
      "error": error.toJson(),
      "time": time,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RetryPart &&
          other.id == id &&
          other.sessionID == sessionID &&
          other.messageID == messageID &&
          other.attempt == attempt &&
          other.error == error &&
          other.time == time);

  @override
  int get hashCode => Object.hash(id, sessionID, messageID, attempt, error, time);

  final String id;
  final String sessionID;
  final String messageID;
  final int attempt;
  final APIError error;
  final Map<String, dynamic> time;
}
