// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-07T10:22:51.679991Z

import 'prompt_file_attachment.dart';

class SessionMessageToolStateCompleted {
  const SessionMessageToolStateCompleted({
    required this.status,
    required this.input,
    this.attachments,
    required this.content,
    required this.structured,
    this.result,
  });

  factory SessionMessageToolStateCompleted.fromJson(Map<String, dynamic> json) {
    return SessionMessageToolStateCompleted(
      status: json["status"] as String,
      input: json["input"] as Map<String, dynamic>,
      attachments: (json["attachments"] as List<dynamic>?)?.map((e) => PromptFileAttachment.fromJson(e as Map<String, dynamic>)).toList(),
      content: (json["content"] as List<dynamic>).cast<dynamic>(),
      structured: json["structured"] as Map<String, dynamic>,
      result: json["result"],
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "status": status,
      "input": input,
      "attachments": attachments?.map((e) => e.toJson()).toList(),
      "content": content,
      "structured": structured,
      "result": result,
    };
  }

  final String status;
  final Map<String, dynamic> input;
  final List<PromptFileAttachment>? attachments;
  final List<dynamic> content;
  final Map<String, dynamic> structured;
  final dynamic result;
}
