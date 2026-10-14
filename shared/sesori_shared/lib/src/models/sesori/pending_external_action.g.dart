// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_external_action.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PendingExternalAction _$PendingExternalActionFromJson(Map json) =>
    _PendingExternalAction(
      id: json['id'] as String,
      sessionID: json['sessionID'] as String,
      displaySessionId: json['displaySessionId'] as String?,
      title: json['title'] as String,
      message: json['message'] as String,
      authorizationUrl: json['authorizationUrl'] as String,
      purpose: $enumDecode(
        _$ExternalActionPurposeEnumMap,
        json['purpose'],
        unknownValue: ExternalActionPurpose.unknown,
      ),
      choices: (json['choices'] as List<dynamic>)
          .map(
            (e) => $enumDecode(
              _$ExternalActionChoiceEnumMap,
              e,
              unknownValue: ExternalActionChoice.unknown,
            ),
          )
          .toList(),
    );

Map<String, dynamic> _$PendingExternalActionToJson(
  _PendingExternalAction instance,
) => <String, dynamic>{
  'id': instance.id,
  'sessionID': instance.sessionID,
  'displaySessionId': ?instance.displaySessionId,
  'title': instance.title,
  'message': instance.message,
  'authorizationUrl': instance.authorizationUrl,
  'purpose': _$ExternalActionPurposeEnumMap[instance.purpose]!,
  'choices': instance.choices
      .map((e) => _$ExternalActionChoiceEnumMap[e]!)
      .toList(),
};

const _$ExternalActionPurposeEnumMap = {
  ExternalActionPurpose.unknown: 'unknown',
  ExternalActionPurpose.authorization: 'authorization',
  ExternalActionPurpose.connectorConsent: 'connectorConsent',
};

const _$ExternalActionChoiceEnumMap = {
  ExternalActionChoice.unknown: 'unknown',
  ExternalActionChoice.accept: 'accept',
  ExternalActionChoice.decline: 'decline',
  ExternalActionChoice.cancel: 'cancel',
};

_PendingExternalActionsResponse _$PendingExternalActionsResponseFromJson(
  Map json,
) => _PendingExternalActionsResponse(
  data: (json['data'] as List<dynamic>)
      .map(
        (e) =>
            PendingExternalAction.fromJson(Map<String, dynamic>.from(e as Map)),
      )
      .toList(),
);

Map<String, dynamic> _$PendingExternalActionsResponseToJson(
  _PendingExternalActionsResponse instance,
) => <String, dynamic>{'data': instance.data.map((e) => e.toJson()).toList()};

_ReplyToExternalActionRequest _$ReplyToExternalActionRequestFromJson(
  Map json,
) => _ReplyToExternalActionRequest(
  requestId: json['requestId'] as String,
  sessionId: json['sessionId'] as String,
  choice: $enumDecode(
    _$ExternalActionChoiceEnumMap,
    json['choice'],
    unknownValue: ExternalActionChoice.unknown,
  ),
);

Map<String, dynamic> _$ReplyToExternalActionRequestToJson(
  _ReplyToExternalActionRequest instance,
) => <String, dynamic>{
  'requestId': instance.requestId,
  'sessionId': instance.sessionId,
  'choice': _$ExternalActionChoiceEnumMap[instance.choice]!,
};

ExternalActionReplyUnknown _$ExternalActionReplyUnknownFromJson(Map json) =>
    ExternalActionReplyUnknown($type: json['type'] as String?);

Map<String, dynamic> _$ExternalActionReplyUnknownToJson(
  ExternalActionReplyUnknown instance,
) => <String, dynamic>{'type': instance.$type};

ExternalActionReplyAccepted _$ExternalActionReplyAcceptedFromJson(Map json) =>
    ExternalActionReplyAccepted($type: json['type'] as String?);

Map<String, dynamic> _$ExternalActionReplyAcceptedToJson(
  ExternalActionReplyAccepted instance,
) => <String, dynamic>{'type': instance.$type};

ExternalActionAlreadySettled _$ExternalActionAlreadySettledFromJson(Map json) =>
    ExternalActionAlreadySettled($type: json['type'] as String?);

Map<String, dynamic> _$ExternalActionAlreadySettledToJson(
  ExternalActionAlreadySettled instance,
) => <String, dynamic>{'type': instance.$type};

ExternalActionUnsupportedChoice _$ExternalActionUnsupportedChoiceFromJson(
  Map json,
) => ExternalActionUnsupportedChoice($type: json['type'] as String?);

Map<String, dynamic> _$ExternalActionUnsupportedChoiceToJson(
  ExternalActionUnsupportedChoice instance,
) => <String, dynamic>{'type': instance.$type};
