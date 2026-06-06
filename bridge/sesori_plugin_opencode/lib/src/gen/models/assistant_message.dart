// GENERATED FILE - DO NOT EDIT BY HAND

import 'message.dart';

class AssistantMessage implements Message {
  const AssistantMessage({
    required this.id,
    required this.sessionID,
    required this.role,
    required this.time,
    this.error,
    required this.parentID,
    required this.modelID,
    required this.providerID,
    required this.mode,
    required this.agent,
    required this.path,
    this.summary,
    required this.cost,
    required this.tokens,
    this.structured,
    this.variant,
    this.finish,
  });

  factory AssistantMessage.fromJson(Map<String, dynamic> json) {
    return AssistantMessage(
      id: json["id"] as String,
      sessionID: json["sessionID"] as String,
      role: json["role"] as String,
      time: json["time"] as Map<String, dynamic>,
      error: json["error"],
      parentID: json["parentID"] as String,
      modelID: json["modelID"] as String,
      providerID: json["providerID"] as String,
      mode: json["mode"] as String,
      agent: json["agent"] as String,
      path: json["path"] as Map<String, dynamic>,
      summary: json["summary"] as bool?,
      cost: json["cost"] as double,
      tokens: json["tokens"] as Map<String, dynamic>,
      structured: json["structured"],
      variant: json["variant"] as String?,
      finish: json["finish"] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "sessionID": sessionID,
      "role": role,
      "time": time,
      "error": error,
      "parentID": parentID,
      "modelID": modelID,
      "providerID": providerID,
      "mode": mode,
      "agent": agent,
      "path": path,
      "summary": summary,
      "cost": cost,
      "tokens": tokens,
      "structured": structured,
      "variant": variant,
      "finish": finish,
    };
  }

  final String id;
  final String sessionID;
  final String role;
  final Map<String, dynamic> time;
  final dynamic error;
  final String parentID;
  final String modelID;
  final String providerID;
  final String mode;
  final String agent;
  final Map<String, dynamic> path;
  final bool? summary;
  final double cost;
  final Map<String, dynamic> tokens;
  final dynamic structured;
  final String? variant;
  final String? finish;
}
