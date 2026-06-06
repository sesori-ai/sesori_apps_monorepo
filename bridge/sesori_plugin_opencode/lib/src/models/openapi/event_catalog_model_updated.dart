// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventCatalogModelUpdated implements Event {
  const EventCatalogModelUpdated({
    required this.id,
    required this.properties,
  });

  factory EventCatalogModelUpdated.fromJson(Map<String, dynamic> json) {
    return EventCatalogModelUpdated(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "catalog.model.updated",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}
