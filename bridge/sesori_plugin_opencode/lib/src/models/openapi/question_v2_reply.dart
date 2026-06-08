// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T13:43:24.185920Z

import 'question_v2_answer.dart';

class QuestionV2Reply {
  const QuestionV2Reply({
    required this.answers,
  });

  factory QuestionV2Reply.fromJson(Map<String, dynamic> json) {
    return QuestionV2Reply(
      answers: (json["answers"] as List<dynamic>).map((e) => QuestionV2Answer.fromJson(e as List<dynamic>)).toList(),
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "answers": answers.map((e) => e.toJson()).toList(),
    };
  }

  final List<QuestionV2Answer> answers;
}
