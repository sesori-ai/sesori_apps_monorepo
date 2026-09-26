// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.18 (cd9a14a6b688d4021bee381dfd39d2cef9c0f862)

import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import 'model_ref.g.dart';
import 'session_message_compaction.g.dart';
import 'session_message_provider_state_5.g.dart';
import 'session_provider_context.g.dart';
import 'token_usage_info.g.dart';

@immutable
class SessionMessageCompactionCompleted implements SessionMessageCompaction {
  const SessionMessageCompactionCompleted({
    required this.id,
    required this.metadata,
    required this.time,
    required this.reason,
    required this.model,
    required this.providerState,
    required this.summary,
    required this.recent,
    required this.providerContext,
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
      providerState: json["providerState"] == null ? null : SessionMessageProviderState5.fromJson(json["providerState"] as Map<String, dynamic>),
      summary: json["summary"] as String,
      recent: json["recent"] as String,
      providerContext: json["providerContext"] == null ? null : SessionProviderContext.fromJson(json["providerContext"] as Map<String, dynamic>),
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
      "providerState": ?providerState?.toJson(),
      "summary": summary,
      "recent": recent,
      "providerContext": ?providerContext?.toJson(),
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
    SessionMessageProviderState5? providerState,
    String? summary,
    String? recent,
    SessionProviderContext? providerContext,
    double? cost,
    TokenUsageInfo? tokens,
  }) {
    return SessionMessageCompactionCompleted(
      id: id ?? this.id,
      metadata: metadata ?? this.metadata,
      time: time ?? this.time,
      reason: reason ?? this.reason,
      model: model ?? this.model,
      providerState: providerState ?? this.providerState,
      summary: summary ?? this.summary,
      recent: recent ?? this.recent,
      providerContext: providerContext ?? this.providerContext,
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
          other.providerState == providerState &&
          other.summary == summary &&
          other.recent == recent &&
          other.providerContext == providerContext &&
          other.cost == cost &&
          other.tokens == tokens);

  @override
  int get hashCode => Object.hash(id, const DeepCollectionEquality().hash(metadata), time, reason, model, providerState, summary, recent, providerContext, cost, tokens);

  final String id;
  final Map<String, dynamic>? metadata;
  final SessionMessageCompactionCompletedTime time;
  final SessionMessageCompactionCompletedReason reason;
  final ModelRef? model;
  final SessionMessageProviderState5? providerState;
  final String summary;
  final String recent;
  final SessionProviderContext? providerContext;
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
