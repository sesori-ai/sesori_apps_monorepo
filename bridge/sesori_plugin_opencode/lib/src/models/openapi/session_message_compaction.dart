// GENERATED FILE - DO NOT EDIT BY HAND

import 'session_message.dart';

class SessionMessageCompaction implements SessionMessage {
  const SessionMessageCompaction({
    required this.type,
    required this.reason,
    required this.summary,
    required this.recent,
    required this.id,
    this.metadata,
    required this.time,
  });

  factory SessionMessageCompaction.fromJson(Map<String, dynamic> json) {
    return SessionMessageCompaction(
      type: json["type"] as String,
      reason: json["reason"] as String,
      summary: json["summary"] as String,
      recent: json["recent"] as String,
      id: json["id"] as String,
      metadata: json["metadata"] as Map<String, dynamic>?,
      time: json["time"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": type,
      "reason": reason,
      "summary": summary,
      "recent": recent,
      "id": id,
      "metadata": metadata,
      "time": time,
    };
  }

  final String type;
  final String reason;
  final String summary;
  final String recent;
  final String id;
  final Map<String, dynamic>? metadata;
  final Map<String, dynamic> time;
}
