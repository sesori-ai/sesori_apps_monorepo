// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'question.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_QuestionInfo _$QuestionInfoFromJson(Map json) => _QuestionInfo(
  question: json['question'] as String,
  header: json['header'] as String,
  options:
      (json['options'] as List<dynamic>?)
          ?.map(
            (e) => QuestionOption.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList() ??
      const [],
  multiple: json['multiple'] as bool? ?? false,
  custom: json['custom'] as bool? ?? true,
);

Map<String, dynamic> _$QuestionInfoToJson(_QuestionInfo instance) =>
    <String, dynamic>{
      'question': instance.question,
      'header': instance.header,
      'options': instance.options.map((e) => e.toJson()).toList(),
      'multiple': instance.multiple,
      'custom': instance.custom,
    };

_QuestionOption _$QuestionOptionFromJson(Map json) => _QuestionOption(
  label: json['label'] as String,
  description: json['description'] as String,
);

Map<String, dynamic> _$QuestionOptionToJson(_QuestionOption instance) =>
    <String, dynamic>{
      'label': instance.label,
      'description': instance.description,
    };
