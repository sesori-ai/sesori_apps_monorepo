// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:04:07.994595Z

import 'package:meta/meta.dart';

@immutable
class SessionMessageToolStateRunning {
  const SessionMessageToolStateRunning({
    required this.status,
    required this.input,
    required this.structured,
    required this.content,
  });

  factory SessionMessageToolStateRunning.fromJson(Map<String, dynamic> json) {
    return SessionMessageToolStateRunning(
      status: json["status"] as String,
      input: json["input"] as Map<String, dynamic>,
      structured: json["structured"] as Map<String, dynamic>,
      content: (json["content"] as List<dynamic>).cast<Object>(),
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "status": status,
      "input": input,
      "structured": structured,
      "content": content,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageToolStateRunning &&
          other.status == status &&
          other.input == input &&
          other.structured == structured &&
          other.content == content);

  @override
  int get hashCode => Object.hash(status, input, structured, content);

  final String status;
  final Map<String, dynamic> input;
  final Map<String, dynamic> structured;
  final List<Object> content;
}
