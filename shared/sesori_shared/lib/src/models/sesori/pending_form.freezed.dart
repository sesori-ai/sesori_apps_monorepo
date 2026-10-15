// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pending_form.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PendingForm {

 String get id; String get sessionID; String? get displaySessionId; String get title; String get message; List<PendingFormField> get fields;

  /// Serializes this PendingForm to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PendingForm;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PendingForm&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.sessionID, _this.sessionID) || other.sessionID == _this.sessionID)&&(identical(other.displaySessionId, _this.displaySessionId) || other.displaySessionId == _this.displaySessionId)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.message, _this.message) || other.message == _this.message)&&const DeepCollectionEquality().equals(other.fields, _this.fields));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PendingForm;
  return Object.hash(runtimeType,_this.id,_this.sessionID,_this.displaySessionId,_this.title,_this.message,const DeepCollectionEquality().hash(_this.fields));
}



}





/// @nodoc
@JsonSerializable()

class _PendingForm implements PendingForm {
  const _PendingForm({required this.id, required this.sessionID, required this.displaySessionId, required this.title, required this.message, required  List<PendingFormField> fields}): _fields = fields;
  factory _PendingForm.fromJson(Map<String, dynamic> json) => _$PendingFormFromJson(json);

@override final  String id;
@override final  String sessionID;
@override final  String? displaySessionId;
@override final  String title;
@override final  String message;
 final  List<PendingFormField> _fields;
@override List<PendingFormField> get fields {
  if (_fields is EqualUnmodifiableListView) return _fields;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_fields);
}



@override
Map<String, dynamic> toJson() {
  return _$PendingFormToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PendingForm&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionID, sessionID) || other.sessionID == sessionID)&&(identical(other.displaySessionId, displaySessionId) || other.displaySessionId == displaySessionId)&&(identical(other.title, title) || other.title == title)&&(identical(other.message, message) || other.message == message)&&const DeepCollectionEquality().equals(other.fields, _fields));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,sessionID,displaySessionId,title,message,const DeepCollectionEquality().hash(_fields));
}



}





/// @nodoc
mixin _$PendingFormsResponse {

 List<PendingForm> get data;

  /// Serializes this PendingFormsResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PendingFormsResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PendingFormsResponse&&const DeepCollectionEquality().equals(other.data, _this.data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PendingFormsResponse;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.data));
}



}





/// @nodoc
@JsonSerializable()

class _PendingFormsResponse implements PendingFormsResponse {
  const _PendingFormsResponse({required  List<PendingForm> data}): _data = data;
  factory _PendingFormsResponse.fromJson(Map<String, dynamic> json) => _$PendingFormsResponseFromJson(json);

 final  List<PendingForm> _data;
@override List<PendingForm> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}



@override
Map<String, dynamic> toJson() {
  return _$PendingFormsResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PendingFormsResponse&&const DeepCollectionEquality().equals(other.data, _data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_data));
}



}





/// @nodoc
mixin _$ReplyToFormRequest {

 String get requestId; String get sessionId; Map<String, FormValue> get values;

  /// Serializes this ReplyToFormRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ReplyToFormRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReplyToFormRequest&&(identical(other.requestId, _this.requestId) || other.requestId == _this.requestId)&&(identical(other.sessionId, _this.sessionId) || other.sessionId == _this.sessionId)&&const DeepCollectionEquality().equals(other.values, _this.values));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ReplyToFormRequest;
  return Object.hash(runtimeType,_this.requestId,_this.sessionId,const DeepCollectionEquality().hash(_this.values));
}



}





/// @nodoc
@JsonSerializable()

class _ReplyToFormRequest implements ReplyToFormRequest {
  const _ReplyToFormRequest({required this.requestId, required this.sessionId, required  Map<String, FormValue> values}): _values = values;
  factory _ReplyToFormRequest.fromJson(Map<String, dynamic> json) => _$ReplyToFormRequestFromJson(json);

@override final  String requestId;
@override final  String sessionId;
 final  Map<String, FormValue> _values;
@override Map<String, FormValue> get values {
  if (_values is EqualUnmodifiableMapView) return _values;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_values);
}



@override
Map<String, dynamic> toJson() {
  return _$ReplyToFormRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReplyToFormRequest&&(identical(other.requestId, requestId) || other.requestId == requestId)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&const DeepCollectionEquality().equals(other.values, _values));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,requestId,sessionId,const DeepCollectionEquality().hash(_values));
}



}





