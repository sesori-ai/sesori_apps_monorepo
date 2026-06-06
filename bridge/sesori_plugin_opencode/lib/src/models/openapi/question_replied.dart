// GENERATED FILE - DO NOT EDIT BY HAND

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
      "answers": answers,
    };
  }

  final String sessionID;
  final String requestID;
  final List<QuestionAnswer> answers;
}
