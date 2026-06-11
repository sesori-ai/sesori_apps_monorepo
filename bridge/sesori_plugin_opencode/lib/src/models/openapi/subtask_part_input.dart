// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';

@immutable
class SubtaskPartInput {
  const SubtaskPartInput({
    this.id,
    required this.type,
    required this.prompt,
    required this.description,
    required this.agent,
    this.model,
    this.command,
  });

  factory SubtaskPartInput.fromJson(Map<String, dynamic> json) {
    return SubtaskPartInput(
      id: json["id"] as String?,
      type: json["type"] as String,
      prompt: json["prompt"] as String,
      description: json["description"] as String,
      agent: json["agent"] as String,
      model: json["model"] == null ? null : SubtaskPartInputModel.fromJson(json["model"] as Map<String, dynamic>),
      command: json["command"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": ?id,
      "type": type,
      "prompt": prompt,
      "description": description,
      "agent": agent,
      "model": ?model?.toJson(),
      "command": ?command,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SubtaskPartInput &&
          other.id == id &&
          other.type == type &&
          other.prompt == prompt &&
          other.description == description &&
          other.agent == agent &&
          other.model == model &&
          other.command == command);

  @override
  int get hashCode => Object.hash(id, type, prompt, description, agent, model, command);

  final String? id;
  final String type;
  final String prompt;
  final String description;
  final String agent;
  final SubtaskPartInputModel? model;
  final String? command;
}

@immutable
class SubtaskPartInputModel {
  const SubtaskPartInputModel({
    required this.providerID,
    required this.modelID,
  });

  factory SubtaskPartInputModel.fromJson(Map<String, dynamic> json) {
    return SubtaskPartInputModel(
      providerID: json["providerID"] as String,
      modelID: json["modelID"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "providerID": providerID,
      "modelID": modelID,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SubtaskPartInputModel &&
          other.providerID == providerID &&
          other.modelID == modelID);

  @override
  int get hashCode => Object.hash(providerID, modelID);

  final String providerID;
  final String modelID;
}
