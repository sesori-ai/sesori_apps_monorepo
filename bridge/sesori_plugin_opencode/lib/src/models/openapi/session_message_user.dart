// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'prompt_agent_attachment.dart';
import 'prompt_file_attachment.dart';
import 'prompt_reference_attachment.dart';
import 'session_message.dart';

@immutable
class SessionMessageUser implements SessionMessage {
  const SessionMessageUser({
    required this.id,
    this.metadata,
    required this.time,
    required this.text,
    this.files,
    this.agents,
    this.references,
  });

  factory SessionMessageUser.fromJson(Map<String, dynamic> json) {
    return SessionMessageUser(
      id: json["id"] as String,
      metadata: json["metadata"] as Map<String, dynamic>?,
      time: SessionMessageUserTime.fromJson(json["time"] as Map<String, dynamic>),
      text: json["text"] as String,
      files: (json["files"] as List<dynamic>?)?.map((e) => PromptFileAttachment.fromJson(e as Map<String, dynamic>)).toList(),
      agents: (json["agents"] as List<dynamic>?)?.map((e) => PromptAgentAttachment.fromJson(e as Map<String, dynamic>)).toList(),
      references: (json["references"] as List<dynamic>?)?.map((e) => PromptReferenceAttachment.fromJson(e as Map<String, dynamic>)).toList(),
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
      "references": ?references?.map((e) => e.toJson()).toList(),
      "type": "user",
    };
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
          const DeepCollectionEquality().equals(other.references, references));

  @override
  int get hashCode => Object.hash(id, const DeepCollectionEquality().hash(metadata), time, text, const DeepCollectionEquality().hash(files), const DeepCollectionEquality().hash(agents), const DeepCollectionEquality().hash(references));

  final String id;
  final Map<String, dynamic>? metadata;
  final SessionMessageUserTime time;
  final String text;
  final List<PromptFileAttachment>? files;
  final List<PromptAgentAttachment>? agents;
  final List<PromptReferenceAttachment>? references;
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageUserTime &&
          other.created == created);

  @override
  int get hashCode => created.hashCode;

  final double created;
}
