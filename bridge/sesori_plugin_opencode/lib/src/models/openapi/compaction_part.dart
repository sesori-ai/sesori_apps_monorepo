// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:11:43.915468Z

import 'package:meta/meta.dart';
import 'part.dart';

@immutable
class CompactionPart implements Part {
  const CompactionPart({
    required this.id,
    required this.sessionID,
    required this.messageID,
    required this.auto,
    this.overflow,
    this.tailStartId,
  });

  factory CompactionPart.fromJson(Map<String, dynamic> json) {
    return CompactionPart(
      id: json["id"] as String,
      sessionID: json["sessionID"] as String,
      messageID: json["messageID"] as String,
      auto: json["auto"] as bool,
      overflow: json["overflow"] as bool?,
      tailStartId: json["tail_start_id"] as String?,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "sessionID": sessionID,
      "messageID": messageID,
      "type": "compaction",
      "auto": auto,
      "overflow": ?overflow,
      "tail_start_id": ?tailStartId,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CompactionPart &&
          other.id == id &&
          other.sessionID == sessionID &&
          other.messageID == messageID &&
          other.auto == auto &&
          other.overflow == overflow &&
          other.tailStartId == tailStartId);

  @override
  int get hashCode => Object.hash(id, sessionID, messageID, auto, overflow, tailStartId);

  final String id;
  final String sessionID;
  final String messageID;
  final bool auto;
  final bool? overflow;
  final String? tailStartId;
}
