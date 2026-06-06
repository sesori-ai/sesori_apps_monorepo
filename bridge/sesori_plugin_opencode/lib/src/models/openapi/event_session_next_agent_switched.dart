// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventSessionNextAgentSwitched implements Event {
  const EventSessionNextAgentSwitched({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextAgentSwitched.fromJson(Map<String, dynamic> json) {
    return EventSessionNextAgentSwitched(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.agent.switched",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}
