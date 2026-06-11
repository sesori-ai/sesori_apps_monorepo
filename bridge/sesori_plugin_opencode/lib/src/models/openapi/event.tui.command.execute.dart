// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'event.dart';

@immutable
class EventTuiCommandExecute0vkghdx implements Event {
  const EventTuiCommandExecute0vkghdx({
    required this.id,
    required this.properties,
  });

  factory EventTuiCommandExecute0vkghdx.fromJson(Map<String, dynamic> json) {
    return EventTuiCommandExecute0vkghdx(
      id: json["id"] as String,
      properties: EventTuiCommandExecute0vkghdxProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "tui.command.execute",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventTuiCommandExecute0vkghdx &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventTuiCommandExecute0vkghdxProperties properties;
}

@immutable
class EventTuiCommandExecute0vkghdxProperties {
  const EventTuiCommandExecute0vkghdxProperties({
    required this.command,
  });

  factory EventTuiCommandExecute0vkghdxProperties.fromJson(Map<String, dynamic> json) {
    return EventTuiCommandExecute0vkghdxProperties(
      command: json["command"] as Object,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "command": command,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventTuiCommandExecute0vkghdxProperties &&
          const DeepCollectionEquality().equals(other.command, command));

  @override
  int get hashCode => const DeepCollectionEquality().hash(command);

  final Object command;
}
