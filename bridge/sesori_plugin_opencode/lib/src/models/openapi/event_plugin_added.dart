// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventPluginAdded implements Event {
  const EventPluginAdded({
    required this.id,
    required this.properties,
  });

  factory EventPluginAdded.fromJson(Map<String, dynamic> json) {
    return EventPluginAdded(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "plugin.added",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}
