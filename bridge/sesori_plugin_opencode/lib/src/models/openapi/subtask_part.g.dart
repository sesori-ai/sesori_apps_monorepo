// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:meta/meta.dart';
import 'part.g.dart';

@immutable
class SubtaskPart implements Part {
  const SubtaskPart({
    this.id = '',
    this.sessionID = '',
    this.messageID = '',
    this.prompt = '',
    this.description = '',
    this.agent = '',
    this.model,
    this.command,
  });

  factory SubtaskPart.fromJson(Map<String, dynamic> json) {
    return SubtaskPart(
      id: (json["id"] ?? '') as String,
      sessionID: (json["sessionID"] ?? '') as String,
      messageID: (json["messageID"] ?? '') as String,
      prompt: (json["prompt"] ?? '') as String,
      description: (json["description"] ?? '') as String,
      agent: (json["agent"] ?? '') as String,
      model: json["model"] == null ? null : SubtaskPartModel.fromJson(json["model"] as Map<String, dynamic>),
      command: json["command"] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "sessionID": sessionID,
      "messageID": messageID,
      "type": "subtask",
      "prompt": prompt,
      "description": description,
      "agent": agent,
      "model": ?model?.toJson(),
      "command": ?command,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SubtaskPart copyWith({
    String? id,
    String? sessionID,
    String? messageID,
    String? prompt,
    String? description,
    String? agent,
    SubtaskPartModel? model,
    String? command,
  }) {
    return SubtaskPart(
      id: id ?? this.id,
      sessionID: sessionID ?? this.sessionID,
      messageID: messageID ?? this.messageID,
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
      (other is SubtaskPart &&
          other.id == id &&
          other.sessionID == sessionID &&
          other.messageID == messageID &&
          other.prompt == prompt &&
          other.description == description &&
          other.agent == agent &&
          other.model == model &&
          other.command == command);

  @override
  int get hashCode => Object.hash(id, sessionID, messageID, prompt, description, agent, model, command);

  final String id;
  final String sessionID;
  final String messageID;
  final String prompt;
  final String description;
  final String agent;
  final SubtaskPartModel? model;
  final String? command;
}

@immutable
class SubtaskPartModel {
  const SubtaskPartModel({
    this.providerID = '',
    this.modelID = '',
  });

  factory SubtaskPartModel.fromJson(Map<String, dynamic> json) {
    return SubtaskPartModel(
      providerID: (json["providerID"] ?? '') as String,
      modelID: (json["modelID"] ?? '') as String,
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
  SubtaskPartModel copyWith({
    String? providerID,
    String? modelID,
  }) {
    return SubtaskPartModel(
      providerID: providerID ?? this.providerID,
      modelID: modelID ?? this.modelID,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SubtaskPartModel &&
          other.providerID == providerID &&
          other.modelID == modelID);

  @override
  int get hashCode => Object.hash(providerID, modelID);

  final String providerID;
  final String modelID;
}
