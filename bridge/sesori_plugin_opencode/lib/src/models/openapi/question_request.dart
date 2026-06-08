// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:04:07.986311Z

import 'package:meta/meta.dart';
import 'question_info.dart';
import 'question_tool.dart';

@immutable
class QuestionRequest {
  const QuestionRequest({
    required this.id,
    required this.sessionID,
    required this.questions,
    this.tool,
  });

  factory QuestionRequest.fromJson(Map<String, dynamic> json) {
    return QuestionRequest(
      id: json["id"] as String,
      sessionID: json["sessionID"] as String,
      questions: (json["questions"] as List<dynamic>).map((e) => QuestionInfo.fromJson(e as Map<String, dynamic>)).toList(),
      tool: json["tool"] == null ? null : QuestionTool.fromJson(json["tool"] as Map<String, dynamic>),
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "sessionID": sessionID,
      "questions": questions.map((e) => e.toJson()).toList(),
      "tool": ?tool?.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QuestionRequest &&
          other.id == id &&
          other.sessionID == sessionID &&
          other.questions == questions &&
          other.tool == tool);

  @override
  int get hashCode => Object.hash(id, sessionID, questions, tool);

  final String id;
  final String sessionID;
  final List<QuestionInfo> questions;
  final QuestionTool? tool;
}
