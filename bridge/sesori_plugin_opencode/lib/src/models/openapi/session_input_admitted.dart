// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:11:43.958615Z

import 'package:meta/meta.dart';
import 'prompt.dart';

@immutable
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
      admittedSeq: (json["admittedSeq"] as num).toInt(),
      id: json["id"] as String,
      sessionID: json["sessionID"] as String,
      prompt: Prompt.fromJson(json["prompt"] as Map<String, dynamic>),
      delivery: json["delivery"] as String,
      timeCreated: (json["timeCreated"] as num).toDouble(),
      promotedSeq: (json["promotedSeq"] as num?)?.toInt(),
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionInputAdmitted &&
          other.admittedSeq == admittedSeq &&
          other.id == id &&
          other.sessionID == sessionID &&
          other.prompt == prompt &&
          other.delivery == delivery &&
          other.timeCreated == timeCreated &&
          other.promotedSeq == promotedSeq);

  @override
  int get hashCode => Object.hash(admittedSeq, id, sessionID, prompt, delivery, timeCreated, promotedSeq);

  final int admittedSeq;
  final String id;
  final String sessionID;
  final Prompt prompt;
  final String delivery;
  final double timeCreated;
  final int? promotedSeq;
}
