// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventAccountAdded implements Event {
  const EventAccountAdded({
    required this.id,
    required this.type,
    required this.properties,
  });

  factory EventAccountAdded.fromJson(Map<String, dynamic> json) {
    return EventAccountAdded(
      id: json["id"] as String,
      type: json["type"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": type,
      "properties": properties,
    };
  }

  final String id;
  final String type;
  final Map<String, dynamic> properties;
}
