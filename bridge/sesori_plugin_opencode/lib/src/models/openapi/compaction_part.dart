// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T09:42:34.321044Z

import 'part.dart';

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

  final String id;
  final String sessionID;
  final String messageID;
  final bool auto;
  final bool? overflow;
  final String? tailStartId;
}
