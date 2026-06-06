// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventMessageRemoved implements Event {
  const EventMessageRemoved({
    required this.id,
    required this.properties,
  });

  factory EventMessageRemoved.fromJson(Map<String, dynamic> json) {
    return EventMessageRemoved(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "message.removed",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}
