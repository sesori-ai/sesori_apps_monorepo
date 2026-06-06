// GENERATED FILE - DO NOT EDIT BY HAND

import 'part.dart';

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
      "snapshot": snapshot,
      "cost": cost,
      "tokens": tokens,
    };
  }

  final String id;
  final String sessionID;
  final String messageID;
  final String reason;
  final String? snapshot;
  final double cost;
  final Map<String, dynamic> tokens;
}
