// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_glossary_words_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ProjectGlossaryWordsRequest _$ProjectGlossaryWordsRequestFromJson(Map json) =>
    _ProjectGlossaryWordsRequest(
      projectKey: json['projectKey'] as String,
      words: (json['words'] as List<dynamic>).map((e) => e as String).toList(),
    );

Map<String, dynamic> _$ProjectGlossaryWordsRequestToJson(
  _ProjectGlossaryWordsRequest instance,
) => <String, dynamic>{
  'projectKey': instance.projectKey,
  'words': instance.words,
};
