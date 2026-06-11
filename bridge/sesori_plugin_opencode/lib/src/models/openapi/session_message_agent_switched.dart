// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'session_message.dart';

@immutable
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
      time: SessionMessageAgentSwitchedTime.fromJson(json["time"] as Map<String, dynamic>),
      agent: json["agent"] as String,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "metadata": ?metadata,
      "time": time.toJson(),
      "type": "agent-switched",
      "agent": agent,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageAgentSwitched &&
          other.id == id &&
          const DeepCollectionEquality().equals(other.metadata, metadata) &&
          other.time == time &&
          other.agent == agent);

  @override
  int get hashCode => Object.hash(id, const DeepCollectionEquality().hash(metadata), time, agent);

  final String id;
  final Map<String, dynamic>? metadata;
  final SessionMessageAgentSwitchedTime time;
  final String agent;
}

@immutable
class SessionMessageAgentSwitchedTime {
  const SessionMessageAgentSwitchedTime({
    required this.created,
  });

  factory SessionMessageAgentSwitchedTime.fromJson(Map<String, dynamic> json) {
    return SessionMessageAgentSwitchedTime(
      created: (json["created"] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "created": created,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageAgentSwitchedTime &&
          other.created == created);

  @override
  int get hashCode => created.hashCode;

  final double created;
}
