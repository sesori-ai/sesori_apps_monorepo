// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T07:51:40.013771Z

import 'message.dart';
import 'output_format.dart';

class UserMessage implements Message {
  const UserMessage({
    required this.id,
    required this.sessionID,
    required this.time,
    this.format,
    this.summary,
    required this.agent,
    required this.model,
    this.system,
    this.tools,
  });

  factory UserMessage.fromJson(Map<String, dynamic> json) {
    return UserMessage(
      id: json["id"] as String,
      sessionID: json["sessionID"] as String,
      time: json["time"] as Map<String, dynamic>,
      format: json["format"] == null ? null : OutputFormat.fromJson(json["format"]),
      summary: json["summary"] as Map<String, dynamic>?,
      agent: json["agent"] as String,
      model: json["model"] as Map<String, dynamic>,
      system: json["system"] as String?,
      tools: (json["tools"] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as bool)),
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "sessionID": sessionID,
      "role": "user",
      "time": time,
      "format": ?format?.toJson(),
      "summary": ?summary,
      "agent": agent,
      "model": model,
      "system": ?system,
      "tools": ?tools,
    };
  }

  final String id;
  final String sessionID;
  final Map<String, dynamic> time;
  final OutputFormat? format;
  final Map<String, dynamic>? summary;
  final String agent;
  final Map<String, dynamic> model;
  final String? system;
  final Map<String, bool>? tools;
}
