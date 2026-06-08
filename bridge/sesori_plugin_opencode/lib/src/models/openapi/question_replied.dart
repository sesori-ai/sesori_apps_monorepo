// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:04:07.986168Z

import 'package:meta/meta.dart';
import 'question_answer.dart';

@immutable
class QuestionReplied {
  const QuestionReplied({
    required this.sessionID,
    required this.requestID,
    required this.answers,
  });

  factory QuestionReplied.fromJson(Map<String, dynamic> json) {
    return QuestionReplied(
      sessionID: json["sessionID"] as String,
      requestID: json["requestID"] as String,
      answers: (json["answers"] as List<dynamic>).map((e) => QuestionAnswer.fromJson(e as List<dynamic>)).toList(),
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "sessionID": sessionID,
      "requestID": requestID,
      "answers": answers.map((e) => e.toJson()).toList(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QuestionReplied &&
          other.sessionID == sessionID &&
          other.requestID == requestID &&
          other.answers == answers);

  @override
  int get hashCode => Object.hash(sessionID, requestID, answers);

  final String sessionID;
  final String requestID;
  final List<QuestionAnswer> answers;
}
