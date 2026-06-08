// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:11:43.962581Z

import 'package:meta/meta.dart';
import 'session_message.dart';

@immutable
class SessionMessageSystem implements SessionMessage {
  const SessionMessageSystem({
    required this.id,
    this.metadata,
    required this.time,
    required this.text,
  });

  factory SessionMessageSystem.fromJson(Map<String, dynamic> json) {
    return SessionMessageSystem(
      id: json["id"] as String,
      metadata: json["metadata"] as Map<String, dynamic>?,
      time: json["time"] as Map<String, dynamic>,
      text: json["text"] as String,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "metadata": ?metadata,
      "time": time,
      "type": "system",
      "text": text,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageSystem &&
          other.id == id &&
          other.metadata == metadata &&
          other.time == time &&
          other.text == text);

  @override
  int get hashCode => Object.hash(id, metadata, time, text);

  final String id;
  final Map<String, dynamic>? metadata;
  final Map<String, dynamic> time;
  final String text;
}
