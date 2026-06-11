// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'part.g.dart';

@immutable
class StepStartPart implements Part {
  const StepStartPart({
    this.id = '',
    this.sessionID = '',
    this.messageID = '',
    this.snapshot,
  });

  factory StepStartPart.fromJson(Map<String, dynamic> json) {
    return StepStartPart(
      id: (json["id"] ?? '') as String,
      sessionID: (json["sessionID"] ?? '') as String,
      messageID: (json["messageID"] ?? '') as String,
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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  StepStartPart copyWith({
    String? id,
    String? sessionID,
    String? messageID,
    String? snapshot,
  }) {
    return StepStartPart(
      id: id ?? this.id,
      sessionID: sessionID ?? this.sessionID,
      messageID: messageID ?? this.messageID,
      snapshot: snapshot ?? this.snapshot,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StepStartPart &&
          other.id == id &&
          other.sessionID == sessionID &&
          other.messageID == messageID &&
          other.snapshot == snapshot);

  @override
  int get hashCode => Object.hash(id, sessionID, messageID, snapshot);

  final String id;
  final String sessionID;
  final String messageID;
  final String? snapshot;
}
