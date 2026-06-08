// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:24:06.198788Z

import 'package:meta/meta.dart';
import 'message.dart';

@immutable
class AssistantMessage implements Message {
  const AssistantMessage({
    required this.id,
    required this.sessionID,
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
      time: json["time"] as Map<String, dynamic>,
      error: json["error"] as Object?,
      parentID: json["parentID"] as String,
      modelID: json["modelID"] as String,
      providerID: json["providerID"] as String,
      mode: json["mode"] as String,
      agent: json["agent"] as String,
      path: json["path"] as Map<String, dynamic>,
      summary: json["summary"] as bool?,
      cost: (json["cost"] as num).toDouble(),
      tokens: json["tokens"] as Map<String, dynamic>,
      structured: json["structured"] as Object?,
      variant: json["variant"] as String?,
      finish: json["finish"] as String?,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "sessionID": sessionID,
      "role": "assistant",
      "time": time,
      "error": ?error,
      "parentID": parentID,
      "modelID": modelID,
      "providerID": providerID,
      "mode": mode,
      "agent": agent,
      "path": path,
      "summary": ?summary,
      "cost": cost,
      "tokens": tokens,
      "structured": ?structured,
      "variant": ?variant,
      "finish": ?finish,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AssistantMessage &&
          other.id == id &&
          other.sessionID == sessionID &&
          other.time == time &&
          other.error == error &&
          other.parentID == parentID &&
          other.modelID == modelID &&
          other.providerID == providerID &&
          other.mode == mode &&
          other.agent == agent &&
          other.path == path &&
          other.summary == summary &&
          other.cost == cost &&
          other.tokens == tokens &&
          other.structured == structured &&
          other.variant == variant &&
          other.finish == finish);

  @override
  int get hashCode => Object.hash(id, sessionID, time, error, parentID, modelID, providerID, mode, agent, path, summary, cost, tokens, structured, variant, finish);

  final String id;
  final String sessionID;
  final Map<String, dynamic> time;
  final Object? error;
  final String parentID;
  final String modelID;
  final String providerID;
  final String mode;
  final String agent;
  final Map<String, dynamic> path;
  final bool? summary;
  final double cost;
  final Map<String, dynamic> tokens;
  final Object? structured;
  final String? variant;
  final String? finish;
}
