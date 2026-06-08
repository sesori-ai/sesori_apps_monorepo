// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:11:43.905623Z

import 'package:meta/meta.dart';
import 'permission_config.dart';

@immutable
class AgentConfig {
  const AgentConfig({
    this.model,
    this.variant,
    this.temperature,
    this.topP,
    this.prompt,
    this.tools,
    this.disable,
    this.description,
    this.mode,
    this.hidden,
    this.options,
    this.color,
    this.steps,
    this.maxSteps,
    this.permission,
  });

  factory AgentConfig.fromJson(Map<String, dynamic> json) {
    return AgentConfig(
      model: json["model"] as String?,
      variant: json["variant"] as String?,
      temperature: (json["temperature"] as num?)?.toDouble(),
      topP: (json["top_p"] as num?)?.toDouble(),
      prompt: json["prompt"] as String?,
      tools: (json["tools"] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as bool)),
      disable: json["disable"] as bool?,
      description: json["description"] as String?,
      mode: json["mode"] as String?,
      hidden: json["hidden"] as bool?,
      options: json["options"] as Map<String, dynamic>?,
      color: json["color"] as Object?,
      steps: (json["steps"] as num?)?.toInt(),
      maxSteps: (json["maxSteps"] as num?)?.toInt(),
      permission: json["permission"] == null ? null : PermissionConfig.fromJson(json["permission"] as Object),
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "model": ?model,
      "variant": ?variant,
      "temperature": ?temperature,
      "top_p": ?topP,
      "prompt": ?prompt,
      "tools": ?tools,
      "disable": ?disable,
      "description": ?description,
      "mode": ?mode,
      "hidden": ?hidden,
      "options": ?options,
      "color": ?color,
      "steps": ?steps,
      "maxSteps": ?maxSteps,
      "permission": ?permission?.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AgentConfig &&
          other.model == model &&
          other.variant == variant &&
          other.temperature == temperature &&
          other.topP == topP &&
          other.prompt == prompt &&
          other.tools == tools &&
          other.disable == disable &&
          other.description == description &&
          other.mode == mode &&
          other.hidden == hidden &&
          other.options == options &&
          other.color == color &&
          other.steps == steps &&
          other.maxSteps == maxSteps &&
          other.permission == permission);

  @override
  int get hashCode => Object.hash(model, variant, temperature, topP, prompt, tools, disable, description, mode, hidden, options, color, steps, maxSteps, permission);

  final String? model;
  final String? variant;
  final double? temperature;
  final double? topP;
  final String? prompt;
  final Map<String, bool>? tools;
  final bool? disable;
  final String? description;
  final String? mode;
  final bool? hidden;
  final Map<String, dynamic>? options;
  final Object? color;
  final int? steps;
  final int? maxSteps;
  final PermissionConfig? permission;
}
