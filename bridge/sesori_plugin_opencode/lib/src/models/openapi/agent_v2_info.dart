// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:24:06.197820Z

import 'package:meta/meta.dart';
import 'permission_v2_ruleset.dart';

@immutable
class AgentV2Info {
  const AgentV2Info({
    required this.id,
    this.model,
    required this.request,
    this.system,
    this.description,
    required this.mode,
    required this.hidden,
    this.color,
    this.steps,
    required this.permissions,
  });

  factory AgentV2Info.fromJson(Map<String, dynamic> json) {
    return AgentV2Info(
      id: json["id"] as String,
      model: json["model"] as Map<String, dynamic>?,
      request: json["request"] as Map<String, dynamic>,
      system: json["system"] as String?,
      description: json["description"] as String?,
      mode: json["mode"] as String,
      hidden: json["hidden"] as bool,
      color: json["color"] as Object?,
      steps: (json["steps"] as num?)?.toInt(),
      permissions: PermissionV2Ruleset.fromJson(json["permissions"] as List<dynamic>),
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "model": ?model,
      "request": request,
      "system": ?system,
      "description": ?description,
      "mode": mode,
      "hidden": hidden,
      "color": ?color,
      "steps": ?steps,
      "permissions": permissions.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AgentV2Info &&
          other.id == id &&
          other.model == model &&
          other.request == request &&
          other.system == system &&
          other.description == description &&
          other.mode == mode &&
          other.hidden == hidden &&
          other.color == color &&
          other.steps == steps &&
          other.permissions == permissions);

  @override
  int get hashCode => Object.hash(id, model, request, system, description, mode, hidden, color, steps, permissions);

  final String id;
  final Map<String, dynamic>? model;
  final Map<String, dynamic> request;
  final String? system;
  final String? description;
  final String mode;
  final bool hidden;
  final Object? color;
  final int? steps;
  final PermissionV2Ruleset permissions;
}
