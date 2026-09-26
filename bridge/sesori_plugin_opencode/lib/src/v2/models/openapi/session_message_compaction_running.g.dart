// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.16 (3a103fe0aff726a4edc7492f03f7b88195d9e4c9)

import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import 'session_message_compaction.g.dart';

@immutable
class SessionMessageCompactionRunning implements SessionMessageCompaction {
  const SessionMessageCompactionRunning({
    required this.id,
    required this.metadata,
    required this.time,
    required this.reason,
    required this.summary,
    required this.recent,
  });

  factory SessionMessageCompactionRunning.fromJson(Map<String, dynamic> json) {
    return SessionMessageCompactionRunning(
      id: json["id"] as String,
      metadata: json["metadata"] as Map<String, dynamic>?,
      time: SessionMessageCompactionRunningTime.fromJson(json["time"] as Map<String, dynamic>),
      reason: SessionMessageCompactionRunningReason.fromJson(json["reason"] as String),
      summary: json["summary"] as String,
      recent: json["recent"] as String,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": "compaction",
      "id": id,
      "metadata": ?metadata,
      "time": time.toJson(),
      "status": "running",
      "reason": reason.toJson(),
      "summary": summary,
      "recent": recent,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionMessageCompactionRunning copyWith({
    String? id,
    Map<String, dynamic>? metadata,
    SessionMessageCompactionRunningTime? time,
    SessionMessageCompactionRunningReason? reason,
    String? summary,
    String? recent,
  }) {
    return SessionMessageCompactionRunning(
      id: id ?? this.id,
      metadata: metadata ?? this.metadata,
      time: time ?? this.time,
      reason: reason ?? this.reason,
      summary: summary ?? this.summary,
      recent: recent ?? this.recent,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageCompactionRunning &&
          other.id == id &&
          const DeepCollectionEquality().equals(other.metadata, metadata) &&
          other.time == time &&
          other.reason == reason &&
          other.summary == summary &&
          other.recent == recent);

  @override
  int get hashCode => Object.hash(id, const DeepCollectionEquality().hash(metadata), time, reason, summary, recent);

  final String id;
  final Map<String, dynamic>? metadata;
  final SessionMessageCompactionRunningTime time;
  final SessionMessageCompactionRunningReason reason;
  final String summary;
  final String recent;
}

@immutable
class SessionMessageCompactionRunningTime {
  const SessionMessageCompactionRunningTime({
    required this.created,
  });

  factory SessionMessageCompactionRunningTime.fromJson(Map<String, dynamic> json) {
    return SessionMessageCompactionRunningTime(
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
  SessionMessageCompactionRunningTime copyWith({
    double? created,
  }) {
    return SessionMessageCompactionRunningTime(
      created: created ?? this.created,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageCompactionRunningTime &&
          other.created == created);

  @override
  int get hashCode => created.hashCode;

  final double created;
}

enum SessionMessageCompactionRunningReason {
  @JsonValue("auto")
  auto,
  @JsonValue("manual")
  manual,

  /// Fallback for values introduced by newer OpenCode servers.
  /// Encodes back to the literal string `unknown`.
  unknown,
  ;

  static SessionMessageCompactionRunningReason fromJson(String value) {
    switch (value) {
      case "auto":
        return SessionMessageCompactionRunningReason.auto;
      case "manual":
        return SessionMessageCompactionRunningReason.manual;
      default:
        return SessionMessageCompactionRunningReason.unknown;
    }
  }

  String toJson() {
    switch (this) {
      case SessionMessageCompactionRunningReason.auto:
        return "auto";
      case SessionMessageCompactionRunningReason.manual:
        return "manual";
      case SessionMessageCompactionRunningReason.unknown:
        return 'unknown';
    }
  }
}
