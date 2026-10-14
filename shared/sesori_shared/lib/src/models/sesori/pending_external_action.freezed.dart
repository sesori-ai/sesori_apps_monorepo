// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pending_external_action.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PendingExternalAction {

 String get id; String get sessionID; String? get displaySessionId; String get title; String get message; String get authorizationUrl;@JsonKey(unknownEnumValue: ExternalActionPurpose.unknown) ExternalActionPurpose get purpose;@JsonKey(unknownEnumValue: ExternalActionChoice.unknown) List<ExternalActionChoice> get choices;

  /// Serializes this PendingExternalAction to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PendingExternalAction;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PendingExternalAction&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.sessionID, _this.sessionID) || other.sessionID == _this.sessionID)&&(identical(other.displaySessionId, _this.displaySessionId) || other.displaySessionId == _this.displaySessionId)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.message, _this.message) || other.message == _this.message)&&(identical(other.authorizationUrl, _this.authorizationUrl) || other.authorizationUrl == _this.authorizationUrl)&&(identical(other.purpose, _this.purpose) || other.purpose == _this.purpose)&&const DeepCollectionEquality().equals(other.choices, _this.choices));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PendingExternalAction;
  return Object.hash(runtimeType,_this.id,_this.sessionID,_this.displaySessionId,_this.title,_this.message,_this.authorizationUrl,_this.purpose,const DeepCollectionEquality().hash(_this.choices));
}



}





/// @nodoc
@JsonSerializable()

class _PendingExternalAction implements PendingExternalAction {
  const _PendingExternalAction({required this.id, required this.sessionID, required this.displaySessionId, required this.title, required this.message, required this.authorizationUrl, @JsonKey(unknownEnumValue: ExternalActionPurpose.unknown) required this.purpose, @JsonKey(unknownEnumValue: ExternalActionChoice.unknown) required  List<ExternalActionChoice> choices}): _choices = choices;
  factory _PendingExternalAction.fromJson(Map<String, dynamic> json) => _$PendingExternalActionFromJson(json);

@override final  String id;
@override final  String sessionID;
@override final  String? displaySessionId;
@override final  String title;
@override final  String message;
@override final  String authorizationUrl;
@override@JsonKey(unknownEnumValue: ExternalActionPurpose.unknown) final  ExternalActionPurpose purpose;
 final  List<ExternalActionChoice> _choices;
@override@JsonKey(unknownEnumValue: ExternalActionChoice.unknown) List<ExternalActionChoice> get choices {
  if (_choices is EqualUnmodifiableListView) return _choices;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_choices);
}



@override
Map<String, dynamic> toJson() {
  return _$PendingExternalActionToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PendingExternalAction&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.displaySessionId, displaySessionId) || other.displaySessionId == displaySessionId)&&(identical(other.title, title) || other.title == title)&&(identical(other.message, message) || other.message == message)&&(identical(other.authorizationUrl, authorizationUrl) || other.authorizationUrl == authorizationUrl)&&(identical(other.purpose, purpose) || other.purpose == purpose)&&const DeepCollectionEquality().equals(other.choices, _choices));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,sessionID,displaySessionId,title,message,authorizationUrl,purpose,const DeepCollectionEquality().hash(_choices));
}



}





/// @nodoc
mixin _$PendingExternalActionsResponse {

 List<PendingExternalAction> get data;

  /// Serializes this PendingExternalActionsResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PendingExternalActionsResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PendingExternalActionsResponse&&const DeepCollectionEquality().equals(other.data, _this.data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PendingExternalActionsResponse;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.data));
}



}





/// @nodoc
@JsonSerializable()

class _PendingExternalActionsResponse implements PendingExternalActionsResponse {
  const _PendingExternalActionsResponse({required  List<PendingExternalAction> data}): _data = data;
  factory _PendingExternalActionsResponse.fromJson(Map<String, dynamic> json) => _$PendingExternalActionsResponseFromJson(json);

 final  List<PendingExternalAction> _data;
@override List<PendingExternalAction> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}



@override
Map<String, dynamic> toJson() {
  return _$PendingExternalActionsResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PendingExternalActionsResponse&&const DeepCollectionEquality().equals(other.data, _data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_data));
}



}





