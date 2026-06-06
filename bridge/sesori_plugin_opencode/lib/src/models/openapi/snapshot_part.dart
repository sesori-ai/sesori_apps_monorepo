// GENERATED FILE - DO NOT EDIT BY HAND

import 'part.dart';

class SnapshotPart implements Part {
  const SnapshotPart({
    required this.id,
    required this.sessionID,
    required this.messageID,
    required this.type,
    required this.snapshot,
  });

  factory SnapshotPart.fromJson(Map<String, dynamic> json) {
    return SnapshotPart(
      id: json["id"] as String,
      sessionID: json["sessionID"] as String,
      messageID: json["messageID"] as String,
      type: json["type"] as String,
      snapshot: json["snapshot"] as String,
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
  final String snapshot;
}
