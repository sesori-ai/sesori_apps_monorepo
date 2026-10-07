// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_prompt_index.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SessionPromptIndexResponse _$SessionPromptIndexResponseFromJson(Map json) =>
    _SessionPromptIndexResponse(
      entries: (json['entries'] as List<dynamic>)
          .map(
            (e) => SessionPromptIndexEntry.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
    );

Map<String, dynamic> _$SessionPromptIndexResponseToJson(
  _SessionPromptIndexResponse instance,
) => <String, dynamic>{
  'entries': instance.entries.map((e) => e.toJson()).toList(),
};

SessionPromptIndexOpener _$SessionPromptIndexOpenerFromJson(Map json) =>
    SessionPromptIndexOpener(
      messageId: json['messageId'] as String,
      seq: (json['seq'] as num).toInt(),
      number: (json['number'] as num).toInt(),
      createdAt: (json['createdAt'] as num?)?.toInt(),
      preview: json['preview'] as String?,
      $type: json['kind'] as String?,
    );

Map<String, dynamic> _$SessionPromptIndexOpenerToJson(
  SessionPromptIndexOpener instance,
) => <String, dynamic>{
  'messageId': instance.messageId,
  'seq': instance.seq,
  'number': instance.number,
  'createdAt': ?instance.createdAt,
  'preview': ?instance.preview,
  'kind': instance.$type,
};

SessionPromptIndexFollowUp _$SessionPromptIndexFollowUpFromJson(Map json) =>
    SessionPromptIndexFollowUp(
      messageId: json['messageId'] as String,
      seq: (json['seq'] as num).toInt(),
      number: (json['number'] as num).toInt(),
      createdAt: (json['createdAt'] as num?)?.toInt(),
      preview: json['preview'] as String?,
      openerMessageId: json['openerMessageId'] as String,
      $type: json['kind'] as String?,
    );

Map<String, dynamic> _$SessionPromptIndexFollowUpToJson(
  SessionPromptIndexFollowUp instance,
) => <String, dynamic>{
  'messageId': instance.messageId,
  'seq': instance.seq,
  'number': instance.number,
  'createdAt': ?instance.createdAt,
  'preview': ?instance.preview,
  'openerMessageId': instance.openerMessageId,
  'kind': instance.$type,
};
