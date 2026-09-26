// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.16 (3a103fe0aff726a4edc7492f03f7b88195d9e4c9)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'session_message_info.g.dart';

@immutable
class SessionMessageSynthetic implements SessionMessageInfo {
  const SessionMessageSynthetic({
    required this.id,
    required this.metadata,
    required this.time,
    required this.text,
    required this.description,
  });

  factory SessionMessageSynthetic.fromJson(Map<String, dynamic> json) {
    return SessionMessageSynthetic(
      id: json["id"] as String,
      metadata: json["metadata"] as Map<String, dynamic>?,
      time: SessionMessageSyntheticTime.fromJson(json["time"] as Map<String, dynamic>),
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
      "text": text,
      "description": ?description,
      "type": "synthetic",
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionMessageSynthetic copyWith({
    String? id,
    Map<String, dynamic>? metadata,
    SessionMessageSyntheticTime? time,
    String? text,
    String? description,
  }) {
    return SessionMessageSynthetic(
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
      (other is SessionMessageSynthetic &&
          other.id == id &&
          const DeepCollectionEquality().equals(other.metadata, metadata) &&
          other.time == time &&
          other.text == text &&
          other.description == description);

  @override
  int get hashCode => Object.hash(id, const DeepCollectionEquality().hash(metadata), time, text, description);

  final String id;
  final Map<String, dynamic>? metadata;
  final SessionMessageSyntheticTime time;
  final String text;
  final String? description;
}

@immutable
class SessionMessageSyntheticTime {
  const SessionMessageSyntheticTime({
    required this.created,
  });

  factory SessionMessageSyntheticTime.fromJson(Map<String, dynamic> json) {
    return SessionMessageSyntheticTime(
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
  SessionMessageSyntheticTime copyWith({
    double? created,
  }) {
    return SessionMessageSyntheticTime(
      created: created ?? this.created,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageSyntheticTime &&
          other.created == created);

  @override
  int get hashCode => created.hashCode;

  final double created;
}
