// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'message.dart';

@immutable
class AssistantMessage implements Message {
  const AssistantMessage({
    required this.id,
    required this.sessionID,
    required this.time,
    this.error,
    required this.parentID,
    required this.modelID,
    required this.providerID,
    required this.mode,
    required this.agent,
    required this.path,
    this.summary,
    required this.cost,
    required this.tokens,
    this.structured,
    this.variant,
    this.finish,
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
    this.completed,
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
    this.total,
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
