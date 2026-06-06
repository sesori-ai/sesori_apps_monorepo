// GENERATED FILE - DO NOT EDIT BY HAND

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
      "options": options,
      "multiple": multiple,
      "custom": custom,
    };
  }

  final String question;
  final String header;
  final List<QuestionOption> options;
  final bool? multiple;
  final bool? custom;
}
