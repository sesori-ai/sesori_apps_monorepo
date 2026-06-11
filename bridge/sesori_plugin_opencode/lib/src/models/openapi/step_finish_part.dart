// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'part.dart';

@immutable
class StepFinishPart implements Part {
  const StepFinishPart({
    required this.id,
    required this.sessionID,
    required this.messageID,
    required this.reason,
    this.snapshot,
    required this.cost,
    required this.tokens,
  });

  factory StepFinishPart.fromJson(Map<String, dynamic> json) {
    return StepFinishPart(
      id: json["id"] as String,
      sessionID: json["sessionID"] as String,
      messageID: json["messageID"] as String,
      reason: json["reason"] as String,
      snapshot: json["snapshot"] as String?,
      cost: (json["cost"] as num).toDouble(),
      tokens: StepFinishPartTokens.fromJson(json["tokens"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "sessionID": sessionID,
      "messageID": messageID,
      "type": "step-finish",
      "reason": reason,
      "snapshot": ?snapshot,
      "cost": cost,
      "tokens": tokens.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StepFinishPart &&
          other.id == id &&
          other.sessionID == sessionID &&
          other.messageID == messageID &&
          other.reason == reason &&
          other.snapshot == snapshot &&
          other.cost == cost &&
          other.tokens == tokens);

  @override
  int get hashCode => Object.hash(id, sessionID, messageID, reason, snapshot, cost, tokens);

  final String id;
  final String sessionID;
  final String messageID;
  final String reason;
  final String? snapshot;
  final double cost;
  final StepFinishPartTokens tokens;
}

@immutable
class StepFinishPartTokens {
  const StepFinishPartTokens({
    this.total,
    required this.input,
    required this.output,
    required this.reasoning,
    required this.cache,
  });

  factory StepFinishPartTokens.fromJson(Map<String, dynamic> json) {
    return StepFinishPartTokens(
      total: (json["total"] as num?)?.toDouble(),
      input: (json["input"] as num).toDouble(),
      output: (json["output"] as num).toDouble(),
      reasoning: (json["reasoning"] as num).toDouble(),
      cache: StepFinishPartTokensCache.fromJson(json["cache"] as Map<String, dynamic>),
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
      (other is StepFinishPartTokens &&
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
  final StepFinishPartTokensCache cache;
}

@immutable
class StepFinishPartTokensCache {
  const StepFinishPartTokensCache({
    required this.read,
    required this.write,
  });

  factory StepFinishPartTokensCache.fromJson(Map<String, dynamic> json) {
    return StepFinishPartTokensCache(
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
      (other is StepFinishPartTokensCache &&
          other.read == read &&
          other.write == write);

  @override
  int get hashCode => Object.hash(read, write);

  final double read;
  final double write;
}
