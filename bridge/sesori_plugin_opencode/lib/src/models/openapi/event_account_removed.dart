// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventAccountRemoved implements Event {
  const EventAccountRemoved({
    required this.id,
    required this.properties,
  });

  factory EventAccountRemoved.fromJson(Map<String, dynamic> json) {
    return EventAccountRemoved(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "account.removed",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}
