// GENERATED FILE - DO NOT EDIT BY HAND

import 'prompt_file_attachment.dart';

class SessionMessageToolStateCompleted {
  const SessionMessageToolStateCompleted({
    required this.status,
    required this.input,
    this.attachments,
    required this.content,
    this.outputPaths,
    required this.structured,
    this.result,
  });

  factory SessionMessageToolStateCompleted.fromJson(Map<String, dynamic> json) {
    return SessionMessageToolStateCompleted(
      status: json["status"] as String,
      input: json["input"] as Map<String, dynamic>,
      attachments: (json["attachments"] as List<dynamic>?)?.map((e) => PromptFileAttachment.fromJson(e as Map<String, dynamic>)).toList(),
      content: (json["content"] as List<dynamic>).cast<dynamic>(),
      outputPaths: (json["outputPaths"] as List<dynamic>?)?.cast<String>(),
      structured: json["structured"] as Map<String, dynamic>,
      result: json["result"],
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "status": status,
      "input": input,
      "attachments": attachments,
      "content": content,
      "outputPaths": outputPaths,
      "structured": structured,
      "result": result,
    };
  }

  final String status;
  final Map<String, dynamic> input;
  final List<PromptFileAttachment>? attachments;
  final List<dynamic> content;
  final List<String>? outputPaths;
  final Map<String, dynamic> structured;
  final dynamic result;
}
