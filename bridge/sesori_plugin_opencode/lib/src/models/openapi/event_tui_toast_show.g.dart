// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:meta/meta.dart';
import 'event.g.dart';

@immutable
class EventTuiToastShow190ap9t implements Event {
  const EventTuiToastShow190ap9t({
    this.id = '',
    required this.properties,
  });

  factory EventTuiToastShow190ap9t.fromJson(Map<String, dynamic> json) {
    return EventTuiToastShow190ap9t(
      id: (json["id"] ?? '') as String,
      properties: EventTuiToastShow190ap9tProperties.fromJson((json["properties"] ?? const <String, dynamic>{}) as Map<String, dynamic>),
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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventTuiToastShow190ap9t copyWith({
    String? id,
    EventTuiToastShow190ap9tProperties? properties,
  }) {
    return EventTuiToastShow190ap9t(
      id: id ?? this.id,
      properties: properties ?? this.properties,
    );
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
    this.message = '',
    this.variant = '',
    this.duration,
  });

  factory EventTuiToastShow190ap9tProperties.fromJson(Map<String, dynamic> json) {
    return EventTuiToastShow190ap9tProperties(
      title: json["title"] as String?,
      message: (json["message"] ?? '') as String,
      variant: (json["variant"] ?? '') as String,
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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventTuiToastShow190ap9tProperties copyWith({
    String? title,
    String? message,
    String? variant,
    int? duration,
  }) {
    return EventTuiToastShow190ap9tProperties(
      title: title ?? this.title,
      message: message ?? this.message,
      variant: variant ?? this.variant,
      duration: duration ?? this.duration,
    );
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
