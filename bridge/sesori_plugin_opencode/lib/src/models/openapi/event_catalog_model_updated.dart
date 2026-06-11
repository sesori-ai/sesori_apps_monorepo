// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'event.dart';
import 'model_v2_info1.dart';

@immutable
class EventCatalogModelUpdated implements Event {
  const EventCatalogModelUpdated({
    required this.id,
    required this.properties,
  });

  factory EventCatalogModelUpdated.fromJson(Map<String, dynamic> json) {
    return EventCatalogModelUpdated(
      id: json["id"] as String,
      properties: EventCatalogModelUpdatedProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "catalog.model.updated",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventCatalogModelUpdated &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventCatalogModelUpdatedProperties properties;
}

@immutable
class EventCatalogModelUpdatedProperties {
  const EventCatalogModelUpdatedProperties({
    required this.model,
  });

  factory EventCatalogModelUpdatedProperties.fromJson(Map<String, dynamic> json) {
    return EventCatalogModelUpdatedProperties(
      model: ModelV2Info1.fromJson(json["model"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "model": model.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventCatalogModelUpdatedProperties &&
          other.model == model);

  @override
  int get hashCode => model.hashCode;

  final ModelV2Info1 model;
}
