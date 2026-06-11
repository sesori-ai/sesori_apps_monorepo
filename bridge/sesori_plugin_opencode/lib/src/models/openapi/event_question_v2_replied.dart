// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'event.dart';
import 'question_v2_answer.dart';

@immutable
class EventQuestionV2Replied implements Event {
  const EventQuestionV2Replied({
    required this.id,
    required this.properties,
  });

  factory EventQuestionV2Replied.fromJson(Map<String, dynamic> json) {
    return EventQuestionV2Replied(
      id: json["id"] as String,
      properties: EventQuestionV2RepliedProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "question.v2.replied",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventQuestionV2Replied &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventQuestionV2RepliedProperties properties;
}

@immutable
class EventQuestionV2RepliedProperties {
  const EventQuestionV2RepliedProperties({
    required this.sessionID,
    required this.requestID,
    required this.answers,
  });

  factory EventQuestionV2RepliedProperties.fromJson(Map<String, dynamic> json) {
    return EventQuestionV2RepliedProperties(
      sessionID: json["sessionID"] as String,
      requestID: json["requestID"] as String,
      answers: (json["answers"] as List<dynamic>).map((e) => QuestionV2Answer.fromJson(e as List<dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "sessionID": sessionID,
      "requestID": requestID,
      "answers": answers.map((e) => e.toJson()).toList(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventQuestionV2RepliedProperties &&
          other.sessionID == sessionID &&
          other.requestID == requestID &&
          const DeepCollectionEquality().equals(other.answers, answers));

  @override
  int get hashCode => Object.hash(sessionID, requestID, const DeepCollectionEquality().hash(answers));

  final String sessionID;
  final String requestID;
  final List<QuestionV2Answer> answers;
}
