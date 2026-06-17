// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.7 (4ed4f749e644ffb5b279fb30b7b915e743d80142)

import 'package:meta/meta.dart';
import 'part.g.dart';

@immutable
class StepFinishPart implements Part {
  const StepFinishPart({
    required this.id,
    required this.sessionID,
    required this.messageID,
    required this.reason,
    required this.snapshot,
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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  StepFinishPart copyWith({
    String? id,
    String? sessionID,
    String? messageID,
    String? reason,
    String? snapshot,
    double? cost,
    StepFinishPartTokens? tokens,
  }) {
    return StepFinishPart(
      id: id ?? this.id,
      sessionID: sessionID ?? this.sessionID,
      messageID: messageID ?? this.messageID,
      reason: reason ?? this.reason,
      snapshot: snapshot ?? this.snapshot,
      cost: cost ?? this.cost,
      tokens: tokens ?? this.tokens,
    );
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
    required this.total,
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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  StepFinishPartTokens copyWith({
    double? total,
    double? input,
    double? output,
    double? reasoning,
    StepFinishPartTokensCache? cache,
  }) {
    return StepFinishPartTokens(
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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  StepFinishPartTokensCache copyWith({
    double? read,
    double? write,
  }) {
    return StepFinishPartTokensCache(
      read: read ?? this.read,
      write: write ?? this.write,
    );
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
