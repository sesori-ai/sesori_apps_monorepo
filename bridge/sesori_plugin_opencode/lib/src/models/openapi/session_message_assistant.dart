// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'session_error_unknown.dart';
import 'session_message.dart';

@immutable
class SessionMessageAssistant implements SessionMessage {
  const SessionMessageAssistant({
    required this.id,
    this.metadata,
    required this.time,
    required this.agent,
    required this.model,
    required this.content,
    this.snapshot,
    this.finish,
    this.cost,
    this.tokens,
    this.error,
  });

  factory SessionMessageAssistant.fromJson(Map<String, dynamic> json) {
    return SessionMessageAssistant(
      id: json["id"] as String,
      metadata: json["metadata"] as Map<String, dynamic>?,
      time: SessionMessageAssistantTime.fromJson(json["time"] as Map<String, dynamic>),
      agent: json["agent"] as String,
      model: SessionMessageAssistantModel.fromJson(json["model"] as Map<String, dynamic>),
      content: (json["content"] as List<dynamic>).cast<Object>(),
      snapshot: json["snapshot"] == null ? null : SessionMessageAssistantSnapshot.fromJson(json["snapshot"] as Map<String, dynamic>),
      finish: json["finish"] as String?,
      cost: (json["cost"] as num?)?.toDouble(),
      tokens: json["tokens"] == null ? null : SessionMessageAssistantTokens.fromJson(json["tokens"] as Map<String, dynamic>),
      error: json["error"] == null ? null : SessionErrorUnknown.fromJson(json["error"] as Map<String, dynamic>),
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
      "content": content,
      "snapshot": ?snapshot?.toJson(),
      "finish": ?finish,
      "cost": ?cost,
      "tokens": ?tokens?.toJson(),
      "error": ?error?.toJson(),
    };
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
          other.cost == cost &&
          other.tokens == tokens &&
          other.error == error);

  @override
  int get hashCode => Object.hash(id, const DeepCollectionEquality().hash(metadata), time, agent, model, const DeepCollectionEquality().hash(content), snapshot, finish, cost, tokens, error);

  final String id;
  final Map<String, dynamic>? metadata;
  final SessionMessageAssistantTime time;
  final String agent;
  final SessionMessageAssistantModel model;
  final List<Object> content;
  final SessionMessageAssistantSnapshot? snapshot;
  final String? finish;
  final double? cost;
  final SessionMessageAssistantTokens? tokens;
  final SessionErrorUnknown? error;
}

@immutable
class SessionMessageAssistantTime {
  const SessionMessageAssistantTime({
    required this.created,
    this.completed,
  });

  factory SessionMessageAssistantTime.fromJson(Map<String, dynamic> json) {
    return SessionMessageAssistantTime(
      created: (json["created"] as num).toDouble(),
      completed: (json["completed"] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "created": created,
      "completed": ?completed,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageAssistantTime &&
          other.created == created &&
          other.completed == completed);

  @override
  int get hashCode => Object.hash(created, completed);

  final double created;
  final double? completed;
}

@immutable
class SessionMessageAssistantModel {
  const SessionMessageAssistantModel({
    required this.id,
    required this.providerID,
    this.variant,
  });

  factory SessionMessageAssistantModel.fromJson(Map<String, dynamic> json) {
    return SessionMessageAssistantModel(
      id: json["id"] as String,
      providerID: json["providerID"] as String,
      variant: json["variant"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "providerID": providerID,
      "variant": ?variant,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageAssistantModel &&
          other.id == id &&
          other.providerID == providerID &&
          other.variant == variant);

  @override
  int get hashCode => Object.hash(id, providerID, variant);

  final String id;
  final String providerID;
  final String? variant;
}

@immutable
class SessionMessageAssistantSnapshot {
  const SessionMessageAssistantSnapshot({
    this.start,
    this.end,
  });

  factory SessionMessageAssistantSnapshot.fromJson(Map<String, dynamic> json) {
    return SessionMessageAssistantSnapshot(
      start: json["start"] as String?,
      end: json["end"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "start": ?start,
      "end": ?end,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageAssistantSnapshot &&
          other.start == start &&
          other.end == end);

  @override
  int get hashCode => Object.hash(start, end);

  final String? start;
  final String? end;
}

@immutable
class SessionMessageAssistantTokens {
  const SessionMessageAssistantTokens({
    required this.input,
    required this.output,
    required this.reasoning,
    required this.cache,
  });

  factory SessionMessageAssistantTokens.fromJson(Map<String, dynamic> json) {
    return SessionMessageAssistantTokens(
      input: (json["input"] as num).toDouble(),
      output: (json["output"] as num).toDouble(),
      reasoning: (json["reasoning"] as num).toDouble(),
      cache: SessionMessageAssistantTokensCache.fromJson(json["cache"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "input": input,
      "output": output,
      "reasoning": reasoning,
      "cache": cache.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageAssistantTokens &&
          other.input == input &&
          other.output == output &&
          other.reasoning == reasoning &&
          other.cache == cache);

  @override
  int get hashCode => Object.hash(input, output, reasoning, cache);

  final double input;
  final double output;
  final double reasoning;
  final SessionMessageAssistantTokensCache cache;
}

@immutable
class SessionMessageAssistantTokensCache {
  const SessionMessageAssistantTokensCache({
    required this.read,
    required this.write,
  });

  factory SessionMessageAssistantTokensCache.fromJson(Map<String, dynamic> json) {
    return SessionMessageAssistantTokensCache(
      read: (json["read"] as num).toDouble(),
      write: (json["write"] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "read": read,
      "write": write,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageAssistantTokensCache &&
          other.read == read &&
          other.write == write);

  @override
  int get hashCode => Object.hash(read, write);

  final double read;
  final double write;
}
