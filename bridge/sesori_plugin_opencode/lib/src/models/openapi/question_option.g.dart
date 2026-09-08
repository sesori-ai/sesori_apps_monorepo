// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.7 (4ed4f749e644ffb5b279fb30b7b915e743d80142)

import 'package:meta/meta.dart';

@immutable
class QuestionOption {
  const QuestionOption({
    required this.label,
    required this.description,
  });

  factory QuestionOption.fromJson(Map<String, dynamic> json) {
    return QuestionOption(
      label: json["label"] as String,
      description: json["description"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "label": label,
      "description": description,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  QuestionOption copyWith({
    String? label,
    String? description,
  }) {
    return QuestionOption(
      label: label ?? this.label,
      description: description ?? this.description,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QuestionOption &&
          other.label == label &&
          other.description == description);

  @override
  int get hashCode => Object.hash(label, description);

  final String label;
  final String description;
}
