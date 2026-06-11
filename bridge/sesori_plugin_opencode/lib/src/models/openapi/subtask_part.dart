// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'part.dart';

@immutable
class SubtaskPart implements Part {
  const SubtaskPart({
    required this.id,
    required this.sessionID,
    required this.messageID,
    required this.prompt,
    required this.description,
    required this.agent,
    this.model,
    this.command,
  });

  factory SubtaskPart.fromJson(Map<String, dynamic> json) {
    return SubtaskPart(
      id: json["id"] as String,
      sessionID: json["sessionID"] as String,
      messageID: json["messageID"] as String,
      prompt: json["prompt"] as String,
      description: json["description"] as String,
      agent: json["agent"] as String,
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
    required this.providerID,
    required this.modelID,
  });

  factory SubtaskPartModel.fromJson(Map<String, dynamic> json) {
    return SubtaskPartModel(
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
      (other is SubtaskPartModel &&
          other.providerID == providerID &&
          other.modelID == modelID);

  @override
  int get hashCode => Object.hash(providerID, modelID);

  final String providerID;
  final String modelID;
}
