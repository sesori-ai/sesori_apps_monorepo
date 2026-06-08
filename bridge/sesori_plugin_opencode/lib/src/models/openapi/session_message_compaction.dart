// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:11:43.960785Z

import 'package:meta/meta.dart';
import 'session_message.dart';

@immutable
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
      "include": ?include,
      "id": id,
      "metadata": ?metadata,
      "time": time,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageCompaction &&
          other.reason == reason &&
          other.summary == summary &&
          other.include == include &&
          other.id == id &&
          other.metadata == metadata &&
          other.time == time);

  @override
  int get hashCode => Object.hash(reason, summary, include, id, metadata, time);

  final String reason;
  final String summary;
  final String? include;
  final String id;
  final Map<String, dynamic>? metadata;
  final Map<String, dynamic> time;
}
