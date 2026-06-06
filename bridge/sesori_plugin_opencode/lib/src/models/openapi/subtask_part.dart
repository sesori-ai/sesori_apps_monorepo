// GENERATED FILE - DO NOT EDIT BY HAND

import 'part.dart';

class SubtaskPart implements Part {
  const SubtaskPart({
    required this.id,
    required this.sessionID,
    required this.messageID,
    required this.type,
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
      type: json["type"] as String,
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
      "type": type,
      "prompt": prompt,
      "description": description,
      "agent": agent,
      "model": model,
      "command": command,
    };
  }

  final String id;
  final String sessionID;
  final String messageID;
  final String type;
  final String prompt;
  final String description;
  final String agent;
  final Map<String, dynamic>? model;
  final String? command;
}
