// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_form.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PendingForm _$PendingFormFromJson(Map json) => _PendingForm(
  id: json['id'] as String,
  sessionID: json['sessionID'] as String,
  displaySessionId: json['displaySessionId'] as String?,
  title: json['title'] as String,
  message: json['message'] as String,
  fields: (json['fields'] as List<dynamic>)
      .map(
        (e) => PendingFormField.fromJson(Map<String, dynamic>.from(e as Map)),
      )
      .toList(),
);

Map<String, dynamic> _$PendingFormToJson(_PendingForm instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sessionID': instance.sessionID,
      'displaySessionId': ?instance.displaySessionId,
      'title': instance.title,
      'message': instance.message,
      'fields': instance.fields.map((e) => e.toJson()).toList(),
    };

_PendingFormsResponse _$PendingFormsResponseFromJson(Map json) =>
    _PendingFormsResponse(
      data: (json['data'] as List<dynamic>)
          .map((e) => PendingForm.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );

Map<String, dynamic> _$PendingFormsResponseToJson(
  _PendingFormsResponse instance,
) => <String, dynamic>{'data': instance.data.map((e) => e.toJson()).toList()};

_ReplyToFormRequest _$ReplyToFormRequestFromJson(Map json) =>
    _ReplyToFormRequest(
      requestId: json['requestId'] as String,
      sessionId: json['sessionId'] as String,
      values: (json['values'] as Map).map(
        (k, e) => MapEntry(
          k as String,
          FormValue.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      ),
    );

Map<String, dynamic> _$ReplyToFormRequestToJson(_ReplyToFormRequest instance) =>
    <String, dynamic>{
      'requestId': instance.requestId,
      'sessionId': instance.sessionId,
      'values': instance.values.map((k, e) => MapEntry(k, e.toJson())),
    };

_DeclineFormRequest _$DeclineFormRequestFromJson(Map json) =>
    _DeclineFormRequest(
      requestId: json['requestId'] as String,
      sessionId: json['sessionId'] as String,
      choice: $enumDecode(
        _$FormDismissalChoiceEnumMap,
        json['choice'],
        unknownValue: FormDismissalChoice.unknown,
      ),
    );

Map<String, dynamic> _$DeclineFormRequestToJson(_DeclineFormRequest instance) =>
    <String, dynamic>{
      'requestId': instance.requestId,
      'sessionId': instance.sessionId,
      'choice': _$FormDismissalChoiceEnumMap[instance.choice]!,
    };

const _$FormDismissalChoiceEnumMap = {
  FormDismissalChoice.unknown: 'unknown',
  FormDismissalChoice.decline: 'decline',
  FormDismissalChoice.cancel: 'cancel',
};

FormReplyUnknown _$FormReplyUnknownFromJson(Map json) =>
    FormReplyUnknown($type: json['type'] as String?);

Map<String, dynamic> _$FormReplyUnknownToJson(FormReplyUnknown instance) =>
    <String, dynamic>{'type': instance.$type};

FormReplyAccepted _$FormReplyAcceptedFromJson(Map json) =>
    FormReplyAccepted($type: json['type'] as String?);

Map<String, dynamic> _$FormReplyAcceptedToJson(FormReplyAccepted instance) =>
    <String, dynamic>{'type': instance.$type};

FormAlreadySettled _$FormAlreadySettledFromJson(Map json) =>
    FormAlreadySettled($type: json['type'] as String?);

Map<String, dynamic> _$FormAlreadySettledToJson(FormAlreadySettled instance) =>
    <String, dynamic>{'type': instance.$type};

FormValidationFailed _$FormValidationFailedFromJson(Map json) =>
    FormValidationFailed(
      fieldErrors: _decodeFieldErrors(
        json['fieldErrors'] as Map<String, dynamic>,
      ),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$FormValidationFailedToJson(
  FormValidationFailed instance,
) => <String, dynamic>{
  'fieldErrors': instance.fieldErrors.map(
    (k, e) => MapEntry(k, _$FormValidationIssueEnumMap[e]!),
  ),
  'type': instance.$type,
};

const _$FormValidationIssueEnumMap = {
  FormValidationIssue.unknown: 'unknown',
  FormValidationIssue.required: 'required',
  FormValidationIssue.invalidType: 'invalidType',
  FormValidationIssue.invalidChoice: 'invalidChoice',
  FormValidationIssue.outOfRange: 'outOfRange',
  FormValidationIssue.invalidLength: 'invalidLength',
  FormValidationIssue.invalidFormat: 'invalidFormat',
};

FormUnsupportedChoice _$FormUnsupportedChoiceFromJson(Map json) =>
    FormUnsupportedChoice($type: json['type'] as String?);

Map<String, dynamic> _$FormUnsupportedChoiceToJson(
  FormUnsupportedChoice instance,
) => <String, dynamic>{'type': instance.$type};
