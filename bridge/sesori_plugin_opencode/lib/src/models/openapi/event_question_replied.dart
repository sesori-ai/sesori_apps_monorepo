// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'event.dart';
import 'question_answer.dart';

@immutable
class EventQuestionReplied implements Event {
  const EventQuestionReplied({
    required this.id,
    required this.properties,
  });

  factory EventQuestionReplied.fromJson(Map<String, dynamic> json) {
    return EventQuestionReplied(
      id: json["id"] as String,
      properties: EventQuestionRepliedProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "question.replied",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventQuestionReplied &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventQuestionRepliedProperties properties;
}

@immutable
class EventQuestionRepliedProperties {
  const EventQuestionRepliedProperties({
    required this.sessionID,
    required this.requestID,
    required this.answers,
  });

  factory EventQuestionRepliedProperties.fromJson(Map<String, dynamic> json) {
    return EventQuestionRepliedProperties(
      sessionID: json["sessionID"] as String,
      requestID: json["requestID"] as String,
      answers: (json["answers"] as List<dynamic>).map((e) => QuestionAnswer.fromJson(e as List<dynamic>)).toList(),
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
      (other is EventQuestionRepliedProperties &&
          other.sessionID == sessionID &&
          other.requestID == requestID &&
          const DeepCollectionEquality().equals(other.answers, answers));

  @override
  int get hashCode => Object.hash(sessionID, requestID, const DeepCollectionEquality().hash(answers));

  final String sessionID;
  final String requestID;
  final List<QuestionAnswer> answers;
}
