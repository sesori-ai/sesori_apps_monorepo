// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_glossary_words_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ProjectGlossaryWordsRequest _$ProjectGlossaryWordsRequestFromJson(Map json) =>
    _ProjectGlossaryWordsRequest(
      scope: ProjectGlossaryScope.fromJson(
        Map<String, dynamic>.from(json['scope'] as Map),
      ),
      words: (json['words'] as List<dynamic>).map((e) => e as String).toList(),
    );

Map<String, dynamic> _$ProjectGlossaryWordsRequestToJson(
  _ProjectGlossaryWordsRequest instance,
) => <String, dynamic>{
  'scope': instance.scope.toJson(),
  'words': instance.words,
};
