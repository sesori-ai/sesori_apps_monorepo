// GENERATED FILE - DO NOT EDIT BY HAND

import 'permission_v2_ruleset.dart';

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
      color: json["color"],
      steps: json["steps"] as int?,
      permissions: PermissionV2Ruleset.fromJson(json["permissions"] as List<dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "model": model,
      "request": request,
      "system": system,
      "description": description,
      "mode": mode,
      "hidden": hidden,
      "color": color,
      "steps": steps,
      "permissions": permissions.toJson(),
    };
  }

  final String id;
  final Map<String, dynamic>? model;
  final Map<String, dynamic> request;
  final String? system;
  final String? description;
  final String mode;
  final bool hidden;
  final dynamic color;
  final int? steps;
  final PermissionV2Ruleset permissions;
}
