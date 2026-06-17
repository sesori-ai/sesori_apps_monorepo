// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.7 (4ed4f749e644ffb5b279fb30b7b915e743d80142)

import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import 'event.g.dart';

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
    required this.title,
    required this.message,
    required this.variant,
    required this.duration,
  });

  factory EventTuiToastShow190ap9tProperties.fromJson(Map<String, dynamic> json) {
    return EventTuiToastShow190ap9tProperties(
      title: json["title"] as String?,
      message: json["message"] as String,
      variant: EventTuiToastShow190ap9tPropertiesVariant.fromJson(json["variant"] as String),
      duration: (json["duration"] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "title": ?title,
      "message": message,
      "variant": variant.toJson(),
      "duration": ?duration,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventTuiToastShow190ap9tProperties copyWith({
    String? title,
    String? message,
    EventTuiToastShow190ap9tPropertiesVariant? variant,
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
  final EventTuiToastShow190ap9tPropertiesVariant variant;
  final int? duration;
}

enum EventTuiToastShow190ap9tPropertiesVariant {
  @JsonValue("info")
  info,
  @JsonValue("success")
  success,
  @JsonValue("warning")
  warning,
  @JsonValue("error")
  error,

  /// Fallback for values introduced by newer OpenCode servers.
  /// Encodes back to the literal string `unknown`.
  unknown,
  ;

  static EventTuiToastShow190ap9tPropertiesVariant fromJson(String value) {
    switch (value) {
      case "info":
        return EventTuiToastShow190ap9tPropertiesVariant.info;
      case "success":
        return EventTuiToastShow190ap9tPropertiesVariant.success;
      case "warning":
        return EventTuiToastShow190ap9tPropertiesVariant.warning;
      case "error":
        return EventTuiToastShow190ap9tPropertiesVariant.error;
      default:
        return EventTuiToastShow190ap9tPropertiesVariant.unknown;
    }
  }

  String toJson() {
    switch (this) {
      case EventTuiToastShow190ap9tPropertiesVariant.info:
        return "info";
      case EventTuiToastShow190ap9tPropertiesVariant.success:
        return "success";
      case EventTuiToastShow190ap9tPropertiesVariant.warning:
        return "warning";
      case EventTuiToastShow190ap9tPropertiesVariant.error:
        return "error";
      case EventTuiToastShow190ap9tPropertiesVariant.unknown:
        return 'unknown';
    }
  }
}
