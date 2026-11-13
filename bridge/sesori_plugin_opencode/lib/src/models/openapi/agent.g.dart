// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.7 (4ed4f749e644ffb5b279fb30b7b915e743d80142)

import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import 'permission_ruleset.g.dart';

@immutable
class Agent {
  const Agent({
    required this.name,
    required this.description,
    required this.mode,
    required this.native,
    required this.hidden,
    required this.topP,
    required this.temperature,
    required this.color,
    required this.permission,
    required this.model,
    required this.variant,
    required this.prompt,
    required this.options,
    required this.steps,
  });

  factory Agent.fromJson(Map<String, dynamic> json) {
    return Agent(
      name: json["name"] as String,
      description: json["description"] as String?,
      mode: AgentMode.fromJson(json["mode"] as String),
      native: json["native"] as bool?,
      hidden: json["hidden"] as bool?,
      topP: (json["topP"] as num?)?.toDouble(),
      temperature: (json["temperature"] as num?)?.toDouble(),
      color: json["color"] as String?,
      permission: PermissionRuleset.fromJson(json["permission"] as List<dynamic>),
      model: json["model"] == null ? null : AgentModel.fromJson(json["model"] as Map<String, dynamic>),
      variant: json["variant"] as String?,
      prompt: json["prompt"] as String?,
      options: json["options"] as Map<String, dynamic>,
      steps: (json["steps"] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "name": name,
      "description": ?description,
      "mode": mode.toJson(),
      "native": ?native,
      "hidden": ?hidden,
      "topP": ?topP,
      "temperature": ?temperature,
      "color": ?color,
      "permission": permission.toJson(),
      "model": ?model?.toJson(),
      "variant": ?variant,
      "prompt": ?prompt,
      "options": options,
      "steps": ?steps,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  Agent copyWith({
    String? name,
    String? description,
    AgentMode? mode,
    bool? native,
    bool? hidden,
    double? topP,
    double? temperature,
    String? color,
    PermissionRuleset? permission,
    AgentModel? model,
    String? variant,
    String? prompt,
    Map<String, dynamic>? options,
    double? steps,
  }) {
    return Agent(
      name: name ?? this.name,
      description: description ?? this.description,
      mode: mode ?? this.mode,
      native: native ?? this.native,
      hidden: hidden ?? this.hidden,
      topP: topP ?? this.topP,
      temperature: temperature ?? this.temperature,
      color: color ?? this.color,
      permission: permission ?? this.permission,
      model: model ?? this.model,
      variant: variant ?? this.variant,
      prompt: prompt ?? this.prompt,
      options: options ?? this.options,
      steps: steps ?? this.steps,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Agent &&
          other.name == name &&
          other.description == description &&
          other.mode == mode &&
          other.native == native &&
          other.hidden == hidden &&
          other.topP == topP &&
          other.temperature == temperature &&
          other.color == color &&
          other.permission == permission &&
          other.model == model &&
          other.variant == variant &&
          other.prompt == prompt &&
          const DeepCollectionEquality().equals(other.options, options) &&
          other.steps == steps);

  @override
  int get hashCode => Object.hash(name, description, mode, native, hidden, topP, temperature, color, permission, model, variant, prompt, const DeepCollectionEquality().hash(options), steps);

  final String name;
  final String? description;
  final AgentMode mode;
  final bool? native;
  final bool? hidden;
  final double? topP;
  final double? temperature;
  final String? color;
  final PermissionRuleset permission;
  final AgentModel? model;
  final String? variant;
  final String? prompt;
  final Map<String, dynamic> options;
  final double? steps;
}

@immutable
class AgentModel {
  const AgentModel({
    required this.modelID,
    required this.providerID,
  });

  factory AgentModel.fromJson(Map<String, dynamic> json) {
    return AgentModel(
      modelID: json["modelID"] as String,
      providerID: json["providerID"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "modelID": modelID,
      "providerID": providerID,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  AgentModel copyWith({
    String? modelID,
    String? providerID,
  }) {
    return AgentModel(
      modelID: modelID ?? this.modelID,
      providerID: providerID ?? this.providerID,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AgentModel &&
          other.modelID == modelID &&
          other.providerID == providerID);

  @override
  int get hashCode => Object.hash(modelID, providerID);

  final String modelID;
  final String providerID;
}

enum AgentMode {
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

  static AgentMode fromJson(String value) {
    switch (value) {
      case "subagent":
        return AgentMode.subagent;
      case "primary":
        return AgentMode.primary;
      case "all":
        return AgentMode.all;
      default:
        return AgentMode.unknown;
    }
  }

  String toJson() {
    switch (this) {
      case AgentMode.subagent:
        return "subagent";
      case AgentMode.primary:
        return "primary";
      case AgentMode.all:
        return "all";
      case AgentMode.unknown:
        return 'unknown';
    }
  }
}
