// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.16 (3a103fe0aff726a4edc7492f03f7b88195d9e4c9)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'form_field.g.dart';
import 'form_when.g.dart';

@immutable
class FormNumberField implements FormField {
  const FormNumberField({
    required this.key,
    required this.title,
    required this.description,
    required this.required,
    required this.hidden,
    required this.when,
    required this.minimum,
    required this.maximum,
    required this.defaultValue,
  });

  factory FormNumberField.fromJson(Map<String, dynamic> json) {
    return FormNumberField(
      key: json["key"] as String,
      title: json["title"] as String?,
      description: json["description"] as String?,
      required: json["required"] as bool?,
      hidden: json["hidden"] as bool?,
      when: (json["when"] as List<dynamic>?)?.map((e) => FormWhen.fromJson(e as Map<String, dynamic>)).toList(),
      minimum: json["minimum"] as Object?,
      maximum: json["maximum"] as Object?,
      defaultValue: json["default"] as Object?,
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
      "type": "number",
      "minimum": ?minimum,
      "maximum": ?maximum,
      "default": ?defaultValue,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  FormNumberField copyWith({
    String? key,
    String? title,
    String? description,
    bool? required,
    bool? hidden,
    List<FormWhen>? when,
    Object? minimum,
    Object? maximum,
    Object? defaultValue,
  }) {
    return FormNumberField(
      key: key ?? this.key,
      title: title ?? this.title,
      description: description ?? this.description,
      required: required ?? this.required,
      hidden: hidden ?? this.hidden,
      when: when ?? this.when,
      minimum: minimum ?? this.minimum,
      maximum: maximum ?? this.maximum,
      defaultValue: defaultValue ?? this.defaultValue,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FormNumberField &&
          other.key == key &&
          other.title == title &&
          other.description == description &&
          other.required == required &&
          other.hidden == hidden &&
          const DeepCollectionEquality().equals(other.when, when) &&
          const DeepCollectionEquality().equals(other.minimum, minimum) &&
          const DeepCollectionEquality().equals(other.maximum, maximum) &&
          const DeepCollectionEquality().equals(other.defaultValue, defaultValue));

  @override
  int get hashCode => Object.hash(key, title, description, required, hidden, const DeepCollectionEquality().hash(when), const DeepCollectionEquality().hash(minimum), const DeepCollectionEquality().hash(maximum), const DeepCollectionEquality().hash(defaultValue));

  final String key;
  final String? title;
  final String? description;
  final bool? required;
  final bool? hidden;
  final List<FormWhen>? when;
  final Object? minimum;
  final Object? maximum;
  final Object? defaultValue;
}
