// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.7 (4ed4f749e644ffb5b279fb30b7b915e743d80142)

import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import 'model.g.dart';

@immutable
class Provider {
  const Provider({
    required this.id,
    required this.name,
    required this.source,
    required this.env,
    required this.key,
    required this.options,
    required this.models,
  });

  factory Provider.fromJson(Map<String, dynamic> json) {
    return Provider(
      id: json["id"] as String,
      name: json["name"] as String,
      source: ProviderSource.fromJson(json["source"] as String),
      env: (json["env"] as List<dynamic>).cast<String>(),
      key: json["key"] as String?,
      options: json["options"] as Map<String, dynamic>,
      models: (json["models"] as Map<String, dynamic>).map((k, v) => MapEntry(k, Model.fromJson(v as Map<String, dynamic>))),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "name": name,
      "source": source.toJson(),
      "env": env,
      "key": ?key,
      "options": options,
      "models": models.map((k, v) => MapEntry(k, v.toJson())),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  Provider copyWith({
    String? id,
    String? name,
    ProviderSource? source,
    List<String>? env,
    String? key,
    Map<String, dynamic>? options,
    Map<String, Model>? models,
  }) {
    return Provider(
      id: id ?? this.id,
      name: name ?? this.name,
      source: source ?? this.source,
      env: env ?? this.env,
      key: key ?? this.key,
      options: options ?? this.options,
      models: models ?? this.models,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Provider &&
          other.id == id &&
          other.name == name &&
          other.source == source &&
          const DeepCollectionEquality().equals(other.env, env) &&
          other.key == key &&
          const DeepCollectionEquality().equals(other.options, options) &&
          const DeepCollectionEquality().equals(other.models, models));

  @override
  int get hashCode => Object.hash(id, name, source, const DeepCollectionEquality().hash(env), key, const DeepCollectionEquality().hash(options), const DeepCollectionEquality().hash(models));

  final String id;
  final String name;
  final ProviderSource source;
  final List<String> env;
  final String? key;
  final Map<String, dynamic> options;
  final Map<String, Model> models;
}

enum ProviderSource {
  @JsonValue("env")
  env,
  @JsonValue("config")
  config,
  @JsonValue("custom")
  custom,
  @JsonValue("api")
  api,

  /// Fallback for values introduced by newer OpenCode servers.
  /// Encodes back to the literal string `unknown`.
  unknown,
  ;

  static ProviderSource fromJson(String value) {
    switch (value) {
      case "env":
        return ProviderSource.env;
      case "config":
        return ProviderSource.config;
      case "custom":
        return ProviderSource.custom;
      case "api":
        return ProviderSource.api;
      default:
        return ProviderSource.unknown;
    }
  }

  String toJson() {
    switch (this) {
      case ProviderSource.env:
        return "env";
      case ProviderSource.config:
        return "config";
      case ProviderSource.custom:
        return "custom";
      case ProviderSource.api:
        return "api";
      case ProviderSource.unknown:
        return 'unknown';
    }
  }
}
