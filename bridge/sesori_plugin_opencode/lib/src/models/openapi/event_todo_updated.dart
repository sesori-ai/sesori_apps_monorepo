// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'event.dart';
import 'todo.dart';

@immutable
class EventTodoUpdated implements Event {
  const EventTodoUpdated({
    required this.id,
    required this.properties,
  });

  factory EventTodoUpdated.fromJson(Map<String, dynamic> json) {
    return EventTodoUpdated(
      id: json["id"] as String,
      properties: EventTodoUpdatedProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "todo.updated",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventTodoUpdated &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventTodoUpdatedProperties properties;
}

@immutable
class EventTodoUpdatedProperties {
  const EventTodoUpdatedProperties({
    required this.sessionID,
    required this.todos,
  });

  factory EventTodoUpdatedProperties.fromJson(Map<String, dynamic> json) {
    return EventTodoUpdatedProperties(
      sessionID: json["sessionID"] as String,
      todos: (json["todos"] as List<dynamic>).map((e) => Todo.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "sessionID": sessionID,
      "todos": todos.map((e) => e.toJson()).toList(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventTodoUpdatedProperties &&
          other.sessionID == sessionID &&
          const DeepCollectionEquality().equals(other.todos, todos));

  @override
  int get hashCode => Object.hash(sessionID, const DeepCollectionEquality().hash(todos));

  final String sessionID;
  final List<Todo> todos;
}
