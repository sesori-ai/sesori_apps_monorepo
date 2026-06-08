// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:11:43.961246Z

import 'package:meta/meta.dart';
import 'session_message.dart';

@immutable
class SessionMessageModelSwitched implements SessionMessage {
  const SessionMessageModelSwitched({
    required this.id,
    this.metadata,
    required this.time,
    required this.model,
  });

  factory SessionMessageModelSwitched.fromJson(Map<String, dynamic> json) {
    return SessionMessageModelSwitched(
      id: json["id"] as String,
      metadata: json["metadata"] as Map<String, dynamic>?,
      time: json["time"] as Map<String, dynamic>,
      model: json["model"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "metadata": ?metadata,
      "time": time,
      "type": "model-switched",
      "model": model,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageModelSwitched &&
          other.id == id &&
          other.metadata == metadata &&
          other.time == time &&
          other.model == model);

  @override
  int get hashCode => Object.hash(id, metadata, time, model);

  final String id;
  final Map<String, dynamic>? metadata;
  final Map<String, dynamic> time;
  final Map<String, dynamic> model;
}
