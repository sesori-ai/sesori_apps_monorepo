// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.16 (3a103fe0aff726a4edc7492f03f7b88195d9e4c9)

import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import 'form_field.g.dart';
import 'form_option.g.dart';
import 'form_when.g.dart';

@immutable
class FormStringField implements FormField {
  const FormStringField({
    required this.key,
    required this.title,
    required this.description,
    required this.required,
    required this.hidden,
    required this.when,
    required this.format,
    required this.minLength,
    required this.maxLength,
    required this.pattern,
    required this.placeholder,
    required this.defaultValue,
    required this.options,
    required this.custom,
  });

  factory FormStringField.fromJson(Map<String, dynamic> json) {
    return FormStringField(
      key: json["key"] as String,
      title: json["title"] as String?,
      description: json["description"] as String?,
      required: json["required"] as bool?,
      hidden: json["hidden"] as bool?,
      when: (json["when"] as List<dynamic>?)?.map((e) => FormWhen.fromJson(e as Map<String, dynamic>)).toList(),
      format: json["format"] == null ? null : FormStringFieldFormat.fromJson(json["format"] as String),
      minLength: (json["minLength"] as num?)?.toInt(),
      maxLength: (json["maxLength"] as num?)?.toInt(),
      pattern: json["pattern"] as String?,
      placeholder: json["placeholder"] as String?,
      defaultValue: json["default"] as String?,
      options: (json["options"] as List<dynamic>?)?.map((e) => FormOption.fromJson(e as Map<String, dynamic>)).toList(),
      custom: json["custom"] as bool?,
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
      "type": "string",
      "format": ?format?.toJson(),
      "minLength": ?minLength,
      "maxLength": ?maxLength,
      "pattern": ?pattern,
      "placeholder": ?placeholder,
      "default": ?defaultValue,
      "options": ?options?.map((e) => e.toJson()).toList(),
      "custom": ?custom,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  FormStringField copyWith({
    String? key,
    String? title,
    String? description,
    bool? required,
    bool? hidden,
    List<FormWhen>? when,
    FormStringFieldFormat? format,
    int? minLength,
    int? maxLength,
    String? pattern,
    String? placeholder,
    String? defaultValue,
    List<FormOption>? options,
    bool? custom,
  }) {
    return FormStringField(
      key: key ?? this.key,
      title: title ?? this.title,
      description: description ?? this.description,
      required: required ?? this.required,
      hidden: hidden ?? this.hidden,
      when: when ?? this.when,
      format: format ?? this.format,
      minLength: minLength ?? this.minLength,
      maxLength: maxLength ?? this.maxLength,
      pattern: pattern ?? this.pattern,
      placeholder: placeholder ?? this.placeholder,
      defaultValue: defaultValue ?? this.defaultValue,
      options: options ?? this.options,
      custom: custom ?? this.custom,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FormStringField &&
          other.key == key &&
          other.title == title &&
          other.description == description &&
          other.required == required &&
          other.hidden == hidden &&
          const DeepCollectionEquality().equals(other.when, when) &&
          other.format == format &&
          other.minLength == minLength &&
          other.maxLength == maxLength &&
          other.pattern == pattern &&
          other.placeholder == placeholder &&
          other.defaultValue == defaultValue &&
          const DeepCollectionEquality().equals(other.options, options) &&
          other.custom == custom);

  @override
  int get hashCode => Object.hash(key, title, description, required, hidden, const DeepCollectionEquality().hash(when), format, minLength, maxLength, pattern, placeholder, defaultValue, const DeepCollectionEquality().hash(options), custom);

  final String key;
  final String? title;
  final String? description;
  final bool? required;
  final bool? hidden;
  final List<FormWhen>? when;
  final FormStringFieldFormat? format;
  final int? minLength;
  final int? maxLength;
  final String? pattern;
  final String? placeholder;
  final String? defaultValue;
  final List<FormOption>? options;
  final bool? custom;
}

enum FormStringFieldFormat {
  @JsonValue("email")
  email,
  @JsonValue("uri")
  uri,
  @JsonValue("date")
  date,
  @JsonValue("date-time")
  dateTime,

  /// Fallback for values introduced by newer OpenCode servers.
  /// Encodes back to the literal string `unknown`.
  unknown,
  ;

  static FormStringFieldFormat fromJson(String value) {
    switch (value) {
      case "email":
        return FormStringFieldFormat.email;
      case "uri":
        return FormStringFieldFormat.uri;
      case "date":
        return FormStringFieldFormat.date;
      case "date-time":
        return FormStringFieldFormat.dateTime;
      default:
        return FormStringFieldFormat.unknown;
    }
  }

  String toJson() {
    switch (this) {
      case FormStringFieldFormat.email:
        return "email";
      case FormStringFieldFormat.uri:
        return "uri";
      case FormStringFieldFormat.date:
        return "date";
      case FormStringFieldFormat.dateTime:
        return "date-time";
      case FormStringFieldFormat.unknown:
        return 'unknown';
    }
  }
}
