// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feedback_prompt_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FeedbackPromptCounting _$FeedbackPromptCountingFromJson(Map json) =>
    FeedbackPromptCounting(
      pointsBySession:
          (json['pointsBySession'] as Map?)?.map(
            (k, e) => MapEntry(k as String, (e as num).toInt()),
          ) ??
          const <String, int>{},
      lastShownAt: json['lastShownAt'] == null
          ? null
          : DateTime.parse(json['lastShownAt'] as String),
      $type: json['kind'] as String?,
    );

Map<String, dynamic> _$FeedbackPromptCountingToJson(
  FeedbackPromptCounting instance,
) => <String, dynamic>{
  'pointsBySession': instance.pointsBySession,
  'lastShownAt': ?instance.lastShownAt?.toIso8601String(),
  'kind': instance.$type,
};

FeedbackPromptRetired _$FeedbackPromptRetiredFromJson(Map json) =>
    FeedbackPromptRetired($type: json['kind'] as String?);

Map<String, dynamic> _$FeedbackPromptRetiredToJson(
  FeedbackPromptRetired instance,
) => <String, dynamic>{'kind': instance.$type};
