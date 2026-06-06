// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventAccountAdded implements Event {
  const EventAccountAdded({
    required this.id,
    required this.properties,
  });

  factory EventAccountAdded.fromJson(Map<String, dynamic> json) {
    return EventAccountAdded(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "account.added",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}
