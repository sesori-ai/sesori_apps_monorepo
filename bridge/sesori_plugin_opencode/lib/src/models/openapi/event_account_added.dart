// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'auth_info.dart';
import 'event.dart';

@immutable
class EventAccountAdded implements Event {
  const EventAccountAdded({
    required this.id,
    required this.properties,
  });

  factory EventAccountAdded.fromJson(Map<String, dynamic> json) {
    return EventAccountAdded(
      id: json["id"] as String,
      properties: EventAccountAddedProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "account.added",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventAccountAdded &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventAccountAddedProperties properties;
}

@immutable
class EventAccountAddedProperties {
  const EventAccountAddedProperties({
    required this.account,
  });

  factory EventAccountAddedProperties.fromJson(Map<String, dynamic> json) {
    return EventAccountAddedProperties(
      account: AuthInfo.fromJson(json["account"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "account": account.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventAccountAddedProperties &&
          other.account == account);

  @override
  int get hashCode => account.hashCode;

  final AuthInfo account;
}
