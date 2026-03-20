// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'messages.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RelayRequest _$RelayRequestFromJson(Map json) => RelayRequest(
  id: json['id'] as String,
  method: json['method'] as String,
  path: json['path'] as String,
  headers: Map<String, String>.from(json['headers'] as Map),
  body: json['body'] as String?,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$RelayRequestToJson(RelayRequest instance) =>
    <String, dynamic>{
      'id': instance.id,
      'method': instance.method,
      'path': instance.path,
      'headers': instance.headers,
      'body': instance.body,
      'type': instance.$type,
    };

RelayResponse _$RelayResponseFromJson(Map json) => RelayResponse(
  id: json['id'] as String,
  status: (json['status'] as num).toInt(),
  headers: Map<String, String>.from(json['headers'] as Map),
  body: json['body'] as String?,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$RelayResponseToJson(RelayResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'status': instance.status,
      'headers': instance.headers,
      'body': instance.body,
      'type': instance.$type,
    };

RelaySseEvent _$RelaySseEventFromJson(Map json) =>
    RelaySseEvent(data: json['data'] as String, $type: json['type'] as String?);

Map<String, dynamic> _$RelaySseEventToJson(RelaySseEvent instance) =>
    <String, dynamic>{'data': instance.data, 'type': instance.$type};

RelaySseSubscribe _$RelaySseSubscribeFromJson(Map json) => RelaySseSubscribe(
  path: json['path'] as String,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$RelaySseSubscribeToJson(RelaySseSubscribe instance) =>
    <String, dynamic>{'path': instance.path, 'type': instance.$type};

RelaySseUnsubscribe _$RelaySseUnsubscribeFromJson(Map json) =>
    RelaySseUnsubscribe($type: json['type'] as String?);

Map<String, dynamic> _$RelaySseUnsubscribeToJson(
  RelaySseUnsubscribe instance,
) => <String, dynamic>{'type': instance.$type};

RelayKeyExchange _$RelayKeyExchangeFromJson(Map json) => RelayKeyExchange(
  publicKey: json['publicKey'] as String,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$RelayKeyExchangeToJson(RelayKeyExchange instance) =>
    <String, dynamic>{'publicKey': instance.publicKey, 'type': instance.$type};

RelayReady _$RelayReadyFromJson(Map json) => RelayReady(
  publicKey: json['publicKey'] as String,
  roomKey: json['roomKey'] as String,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$RelayReadyToJson(RelayReady instance) =>
    <String, dynamic>{
      'publicKey': instance.publicKey,
      'roomKey': instance.roomKey,
      'type': instance.$type,
    };

RelayResume _$RelayResumeFromJson(Map json) =>
    RelayResume($type: json['type'] as String?);

Map<String, dynamic> _$RelayResumeToJson(RelayResume instance) =>
    <String, dynamic>{'type': instance.$type};

RelayResumeAck _$RelayResumeAckFromJson(Map json) =>
    RelayResumeAck($type: json['type'] as String?);

Map<String, dynamic> _$RelayResumeAckToJson(RelayResumeAck instance) =>
    <String, dynamic>{'type': instance.$type};

RelayRekeyRequired _$RelayRekeyRequiredFromJson(Map json) =>
    RelayRekeyRequired($type: json['type'] as String?);

Map<String, dynamic> _$RelayRekeyRequiredToJson(RelayRekeyRequired instance) =>
    <String, dynamic>{'type': instance.$type};

AuthRelayMessage _$AuthRelayMessageFromJson(Map json) => AuthRelayMessage(
  token: json['token'] as String,
  role: json['role'] as String,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$AuthRelayMessageToJson(AuthRelayMessage instance) =>
    <String, dynamic>{
      'token': instance.token,
      'role': instance.role,
      'type': instance.$type,
    };
