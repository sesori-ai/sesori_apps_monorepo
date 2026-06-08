// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:04:08.001479Z

import 'package:meta/meta.dart';

@immutable
class SyncEventSessionNextPrompted {
  const SyncEventSessionNextPrompted({
    required this.type,
    required this.id,
    required this.syncEvent,
  });

  factory SyncEventSessionNextPrompted.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextPrompted(
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
      (other is SyncEventSessionNextPrompted &&
          other.type == type &&
          other.id == id &&
          other.syncEvent == syncEvent);

  @override
  int get hashCode => Object.hash(type, id, syncEvent);

  final String type;
  final String id;
  final Map<String, dynamic> syncEvent;
}
