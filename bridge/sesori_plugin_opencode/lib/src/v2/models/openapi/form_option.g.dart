// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.18 (cd9a14a6b688d4021bee381dfd39d2cef9c0f862)

import 'package:meta/meta.dart';

@immutable
class FormOption {
  const FormOption({
    required this.value,
    required this.label,
    required this.description,
  });

  factory FormOption.fromJson(Map<String, dynamic> json) {
    return FormOption(
      value: json["value"] as String,
      label: json["label"] as String,
      description: json["description"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "value": value,
      "label": label,
      "description": ?description,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  FormOption copyWith({
    String? value,
    String? label,
    String? description,
  }) {
    return FormOption(
      value: value ?? this.value,
      label: label ?? this.label,
      description: description ?? this.description,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FormOption &&
          other.value == value &&
          other.label == label &&
          other.description == description);

  @override
  int get hashCode => Object.hash(value, label, description);

  final String value;
  final String label;
  final String? description;
}
