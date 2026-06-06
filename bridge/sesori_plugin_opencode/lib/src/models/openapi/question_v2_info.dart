// GENERATED FILE - DO NOT EDIT BY HAND

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
      "options": options,
      "multiple": multiple,
      "custom": custom,
    };
  }

  final String question;
  final String header;
  final List<QuestionV2Option> options;
  final bool? multiple;
  final bool? custom;
}
