// GENERATED FILE - DO NOT EDIT BY HAND

import 'prompt_agent_attachment.dart';
import 'prompt_file_attachment.dart';
import 'prompt_reference_attachment.dart';

class Prompt {
  const Prompt({
    required this.text,
    this.files,
    this.agents,
    this.references,
  });

  factory Prompt.fromJson(Map<String, dynamic> json) {
    return Prompt(
      text: json["text"] as String,
      files: (json["files"] as List<dynamic>?)?.map((e) => PromptFileAttachment.fromJson(e as Map<String, dynamic>)).toList(),
      agents: (json["agents"] as List<dynamic>?)?.map((e) => PromptAgentAttachment.fromJson(e as Map<String, dynamic>)).toList(),
      references: (json["references"] as List<dynamic>?)?.map((e) => PromptReferenceAttachment.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "text": text,
      "files": files,
      "agents": agents,
      "references": references,
    };
  }

  final String text;
  final List<PromptFileAttachment>? files;
  final List<PromptAgentAttachment>? agents;
  final List<PromptReferenceAttachment>? references;
}
