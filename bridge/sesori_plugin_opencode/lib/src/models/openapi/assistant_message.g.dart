// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.7 (4ed4f749e644ffb5b279fb30b7b915e743d80142)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'message.g.dart';

@immutable
class AssistantMessage implements Message {
  const AssistantMessage({
    required this.id,
    required this.sessionID,
    required this.time,
    required this.error,
    required this.parentID,
    required this.modelID,
    required this.providerID,
    required this.mode,
    required this.agent,
    required this.path,
    required this.summary,
    required this.cost,
    required this.tokens,
    required this.structured,
    required this.variant,
    required this.finish,
  });

  factory AssistantMessage.fromJson(Map<String, dynamic> json) {
    return AssistantMessage(
      id: json["id"] as String,
      sessionID: json["sessionID"] as String,
      time: AssistantMessageTime.fromJson(json["time"] as Map<String, dynamic>),
      error: json["error"] as Object?,
      parentID: json["parentID"] as String,
      modelID: json["modelID"] as String,
      providerID: json["providerID"] as String,
      mode: json["mode"] as String,
      agent: json["agent"] as String,
      path: AssistantMessagePath.fromJson(json["path"] as Map<String, dynamic>),
      summary: json["summary"] as bool?,
      cost: (json["cost"] as num).toDouble(),
      tokens: AssistantMessageTokens.fromJson(json["tokens"] as Map<String, dynamic>),
      structured: json["structured"] as Object?,
      variant: json["variant"] as String?,
      finish: json["finish"] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "sessionID": sessionID,
      "role": "assistant",
      "time": time.toJson(),
      "error": ?error,
      "parentID": parentID,
      "modelID": modelID,
      "providerID": providerID,
      "mode": mode,
      "agent": agent,
      "path": path.toJson(),
      "summary": ?summary,
      "cost": cost,
      "tokens": tokens.toJson(),
      "structured": ?structured,
      "variant": ?variant,
      "finish": ?finish,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  AssistantMessage copyWith({
    String? id,
    String? sessionID,
    AssistantMessageTime? time,
    Object? error,
    String? parentID,
    String? modelID,
    String? providerID,
    String? mode,
    String? agent,
    AssistantMessagePath? path,
    bool? summary,
    double? cost,
    AssistantMessageTokens? tokens,
    Object? structured,
    String? variant,
    String? finish,
  }) {
    return AssistantMessage(
      id: id ?? this.id,
      sessionID: sessionID ?? this.sessionID,
      time: time ?? this.time,
      error: error ?? this.error,
      parentID: parentID ?? this.parentID,
      modelID: modelID ?? this.modelID,
      providerID: providerID ?? this.providerID,
      mode: mode ?? this.mode,
      agent: agent ?? this.agent,
      path: path ?? this.path,
      summary: summary ?? this.summary,
      cost: cost ?? this.cost,
      tokens: tokens ?? this.tokens,
      structured: structured ?? this.structured,
      variant: variant ?? this.variant,
      finish: finish ?? this.finish,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AssistantMessage &&
          other.id == id &&
          other.sessionID == sessionID &&
          other.time == time &&
          const DeepCollectionEquality().equals(other.error, error) &&
          other.parentID == parentID &&
          other.modelID == modelID &&
          other.providerID == providerID &&
          other.mode == mode &&
          other.agent == agent &&
          other.path == path &&
          other.summary == summary &&
          other.cost == cost &&
          other.tokens == tokens &&
          const DeepCollectionEquality().equals(other.structured, structured) &&
          other.variant == variant &&
          other.finish == finish);

  @override
  int get hashCode => Object.hash(id, sessionID, time, const DeepCollectionEquality().hash(error), parentID, modelID, providerID, mode, agent, path, summary, cost, tokens, const DeepCollectionEquality().hash(structured), variant, finish);

  final String id;
  final String sessionID;
  final AssistantMessageTime time;
  final Object? error;
  final String parentID;
  final String modelID;
  final String providerID;
  final String mode;
  final String agent;
  final AssistantMessagePath path;
  final bool? summary;
  final double cost;
  final AssistantMessageTokens tokens;
  final Object? structured;
  final String? variant;
  final String? finish;
}

@immutable
class AssistantMessageTime {
  const AssistantMessageTime({
    required this.created,
    required this.completed,
  });

  factory AssistantMessageTime.fromJson(Map<String, dynamic> json) {
    return AssistantMessageTime(
      created: (json["created"] as num).toInt(),
      completed: (json["completed"] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "created": created,
      "completed": ?completed,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  AssistantMessageTime copyWith({
    int? created,
    int? completed,
  }) {
    return AssistantMessageTime(
      created: created ?? this.created,
      completed: completed ?? this.completed,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AssistantMessageTime &&
          other.created == created &&
          other.completed == completed);

  @override
  int get hashCode => Object.hash(created, completed);

  final int created;
  final int? completed;
}

@immutable
class AssistantMessagePath {
  const AssistantMessagePath({
    required this.cwd,
    required this.root,
  });

  factory AssistantMessagePath.fromJson(Map<String, dynamic> json) {
    return AssistantMessagePath(
      cwd: json["cwd"] as String,
      root: json["root"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "cwd": cwd,
      "root": root,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  AssistantMessagePath copyWith({
    String? cwd,
    String? root,
  }) {
    return AssistantMessagePath(
      cwd: cwd ?? this.cwd,
      root: root ?? this.root,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AssistantMessagePath &&
          other.cwd == cwd &&
          other.root == root);

  @override
  int get hashCode => Object.hash(cwd, root);

  final String cwd;
  final String root;
}

@immutable
class AssistantMessageTokens {
  const AssistantMessageTokens({
    required this.total,
    required this.input,
    required this.output,
    required this.reasoning,
    required this.cache,
  });

  factory AssistantMessageTokens.fromJson(Map<String, dynamic> json) {
    return AssistantMessageTokens(
      total: (json["total"] as num?)?.toDouble(),
      input: (json["input"] as num).toDouble(),
      output: (json["output"] as num).toDouble(),
      reasoning: (json["reasoning"] as num).toDouble(),
      cache: AssistantMessageTokensCache.fromJson(json["cache"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "total": ?total,
      "input": input,
      "output": output,
      "reasoning": reasoning,
      "cache": cache.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  AssistantMessageTokens copyWith({
    double? total,
    double? input,
    double? output,
    double? reasoning,
    AssistantMessageTokensCache? cache,
  }) {
    return AssistantMessageTokens(
      total: total ?? this.total,
      input: input ?? this.input,
      output: output ?? this.output,
      reasoning: reasoning ?? this.reasoning,
      cache: cache ?? this.cache,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AssistantMessageTokens &&
          other.total == total &&
          other.input == input &&
          other.output == output &&
          other.reasoning == reasoning &&
          other.cache == cache);

  @override
  int get hashCode => Object.hash(total, input, output, reasoning, cache);

  final double? total;
  final double input;
  final double output;
  final double reasoning;
  final AssistantMessageTokensCache cache;
}

@immutable
class AssistantMessageTokensCache {
  const AssistantMessageTokensCache({
    required this.read,
    required this.write,
  });

  factory AssistantMessageTokensCache.fromJson(Map<String, dynamic> json) {
    return AssistantMessageTokensCache(
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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  AssistantMessageTokensCache copyWith({
    double? read,
    double? write,
  }) {
    return AssistantMessageTokensCache(
      read: read ?? this.read,
      write: write ?? this.write,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AssistantMessageTokensCache &&
          other.read == read &&
          other.write == write);

  @override
  int get hashCode => Object.hash(read, write);

  final double read;
  final double write;
}
