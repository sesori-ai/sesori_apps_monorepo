// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_prompt_search.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SessionPromptSearchRequest _$SessionPromptSearchRequestFromJson(Map json) =>
    _SessionPromptSearchRequest(
      sessionId: json['sessionId'] as String,
      query: json['query'] as String,
    );

Map<String, dynamic> _$SessionPromptSearchRequestToJson(
  _SessionPromptSearchRequest instance,
) => <String, dynamic>{
  'sessionId': instance.sessionId,
  'query': instance.query,
};

_SessionPromptSearchResponse _$SessionPromptSearchResponseFromJson(Map json) =>
    _SessionPromptSearchResponse(
      matches: (json['matches'] as List<dynamic>)
          .map(
            (e) => SessionPromptSearchMatch.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
    );

Map<String, dynamic> _$SessionPromptSearchResponseToJson(
  _SessionPromptSearchResponse instance,
) => <String, dynamic>{
  'matches': instance.matches.map((e) => e.toJson()).toList(),
};

_SessionPromptSearchMatch _$SessionPromptSearchMatchFromJson(Map json) =>
    _SessionPromptSearchMatch(
      messageId: json['messageId'] as String,
      excerpt: SessionPromptExcerpt.fromJson(
        Map<String, dynamic>.from(json['excerpt'] as Map),
      ),
    );

Map<String, dynamic> _$SessionPromptSearchMatchToJson(
  _SessionPromptSearchMatch instance,
) => <String, dynamic>{
  'messageId': instance.messageId,
  'excerpt': instance.excerpt.toJson(),
};

_SessionPromptExcerpt _$SessionPromptExcerptFromJson(Map json) =>
    _SessionPromptExcerpt(
      before: json['before'] as String,
      match: json['match'] as String,
      after: json['after'] as String,
    );

Map<String, dynamic> _$SessionPromptExcerptToJson(
  _SessionPromptExcerpt instance,
) => <String, dynamic>{
  'before': instance.before,
  'match': instance.match,
  'after': instance.after,
};
