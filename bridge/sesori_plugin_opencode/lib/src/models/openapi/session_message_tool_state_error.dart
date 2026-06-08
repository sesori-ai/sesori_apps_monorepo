// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T07:51:40.005482Z

import 'session_error_unknown.dart';

class SessionMessageToolStateError {
  const SessionMessageToolStateError({
    required this.status,
    required this.input,
    required this.content,
    required this.structured,
    required this.error,
    this.result,
  });

  factory SessionMessageToolStateError.fromJson(Map<String, dynamic> json) {
    return SessionMessageToolStateError(
      status: json["status"] as String,
      input: json["input"] as Map<String, dynamic>,
      content: (json["content"] as List<dynamic>).cast<dynamic>(),
      structured: json["structured"] as Map<String, dynamic>,
      error: SessionErrorUnknown.fromJson(json["error"] as Map<String, dynamic>),
      result: json["result"],
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "status": status,
      "input": input,
      "content": content,
      "structured": structured,
      "error": error.toJson(),
      "result": ?result,
    };
  }

  final String status;
  final Map<String, dynamic> input;
  final List<dynamic> content;
  final Map<String, dynamic> structured;
  final SessionErrorUnknown error;
  final dynamic result;
}
