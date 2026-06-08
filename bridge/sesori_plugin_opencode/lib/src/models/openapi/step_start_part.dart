// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T08:11:58.923187Z

import 'part.dart';

class StepStartPart implements Part {
  const StepStartPart({
    required this.id,
    required this.sessionID,
    required this.messageID,
    this.snapshot,
  });

  factory StepStartPart.fromJson(Map<String, dynamic> json) {
    return StepStartPart(
      id: json["id"] as String,
      sessionID: json["sessionID"] as String,
      messageID: json["messageID"] as String,
      snapshot: json["snapshot"] as String?,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "sessionID": sessionID,
      "messageID": messageID,
      "type": "step-start",
      "snapshot": ?snapshot,
    };
  }

  final String id;
  final String sessionID;
  final String messageID;
  final String? snapshot;
}
