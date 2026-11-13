// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.2.7 (fedc6f208aa2bd54c1019227214568083f6380ad)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'model_variant_settings.g.dart';

@immutable
class ModelVariant {
  const ModelVariant({
    required this.id,
    required this.settings,
    required this.headers,
    required this.body,
  });

  factory ModelVariant.fromJson(Map<String, dynamic> json) {
    return ModelVariant(
      id: json["id"] as String,
      settings: json["settings"] == null
          ? null
          : ModelVariantSettings.fromJson(json["settings"] as Map<String, dynamic>),
      headers: (json["headers"] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as String)),
      body: json["body"] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "settings": ?settings?.toJson(),
      "headers": ?headers,
      "body": ?body,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ModelVariant copyWith({
    String? id,
    ModelVariantSettings? settings,
    Map<String, String>? headers,
    Map<String, dynamic>? body,
  }) {
    return ModelVariant(
      id: id ?? this.id,
      settings: settings ?? this.settings,
      headers: headers ?? this.headers,
      body: body ?? this.body,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModelVariant &&
          other.id == id &&
          other.settings == settings &&
          const DeepCollectionEquality().equals(other.headers, headers) &&
          const DeepCollectionEquality().equals(other.body, body));

  @override
  int get hashCode => Object.hash(
    id,
    settings,
    const DeepCollectionEquality().hash(headers),
    const DeepCollectionEquality().hash(body),
  );

  final String id;
  final ModelVariantSettings? settings;
  final Map<String, String>? headers;
  final Map<String, dynamic>? body;
}
