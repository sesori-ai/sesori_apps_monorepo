// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'codex_tool_outcome_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CodexToolOutcomeFileDto {

 int get schemaVersion; List<CodexStoredToolErrorDto> get errors;
/// Create a copy of CodexToolOutcomeFileDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexToolOutcomeFileDtoCopyWith<CodexToolOutcomeFileDto> get copyWith => _$CodexToolOutcomeFileDtoCopyWithImpl<CodexToolOutcomeFileDto>(this as CodexToolOutcomeFileDto, _$identity);

  /// Serializes this CodexToolOutcomeFileDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexToolOutcomeFileDto&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion)&&const DeepCollectionEquality().equals(other.errors, errors));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,schemaVersion,const DeepCollectionEquality().hash(errors));

@override
String toString() {
  return 'CodexToolOutcomeFileDto(schemaVersion: $schemaVersion, errors: $errors)';
}


}

/// @nodoc
abstract mixin class $CodexToolOutcomeFileDtoCopyWith<$Res>  {
  factory $CodexToolOutcomeFileDtoCopyWith(CodexToolOutcomeFileDto value, $Res Function(CodexToolOutcomeFileDto) _then) = _$CodexToolOutcomeFileDtoCopyWithImpl;
@useResult
$Res call({
 int schemaVersion, List<CodexStoredToolErrorDto> errors
});




}
/// @nodoc
class _$CodexToolOutcomeFileDtoCopyWithImpl<$Res>
    implements $CodexToolOutcomeFileDtoCopyWith<$Res> {
  _$CodexToolOutcomeFileDtoCopyWithImpl(this._self, this._then);

  final CodexToolOutcomeFileDto _self;
  final $Res Function(CodexToolOutcomeFileDto) _then;

/// Create a copy of CodexToolOutcomeFileDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? schemaVersion = null,Object? errors = null,}) {
  return _then(_self.copyWith(
schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,errors: null == errors ? _self.errors : errors // ignore: cast_nullable_to_non_nullable
as List<CodexStoredToolErrorDto>,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _CodexToolOutcomeFileDto implements CodexToolOutcomeFileDto {
  const _CodexToolOutcomeFileDto({required this.schemaVersion, required final  List<CodexStoredToolErrorDto> errors}): _errors = errors;
  factory _CodexToolOutcomeFileDto.fromJson(Map<String, dynamic> json) => _$CodexToolOutcomeFileDtoFromJson(json);

@override final  int schemaVersion;
 final  List<CodexStoredToolErrorDto> _errors;
@override List<CodexStoredToolErrorDto> get errors {
  if (_errors is EqualUnmodifiableListView) return _errors;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_errors);
}


/// Create a copy of CodexToolOutcomeFileDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexToolOutcomeFileDtoCopyWith<_CodexToolOutcomeFileDto> get copyWith => __$CodexToolOutcomeFileDtoCopyWithImpl<_CodexToolOutcomeFileDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CodexToolOutcomeFileDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexToolOutcomeFileDto&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion)&&const DeepCollectionEquality().equals(other._errors, _errors));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,schemaVersion,const DeepCollectionEquality().hash(_errors));

@override
String toString() {
  return 'CodexToolOutcomeFileDto(schemaVersion: $schemaVersion, errors: $errors)';
}


}

/// @nodoc
abstract mixin class _$CodexToolOutcomeFileDtoCopyWith<$Res> implements $CodexToolOutcomeFileDtoCopyWith<$Res> {
  factory _$CodexToolOutcomeFileDtoCopyWith(_CodexToolOutcomeFileDto value, $Res Function(_CodexToolOutcomeFileDto) _then) = __$CodexToolOutcomeFileDtoCopyWithImpl;
@override @useResult
$Res call({
 int schemaVersion, List<CodexStoredToolErrorDto> errors
});




}
/// @nodoc
class __$CodexToolOutcomeFileDtoCopyWithImpl<$Res>
    implements _$CodexToolOutcomeFileDtoCopyWith<$Res> {
  __$CodexToolOutcomeFileDtoCopyWithImpl(this._self, this._then);

  final _CodexToolOutcomeFileDto _self;
  final $Res Function(_CodexToolOutcomeFileDto) _then;

/// Create a copy of CodexToolOutcomeFileDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? schemaVersion = null,Object? errors = null,}) {
  return _then(_CodexToolOutcomeFileDto(
schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,errors: null == errors ? _self._errors : errors // ignore: cast_nullable_to_non_nullable
as List<CodexStoredToolErrorDto>,
  ));
}


}


/// @nodoc
mixin _$CodexStoredToolErrorDto {

 String get sessionId; String get callId;
/// Create a copy of CodexStoredToolErrorDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexStoredToolErrorDtoCopyWith<CodexStoredToolErrorDto> get copyWith => _$CodexStoredToolErrorDtoCopyWithImpl<CodexStoredToolErrorDto>(this as CodexStoredToolErrorDto, _$identity);

  /// Serializes this CodexStoredToolErrorDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexStoredToolErrorDto&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.callId, callId) || other.callId == callId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId,callId);

@override
String toString() {
  return 'CodexStoredToolErrorDto(sessionId: $sessionId, callId: $callId)';
}


}

/// @nodoc
abstract mixin class $CodexStoredToolErrorDtoCopyWith<$Res>  {
  factory $CodexStoredToolErrorDtoCopyWith(CodexStoredToolErrorDto value, $Res Function(CodexStoredToolErrorDto) _then) = _$CodexStoredToolErrorDtoCopyWithImpl;
@useResult
$Res call({
 String sessionId, String callId
});




}
/// @nodoc
class _$CodexStoredToolErrorDtoCopyWithImpl<$Res>
    implements $CodexStoredToolErrorDtoCopyWith<$Res> {
  _$CodexStoredToolErrorDtoCopyWithImpl(this._self, this._then);

  final CodexStoredToolErrorDto _self;
  final $Res Function(CodexStoredToolErrorDto) _then;

/// Create a copy of CodexStoredToolErrorDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = null,Object? callId = null,}) {
  return _then(_self.copyWith(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,callId: null == callId ? _self.callId : callId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _CodexStoredToolErrorDto implements CodexStoredToolErrorDto {
  const _CodexStoredToolErrorDto({required this.sessionId, required this.callId});
  factory _CodexStoredToolErrorDto.fromJson(Map<String, dynamic> json) => _$CodexStoredToolErrorDtoFromJson(json);

@override final  String sessionId;
@override final  String callId;

/// Create a copy of CodexStoredToolErrorDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexStoredToolErrorDtoCopyWith<_CodexStoredToolErrorDto> get copyWith => __$CodexStoredToolErrorDtoCopyWithImpl<_CodexStoredToolErrorDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CodexStoredToolErrorDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexStoredToolErrorDto&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.callId, callId) || other.callId == callId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId,callId);

@override
String toString() {
  return 'CodexStoredToolErrorDto(sessionId: $sessionId, callId: $callId)';
}


}

/// @nodoc
abstract mixin class _$CodexStoredToolErrorDtoCopyWith<$Res> implements $CodexStoredToolErrorDtoCopyWith<$Res> {
  factory _$CodexStoredToolErrorDtoCopyWith(_CodexStoredToolErrorDto value, $Res Function(_CodexStoredToolErrorDto) _then) = __$CodexStoredToolErrorDtoCopyWithImpl;
@override @useResult
$Res call({
 String sessionId, String callId
});




}
/// @nodoc
class __$CodexStoredToolErrorDtoCopyWithImpl<$Res>
    implements _$CodexStoredToolErrorDtoCopyWith<$Res> {
  __$CodexStoredToolErrorDtoCopyWithImpl(this._self, this._then);

  final _CodexStoredToolErrorDto _self;
  final $Res Function(_CodexStoredToolErrorDto) _then;

/// Create a copy of CodexStoredToolErrorDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? callId = null,}) {
  return _then(_CodexStoredToolErrorDto(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,callId: null == callId ? _self.callId : callId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
