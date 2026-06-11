// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'event.dart';

@immutable
class EventTuiSessionSelect16fpc99 implements Event {
  const EventTuiSessionSelect16fpc99({
    required this.id,
    required this.properties,
  });

  factory EventTuiSessionSelect16fpc99.fromJson(Map<String, dynamic> json) {
    return EventTuiSessionSelect16fpc99(
      id: json["id"] as String,
      properties: EventTuiSessionSelect16fpc99Properties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "tui.session.select",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventTuiSessionSelect16fpc99 &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventTuiSessionSelect16fpc99Properties properties;
}

@immutable
class EventTuiSessionSelect16fpc99Properties {
  const EventTuiSessionSelect16fpc99Properties({
    required this.sessionID,
  });

  factory EventTuiSessionSelect16fpc99Properties.fromJson(Map<String, dynamic> json) {
    return EventTuiSessionSelect16fpc99Properties(
      sessionID: json["sessionID"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "sessionID": sessionID,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventTuiSessionSelect16fpc99Properties &&
          other.sessionID == sessionID);

  @override
  int get hashCode => sessionID.hashCode;

  final String sessionID;
}
