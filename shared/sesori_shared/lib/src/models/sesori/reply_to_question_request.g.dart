// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reply_to_question_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ReplyToQuestionRequest _$ReplyToQuestionRequestFromJson(Map json) =>
    _ReplyToQuestionRequest(
      answers: (json['answers'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$ReplyToQuestionRequestToJson(
  _ReplyToQuestionRequest instance,
) => <String, dynamic>{'answers': instance.answers};
