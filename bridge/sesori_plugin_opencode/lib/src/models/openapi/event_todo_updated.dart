// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventTodoUpdated implements Event {
  const EventTodoUpdated({
    required this.id,
    required this.properties,
  });

  factory EventTodoUpdated.fromJson(Map<String, dynamic> json) {
    return EventTodoUpdated(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "todo.updated",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}
