// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.16 (3a103fe0aff726a4edc7492f03f7b88195d9e4c9)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'prompt_agent_attachment.g.dart';
import 'prompt_file_attachment.g.dart';
import 'prompt_skill_attachment.g.dart';
import 'session_message_info.g.dart';

@immutable
class SessionMessageUser implements SessionMessageInfo {
  const SessionMessageUser({
    required this.id,
    required this.metadata,
    required this.time,
    required this.text,
    required this.files,
    required this.agents,
    required this.skills,
  });

  factory SessionMessageUser.fromJson(Map<String, dynamic> json) {
    return SessionMessageUser(
      id: json["id"] as String,
      metadata: json["metadata"] as Map<String, dynamic>?,
      time: SessionMessageUserTime.fromJson(json["time"] as Map<String, dynamic>),
      text: json["text"] as String,
      files: (json["files"] as List<dynamic>?)?.map((e) => PromptFileAttachment.fromJson(e as Map<String, dynamic>)).toList(),
      agents: (json["agents"] as List<dynamic>?)?.map((e) => PromptAgentAttachment.fromJson(e as Map<String, dynamic>)).toList(),
      skills: (json["skills"] as List<dynamic>?)?.map((e) => PromptSkillAttachment.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "metadata": ?metadata,
      "time": time.toJson(),
      "text": text,
      "files": ?files?.map((e) => e.toJson()).toList(),
      "agents": ?agents?.map((e) => e.toJson()).toList(),
      "skills": ?skills?.map((e) => e.toJson()).toList(),
      "type": "user",
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionMessageUser copyWith({
    String? id,
    Map<String, dynamic>? metadata,
    SessionMessageUserTime? time,
    String? text,
    List<PromptFileAttachment>? files,
    List<PromptAgentAttachment>? agents,
    List<PromptSkillAttachment>? skills,
  }) {
    return SessionMessageUser(
      id: id ?? this.id,
      metadata: metadata ?? this.metadata,
      time: time ?? this.time,
      text: text ?? this.text,
      files: files ?? this.files,
      agents: agents ?? this.agents,
      skills: skills ?? this.skills,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageUser &&
          other.id == id &&
          const DeepCollectionEquality().equals(other.metadata, metadata) &&
          other.time == time &&
          other.text == text &&
          const DeepCollectionEquality().equals(other.files, files) &&
          const DeepCollectionEquality().equals(other.agents, agents) &&
          const DeepCollectionEquality().equals(other.skills, skills));

  @override
  int get hashCode => Object.hash(id, const DeepCollectionEquality().hash(metadata), time, text, const DeepCollectionEquality().hash(files), const DeepCollectionEquality().hash(agents), const DeepCollectionEquality().hash(skills));

  final String id;
  final Map<String, dynamic>? metadata;
  final SessionMessageUserTime time;
  final String text;
  final List<PromptFileAttachment>? files;
  final List<PromptAgentAttachment>? agents;
  final List<PromptSkillAttachment>? skills;
}

@immutable
class SessionMessageUserTime {
  const SessionMessageUserTime({
    required this.created,
  });

  factory SessionMessageUserTime.fromJson(Map<String, dynamic> json) {
    return SessionMessageUserTime(
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
  SessionMessageUserTime copyWith({
    double? created,
  }) {
    return SessionMessageUserTime(
      created: created ?? this.created,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageUserTime &&
          other.created == created);

  @override
  int get hashCode => created.hashCode;

  final double created;
}
