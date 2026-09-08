// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.7 (4ed4f749e644ffb5b279fb30b7b915e743d80142)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'question_info.g.dart';
import 'question_tool.g.dart';

@immutable
class QuestionRequest {
  const QuestionRequest({
    required this.id,
    required this.sessionID,
    required this.questions,
    required this.tool,
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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  QuestionRequest copyWith({
    String? id,
    String? sessionID,
    List<QuestionInfo>? questions,
    QuestionTool? tool,
  }) {
    return QuestionRequest(
      id: id ?? this.id,
      sessionID: sessionID ?? this.sessionID,
      questions: questions ?? this.questions,
      tool: tool ?? this.tool,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QuestionRequest &&
          other.id == id &&
          other.sessionID == sessionID &&
          const DeepCollectionEquality().equals(other.questions, questions) &&
          other.tool == tool);

  @override
  int get hashCode => Object.hash(id, sessionID, const DeepCollectionEquality().hash(questions), tool);

  final String id;
  final String sessionID;
  final List<QuestionInfo> questions;
  final QuestionTool? tool;
}
