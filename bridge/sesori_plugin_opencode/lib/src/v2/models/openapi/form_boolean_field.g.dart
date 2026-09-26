// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.18 (cd9a14a6b688d4021bee381dfd39d2cef9c0f862)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'form_field.g.dart';
import 'form_when.g.dart';

@immutable
class FormBooleanField implements FormField {
  const FormBooleanField({
    required this.key,
    required this.title,
    required this.description,
    required this.required,
    required this.hidden,
    required this.when,
    required this.defaultValue,
  });

  factory FormBooleanField.fromJson(Map<String, dynamic> json) {
    return FormBooleanField(
      key: json["key"] as String,
      title: json["title"] as String?,
      description: json["description"] as String?,
      required: json["required"] as bool?,
      hidden: json["hidden"] as bool?,
      when: (json["when"] as List<dynamic>?)?.map((e) => FormWhen.fromJson(e as Map<String, dynamic>)).toList(),
      defaultValue: json["default"] as bool?,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "key": key,
      "title": ?title,
      "description": ?description,
      "required": ?required,
      "hidden": ?hidden,
      "when": ?when?.map((e) => e.toJson()).toList(),
      "type": "boolean",
      "default": ?defaultValue,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  FormBooleanField copyWith({
    String? key,
    String? title,
    String? description,
    bool? required,
    bool? hidden,
    List<FormWhen>? when,
    bool? defaultValue,
  }) {
    return FormBooleanField(
      key: key ?? this.key,
      title: title ?? this.title,
      description: description ?? this.description,
      required: required ?? this.required,
      hidden: hidden ?? this.hidden,
      when: when ?? this.when,
      defaultValue: defaultValue ?? this.defaultValue,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FormBooleanField &&
          other.key == key &&
          other.title == title &&
          other.description == description &&
          other.required == required &&
          other.hidden == hidden &&
          const DeepCollectionEquality().equals(other.when, when) &&
          other.defaultValue == defaultValue);

  @override
  int get hashCode => Object.hash(key, title, description, required, hidden, const DeepCollectionEquality().hash(when), defaultValue);

  final String key;
  final String? title;
  final String? description;
  final bool? required;
  final bool? hidden;
  final List<FormWhen>? when;
  final bool? defaultValue;
}
