// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.16 (3a103fe0aff726a4edc7492f03f7b88195d9e4c9)

import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import 'provider_settings.g.dart';

@immutable
class ProviderInfo {
  const ProviderInfo({
    required this.id,
    required this.canonical,
    required this.integrationID,
    required this.name,
    required this.activation,
    required this.package,
    required this.settings,
    required this.headers,
    required this.body,
  });

  factory ProviderInfo.fromJson(Map<String, dynamic> json) {
    return ProviderInfo(
      id: json["id"] as String,
      canonical: json["canonical"] as String?,
      integrationID: json["integrationID"] as String?,
      name: json["name"] as String,
      activation: ProviderInfoActivation.fromJson(json["activation"] as String),
      package: json["package"] as String,
      settings: json["settings"] == null ? null : ProviderSettings.fromJson(json["settings"] as Map<String, dynamic>),
      headers: (json["headers"] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as String)),
      body: json["body"] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "canonical": ?canonical,
      "integrationID": ?integrationID,
      "name": name,
      "activation": activation.toJson(),
      "package": package,
      "settings": ?settings?.toJson(),
      "headers": ?headers,
      "body": ?body,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ProviderInfo copyWith({
    String? id,
    String? canonical,
    String? integrationID,
    String? name,
    ProviderInfoActivation? activation,
    String? package,
    ProviderSettings? settings,
    Map<String, String>? headers,
    Map<String, dynamic>? body,
  }) {
    return ProviderInfo(
      id: id ?? this.id,
      canonical: canonical ?? this.canonical,
      integrationID: integrationID ?? this.integrationID,
      name: name ?? this.name,
      activation: activation ?? this.activation,
      package: package ?? this.package,
      settings: settings ?? this.settings,
      headers: headers ?? this.headers,
      body: body ?? this.body,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProviderInfo &&
          other.id == id &&
          other.canonical == canonical &&
          other.integrationID == integrationID &&
          other.name == name &&
          other.activation == activation &&
          other.package == package &&
          other.settings == settings &&
          const DeepCollectionEquality().equals(other.headers, headers) &&
          const DeepCollectionEquality().equals(other.body, body));

  @override
  int get hashCode => Object.hash(id, canonical, integrationID, name, activation, package, settings, const DeepCollectionEquality().hash(headers), const DeepCollectionEquality().hash(body));

  final String id;
  final String? canonical;
  final String? integrationID;
  final String name;
  final ProviderInfoActivation activation;
  final String package;
  final ProviderSettings? settings;
  final Map<String, String>? headers;
  final Map<String, dynamic>? body;
}

enum ProviderInfoActivation {
  @JsonValue("auto")
  auto,
  @JsonValue("enabled")
  enabled,
  @JsonValue("disabled")
  disabled,

  /// Fallback for values introduced by newer OpenCode servers.
  /// Encodes back to the literal string `unknown`.
  unknown,
  ;

  static ProviderInfoActivation fromJson(String value) {
    switch (value) {
      case "auto":
        return ProviderInfoActivation.auto;
      case "enabled":
        return ProviderInfoActivation.enabled;
      case "disabled":
        return ProviderInfoActivation.disabled;
      default:
        return ProviderInfoActivation.unknown;
    }
  }

  String toJson() {
    switch (this) {
      case ProviderInfoActivation.auto:
        return "auto";
      case ProviderInfoActivation.enabled:
        return "enabled";
      case ProviderInfoActivation.disabled:
        return "disabled";
      case ProviderInfoActivation.unknown:
        return 'unknown';
    }
  }
}
