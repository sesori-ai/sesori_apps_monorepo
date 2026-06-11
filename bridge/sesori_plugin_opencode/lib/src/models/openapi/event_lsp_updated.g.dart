// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'event.g.dart';

@immutable
class EventLspUpdated implements Event {
  const EventLspUpdated({
    this.id = '',
    this.properties = const {},
  });

  factory EventLspUpdated.fromJson(Map<String, dynamic> json) {
    return EventLspUpdated(
      id: (json["id"] ?? '') as String,
      properties: (json["properties"] ?? const <String, dynamic>{}) as Map<String, dynamic>,
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
