// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventFileEdited implements Event {
  const EventFileEdited({
    required this.id,
    required this.properties,
  });

  factory EventFileEdited.fromJson(Map<String, dynamic> json) {
    return EventFileEdited(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "file.edited",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}
