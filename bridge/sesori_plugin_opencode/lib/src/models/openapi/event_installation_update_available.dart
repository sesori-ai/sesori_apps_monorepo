// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventInstallationUpdateAvailable implements Event {
  const EventInstallationUpdateAvailable({
    required this.id,
    required this.properties,
  });

  factory EventInstallationUpdateAvailable.fromJson(Map<String, dynamic> json) {
    return EventInstallationUpdateAvailable(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "installation.update-available",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}