/// @nodoc
mixin _$ReplyToExternalActionRequest {

 String get requestId; String get sessionId;@JsonKey(unknownEnumValue: ExternalActionChoice.unknown) ExternalActionChoice get choice;

  /// Serializes this ReplyToExternalActionRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ReplyToExternalActionRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReplyToExternalActionRequest&&(identical(other.requestId, _this.requestId) || other.requestId == _this.requestId)&&(identical(other.sessionId, _this.sessionId) || other.sessionId == _this.sessionId)&&(identical(other.choice, _this.choice) || other.choice == _this.choice));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ReplyToExternalActionRequest;
  return Object.hash(runtimeType,_this.requestId,_this.sessionId,_this.choice);
}

@override
String toString() {
  final _this = this as ReplyToExternalActionRequest;
  return 'ReplyToExternalActionRequest(requestId: ${_this.requestId}, sessionId: ${_this.sessionId}, choice: ${_this.choice})';
}


}





/// @nodoc
@JsonSerializable()

class _ReplyToExternalActionRequest implements ReplyToExternalActionRequest {
  const _ReplyToExternalActionRequest({required this.requestId, required this.sessionId, @JsonKey(unknownEnumValue: ExternalActionChoice.unknown) required this.choice});
  factory _ReplyToExternalActionRequest.fromJson(Map<String, dynamic> json) => _$ReplyToExternalActionRequestFromJson(json);

@override final  String requestId;
@override final  String sessionId;
@override@JsonKey(unknownEnumValue: ExternalActionChoice.unknown) final  ExternalActionChoice choice;


@override
Map<String, dynamic> toJson() {
  return _$ReplyToExternalActionRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReplyToExternalActionRequest&&(identical(other.requestId, requestId) || other.requestId == requestId)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.choice, choice) || other.choice == choice));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,requestId,sessionId,choice);
}

@override
String toString() {
    return 'ReplyToExternalActionRequest(requestId: $requestId, sessionId: $sessionId, choice: $choice)';
}


}




ExternalActionReplyResult _$ExternalActionReplyResultFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'accepted':
          return ExternalActionReplyAccepted.fromJson(
            json
          );
                case 'alreadySettled':
          return ExternalActionAlreadySettled.fromJson(
            json
          );
                case 'unsupportedChoice':
          return ExternalActionUnsupportedChoice.fromJson(
            json
          );
        
          default:
            return ExternalActionReplyUnknown.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$ExternalActionReplyResult {



  /// Serializes this ExternalActionReplyResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ExternalActionReplyResult);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ExternalActionReplyResult()';
}


}





/// @nodoc
@JsonSerializable()

class ExternalActionReplyUnknown implements ExternalActionReplyResult {
  const ExternalActionReplyUnknown({ String? $type}): $type = $type ?? 'unknown';
  factory ExternalActionReplyUnknown.fromJson(Map<String, dynamic> json) => _$ExternalActionReplyUnknownFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$ExternalActionReplyUnknownToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ExternalActionReplyUnknown);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ExternalActionReplyResult.unknown()';
}


}




/// @nodoc
@JsonSerializable()

class ExternalActionReplyAccepted implements ExternalActionReplyResult {
  const ExternalActionReplyAccepted({ String? $type}): $type = $type ?? 'accepted';
  factory ExternalActionReplyAccepted.fromJson(Map<String, dynamic> json) => _$ExternalActionReplyAcceptedFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$ExternalActionReplyAcceptedToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ExternalActionReplyAccepted);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ExternalActionReplyResult.accepted()';
}


}




/// @nodoc
@JsonSerializable()

class ExternalActionAlreadySettled implements ExternalActionReplyResult {
  const ExternalActionAlreadySettled({ String? $type}): $type = $type ?? 'alreadySettled';
  factory ExternalActionAlreadySettled.fromJson(Map<String, dynamic> json) => _$ExternalActionAlreadySettledFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$ExternalActionAlreadySettledToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ExternalActionAlreadySettled);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ExternalActionReplyResult.alreadySettled()';
}


}




/// @nodoc
@JsonSerializable()

class ExternalActionUnsupportedChoice implements ExternalActionReplyResult {
  const ExternalActionUnsupportedChoice({ String? $type}): $type = $type ?? 'unsupportedChoice';
  factory ExternalActionUnsupportedChoice.fromJson(Map<String, dynamic> json) => _$ExternalActionUnsupportedChoiceFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$ExternalActionUnsupportedChoiceToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ExternalActionUnsupportedChoice);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ExternalActionReplyResult.unsupportedChoice()';
}


}




// dart format on
