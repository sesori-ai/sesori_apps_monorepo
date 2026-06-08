// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T08:11:58.921496Z

import 'prompt_agent_attachment.dart';
import 'prompt_file_attachment.dart';
import 'prompt_reference_attachment.dart';
import 'session_message.dart';

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
      time: json["time"] as Map<String, dynamic>,
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
      "time": time,
      "text": text,
      "files": ?files?.map((e) => e.toJson()).toList(),
      "agents": ?agents?.map((e) => e.toJson()).toList(),
      "references": ?references?.map((e) => e.toJson()).toList(),
      "type": "user",
    };
  }

  final String id;
  final Map<String, dynamic>? metadata;
  final Map<String, dynamic> time;
  final String text;
  final List<PromptFileAttachment>? files;
  final List<PromptAgentAttachment>? agents;
  final List<PromptReferenceAttachment>? references;
}
