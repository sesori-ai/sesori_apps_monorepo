// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventTuiSessionSelect16fpc99 implements Event {
  const EventTuiSessionSelect16fpc99({
    required this.id,
    required this.type,
    required this.properties,
  });

  factory EventTuiSessionSelect16fpc99.fromJson(Map<String, dynamic> json) {
    return EventTuiSessionSelect16fpc99(
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
