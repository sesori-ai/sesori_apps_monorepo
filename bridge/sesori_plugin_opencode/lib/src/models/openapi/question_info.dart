// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T08:11:58.913845Z

import 'question_option.dart';

class QuestionInfo {
  const QuestionInfo({
    required this.question,
    required this.header,
    required this.options,
    this.multiple,
    this.custom,
  });

  factory QuestionInfo.fromJson(Map<String, dynamic> json) {
    return QuestionInfo(
      question: json["question"] as String,
      header: json["header"] as String,
      options: (json["options"] as List<dynamic>).map((e) => QuestionOption.fromJson(e as Map<String, dynamic>)).toList(),
      multiple: json["multiple"] as bool?,
      custom: json["custom"] as bool?,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "question": question,
      "header": header,
      "options": options.map((e) => e.toJson()).toList(),
      "multiple": ?multiple,
      "custom": ?custom,
    };
  }

  final String question;
  final String header;
  final List<QuestionOption> options;
  final bool? multiple;
  final bool? custom;
}
