// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.18 (cd9a14a6b688d4021bee381dfd39d2cef9c0f862)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'session_message_info.g.dart';

@immutable
class SessionMessageSystem implements SessionMessageInfo {
  const SessionMessageSystem({
    required this.id,
    required this.metadata,
    required this.time,
    required this.text,
    required this.description,
  });

  factory SessionMessageSystem.fromJson(Map<String, dynamic> json) {
    return SessionMessageSystem(
      id: json["id"] as String,
      metadata: json["metadata"] as Map<String, dynamic>?,
      time: SessionMessageSystemTime.fromJson(json["time"] as Map<String, dynamic>),
      text: json["text"] as String,
      description: json["description"] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "metadata": ?metadata,
      "time": time.toJson(),
      "type": "system",
      "text": text,
      "description": ?description,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionMessageSystem copyWith({
    String? id,
    Map<String, dynamic>? metadata,
    SessionMessageSystemTime? time,
    String? text,
    String? description,
  }) {
    return SessionMessageSystem(
      id: id ?? this.id,
      metadata: metadata ?? this.metadata,
      time: time ?? this.time,
      text: text ?? this.text,
      description: description ?? this.description,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageSystem &&
          other.id == id &&
          const DeepCollectionEquality().equals(other.metadata, metadata) &&
          other.time == time &&
          other.text == text &&
          other.description == description);

  @override
  int get hashCode => Object.hash(id, const DeepCollectionEquality().hash(metadata), time, text, description);

  final String id;
  final Map<String, dynamic>? metadata;
  final SessionMessageSystemTime time;
  final String text;
  final String? description;
}

@immutable
class SessionMessageSystemTime {
  const SessionMessageSystemTime({
    required this.created,
  });

  factory SessionMessageSystemTime.fromJson(Map<String, dynamic> json) {
    return SessionMessageSystemTime(
      created: (json["created"] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "created": created,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionMessageSystemTime copyWith({
    double? created,
  }) {
    return SessionMessageSystemTime(
      created: created ?? this.created,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageSystemTime &&
          other.created == created);

  @override
  int get hashCode => created.hashCode;

  final double created;
}
