// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.16 (3a103fe0aff726a4edc7492f03f7b88195d9e4c9)

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
