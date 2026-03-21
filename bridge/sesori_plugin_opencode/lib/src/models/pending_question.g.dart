// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_question.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PendingQuestion _$PendingQuestionFromJson(Map json) => _PendingQuestion(
  id: json['id'] as String,
  sessionID: json['sessionID'] as String,
  questions: (json['questions'] as List<dynamic>)
      .map((e) => QuestionInfo.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList(),
);

Map<String, dynamic> _$PendingQuestionToJson(_PendingQuestion instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sessionID': instance.sessionID,
      'questions': instance.questions.map((e) => e.toJson()).toList(),
    };
