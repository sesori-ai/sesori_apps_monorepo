// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.16 (3a103fe0aff726a4edc7492f03f7b88195d9e4c9)

import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import 'model_ref.g.dart';
import 'permission_ruleset.g.dart';
import 'provider_request.g.dart';

@immutable
class AgentInfo {
  const AgentInfo({
    required this.id,
    required this.name,
    required this.model,
    required this.request,
    required this.system,
    required this.description,
    required this.mode,
    required this.hidden,
    required this.color,
    required this.steps,
    required this.permissions,
  });

  factory AgentInfo.fromJson(Map<String, dynamic> json) {
    return AgentInfo(
      id: json["id"] as String,
      name: json["name"] as String,
      model: json["model"] == null ? null : ModelRef.fromJson(json["model"] as Map<String, dynamic>),
      request: ProviderRequest.fromJson(json["request"] as Map<String, dynamic>),
      system: json["system"] as String?,
      description: json["description"] as String?,
      mode: AgentInfoMode.fromJson(json["mode"] as String),
      hidden: json["hidden"] as bool,
      color: json["color"] as String?,
      steps: (json["steps"] as num?)?.toInt(),
      permissions: PermissionRuleset.fromJson(json["permissions"] as List<dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "name": name,
      "model": ?model?.toJson(),
      "request": request.toJson(),
      "system": ?system,
      "description": ?description,
      "mode": mode.toJson(),
      "hidden": hidden,
      "color": ?color,
      "steps": ?steps,
      "permissions": permissions.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  AgentInfo copyWith({
    String? id,
    String? name,
    ModelRef? model,
    ProviderRequest? request,
    String? system,
    String? description,
    AgentInfoMode? mode,
    bool? hidden,
    String? color,
    int? steps,
    PermissionRuleset? permissions,
  }) {
    return AgentInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      model: model ?? this.model,
      request: request ?? this.request,
      system: system ?? this.system,
      description: description ?? this.description,
      mode: mode ?? this.mode,
      hidden: hidden ?? this.hidden,
      color: color ?? this.color,
      steps: steps ?? this.steps,
      permissions: permissions ?? this.permissions,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AgentInfo &&
          other.id == id &&
          other.name == name &&
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
  int get hashCode => Object.hash(id, name, model, request, system, description, mode, hidden, color, steps, permissions);

  final String id;
  final String name;
  final ModelRef? model;
  final ProviderRequest request;
  final String? system;
  final String? description;
  final AgentInfoMode mode;
  final bool hidden;
  final String? color;
  final int? steps;
  final PermissionRuleset permissions;
}

enum AgentInfoMode {
  @JsonValue("subagent")
  subagent,
  @JsonValue("primary")
  primary,
  @JsonValue("all")
  all,

  /// Fallback for values introduced by newer OpenCode servers.
  /// Encodes back to the literal string `unknown`.
  unknown,
  ;

  static AgentInfoMode fromJson(String value) {
    switch (value) {
      case "subagent":
        return AgentInfoMode.subagent;
      case "primary":
        return AgentInfoMode.primary;
      case "all":
        return AgentInfoMode.all;
      default:
        return AgentInfoMode.unknown;
    }
  }

  String toJson() {
    switch (this) {
      case AgentInfoMode.subagent:
        return "subagent";
      case AgentInfoMode.primary:
        return "primary";
      case AgentInfoMode.all:
        return "all";
      case AgentInfoMode.unknown:
        return 'unknown';
    }
  }
}
