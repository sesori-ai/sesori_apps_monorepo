// GENERATED FILE - DO NOT EDIT BY HAND


class SyncEventSessionUpdated {
  const SyncEventSessionUpdated({
    required this.type,
    required this.id,
    required this.syncEvent,
  });

  factory SyncEventSessionUpdated.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionUpdated(
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
