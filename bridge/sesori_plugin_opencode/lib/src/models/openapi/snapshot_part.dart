// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-07T10:22:51.682467Z

import 'part.dart';

class SnapshotPart implements Part {
  const SnapshotPart({
    required this.id,
    required this.sessionID,
    required this.messageID,
    required this.snapshot,
  });

  factory SnapshotPart.fromJson(Map<String, dynamic> json) {
    return SnapshotPart(
      id: json["id"] as String,
      sessionID: json["sessionID"] as String,
      messageID: json["messageID"] as String,
      snapshot: json["snapshot"] as String,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "sessionID": sessionID,
      "messageID": messageID,
      "type": "snapshot",
      "snapshot": snapshot,
    };
  }

  final String id;
  final String sessionID;
  final String messageID;
  final String snapshot;
}
