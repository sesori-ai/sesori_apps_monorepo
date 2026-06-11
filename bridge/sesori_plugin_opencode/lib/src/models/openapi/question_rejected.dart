// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';

@immutable
class QuestionRejected {
  const QuestionRejected({
    required this.sessionID,
    required this.requestID,
  });

  factory QuestionRejected.fromJson(Map<String, dynamic> json) {
    return QuestionRejected(
      sessionID: json["sessionID"] as String,
      requestID: json["requestID"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "sessionID": sessionID,
      "requestID": requestID,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QuestionRejected &&
          other.sessionID == sessionID &&
          other.requestID == requestID);

  @override
  int get hashCode => Object.hash(sessionID, requestID);

  final String sessionID;
  final String requestID;
}
