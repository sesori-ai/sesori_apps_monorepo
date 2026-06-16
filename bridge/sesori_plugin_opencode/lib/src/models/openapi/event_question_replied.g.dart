// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'event.g.dart';
import 'question_answer.g.dart';

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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventQuestionReplied copyWith({
    String? id,
    EventQuestionRepliedProperties? properties,
  }) {
    return EventQuestionReplied(
      id: id ?? this.id,
      properties: properties ?? this.properties,
    );
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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventQuestionRepliedProperties copyWith({
    String? sessionID,
    String? requestID,
    List<QuestionAnswer>? answers,
  }) {
    return EventQuestionRepliedProperties(
      sessionID: sessionID ?? this.sessionID,
      requestID: requestID ?? this.requestID,
      answers: answers ?? this.answers,
    );
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
