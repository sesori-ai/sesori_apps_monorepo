// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.16 (3a103fe0aff726a4edc7492f03f7b88195d9e4c9)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'session_message_info.g.dart';

@immutable
class SessionMessageSkill implements SessionMessageInfo {
  const SessionMessageSkill({
    required this.id,
    required this.metadata,
    required this.time,
    required this.skill,
    required this.name,
    required this.text,
  });

  factory SessionMessageSkill.fromJson(Map<String, dynamic> json) {
    return SessionMessageSkill(
      id: json["id"] as String,
      metadata: json["metadata"] as Map<String, dynamic>?,
      time: SessionMessageSkillTime.fromJson(json["time"] as Map<String, dynamic>),
      skill: json["skill"] as String,
      name: json["name"] as String,
      text: json["text"] as String,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "metadata": ?metadata,
      "time": time.toJson(),
      "type": "skill",
      "skill": skill,
      "name": name,
      "text": text,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionMessageSkill copyWith({
    String? id,
    Map<String, dynamic>? metadata,
    SessionMessageSkillTime? time,
    String? skill,
    String? name,
    String? text,
  }) {
    return SessionMessageSkill(
      id: id ?? this.id,
      metadata: metadata ?? this.metadata,
      time: time ?? this.time,
      skill: skill ?? this.skill,
      name: name ?? this.name,
      text: text ?? this.text,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageSkill &&
          other.id == id &&
          const DeepCollectionEquality().equals(other.metadata, metadata) &&
          other.time == time &&
          other.skill == skill &&
          other.name == name &&
          other.text == text);

  @override
  int get hashCode => Object.hash(id, const DeepCollectionEquality().hash(metadata), time, skill, name, text);

  final String id;
  final Map<String, dynamic>? metadata;
  final SessionMessageSkillTime time;
  final String skill;
  final String name;
  final String text;
}

@immutable
class SessionMessageSkillTime {
  const SessionMessageSkillTime({
    required this.created,
  });

  factory SessionMessageSkillTime.fromJson(Map<String, dynamic> json) {
    return SessionMessageSkillTime(
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
  SessionMessageSkillTime copyWith({
    double? created,
  }) {
    return SessionMessageSkillTime(
      created: created ?? this.created,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageSkillTime &&
          other.created == created);

  @override
  int get hashCode => created.hashCode;

  final double created;
}
