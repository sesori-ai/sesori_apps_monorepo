// GENERATED FILE - DO NOT EDIT BY HAND


class SyncEventSessionNextTextEnded {
  const SyncEventSessionNextTextEnded({
    required this.type,
    required this.id,
    required this.syncEvent,
  });

  factory SyncEventSessionNextTextEnded.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextTextEnded(
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
