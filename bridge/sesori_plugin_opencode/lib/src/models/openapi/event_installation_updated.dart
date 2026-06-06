// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventInstallationUpdated implements Event {
  const EventInstallationUpdated({
    required this.id,
    required this.properties,
  });

  factory EventInstallationUpdated.fromJson(Map<String, dynamic> json) {
    return EventInstallationUpdated(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "installation.updated",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}
