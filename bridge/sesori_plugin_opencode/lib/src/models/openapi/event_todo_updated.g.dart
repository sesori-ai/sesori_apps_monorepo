// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'event.g.dart';
import 'todo.g.dart';

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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventTodoUpdated copyWith({
    String? id,
    EventTodoUpdatedProperties? properties,
  }) {
    return EventTodoUpdated(
      id: id ?? this.id,
      properties: properties ?? this.properties,
    );
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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventTodoUpdatedProperties copyWith({
    String? sessionID,
    List<Todo>? todos,
  }) {
    return EventTodoUpdatedProperties(
      sessionID: sessionID ?? this.sessionID,
      todos: todos ?? this.todos,
    );
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
