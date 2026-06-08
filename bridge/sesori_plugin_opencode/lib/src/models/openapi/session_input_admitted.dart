// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T07:51:40.002285Z

import 'prompt.dart';

class SessionInputAdmitted {
  const SessionInputAdmitted({
    required this.admittedSeq,
    required this.id,
    required this.sessionID,
    required this.prompt,
    required this.delivery,
    required this.timeCreated,
    this.promotedSeq,
  });

  factory SessionInputAdmitted.fromJson(Map<String, dynamic> json) {
    return SessionInputAdmitted(
      admittedSeq: json["admittedSeq"] as int,
      id: json["id"] as String,
      sessionID: json["sessionID"] as String,
      prompt: Prompt.fromJson(json["prompt"] as Map<String, dynamic>),
      delivery: json["delivery"] as String,
      timeCreated: (json["timeCreated"] as num).toDouble(),
      promotedSeq: json["promotedSeq"] as int?,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "admittedSeq": admittedSeq,
      "id": id,
      "sessionID": sessionID,
      "prompt": prompt.toJson(),
      "delivery": delivery,
      "timeCreated": timeCreated,
      "promotedSeq": ?promotedSeq,
    };
  }

  final int admittedSeq;
  final String id;
  final String sessionID;
  final Prompt prompt;
  final String delivery;
  final double timeCreated;
  final int? promotedSeq;
}
