// GENERATED FILE - DO NOT EDIT BY HAND

import 'message.dart';
import 'output_format.dart';

class UserMessage implements Message {
  const UserMessage({
    required this.id,
    required this.sessionID,
    required this.role,
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
      role: json["role"] as String,
      time: json["time"] as Map<String, dynamic>,
      format: json["format"] == null ? null : OutputFormat.fromJson(json["format"] as Map<String, dynamic>),
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
      "role": role,
      "time": time,
      "format": format?.toJson(),
      "summary": summary,
      "agent": agent,
      "model": model,
      "system": system,
      "tools": tools,
    };
  }

  final String id;
  final String sessionID;
  final String role;
  final Map<String, dynamic> time;
  final OutputFormat? format;
  final Map<String, dynamic>? summary;
  final String agent;
  final Map<String, dynamic> model;
  final String? system;
  final Map<String, bool>? tools;
}
