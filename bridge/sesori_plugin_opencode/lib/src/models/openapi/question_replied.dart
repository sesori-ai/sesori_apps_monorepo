// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T08:11:58.914264Z

import 'question_answer.dart';

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

  final String sessionID;
  final String requestID;
  final List<QuestionAnswer> answers;
}
