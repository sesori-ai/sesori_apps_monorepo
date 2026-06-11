// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';

@immutable
class CommandV2Info {
  const CommandV2Info({
    required this.name,
    required this.template,
    this.description,
    this.agent,
    this.model,
    this.subtask,
  });

  factory CommandV2Info.fromJson(Map<String, dynamic> json) {
    return CommandV2Info(
      name: json["name"] as String,
      template: json["template"] as String,
      description: json["description"] as String?,
      agent: json["agent"] as String?,
      model: json["model"] == null ? null : CommandV2InfoModel.fromJson(json["model"] as Map<String, dynamic>),
      subtask: json["subtask"] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "name": name,
      "template": template,
      "description": ?description,
      "agent": ?agent,
      "model": ?model?.toJson(),
      "subtask": ?subtask,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CommandV2Info &&
          other.name == name &&
          other.template == template &&
          other.description == description &&
          other.agent == agent &&
          other.model == model &&
          other.subtask == subtask);

  @override
  int get hashCode => Object.hash(name, template, description, agent, model, subtask);

  final String name;
  final String template;
  final String? description;
  final String? agent;
  final CommandV2InfoModel? model;
  final bool? subtask;
}

@immutable
class CommandV2InfoModel {
  const CommandV2InfoModel({
    required this.id,
    required this.providerID,
    this.variant,
  });

  factory CommandV2InfoModel.fromJson(Map<String, dynamic> json) {
    return CommandV2InfoModel(
      id: json["id"] as String,
      providerID: json["providerID"] as String,
      variant: json["variant"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "providerID": providerID,
      "variant": ?variant,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CommandV2InfoModel &&
          other.id == id &&
          other.providerID == providerID &&
          other.variant == variant);

  @override
  int get hashCode => Object.hash(id, providerID, variant);

  final String id;
  final String providerID;
  final String? variant;
}
