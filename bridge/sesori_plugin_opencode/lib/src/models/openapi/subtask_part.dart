// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T09:42:34.356756Z

import 'part.dart';

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
      model: json["model"] as Map<String, dynamic>?,
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
      "model": ?model,
      "command": ?command,
    };
  }

  final String id;
  final String sessionID;
  final String messageID;
  final String prompt;
  final String description;
  final String agent;
  final Map<String, dynamic>? model;
  final String? command;
}
