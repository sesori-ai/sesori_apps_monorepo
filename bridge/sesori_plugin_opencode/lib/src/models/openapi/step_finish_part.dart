// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:04:07.996681Z

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
      tokens: json["tokens"] as Map<String, dynamic>,
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
      "tokens": tokens,
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
  final Map<String, dynamic> tokens;
}