/// @nodoc
mixin _$DeclineFormRequest {

 String get requestId; String get sessionId;@JsonKey(unknownEnumValue: FormDismissalChoice.unknown) FormDismissalChoice get choice;

  /// Serializes this DeclineFormRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as DeclineFormRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeclineFormRequest&&(identical(other.requestId, _this.requestId) || other.requestId == _this.requestId)&&(identical(other.sessionId, _this.sessionId) || other.sessionId == _this.sessionId)&&(identical(other.choice, _this.choice) || other.choice == _this.choice));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as DeclineFormRequest;
  return Object.hash(runtimeType,_this.requestId,_this.sessionId,_this.choice);
}



}





/// @nodoc
@JsonSerializable()

class _DeclineFormRequest implements DeclineFormRequest {
  const _DeclineFormRequest({required this.requestId, required this.sessionId, @JsonKey(unknownEnumValue: FormDismissalChoice.unknown) required this.choice});
  factory _DeclineFormRequest.fromJson(Map<String, dynamic> json) => _$DeclineFormRequestFromJson(json);

@override final  String requestId;
@override final  String sessionId;
@override@JsonKey(unknownEnumValue: FormDismissalChoice.unknown) final  FormDismissalChoice choice;


@override
Map<String, dynamic> toJson() {
  return _$DeclineFormRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeclineFormRequest&&(identical(other.requestId, requestId) || other.requestId == requestId)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.choice, choice) || other.choice == choice));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,requestId,sessionId,choice);
}



}




FormReplyResult _$FormReplyResultFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'accepted':
          return FormReplyAccepted.fromJson(
            json
          );
                case 'alreadySettled':
          return FormAlreadySettled.fromJson(
            json
          );
                case 'validationFailed':
          return FormValidationFailed.fromJson(
            json
          );
                case 'unsupportedChoice':
          return FormUnsupportedChoice.fromJson(
            json
          );
        
          default:
            return FormReplyUnknown.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$FormReplyResult {



  /// Serializes this FormReplyResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FormReplyResult);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;



}





/// @nodoc
@JsonSerializable()

class FormReplyUnknown implements FormReplyResult {
  const FormReplyUnknown({ String? $type}): $type = $type ?? 'unknown';
  factory FormReplyUnknown.fromJson(Map<String, dynamic> json) => _$FormReplyUnknownFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$FormReplyUnknownToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FormReplyUnknown);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;



}




/// @nodoc
@JsonSerializable()

class FormReplyAccepted implements FormReplyResult {
  const FormReplyAccepted({ String? $type}): $type = $type ?? 'accepted';
  factory FormReplyAccepted.fromJson(Map<String, dynamic> json) => _$FormReplyAcceptedFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$FormReplyAcceptedToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FormReplyAccepted);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;



}




/// @nodoc
@JsonSerializable()

class FormAlreadySettled implements FormReplyResult {
  const FormAlreadySettled({ String? $type}): $type = $type ?? 'alreadySettled';
  factory FormAlreadySettled.fromJson(Map<String, dynamic> json) => _$FormAlreadySettledFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$FormAlreadySettledToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FormAlreadySettled);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;



}




/// @nodoc
@JsonSerializable()

class FormValidationFailed implements FormReplyResult {
  const FormValidationFailed({@JsonKey(fromJson: _decodeFieldErrors) required  Map<String, FormValidationIssue> fieldErrors,  String? $type}): _fieldErrors = fieldErrors,$type = $type ?? 'validationFailed';
  factory FormValidationFailed.fromJson(Map<String, dynamic> json) => _$FormValidationFailedFromJson(json);

 final  Map<String, FormValidationIssue> _fieldErrors;
@JsonKey(fromJson: _decodeFieldErrors) Map<String, FormValidationIssue> get fieldErrors {
  if (_fieldErrors is EqualUnmodifiableMapView) return _fieldErrors;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_fieldErrors);
}


@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$FormValidationFailedToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FormValidationFailed&&const DeepCollectionEquality().equals(other.fieldErrors, _fieldErrors));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_fieldErrors));
}



}




/// @nodoc
@JsonSerializable()

class FormUnsupportedChoice implements FormReplyResult {
  const FormUnsupportedChoice({ String? $type}): $type = $type ?? 'unsupportedChoice';
  factory FormUnsupportedChoice.fromJson(Map<String, dynamic> json) => _$FormUnsupportedChoiceFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$FormUnsupportedChoiceToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FormUnsupportedChoice);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;



}




// dart format on
