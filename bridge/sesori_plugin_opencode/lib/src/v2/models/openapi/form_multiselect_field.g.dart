// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.16 (3a103fe0aff726a4edc7492f03f7b88195d9e4c9)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'form_field.g.dart';
import 'form_option.g.dart';
import 'form_when.g.dart';

@immutable
class FormMultiselectField implements FormField {
  const FormMultiselectField({
    required this.key,
    required this.title,
    required this.description,
    required this.required,
    required this.hidden,
    required this.when,
    required this.options,
    required this.minItems,
    required this.maxItems,
    required this.custom,
    required this.defaultValue,
  });

  factory FormMultiselectField.fromJson(Map<String, dynamic> json) {
    return FormMultiselectField(
      key: json["key"] as String,
      title: json["title"] as String?,
      description: json["description"] as String?,
      required: json["required"] as bool?,
      hidden: json["hidden"] as bool?,
      when: (json["when"] as List<dynamic>?)?.map((e) => FormWhen.fromJson(e as Map<String, dynamic>)).toList(),
      options: (json["options"] as List<dynamic>).map((e) => FormOption.fromJson(e as Map<String, dynamic>)).toList(),
      minItems: (json["minItems"] as num?)?.toInt(),
      maxItems: (json["maxItems"] as num?)?.toInt(),
      custom: json["custom"] as bool?,
      defaultValue: (json["default"] as List<dynamic>?)?.cast<String>(),
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
      "type": "multiselect",
      "options": options.map((e) => e.toJson()).toList(),
      "minItems": ?minItems,
      "maxItems": ?maxItems,
      "custom": ?custom,
      "default": ?defaultValue,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  FormMultiselectField copyWith({
    String? key,
    String? title,
    String? description,
    bool? required,
    bool? hidden,
    List<FormWhen>? when,
    List<FormOption>? options,
    int? minItems,
    int? maxItems,
    bool? custom,
    List<String>? defaultValue,
  }) {
    return FormMultiselectField(
      key: key ?? this.key,
      title: title ?? this.title,
      description: description ?? this.description,
      required: required ?? this.required,
      hidden: hidden ?? this.hidden,
      when: when ?? this.when,
      options: options ?? this.options,
      minItems: minItems ?? this.minItems,
      maxItems: maxItems ?? this.maxItems,
      custom: custom ?? this.custom,
      defaultValue: defaultValue ?? this.defaultValue,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FormMultiselectField &&
          other.key == key &&
          other.title == title &&
          other.description == description &&
          other.required == required &&
          other.hidden == hidden &&
          const DeepCollectionEquality().equals(other.when, when) &&
          const DeepCollectionEquality().equals(other.options, options) &&
          other.minItems == minItems &&
          other.maxItems == maxItems &&
          other.custom == custom &&
          const DeepCollectionEquality().equals(other.defaultValue, defaultValue));

  @override
  int get hashCode => Object.hash(key, title, description, required, hidden, const DeepCollectionEquality().hash(when), const DeepCollectionEquality().hash(options), minItems, maxItems, custom, const DeepCollectionEquality().hash(defaultValue));

  final String key;
  final String? title;
  final String? description;
  final bool? required;
  final bool? hidden;
  final List<FormWhen>? when;
  final List<FormOption> options;
  final int? minItems;
  final int? maxItems;
  final bool? custom;
  final List<String>? defaultValue;
}
