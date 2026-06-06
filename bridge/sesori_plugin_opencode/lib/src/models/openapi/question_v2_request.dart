// GENERATED FILE - DO NOT EDIT BY HAND

import 'question_v2_info.dart';
import 'question_v2_tool.dart';

class QuestionV2Request {
  const QuestionV2Request({
    required this.id,
    required this.sessionID,
    required this.questions,
    this.tool,
  });

  factory QuestionV2Request.fromJson(Map<String, dynamic> json) {
    return QuestionV2Request(
      id: json["id"] as String,
      sessionID: json["sessionID"] as String,
      questions: (json["questions"] as List<dynamic>).map((e) => QuestionV2Info.fromJson(e as Map<String, dynamic>)).toList(),
      tool: json["tool"] == null ? null : QuestionV2Tool.fromJson(json["tool"] as Map<String, dynamic>),
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
  final List<QuestionV2Info> questions;
  final QuestionV2Tool? tool;
}
