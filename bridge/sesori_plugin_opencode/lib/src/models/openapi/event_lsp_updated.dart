// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventLspUpdated implements Event {
  const EventLspUpdated({
    required this.id,
    required this.properties,
  });

  factory EventLspUpdated.fromJson(Map<String, dynamic> json) {
    return EventLspUpdated(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "lsp.updated",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}
