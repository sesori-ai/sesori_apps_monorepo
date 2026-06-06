// GENERATED FILE - DO NOT EDIT BY HAND

import 'question_info.dart';
import 'question_tool.dart';

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
      "questions": questions,
      "tool": tool?.toJson(),
    };
  }

  final String id;
  final String sessionID;
  final List<QuestionInfo> questions;
  final QuestionTool? tool;
}
