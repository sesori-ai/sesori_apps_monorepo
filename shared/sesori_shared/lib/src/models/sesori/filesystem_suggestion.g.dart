// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'filesystem_suggestion.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_FilesystemSuggestion _$FilesystemSuggestionFromJson(Map json) =>
    _FilesystemSuggestion(
      path: json['path'] as String,
      name: json['name'] as String,
      isGitRepo: json['isGitRepo'] as bool,
    );

Map<String, dynamic> _$FilesystemSuggestionToJson(
  _FilesystemSuggestion instance,
) => <String, dynamic>{
  'path': instance.path,
  'name': instance.name,
  'isGitRepo': instance.isGitRepo,
};
