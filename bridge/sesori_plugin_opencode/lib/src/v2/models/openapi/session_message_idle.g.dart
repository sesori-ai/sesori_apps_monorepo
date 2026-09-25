// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.16 (3a103fe0aff726a4edc7492f03f7b88195d9e4c9)

import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import 'session_message_info.g.dart';

@immutable
class SessionMessageIdle implements SessionMessageInfo {
  const SessionMessageIdle({
    required this.id,
    required this.metadata,
    required this.time,
    required this.outcome,
  });

  factory SessionMessageIdle.fromJson(Map<String, dynamic> json) {
    return SessionMessageIdle(
      id: json["id"] as String,
      metadata: json["metadata"] as Map<String, dynamic>?,
      time: SessionMessageIdleTime.fromJson(json["time"] as Map<String, dynamic>),
      outcome: SessionMessageIdleOutcome.fromJson(json["outcome"] as String),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "metadata": ?metadata,
      "time": time.toJson(),
      "type": "idle",
      "outcome": outcome.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionMessageIdle copyWith({
    String? id,
    Map<String, dynamic>? metadata,
    SessionMessageIdleTime? time,
    SessionMessageIdleOutcome? outcome,
  }) {
    return SessionMessageIdle(
      id: id ?? this.id,
      metadata: metadata ?? this.metadata,
      time: time ?? this.time,
      outcome: outcome ?? this.outcome,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageIdle &&
          other.id == id &&
          const DeepCollectionEquality().equals(other.metadata, metadata) &&
          other.time == time &&
          other.outcome == outcome);

  @override
  int get hashCode => Object.hash(id, const DeepCollectionEquality().hash(metadata), time, outcome);

  final String id;
  final Map<String, dynamic>? metadata;
  final SessionMessageIdleTime time;
  final SessionMessageIdleOutcome outcome;
}

@immutable
class SessionMessageIdleTime {
  const SessionMessageIdleTime({
    required this.created,
  });

  factory SessionMessageIdleTime.fromJson(Map<String, dynamic> json) {
    return SessionMessageIdleTime(
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
  SessionMessageIdleTime copyWith({
    double? created,
  }) {
    return SessionMessageIdleTime(
      created: created ?? this.created,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageIdleTime &&
          other.created == created);

  @override
  int get hashCode => created.hashCode;

  final double created;
}

enum SessionMessageIdleOutcome {
  @JsonValue("succeeded")
  succeeded,
  @JsonValue("failed")
  failed,
  @JsonValue("interrupted")
  interrupted,

  /// Fallback for values introduced by newer OpenCode servers.
  /// Encodes back to the literal string `unknown`.
  unknown,
  ;

  static SessionMessageIdleOutcome fromJson(String value) {
    switch (value) {
      case "succeeded":
        return SessionMessageIdleOutcome.succeeded;
      case "failed":
        return SessionMessageIdleOutcome.failed;
      case "interrupted":
        return SessionMessageIdleOutcome.interrupted;
      default:
        return SessionMessageIdleOutcome.unknown;
    }
  }

  String toJson() {
    switch (this) {
      case SessionMessageIdleOutcome.succeeded:
        return "succeeded";
      case SessionMessageIdleOutcome.failed:
        return "failed";
      case SessionMessageIdleOutcome.interrupted:
        return "interrupted";
      case SessionMessageIdleOutcome.unknown:
        return 'unknown';
    }
  }
}
