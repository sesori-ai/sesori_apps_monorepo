// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Message _$MessageFromJson(Map json) => _Message(
  role: json['role'] as String,
  id: json['id'] as String,
  sessionID: json['sessionID'] as String,
  parentID: json['parentID'] as String?,
  agent: json['agent'] as String?,
  modelID: json['modelID'] as String?,
  providerID: json['providerID'] as String?,
  cost: (json['cost'] as num?)?.toDouble(),
  tokens: json['tokens'] == null
      ? null
      : MessageTokens.fromJson(
          Map<String, dynamic>.from(json['tokens'] as Map),
        ),
  time: json['time'] == null ? null : MessageTime.fromJson(Map<String, dynamic>.from(json['time'] as Map)),
  finish: json['finish'] as String?,
);

Map<String, dynamic> _$MessageToJson(_Message instance) => <String, dynamic>{
  'role': instance.role,
  'id': instance.id,
  'sessionID': instance.sessionID,
  'parentID': instance.parentID,
  'agent': instance.agent,
  'modelID': instance.modelID,
  'providerID': instance.providerID,
  'cost': instance.cost,
  'tokens': instance.tokens?.toJson(),
  'time': instance.time?.toJson(),
  'finish': instance.finish,
};

_MessageTime _$MessageTimeFromJson(Map json) => _MessageTime(
  created: (json['created'] as num).toInt(),
  completed: (json['completed'] as num?)?.toInt(),
);

Map<String, dynamic> _$MessageTimeToJson(_MessageTime instance) => <String, dynamic>{
  'created': instance.created,
  'completed': instance.completed,
};

_MessageTokens _$MessageTokensFromJson(Map json) => _MessageTokens(
  input: (json['input'] as num?)?.toInt() ?? 0,
  output: (json['output'] as num?)?.toInt() ?? 0,
  reasoning: (json['reasoning'] as num?)?.toInt() ?? 0,
  cache: json['cache'] == null ? null : TokenCache.fromJson(Map<String, dynamic>.from(json['cache'] as Map)),
);

Map<String, dynamic> _$MessageTokensToJson(_MessageTokens instance) => <String, dynamic>{
  'input': instance.input,
  'output': instance.output,
  'reasoning': instance.reasoning,
  'cache': instance.cache?.toJson(),
};

_TokenCache _$TokenCacheFromJson(Map json) => _TokenCache(
  read: (json['read'] as num?)?.toInt() ?? 0,
  write: (json['write'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$TokenCacheToJson(_TokenCache instance) => <String, dynamic>{
  'read': instance.read,
  'write': instance.write,
};
