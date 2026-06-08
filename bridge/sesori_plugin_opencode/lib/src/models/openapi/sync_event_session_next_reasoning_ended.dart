// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:04:08.001641Z

import 'package:meta/meta.dart';

@immutable
class SyncEventSessionNextReasoningEnded {
  const SyncEventSessionNextReasoningEnded({
    required this.type,
    required this.id,
    required this.syncEvent,
  });

  factory SyncEventSessionNextReasoningEnded.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextReasoningEnded(
      type: json["type"] as String,
      id: json["id"] as String,
      syncEvent: json["syncEvent"] as Map<String, dynamic>,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": type,
      "id": id,
      "syncEvent": syncEvent,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncEventSessionNextReasoningEnded &&
          other.type == type &&
          other.id == id &&
          other.syncEvent == syncEvent);

  @override
  int get hashCode => Object.hash(type, id, syncEvent);

  final String type;
  final String id;
  final Map<String, dynamic> syncEvent;
}
