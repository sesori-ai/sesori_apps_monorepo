// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventServerInstanceDisposed implements Event {
  const EventServerInstanceDisposed({
    required this.id,
    required this.properties,
  });

  factory EventServerInstanceDisposed.fromJson(Map<String, dynamic> json) {
    return EventServerInstanceDisposed(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "server.instance.disposed",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}
