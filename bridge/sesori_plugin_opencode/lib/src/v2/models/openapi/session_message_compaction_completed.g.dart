// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.1.4 (68bc26b7da1990ce10ffecfbc1e09eb13aa5d824)

import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import 'model_ref.g.dart';
import 'session_message_compaction.g.dart';
import 'session_message_native_4.g.dart';
import 'token_usage_info.g.dart';

@immutable
class SessionMessageCompactionCompleted implements SessionMessageCompaction {
  const SessionMessageCompactionCompleted({
    required this.id,
    required this.metadata,
    required this.time,
    required this.reason,
    required this.model,
    required this.native,
    required this.summary,
    required this.cost,
    required this.tokens,
  });

  factory SessionMessageCompactionCompleted.fromJson(Map<String, dynamic> json) {
    return SessionMessageCompactionCompleted(
      id: json["id"] as String,
      metadata: json["metadata"] as Map<String, dynamic>?,
      time: SessionMessageCompactionCompletedTime.fromJson(json["time"] as Map<String, dynamic>),
      reason: SessionMessageCompactionCompletedReason.fromJson(json["reason"] as String),
      model: json["model"] == null ? null : ModelRef.fromJson(json["model"] as Map<String, dynamic>),
      native: json["native"] == null ? null : SessionMessageNative4.fromJson(json["native"] as Map<String, dynamic>),
      summary: json["summary"] as String,
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
      "status": "completed",
      "reason": reason.toJson(),
      "model": ?model?.toJson(),
      "native": ?native?.toJson(),
      "summary": summary,
      "cost": ?cost,
      "tokens": ?tokens?.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionMessageCompactionCompleted copyWith({
    String? id,
    Map<String, dynamic>? metadata,
    SessionMessageCompactionCompletedTime? time,
    SessionMessageCompactionCompletedReason? reason,
    ModelRef? model,
    SessionMessageNative4? native,
    String? summary,
    double? cost,
    TokenUsageInfo? tokens,
  }) {
    return SessionMessageCompactionCompleted(
      id: id ?? this.id,
      metadata: metadata ?? this.metadata,
      time: time ?? this.time,
      reason: reason ?? this.reason,
      model: model ?? this.model,
      native: native ?? this.native,
      summary: summary ?? this.summary,
      cost: cost ?? this.cost,
      tokens: tokens ?? this.tokens,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageCompactionCompleted &&
          other.id == id &&
          const DeepCollectionEquality().equals(other.metadata, metadata) &&
          other.time == time &&
          other.reason == reason &&
          other.model == model &&
          other.native == native &&
          other.summary == summary &&
          other.cost == cost &&
          other.tokens == tokens);

  @override
  int get hashCode => Object.hash(id, const DeepCollectionEquality().hash(metadata), time, reason, model, native, summary, cost, tokens);

  final String id;
  final Map<String, dynamic>? metadata;
  final SessionMessageCompactionCompletedTime time;
  final SessionMessageCompactionCompletedReason reason;
  final ModelRef? model;
  final SessionMessageNative4? native;
  final String summary;
  final double? cost;
  final TokenUsageInfo? tokens;
}

@immutable
class SessionMessageCompactionCompletedTime {
  const SessionMessageCompactionCompletedTime({
    required this.created,
  });

  factory SessionMessageCompactionCompletedTime.fromJson(Map<String, dynamic> json) {
    return SessionMessageCompactionCompletedTime(
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
  SessionMessageCompactionCompletedTime copyWith({
    double? created,
  }) {
    return SessionMessageCompactionCompletedTime(
      created: created ?? this.created,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageCompactionCompletedTime &&
          other.created == created);

  @override
  int get hashCode => created.hashCode;

  final double created;
}

enum SessionMessageCompactionCompletedReason {
  @JsonValue("auto")
  auto,
  @JsonValue("manual")
  manual,

  /// Fallback for values introduced by newer OpenCode servers.
  /// Encodes back to the literal string `unknown`.
  unknown,
  ;

  static SessionMessageCompactionCompletedReason fromJson(String value) {
    switch (value) {
      case "auto":
        return SessionMessageCompactionCompletedReason.auto;
      case "manual":
        return SessionMessageCompactionCompletedReason.manual;
      default:
        return SessionMessageCompactionCompletedReason.unknown;
    }
  }

  String toJson() {
    switch (this) {
      case SessionMessageCompactionCompletedReason.auto:
        return "auto";
      case SessionMessageCompactionCompletedReason.manual:
        return "manual";
      case SessionMessageCompactionCompletedReason.unknown:
        return 'unknown';
    }
  }
}
