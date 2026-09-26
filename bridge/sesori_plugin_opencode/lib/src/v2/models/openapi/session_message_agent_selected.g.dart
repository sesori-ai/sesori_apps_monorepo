// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.18 (cd9a14a6b688d4021bee381dfd39d2cef9c0f862)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'session_message_info.g.dart';

@immutable
class SessionMessageAgentSelected implements SessionMessageInfo {
  const SessionMessageAgentSelected({
    required this.id,
    required this.metadata,
    required this.time,
    required this.agent,
    required this.previous,
  });

  factory SessionMessageAgentSelected.fromJson(Map<String, dynamic> json) {
    return SessionMessageAgentSelected(
      id: json["id"] as String,
      metadata: json["metadata"] as Map<String, dynamic>?,
      time: SessionMessageAgentSelectedTime.fromJson(json["time"] as Map<String, dynamic>),
      agent: json["agent"] as String,
      previous: json["previous"] as String?,
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
      "previous": ?previous,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionMessageAgentSelected copyWith({
    String? id,
    Map<String, dynamic>? metadata,
    SessionMessageAgentSelectedTime? time,
    String? agent,
    String? previous,
  }) {
    return SessionMessageAgentSelected(
      id: id ?? this.id,
      metadata: metadata ?? this.metadata,
      time: time ?? this.time,
      agent: agent ?? this.agent,
      previous: previous ?? this.previous,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageAgentSelected &&
          other.id == id &&
          const DeepCollectionEquality().equals(other.metadata, metadata) &&
          other.time == time &&
          other.agent == agent &&
          other.previous == previous);

  @override
  int get hashCode => Object.hash(id, const DeepCollectionEquality().hash(metadata), time, agent, previous);

  final String id;
  final Map<String, dynamic>? metadata;
  final SessionMessageAgentSelectedTime time;
  final String agent;
  final String? previous;
}

@immutable
class SessionMessageAgentSelectedTime {
  const SessionMessageAgentSelectedTime({
    required this.created,
  });

  factory SessionMessageAgentSelectedTime.fromJson(Map<String, dynamic> json) {
    return SessionMessageAgentSelectedTime(
      created: (json["created"] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "created": created,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionMessageAgentSelectedTime copyWith({
    double? created,
  }) {
    return SessionMessageAgentSelectedTime(
      created: created ?? this.created,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageAgentSelectedTime &&
          other.created == created);

  @override
  int get hashCode => created.hashCode;

  final double created;
}
