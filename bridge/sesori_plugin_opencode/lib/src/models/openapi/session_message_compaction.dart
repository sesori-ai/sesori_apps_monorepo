// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-07T10:22:51.677769Z

import 'session_message.dart';

class SessionMessageCompaction implements SessionMessage {
  const SessionMessageCompaction({
    required this.reason,
    required this.summary,
    this.include,
    required this.id,
    this.metadata,
    required this.time,
  });

  factory SessionMessageCompaction.fromJson(Map<String, dynamic> json) {
    return SessionMessageCompaction(
      reason: json["reason"] as String,
      summary: json["summary"] as String,
      include: json["include"] as String?,
      id: json["id"] as String,
      metadata: json["metadata"] as Map<String, dynamic>?,
      time: json["time"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": "compaction",
      "reason": reason,
      "summary": summary,
      "include": include,
      "id": id,
      "metadata": metadata,
      "time": time,
    };
  }

  final String reason;
  final String summary;
  final String? include;
  final String id;
  final Map<String, dynamic>? metadata;
  final Map<String, dynamic> time;
}
