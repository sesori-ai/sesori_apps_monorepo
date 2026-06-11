// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';

@immutable
class AgentPartInput {
  const AgentPartInput({
    this.id,
    this.type = '',
    this.name = '',
    this.source,
  });

  factory AgentPartInput.fromJson(Map<String, dynamic> json) {
    return AgentPartInput(
      id: json["id"] as String?,
      type: (json["type"] ?? '') as String,
      name: (json["name"] ?? '') as String,
      source: json["source"] == null ? null : AgentPartInputSource.fromJson(json["source"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": ?id,
      "type": type,
      "name": name,
      "source": ?source?.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  AgentPartInput copyWith({
    String? id,
    String? type,
    String? name,
    AgentPartInputSource? source,
  }) {
    return AgentPartInput(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      source: source ?? this.source,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AgentPartInput &&
          other.id == id &&
          other.type == type &&
          other.name == name &&
          other.source == source);

  @override
  int get hashCode => Object.hash(id, type, name, source);

  final String? id;
  final String type;
  final String name;
  final AgentPartInputSource? source;
}

@immutable
class AgentPartInputSource {
  const AgentPartInputSource({
    this.value = '',
    this.start = 0,
    this.end = 0,
  });

  factory AgentPartInputSource.fromJson(Map<String, dynamic> json) {
    return AgentPartInputSource(
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
  AgentPartInputSource copyWith({
    String? value,
    int? start,
    int? end,
  }) {
    return AgentPartInputSource(
      value: value ?? this.value,
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AgentPartInputSource &&
          other.value == value &&
          other.start == start &&
          other.end == end);

  @override
  int get hashCode => Object.hash(value, start, end);

  final String value;
  final int start;
  final int end;
}
