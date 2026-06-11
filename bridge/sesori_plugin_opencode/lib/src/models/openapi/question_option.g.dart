// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';

@immutable
class QuestionOption {
  const QuestionOption({
    this.label = '',
    this.description = '',
  });

  factory QuestionOption.fromJson(Map<String, dynamic> json) {
    return QuestionOption(
      label: (json["label"] ?? '') as String,
      description: (json["description"] ?? '') as String,
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
