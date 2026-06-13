// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:meta/meta.dart';
import 'part.g.dart';

@immutable
class AgentPart implements Part {
  const AgentPart({
    this.id = '',
    this.sessionID = '',
    this.messageID = '',
    this.name = '',
    this.source,
  });

  factory AgentPart.fromJson(Map<String, dynamic> json) {
    return AgentPart(
      id: (json["id"] ?? '') as String,
      sessionID: (json["sessionID"] ?? '') as String,
      messageID: (json["messageID"] ?? '') as String,
      name: (json["name"] ?? '') as String,
      source: json["source"] == null ? null : AgentPartSource.fromJson(json["source"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "sessionID": sessionID,
      "messageID": messageID,
      "type": "agent",
      "name": name,
      "source": ?source?.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  AgentPart copyWith({
    String? id,
    String? sessionID,
    String? messageID,
    String? name,
    AgentPartSource? source,
  }) {
    return AgentPart(
      id: id ?? this.id,
      sessionID: sessionID ?? this.sessionID,
      messageID: messageID ?? this.messageID,
      name: name ?? this.name,
      source: source ?? this.source,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AgentPart &&
          other.id == id &&
          other.sessionID == sessionID &&
          other.messageID == messageID &&
          other.name == name &&
          other.source == source);

  @override
  int get hashCode => Object.hash(id, sessionID, messageID, name, source);

  final String id;
  final String sessionID;
  final String messageID;
  final String name;
  final AgentPartSource? source;
}

@immutable
class AgentPartSource {
  const AgentPartSource({
    this.value = '',
    this.start = 0,
    this.end = 0,
  });

  factory AgentPartSource.fromJson(Map<String, dynamic> json) {
    return AgentPartSource(
      value: (json["value"] ?? '') as String,
      start: ((json["start"] ?? 0) as num).toInt(),
      end: ((json["end"] ?? 0) as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "value": value,
      "start": start,
      "end": end,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  AgentPartSource copyWith({
    String? value,
    int? start,
    int? end,
  }) {
    return AgentPartSource(
      value: value ?? this.value,
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AgentPartSource &&
          other.value == value &&
          other.start == start &&
          other.end == end);

  @override
  int get hashCode => Object.hash(value, start, end);

  final String value;
  final int start;
  final int end;
}
