// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventSessionNextToolSuccess implements Event {
  const EventSessionNextToolSuccess({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextToolSuccess.fromJson(Map<String, dynamic> json) {
    return EventSessionNextToolSuccess(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.tool.success",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}
