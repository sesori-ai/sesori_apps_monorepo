// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:meta/meta.dart';

@immutable
class SubtaskPartInput {
  const SubtaskPartInput({
    required this.id,
    required this.type,
    required this.prompt,
    required this.description,
    required this.agent,
    required this.model,
    required this.command,
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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SubtaskPartInput copyWith({
    String? id,
    String? type,
    String? prompt,
    String? description,
    String? agent,
    SubtaskPartInputModel? model,
    String? command,
  }) {
    return SubtaskPartInput(
      id: id ?? this.id,
      type: type ?? this.type,
      prompt: prompt ?? this.prompt,
      description: description ?? this.description,
      agent: agent ?? this.agent,
      model: model ?? this.model,
      command: command ?? this.command,
    );
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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SubtaskPartInputModel copyWith({
    String? providerID,
    String? modelID,
  }) {
    return SubtaskPartInputModel(
      providerID: providerID ?? this.providerID,
      modelID: modelID ?? this.modelID,
    );
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
