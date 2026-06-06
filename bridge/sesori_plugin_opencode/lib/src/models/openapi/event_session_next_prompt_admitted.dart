// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventSessionNextPromptAdmitted implements Event {
  const EventSessionNextPromptAdmitted({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextPromptAdmitted.fromJson(Map<String, dynamic> json) {
    return EventSessionNextPromptAdmitted(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.prompt.admitted",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}
