// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:11:43.955708Z

import 'package:meta/meta.dart';
import 'question_v2_answer.dart';

@immutable
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QuestionV2Reply &&
          other.answers == answers);

  @override
  int get hashCode => answers.hashCode;

  final List<QuestionV2Answer> answers;
}
