// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T13:40:29.582643Z

import 'permission_ruleset.dart';

class Agent {
  const Agent({
    required this.name,
    this.description,
    required this.mode,
    this.native,
    this.hidden,
    this.topP,
    this.temperature,
    this.color,
    required this.permission,
    this.model,
    this.variant,
    this.prompt,
    required this.options,
    this.steps,
  });

  factory Agent.fromJson(Map<String, dynamic> json) {
    return Agent(
      name: json["name"] as String,
      description: json["description"] as String?,
      mode: json["mode"] as String,
      native: json["native"] as bool?,
      hidden: json["hidden"] as bool?,
      topP: (json["topP"] as num?)?.toDouble(),
      temperature: (json["temperature"] as num?)?.toDouble(),
      color: json["color"] as String?,
      permission: PermissionRuleset.fromJson(json["permission"] as List<dynamic>),
      model: json["model"] as Map<String, dynamic>?,
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
      "mode": mode,
      "native": ?native,
      "hidden": ?hidden,
      "topP": ?topP,
      "temperature": ?temperature,
      "color": ?color,
      "permission": permission.toJson(),
      "model": ?model,
      "variant": ?variant,
      "prompt": ?prompt,
      "options": options,
      "steps": ?steps,
    };
  }

  final String name;
  final String? description;
  final String mode;
  final bool? native;
  final bool? hidden;
  final double? topP;
  final double? temperature;
  final String? color;
  final PermissionRuleset permission;
  final Map<String, dynamic>? model;
  final String? variant;
  final String? prompt;
  final Map<String, dynamic> options;
  final double? steps;
}
