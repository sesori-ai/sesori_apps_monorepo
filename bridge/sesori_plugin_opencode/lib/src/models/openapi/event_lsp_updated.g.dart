// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.7 (4ed4f749e644ffb5b279fb30b7b915e743d80142)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'event.g.dart';

@immutable
class EventLspUpdated implements Event {
  const EventLspUpdated({
    required this.id,
    required this.properties,
  });

  factory EventLspUpdated.fromJson(Map<String, dynamic> json) {
    return EventLspUpdated(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "lsp.updated",
      "properties": properties,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventLspUpdated copyWith({
    String? id,
    Map<String, dynamic>? properties,
  }) {
    return EventLspUpdated(
      id: id ?? this.id,
      properties: properties ?? this.properties,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventLspUpdated &&
          other.id == id &&
          const DeepCollectionEquality().equals(other.properties, properties));

  @override
  int get hashCode => Object.hash(id, const DeepCollectionEquality().hash(properties));

  final String id;
  final Map<String, dynamic> properties;
}
