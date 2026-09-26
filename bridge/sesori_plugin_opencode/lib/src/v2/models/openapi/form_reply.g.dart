// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.18 (cd9a14a6b688d4021bee381dfd39d2cef9c0f862)

import 'package:meta/meta.dart';
import 'form_answer.g.dart';

@immutable
class FormReply {
  const FormReply({
    required this.answer,
  });

  factory FormReply.fromJson(Map<String, dynamic> json) {
    return FormReply(
      answer: FormAnswer.fromJson(json["answer"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "answer": answer.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  FormReply copyWith({
    FormAnswer? answer,
  }) {
    return FormReply(
      answer: answer ?? this.answer,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FormReply &&
          other.answer == answer);

  @override
  int get hashCode => answer.hashCode;

  final FormAnswer answer;
}
