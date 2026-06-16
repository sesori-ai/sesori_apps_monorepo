// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'question_option.g.dart';

@immutable
class QuestionInfo {
  const QuestionInfo({
    required this.question,
    required this.header,
    required this.options,
    required this.multiple,
    required this.custom,
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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  QuestionInfo copyWith({
    String? question,
    String? header,
    List<QuestionOption>? options,
    bool? multiple,
    bool? custom,
  }) {
    return QuestionInfo(
      question: question ?? this.question,
      header: header ?? this.header,
      options: options ?? this.options,
      multiple: multiple ?? this.multiple,
      custom: custom ?? this.custom,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QuestionInfo &&
          other.question == question &&
          other.header == header &&
          const DeepCollectionEquality().equals(other.options, options) &&
          other.multiple == multiple &&
          other.custom == custom);

  @override
  int get hashCode => Object.hash(question, header, const DeepCollectionEquality().hash(options), multiple, custom);

  final String question;
  final String header;
  final List<QuestionOption> options;
  final bool? multiple;
  final bool? custom;
}
