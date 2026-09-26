// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.18 (cd9a14a6b688d4021bee381dfd39d2cef9c0f862)

import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import 'session_message_compaction.g.dart';
import 'session_structured_error.g.dart';
import 'token_usage_info.g.dart';

@immutable
class SessionMessageCompactionFailed implements SessionMessageCompaction {
  const SessionMessageCompactionFailed({
    required this.id,
    required this.metadata,
    required this.time,
    required this.reason,
    required this.error,
    required this.cost,
    required this.tokens,
  });

  factory SessionMessageCompactionFailed.fromJson(Map<String, dynamic> json) {
    return SessionMessageCompactionFailed(
      id: json["id"] as String,
      metadata: json["metadata"] as Map<String, dynamic>?,
      time: SessionMessageCompactionFailedTime.fromJson(json["time"] as Map<String, dynamic>),
      reason: SessionMessageCompactionFailedReason.fromJson(json["reason"] as String),
      error: SessionStructuredError.fromJson(json["error"] as Map<String, dynamic>),
      cost: (json["cost"] as num?)?.toDouble(),
      tokens: json["tokens"] == null ? null : TokenUsageInfo.fromJson(json["tokens"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": "compaction",
      "id": id,
      "metadata": ?metadata,
      "time": time.toJson(),
      "status": "failed",
      "reason": reason.toJson(),
      "error": error.toJson(),
      "cost": ?cost,
      "tokens": ?tokens?.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionMessageCompactionFailed copyWith({
    String? id,
    Map<String, dynamic>? metadata,
    SessionMessageCompactionFailedTime? time,
    SessionMessageCompactionFailedReason? reason,
    SessionStructuredError? error,
    double? cost,
    TokenUsageInfo? tokens,
  }) {
    return SessionMessageCompactionFailed(
      id: id ?? this.id,
      metadata: metadata ?? this.metadata,
      time: time ?? this.time,
      reason: reason ?? this.reason,
      error: error ?? this.error,
      cost: cost ?? this.cost,
      tokens: tokens ?? this.tokens,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageCompactionFailed &&
          other.id == id &&
          const DeepCollectionEquality().equals(other.metadata, metadata) &&
          other.time == time &&
          other.reason == reason &&
          other.error == error &&
          other.cost == cost &&
          other.tokens == tokens);

  @override
  int get hashCode => Object.hash(id, const DeepCollectionEquality().hash(metadata), time, reason, error, cost, tokens);

  final String id;
  final Map<String, dynamic>? metadata;
  final SessionMessageCompactionFailedTime time;
  final SessionMessageCompactionFailedReason reason;
  final SessionStructuredError error;
  final double? cost;
  final TokenUsageInfo? tokens;
}

@immutable
class SessionMessageCompactionFailedTime {
  const SessionMessageCompactionFailedTime({
    required this.created,
  });

  factory SessionMessageCompactionFailedTime.fromJson(Map<String, dynamic> json) {
    return SessionMessageCompactionFailedTime(
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
  SessionMessageCompactionFailedTime copyWith({
    double? created,
  }) {
    return SessionMessageCompactionFailedTime(
      created: created ?? this.created,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageCompactionFailedTime &&
          other.created == created);

  @override
  int get hashCode => created.hashCode;

  final double created;
}

enum SessionMessageCompactionFailedReason {
  @JsonValue("auto")
  auto,
  @JsonValue("manual")
  manual,

  /// Fallback for values introduced by newer OpenCode servers.
  /// Encodes back to the literal string `unknown`.
  unknown,
  ;

  static SessionMessageCompactionFailedReason fromJson(String value) {
    switch (value) {
      case "auto":
        return SessionMessageCompactionFailedReason.auto;
      case "manual":
        return SessionMessageCompactionFailedReason.manual;
      default:
        return SessionMessageCompactionFailedReason.unknown;
    }
  }

  String toJson() {
    switch (this) {
      case SessionMessageCompactionFailedReason.auto:
        return "auto";
      case SessionMessageCompactionFailedReason.manual:
        return "manual";
      case SessionMessageCompactionFailedReason.unknown:
        return 'unknown';
    }
  }
}
