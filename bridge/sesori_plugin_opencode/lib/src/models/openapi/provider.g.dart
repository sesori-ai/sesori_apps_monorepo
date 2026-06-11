// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'model.g.dart';

@immutable
class Provider {
  const Provider({
    this.id = '',
    this.name = '',
    this.source = '',
    this.env = const [],
    this.key,
    this.options = const {},
    this.models = const {},
  });

  factory Provider.fromJson(Map<String, dynamic> json) {
    return Provider(
      id: (json["id"] ?? '') as String,
      name: (json["name"] ?? '') as String,
      source: (json["source"] ?? '') as String,
      env: ((json["env"] ?? const []) as List<dynamic>).cast<String>(),
      key: json["key"] as String?,
      options: (json["options"] ?? const <String, dynamic>{}) as Map<String, dynamic>,
      models: ((json["models"] ?? const <String, dynamic>{}) as Map<String, dynamic>).map((k, v) => MapEntry(k, Model.fromJson(v as Map<String, dynamic>))),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "name": name,
      "source": source,
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
    String? source,
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
  final String source;
  final List<String> env;
  final String? key;
  final Map<String, dynamic> options;
  final Map<String, Model> models;
}
