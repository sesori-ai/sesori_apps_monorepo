// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:04:07.994041Z

import 'package:meta/meta.dart';
import 'prompt_file_attachment.dart';

@immutable
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
      content: (json["content"] as List<dynamic>).cast<Object>(),
      structured: json["structured"] as Map<String, dynamic>,
      result: json["result"] as Object?,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "status": status,
      "input": input,
      "attachments": ?attachments?.map((e) => e.toJson()).toList(),
      "content": content,
      "structured": structured,
      "result": ?result,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageToolStateCompleted &&
          other.status == status &&
          other.input == input &&
          other.attachments == attachments &&
          other.content == content &&
          other.structured == structured &&
          other.result == result);

  @override
  int get hashCode => Object.hash(status, input, attachments, content, structured, result);

  final String status;
  final Map<String, dynamic> input;
  final List<PromptFileAttachment>? attachments;
  final List<Object> content;
  final Map<String, dynamic> structured;
  final Object? result;
}
