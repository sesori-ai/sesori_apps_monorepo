// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'auth_info.dart';
import 'event.dart';

@immutable
class EventAccountRemoved implements Event {
  const EventAccountRemoved({
    required this.id,
    required this.properties,
  });

  factory EventAccountRemoved.fromJson(Map<String, dynamic> json) {
    return EventAccountRemoved(
      id: json["id"] as String,
      properties: EventAccountRemovedProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "account.removed",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventAccountRemoved &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventAccountRemovedProperties properties;
}

@immutable
class EventAccountRemovedProperties {
  const EventAccountRemovedProperties({
    required this.account,
  });

  factory EventAccountRemovedProperties.fromJson(Map<String, dynamic> json) {
    return EventAccountRemovedProperties(
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
      (other is EventAccountRemovedProperties &&
          other.account == account);

  @override
  int get hashCode => account.hashCode;

  final AuthInfo account;
}
