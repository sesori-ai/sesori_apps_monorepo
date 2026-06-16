// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:meta/meta.dart';
import 'part.g.dart';

@immutable
class CompactionPart implements Part {
  const CompactionPart({
    required this.id,
    required this.sessionID,
    required this.messageID,
    required this.auto,
    required this.overflow,
    required this.tailStartId,
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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  CompactionPart copyWith({
    String? id,
    String? sessionID,
    String? messageID,
    bool? auto,
    bool? overflow,
    String? tailStartId,
  }) {
    return CompactionPart(
      id: id ?? this.id,
      sessionID: sessionID ?? this.sessionID,
      messageID: messageID ?? this.messageID,
      auto: auto ?? this.auto,
      overflow: overflow ?? this.overflow,
      tailStartId: tailStartId ?? this.tailStartId,
    );
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
