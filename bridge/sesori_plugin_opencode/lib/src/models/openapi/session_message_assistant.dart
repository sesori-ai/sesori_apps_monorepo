// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-07T10:22:51.676738Z

import 'session_error_unknown.dart';
import 'session_message.dart';

class SessionMessageAssistant implements SessionMessage {
  const SessionMessageAssistant({
    required this.id,
    this.metadata,
    required this.time,
    required this.agent,
    required this.model,
    required this.content,
    this.snapshot,
    this.finish,
    this.cost,
    this.tokens,
    this.error,
  });

  factory SessionMessageAssistant.fromJson(Map<String, dynamic> json) {
    return SessionMessageAssistant(
      id: json["id"] as String,
      metadata: json["metadata"] as Map<String, dynamic>?,
      time: json["time"] as Map<String, dynamic>,
      agent: json["agent"] as String,
      model: json["model"] as Map<String, dynamic>,
      content: (json["content"] as List<dynamic>).cast<dynamic>(),
      snapshot: json["snapshot"] as Map<String, dynamic>?,
      finish: json["finish"] as String?,
      cost: (json["cost"] as num?)?.toDouble(),
      tokens: json["tokens"] as Map<String, dynamic>?,
      error: json["error"] == null ? null : SessionErrorUnknown.fromJson(json["error"] as Map<String, dynamic>),
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "metadata": metadata,
      "time": time,
      "type": "assistant",
      "agent": agent,
      "model": model,
      "content": content,
      "snapshot": snapshot,
      "finish": finish,
      "cost": cost,
      "tokens": tokens,
      "error": error?.toJson(),
    };
  }

  final String id;
  final Map<String, dynamic>? metadata;
  final Map<String, dynamic> time;
  final String agent;
  final Map<String, dynamic> model;
  final List<dynamic> content;
  final Map<String, dynamic>? snapshot;
  final String? finish;
  final double? cost;
  final Map<String, dynamic>? tokens;
  final SessionErrorUnknown? error;
}
