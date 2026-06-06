// GENERATED FILE - DO NOT EDIT BY HAND

import 'part.dart';

class StepStartPart implements Part {
  const StepStartPart({
    required this.id,
    required this.sessionID,
    required this.messageID,
    required this.type,
    this.snapshot,
  });

  factory StepStartPart.fromJson(Map<String, dynamic> json) {
    return StepStartPart(
      id: json["id"] as String,
      sessionID: json["sessionID"] as String,
      messageID: json["messageID"] as String,
      type: json["type"] as String,
      snapshot: json["snapshot"] as String?,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "sessionID": sessionID,
      "messageID": messageID,
      "type": type,
      "snapshot": snapshot,
    };
  }

  final String id;
  final String sessionID;
  final String messageID;
  final String type;
  final String? snapshot;
}
