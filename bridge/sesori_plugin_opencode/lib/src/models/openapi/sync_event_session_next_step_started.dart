// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-07T10:22:51.686728Z


class SyncEventSessionNextStepStarted {
  const SyncEventSessionNextStepStarted({
    required this.type,
    required this.id,
    required this.syncEvent,
  });

  factory SyncEventSessionNextStepStarted.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextStepStarted(
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

  final String type;
  final String id;
  final Map<String, dynamic> syncEvent;
}
