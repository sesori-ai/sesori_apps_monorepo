// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T13:40:29.629061Z

import 'question_v2_option.dart';

class QuestionV2Info {
  const QuestionV2Info({
    required this.question,
    required this.header,
    required this.options,
    this.multiple,
    this.custom,
  });

  factory QuestionV2Info.fromJson(Map<String, dynamic> json) {
    return QuestionV2Info(
      question: json["question"] as String,
      header: json["header"] as String,
      options: (json["options"] as List<dynamic>).map((e) => QuestionV2Option.fromJson(e as Map<String, dynamic>)).toList(),
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
  final List<QuestionV2Option> options;
  final bool? multiple;
  final bool? custom;
}
