// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:11:43.908156Z

import 'package:meta/meta.dart';

@immutable
class AgentPartInput {
  const AgentPartInput({
    this.id,
    required this.type,
    required this.name,
    this.source,
  });

  factory AgentPartInput.fromJson(Map<String, dynamic> json) {
    return AgentPartInput(
      id: json["id"] as String?,
      type: json["type"] as String,
      name: json["name"] as String,
      source: json["source"] as Map<String, dynamic>?,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": ?id,
      "type": type,
      "name": name,
      "source": ?source,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AgentPartInput &&
          other.id == id &&
          other.type == type &&
          other.name == name &&
          other.source == source);

  @override
  int get hashCode => Object.hash(id, type, name, source);

  final String? id;
  final String type;
  final String name;
  final Map<String, dynamic>? source;
}
