// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'event.dart';

@immutable
class EventTuiToastShow190ap9t implements Event {
  const EventTuiToastShow190ap9t({
    required this.id,
    required this.properties,
  });

  factory EventTuiToastShow190ap9t.fromJson(Map<String, dynamic> json) {
    return EventTuiToastShow190ap9t(
      id: json["id"] as String,
      properties: EventTuiToastShow190ap9tProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "tui.toast.show",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventTuiToastShow190ap9t &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventTuiToastShow190ap9tProperties properties;
}

@immutable
class EventTuiToastShow190ap9tProperties {
  const EventTuiToastShow190ap9tProperties({
    this.title,
    required this.message,
    required this.variant,
    this.duration,
  });

  factory EventTuiToastShow190ap9tProperties.fromJson(Map<String, dynamic> json) {
    return EventTuiToastShow190ap9tProperties(
      title: json["title"] as String?,
      message: json["message"] as String,
      variant: json["variant"] as String,
      duration: (json["duration"] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "title": ?title,
      "message": message,
      "variant": variant,
      "duration": ?duration,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventTuiToastShow190ap9tProperties &&
          other.title == title &&
          other.message == message &&
          other.variant == variant &&
          other.duration == duration);

  @override
  int get hashCode => Object.hash(title, message, variant, duration);

  final String? title;
  final String message;
  final String variant;
  final int? duration;
}
