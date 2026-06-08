// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:24:06.243635Z

import 'package:meta/meta.dart';

@immutable
class QuestionV2Tool {
  const QuestionV2Tool({
    required this.messageID,
    required this.callID,
  });

  factory QuestionV2Tool.fromJson(Map<String, dynamic> json) {
    return QuestionV2Tool(
      messageID: json["messageID"] as String,
      callID: json["callID"] as String,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "messageID": messageID,
      "callID": callID,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QuestionV2Tool &&
          other.messageID == messageID &&
          other.callID == callID);

  @override
  int get hashCode => Object.hash(messageID, callID);

  final String messageID;
  final String callID;
}
