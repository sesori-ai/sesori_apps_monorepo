// GENERATED FILE - DO NOT EDIT BY HAND

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
    required this.type,
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
      type: json["type"] as String,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "metadata": metadata,
      "time": time,
      "text": text,
      "files": files,
      "agents": agents,
      "references": references,
      "type": type,
    };
  }

  final String id;
  final Map<String, dynamic>? metadata;
  final Map<String, dynamic> time;
  final String text;
  final List<PromptFileAttachment>? files;
  final List<PromptAgentAttachment>? agents;
  final List<PromptReferenceAttachment>? references;
  final String type;
}
