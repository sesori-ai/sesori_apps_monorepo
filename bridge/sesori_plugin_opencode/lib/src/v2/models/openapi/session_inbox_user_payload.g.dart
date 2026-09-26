// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.18 (cd9a14a6b688d4021bee381dfd39d2cef9c0f862)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'prompt_agent_attachment.g.dart';
import 'prompt_file_attachment.g.dart';
import 'prompt_skill_attachment.g.dart';

@immutable
class SessionInboxUserPayload {
  const SessionInboxUserPayload({
    required this.text,
    required this.files,
    required this.agents,
    required this.skills,
    required this.metadata,
  });

  factory SessionInboxUserPayload.fromJson(Map<String, dynamic> json) {
    return SessionInboxUserPayload(
      text: json["text"] as String,
      files: (json["files"] as List<dynamic>?)?.map((e) => PromptFileAttachment.fromJson(e as Map<String, dynamic>)).toList(),
      agents: (json["agents"] as List<dynamic>?)?.map((e) => PromptAgentAttachment.fromJson(e as Map<String, dynamic>)).toList(),
      skills: (json["skills"] as List<dynamic>?)?.map((e) => PromptSkillAttachment.fromJson(e as Map<String, dynamic>)).toList(),
      metadata: json["metadata"] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "text": text,
      "files": ?files?.map((e) => e.toJson()).toList(),
      "agents": ?agents?.map((e) => e.toJson()).toList(),
      "skills": ?skills?.map((e) => e.toJson()).toList(),
      "metadata": ?metadata,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionInboxUserPayload copyWith({
    String? text,
    List<PromptFileAttachment>? files,
    List<PromptAgentAttachment>? agents,
    List<PromptSkillAttachment>? skills,
    Map<String, dynamic>? metadata,
  }) {
    return SessionInboxUserPayload(
      text: text ?? this.text,
      files: files ?? this.files,
      agents: agents ?? this.agents,
      skills: skills ?? this.skills,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionInboxUserPayload &&
          other.text == text &&
          const DeepCollectionEquality().equals(other.files, files) &&
          const DeepCollectionEquality().equals(other.agents, agents) &&
          const DeepCollectionEquality().equals(other.skills, skills) &&
          const DeepCollectionEquality().equals(other.metadata, metadata));

  @override
  int get hashCode => Object.hash(text, const DeepCollectionEquality().hash(files), const DeepCollectionEquality().hash(agents), const DeepCollectionEquality().hash(skills), const DeepCollectionEquality().hash(metadata));

  final String text;
  final List<PromptFileAttachment>? files;
  final List<PromptAgentAttachment>? agents;
  final List<PromptSkillAttachment>? skills;
  final Map<String, dynamic>? metadata;
}
