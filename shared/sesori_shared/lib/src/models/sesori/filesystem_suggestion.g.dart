// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'filesystem_suggestion.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_FilesystemSuggestionsRequest _$FilesystemSuggestionsRequestFromJson(
  Map json,
) => _FilesystemSuggestionsRequest(
  maxResults: (json['maxResults'] as num).toInt(),
  prefix: json['prefix'] as String?,
);

Map<String, dynamic> _$FilesystemSuggestionsRequestToJson(
  _FilesystemSuggestionsRequest instance,
) => <String, dynamic>{
  'maxResults': instance.maxResults,
  'prefix': instance.prefix,
};

_FilesystemSuggestions _$FilesystemSuggestionsFromJson(Map json) =>
    _FilesystemSuggestions(
      data: (json['data'] as List<dynamic>)
          .map(
            (e) => FilesystemSuggestion.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
    );

Map<String, dynamic> _$FilesystemSuggestionsToJson(
  _FilesystemSuggestions instance,
) => <String, dynamic>{'data': instance.data.map((e) => e.toJson()).toList()};

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
