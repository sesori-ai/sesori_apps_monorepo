// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'event.dart';

@immutable
class EventTuiPromptAppend1opz5ph implements Event {
  const EventTuiPromptAppend1opz5ph({
    required this.id,
    required this.properties,
  });

  factory EventTuiPromptAppend1opz5ph.fromJson(Map<String, dynamic> json) {
    return EventTuiPromptAppend1opz5ph(
      id: json["id"] as String,
      properties: EventTuiPromptAppend1opz5phProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "tui.prompt.append",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventTuiPromptAppend1opz5ph &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventTuiPromptAppend1opz5phProperties properties;
}

@immutable
class EventTuiPromptAppend1opz5phProperties {
  const EventTuiPromptAppend1opz5phProperties({
    required this.text,
  });

  factory EventTuiPromptAppend1opz5phProperties.fromJson(Map<String, dynamic> json) {
    return EventTuiPromptAppend1opz5phProperties(
      text: json["text"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "text": text,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventTuiPromptAppend1opz5phProperties &&
          other.text == text);

  @override
  int get hashCode => text.hashCode;

  final String text;
}
