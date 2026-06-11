// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'event.dart';

@immutable
class EventAccountSwitched implements Event {
  const EventAccountSwitched({
    required this.id,
    required this.properties,
  });

  factory EventAccountSwitched.fromJson(Map<String, dynamic> json) {
    return EventAccountSwitched(
      id: json["id"] as String,
      properties: EventAccountSwitchedProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "account.switched",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventAccountSwitched &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventAccountSwitchedProperties properties;
}

@immutable
class EventAccountSwitchedProperties {
  const EventAccountSwitchedProperties({
    required this.serviceID,
    this.from,
    this.to,
  });

  factory EventAccountSwitchedProperties.fromJson(Map<String, dynamic> json) {
    return EventAccountSwitchedProperties(
      serviceID: json["serviceID"] as String,
      from: json["from"] as String?,
      to: json["to"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "serviceID": serviceID,
      "from": ?from,
      "to": ?to,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventAccountSwitchedProperties &&
          other.serviceID == serviceID &&
          other.from == from &&
          other.to == to);

  @override
  int get hashCode => Object.hash(serviceID, from, to);

  final String serviceID;
  final String? from;
  final String? to;
}
