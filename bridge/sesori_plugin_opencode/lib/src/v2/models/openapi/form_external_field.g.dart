// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.18 (cd9a14a6b688d4021bee381dfd39d2cef9c0f862)

import 'package:meta/meta.dart';
import 'form_field.g.dart';

@immutable
class FormExternalField implements FormField {
  const FormExternalField({
    required this.key,
    required this.url,
    required this.title,
    required this.description,
  });

  factory FormExternalField.fromJson(Map<String, dynamic> json) {
    return FormExternalField(
      key: json["key"] as String,
      url: json["url"] as String,
      title: json["title"] as String?,
      description: json["description"] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "key": key,
      "type": "external",
      "url": url,
      "title": ?title,
      "description": ?description,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  FormExternalField copyWith({
    String? key,
    String? url,
    String? title,
    String? description,
  }) {
    return FormExternalField(
      key: key ?? this.key,
      url: url ?? this.url,
      title: title ?? this.title,
      description: description ?? this.description,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FormExternalField &&
          other.key == key &&
          other.url == url &&
          other.title == title &&
          other.description == description);

  @override
  int get hashCode => Object.hash(key, url, title, description);

  final String key;
  final String url;
  final String? title;
  final String? description;
}
