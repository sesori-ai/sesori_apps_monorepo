// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plugin_pending_question.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$PluginQuestionOptionToJson(
  _PluginQuestionOption instance,
) => <String, dynamic>{
  'label': instance.label,
  'description': instance.description,
};

Map<String, dynamic> _$PluginQuestionInfoToJson(_PluginQuestionInfo instance) =>
    <String, dynamic>{
      'question': instance.question,
      'header': instance.header,
      'options': instance.options.map((e) => e.toJson()).toList(),
      'multiple': instance.multiple,
      'custom': instance.custom,
    };

Map<String, dynamic> _$PluginPendingQuestionToJson(
  _PluginPendingQuestion instance,
) => <String, dynamic>{
  'id': instance.id,
  'sessionID': instance.sessionID,
  'questions': instance.questions.map((e) => e.toJson()).toList(),
};
