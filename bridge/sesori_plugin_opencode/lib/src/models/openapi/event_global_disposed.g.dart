// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'event.g.dart';

@immutable
class EventGlobalDisposed implements Event {
  const EventGlobalDisposed({
    this.id = '',
    this.properties = const {},
  });

  factory EventGlobalDisposed.fromJson(Map<String, dynamic> json) {
    return EventGlobalDisposed(
      id: (json["id"] ?? '') as String,
      properties: (json["properties"] ?? const <String, dynamic>{}) as Map<String, dynamic>,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "global.disposed",
      "properties": properties,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventGlobalDisposed copyWith({
    String? id,
    Map<String, dynamic>? properties,
  }) {
    return EventGlobalDisposed(
      id: id ?? this.id,
      properties: properties ?? this.properties,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventGlobalDisposed &&
          other.id == id &&
          const DeepCollectionEquality().equals(other.properties, properties));

  @override
  int get hashCode => Object.hash(id, const DeepCollectionEquality().hash(properties));

  final String id;
  final Map<String, dynamic> properties;
}
