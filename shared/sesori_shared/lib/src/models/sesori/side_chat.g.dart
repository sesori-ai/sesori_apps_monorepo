// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'side_chat.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SideChatExchange _$SideChatExchangeFromJson(Map json) => _SideChatExchange(
  id: json['id'] as String,
  question: json['question'] as String,
  answer: json['answer'] as String,
  answerNotice: json['answerNotice'] as String?,
  askedAt: (json['askedAt'] as num).toInt(),
  answeredAt: (json['answeredAt'] as num).toInt(),
);

Map<String, dynamic> _$SideChatExchangeToJson(_SideChatExchange instance) =>
    <String, dynamic>{
      'id': instance.id,
      'question': instance.question,
      'answer': instance.answer,
      'answerNotice': ?instance.answerNotice,
      'askedAt': instance.askedAt,
      'answeredAt': instance.answeredAt,
    };

_SideChat _$SideChatFromJson(Map json) => _SideChat(
  id: json['id'] as String,
  exchanges: (json['exchanges'] as List<dynamic>)
      .map(
        (e) => SideChatExchange.fromJson(Map<String, dynamic>.from(e as Map)),
      )
      .toList(),
);

Map<String, dynamic> _$SideChatToJson(_SideChat instance) => <String, dynamic>{
  'id': instance.id,
  'exchanges': instance.exchanges.map((e) => e.toJson()).toList(),
};

_SideChatListResponse _$SideChatListResponseFromJson(Map json) =>
    _SideChatListResponse(
      sideChats: (json['sideChats'] as List<dynamic>)
          .map((e) => SideChat.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );

Map<String, dynamic> _$SideChatListResponseToJson(
  _SideChatListResponse instance,
) => <String, dynamic>{
  'sideChats': instance.sideChats.map((e) => e.toJson()).toList(),
};

_AskSideQuestionRequest _$AskSideQuestionRequestFromJson(Map json) =>
    _AskSideQuestionRequest(
      sessionId: json['sessionId'] as String,
      sideChatId: json['sideChatId'] as String?,
      question: json['question'] as String,
    );

Map<String, dynamic> _$AskSideQuestionRequestToJson(
  _AskSideQuestionRequest instance,
) => <String, dynamic>{
  'sessionId': instance.sessionId,
  'sideChatId': ?instance.sideChatId,
  'question': instance.question,
};

AskSideQuestionAnswered _$AskSideQuestionAnsweredFromJson(Map json) =>
    AskSideQuestionAnswered(
      sideChatId: json['sideChatId'] as String,
      exchange: SideChatExchange.fromJson(
        Map<String, dynamic>.from(json['exchange'] as Map),
      ),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$AskSideQuestionAnsweredToJson(
  AskSideQuestionAnswered instance,
) => <String, dynamic>{
  'sideChatId': instance.sideChatId,
  'exchange': instance.exchange.toJson(),
  'type': instance.$type,
};

AskSideQuestionRefused _$AskSideQuestionRefusedFromJson(Map json) =>
    AskSideQuestionRefused(
      reason: $enumDecode(
        _$SideQuestionRefusalEnumMap,
        json['reason'],
        unknownValue: SideQuestionRefusal.unknown,
      ),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$AskSideQuestionRefusedToJson(
  AskSideQuestionRefused instance,
) => <String, dynamic>{
  'reason': _$SideQuestionRefusalEnumMap[instance.reason]!,
  'type': instance.$type,
};

const _$SideQuestionRefusalEnumMap = {
  SideQuestionRefusal.harnessUnsupported: 'harnessUnsupported',
  SideQuestionRefusal.harnessUpdateRequired: 'harnessUpdateRequired',
  SideQuestionRefusal.noTurnYet: 'noTurnYet',
  SideQuestionRefusal.tooLong: 'tooLong',
  SideQuestionRefusal.noAnswer: 'noAnswer',
  SideQuestionRefusal.repeatedRunningReply: 'repeatedRunningReply',
  SideQuestionRefusal.unknown: 'unknown',
};

AskSideQuestionUnknown _$AskSideQuestionUnknownFromJson(Map json) =>
    AskSideQuestionUnknown($type: json['type'] as String?);

Map<String, dynamic> _$AskSideQuestionUnknownToJson(
  AskSideQuestionUnknown instance,
) => <String, dynamic>{'type': instance.$type};
