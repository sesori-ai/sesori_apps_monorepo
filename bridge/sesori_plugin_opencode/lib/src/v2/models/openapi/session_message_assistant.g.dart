// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.18 (cd9a14a6b688d4021bee381dfd39d2cef9c0f862)

import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import 'model_ref.g.dart';
import 'session_message_assistant_content.g.dart';
import 'session_message_assistant_retry.g.dart';
import 'session_message_info.g.dart';
import 'session_message_provider_state_4.g.dart';
import 'session_structured_error.g.dart';
import 'token_usage_info.g.dart';

@immutable
class SessionMessageAssistant implements SessionMessageInfo {
  const SessionMessageAssistant({
    required this.id,
    required this.metadata,
    required this.time,
    required this.agent,
    required this.model,
    required this.content,
    required this.snapshot,
    required this.finish,
    required this.rawFinish,
    required this.providerState,
    required this.cost,
    required this.tokens,
    required this.error,
    required this.retry,
  });

  factory SessionMessageAssistant.fromJson(Map<String, dynamic> json) {
    return SessionMessageAssistant(
      id: json["id"] as String,
      metadata: json["metadata"] as Map<String, dynamic>?,
      time: SessionMessageAssistantTime.fromJson(json["time"] as Map<String, dynamic>),
      agent: json["agent"] as String,
      model: ModelRef.fromJson(json["model"] as Map<String, dynamic>),
      content: (json["content"] as List<dynamic>).map((e) => SessionMessageAssistantContent.fromJson(e as Map<String, dynamic>)).toList(),
      snapshot: json["snapshot"] == null ? null : SessionMessageAssistantSnapshot.fromJson(json["snapshot"] as Map<String, dynamic>),
      finish: json["finish"] == null ? null : SessionMessageAssistantFinish.fromJson(json["finish"] as String),
      rawFinish: json["rawFinish"] as String?,
      providerState: json["providerState"] == null ? null : SessionMessageProviderState4.fromJson(json["providerState"] as Map<String, dynamic>),
      cost: (json["cost"] as num?)?.toDouble(),
      tokens: json["tokens"] == null ? null : TokenUsageInfo.fromJson(json["tokens"] as Map<String, dynamic>),
      error: json["error"] == null ? null : SessionStructuredError.fromJson(json["error"] as Map<String, dynamic>),
      retry: json["retry"] == null ? null : SessionMessageAssistantRetry.fromJson(json["retry"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "metadata": ?metadata,
      "time": time.toJson(),
      "type": "assistant",
      "agent": agent,
      "model": model.toJson(),
      "content": content.map((e) => e.toJson()).toList(),
      "snapshot": ?snapshot?.toJson(),
      "finish": ?finish?.toJson(),
      "rawFinish": ?rawFinish,
      "providerState": ?providerState?.toJson(),
      "cost": ?cost,
      "tokens": ?tokens?.toJson(),
      "error": ?error?.toJson(),
      "retry": ?retry?.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionMessageAssistant copyWith({
    String? id,
    Map<String, dynamic>? metadata,
    SessionMessageAssistantTime? time,
    String? agent,
    ModelRef? model,
    List<SessionMessageAssistantContent>? content,
    SessionMessageAssistantSnapshot? snapshot,
    SessionMessageAssistantFinish? finish,
    String? rawFinish,
    SessionMessageProviderState4? providerState,
    double? cost,
    TokenUsageInfo? tokens,
    SessionStructuredError? error,
    SessionMessageAssistantRetry? retry,
  }) {
    return SessionMessageAssistant(
      id: id ?? this.id,
      metadata: metadata ?? this.metadata,
      time: time ?? this.time,
      agent: agent ?? this.agent,
      model: model ?? this.model,
      content: content ?? this.content,
      snapshot: snapshot ?? this.snapshot,
      finish: finish ?? this.finish,
      rawFinish: rawFinish ?? this.rawFinish,
      providerState: providerState ?? this.providerState,
      cost: cost ?? this.cost,
      tokens: tokens ?? this.tokens,
      error: error ?? this.error,
      retry: retry ?? this.retry,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageAssistant &&
          other.id == id &&
          const DeepCollectionEquality().equals(other.metadata, metadata) &&
          other.time == time &&
          other.agent == agent &&
          other.model == model &&
          const DeepCollectionEquality().equals(other.content, content) &&
          other.snapshot == snapshot &&
          other.finish == finish &&
          other.rawFinish == rawFinish &&
          other.providerState == providerState &&
          other.cost == cost &&
          other.tokens == tokens &&
          other.error == error &&
          other.retry == retry);

  @override
  int get hashCode => Object.hash(id, const DeepCollectionEquality().hash(metadata), time, agent, model, const DeepCollectionEquality().hash(content), snapshot, finish, rawFinish, providerState, cost, tokens, error, retry);

  final String id;
  final Map<String, dynamic>? metadata;
  final SessionMessageAssistantTime time;
  final String agent;
  final ModelRef model;
  final List<SessionMessageAssistantContent> content;
  final SessionMessageAssistantSnapshot? snapshot;
  final SessionMessageAssistantFinish? finish;
  final String? rawFinish;
  final SessionMessageProviderState4? providerState;
  final double? cost;
  final TokenUsageInfo? tokens;
  final SessionStructuredError? error;
  final SessionMessageAssistantRetry? retry;
}

@immutable
class SessionMessageAssistantTime {
  const SessionMessageAssistantTime({
    required this.created,
    required this.streamed,
    required this.completed,
  });

  factory SessionMessageAssistantTime.fromJson(Map<String, dynamic> json) {
    return SessionMessageAssistantTime(
      created: (json["created"] as num).toDouble(),
      streamed: (json["streamed"] as num?)?.toDouble(),
      completed: (json["completed"] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "created": created,
      "streamed": ?streamed,
      "completed": ?completed,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionMessageAssistantTime copyWith({
    double? created,
    double? streamed,
    double? completed,
  }) {
    return SessionMessageAssistantTime(
      created: created ?? this.created,
      streamed: streamed ?? this.streamed,
      completed: completed ?? this.completed,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageAssistantTime &&
          other.created == created &&
          other.streamed == streamed &&
          other.completed == completed);

  @override
  int get hashCode => Object.hash(created, streamed, completed);

  final double created;
  final double? streamed;
  final double? completed;
}

@immutable
class SessionMessageAssistantSnapshot {
  const SessionMessageAssistantSnapshot({
    required this.start,
    required this.end,
    required this.files,
  });

  factory SessionMessageAssistantSnapshot.fromJson(Map<String, dynamic> json) {
    return SessionMessageAssistantSnapshot(
      start: json["start"] as String?,
      end: json["end"] as String?,
      files: (json["files"] as List<dynamic>?)?.cast<String>(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "start": ?start,
      "end": ?end,
      "files": ?files,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionMessageAssistantSnapshot copyWith({
    String? start,
    String? end,
    List<String>? files,
  }) {
    return SessionMessageAssistantSnapshot(
      start: start ?? this.start,
      end: end ?? this.end,
      files: files ?? this.files,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageAssistantSnapshot &&
          other.start == start &&
          other.end == end &&
          const DeepCollectionEquality().equals(other.files, files));

  @override
  int get hashCode => Object.hash(start, end, const DeepCollectionEquality().hash(files));

  final String? start;
  final String? end;
  final List<String>? files;
}

enum SessionMessageAssistantFinish {
  @JsonValue("stop")
  stop,
  @JsonValue("length")
  length,
  @JsonValue("tool-calls")
  toolCalls,
  @JsonValue("content-filter")
  contentFilter,
  @JsonValue("error")
  error,
  @JsonValue("unknown")
  unknown,
  ;

  static SessionMessageAssistantFinish fromJson(String value) {
    switch (value) {
      case "stop":
        return SessionMessageAssistantFinish.stop;
      case "length":
        return SessionMessageAssistantFinish.length;
      case "tool-calls":
        return SessionMessageAssistantFinish.toolCalls;
      case "content-filter":
        return SessionMessageAssistantFinish.contentFilter;
      case "error":
        return SessionMessageAssistantFinish.error;
      case "unknown":
        return SessionMessageAssistantFinish.unknown;
      default:
        return SessionMessageAssistantFinish.unknown;
    }
  }

  String toJson() {
    switch (this) {
      case SessionMessageAssistantFinish.stop:
        return "stop";
      case SessionMessageAssistantFinish.length:
        return "length";
      case SessionMessageAssistantFinish.toolCalls:
        return "tool-calls";
      case SessionMessageAssistantFinish.contentFilter:
        return "content-filter";
      case SessionMessageAssistantFinish.error:
        return "error";
      case SessionMessageAssistantFinish.unknown:
        return "unknown";
    }
  }
}
