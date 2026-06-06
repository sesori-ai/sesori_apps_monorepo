// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventTuiCommandExecute0vkghdx implements Event {
  const EventTuiCommandExecute0vkghdx({
    required this.id,
    required this.properties,
  });

  factory EventTuiCommandExecute0vkghdx.fromJson(Map<String, dynamic> json) {
    return EventTuiCommandExecute0vkghdx(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "tui.command.execute",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}
