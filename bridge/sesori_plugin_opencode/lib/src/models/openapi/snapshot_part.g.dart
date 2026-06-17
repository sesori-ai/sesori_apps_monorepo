// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.7 (4ed4f749e644ffb5b279fb30b7b915e743d80142)

import 'package:meta/meta.dart';
import 'part.g.dart';

@immutable
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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SnapshotPart copyWith({
    String? id,
    String? sessionID,
    String? messageID,
    String? snapshot,
  }) {
    return SnapshotPart(
      id: id ?? this.id,
      sessionID: sessionID ?? this.sessionID,
      messageID: messageID ?? this.messageID,
      snapshot: snapshot ?? this.snapshot,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SnapshotPart &&
          other.id == id &&
          other.sessionID == sessionID &&
          other.messageID == messageID &&
          other.snapshot == snapshot);

  @override
  int get hashCode => Object.hash(id, sessionID, messageID, snapshot);

  final String id;
  final String sessionID;
  final String messageID;
  final String snapshot;
}
