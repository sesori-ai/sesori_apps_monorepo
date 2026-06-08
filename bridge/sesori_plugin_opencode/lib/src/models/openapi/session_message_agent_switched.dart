// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T13:43:24.188781Z

import 'session_message.dart';

class SessionMessageAgentSwitched implements SessionMessage {
  const SessionMessageAgentSwitched({
    required this.id,
    this.metadata,
    required this.time,
    required this.agent,
  });

  factory SessionMessageAgentSwitched.fromJson(Map<String, dynamic> json) {
    return SessionMessageAgentSwitched(
      id: json["id"] as String,
      metadata: json["metadata"] as Map<String, dynamic>?,
      time: json["time"] as Map<String, dynamic>,
      agent: json["agent"] as String,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "metadata": ?metadata,
      "time": time,
      "type": "agent-switched",
      "agent": agent,
    };
  }

  final String id;
  final Map<String, dynamic>? metadata;
  final Map<String, dynamic> time;
  final String agent;
}
