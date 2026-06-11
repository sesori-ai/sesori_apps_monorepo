// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'event.dart';
import 'question_v2_info.dart';
import 'question_v2_tool.dart';

@immutable
class EventQuestionV2Asked implements Event {
  const EventQuestionV2Asked({
    required this.id,
    required this.properties,
  });

  factory EventQuestionV2Asked.fromJson(Map<String, dynamic> json) {
    return EventQuestionV2Asked(
      id: json["id"] as String,
      properties: EventQuestionV2AskedProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "question.v2.asked",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventQuestionV2Asked &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventQuestionV2AskedProperties properties;
}

@immutable
class EventQuestionV2AskedProperties {
  const EventQuestionV2AskedProperties({
    required this.id,
    required this.sessionID,
    required this.questions,
    this.tool,
  });

  factory EventQuestionV2AskedProperties.fromJson(Map<String, dynamic> json) {
    return EventQuestionV2AskedProperties(
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
      (other is EventQuestionV2AskedProperties &&
          other.id == id &&
          other.sessionID == sessionID &&
          const DeepCollectionEquality().equals(other.questions, questions) &&
          other.tool == tool);

  @override
  int get hashCode => Object.hash(id, sessionID, const DeepCollectionEquality().hash(questions), tool);

  final String id;
  final String sessionID;
  final List<QuestionV2Info> questions;
  final QuestionV2Tool? tool;
}
