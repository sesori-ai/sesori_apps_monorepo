// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_glossary_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ProjectGlossaryWordsResponse _$ProjectGlossaryWordsResponseFromJson(
  Map json,
) => _ProjectGlossaryWordsResponse(
  words: (json['words'] as List<dynamic>).map((e) => e as String).toList(),
);

_ProjectGlossaryAddedWordsResponse _$ProjectGlossaryAddedWordsResponseFromJson(
  Map json,
) => _ProjectGlossaryAddedWordsResponse(
  added: (json['added'] as List<dynamic>).map((e) => e as String).toList(),
);

_ProjectGlossaryRemovedWordsResponse
_$ProjectGlossaryRemovedWordsResponseFromJson(Map json) =>
    _ProjectGlossaryRemovedWordsResponse(
      removed: (json['removed'] as num).toInt(),
    );
