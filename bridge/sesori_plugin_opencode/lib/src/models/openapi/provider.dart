// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T07:51:39.998332Z

import 'model.dart';

class Provider {
  const Provider({
    required this.id,
    required this.name,
    required this.source,
    required this.env,
    this.key,
    required this.options,
    required this.models,
  });

  factory Provider.fromJson(Map<String, dynamic> json) {
    return Provider(
      id: json["id"] as String,
      name: json["name"] as String,
      source: json["source"] as String,
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
      "source": source,
      "env": env,
      "key": ?key,
      "options": options,
      "models": models.map((k, v) => MapEntry(k, v.toJson())),
    };
  }

  final String id;
  final String name;
  final String source;
  final List<String> env;
  final String? key;
  final Map<String, dynamic> options;
  final Map<String, Model> models;
}
