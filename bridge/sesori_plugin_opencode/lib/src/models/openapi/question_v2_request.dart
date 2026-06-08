// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:11:43.955855Z

import 'package:meta/meta.dart';
import 'question_v2_info.dart';
import 'question_v2_tool.dart';

@immutable
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
      "questions": questions.map((e) => e.toJson()).toList(),
      "tool": ?tool?.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QuestionV2Request &&
          other.id == id &&
          other.sessionID == sessionID &&
          other.questions == questions &&
          other.tool == tool);

  @override
  int get hashCode => Object.hash(id, sessionID, questions, tool);

  final String id;
  final String sessionID;
  final List<QuestionV2Info> questions;
  final QuestionV2Tool? tool;
}
