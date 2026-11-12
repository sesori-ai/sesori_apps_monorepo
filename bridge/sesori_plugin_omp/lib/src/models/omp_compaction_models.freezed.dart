// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'omp_compaction_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$OmpCompactionStartDto {

 String get sessionId;
/// Create a copy of OmpCompactionStartDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OmpCompactionStartDtoCopyWith<OmpCompactionStartDto> get copyWith => _$OmpCompactionStartDtoCopyWithImpl<OmpCompactionStartDto>(this as OmpCompactionStartDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as OmpCompactionStartDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OmpCompactionStartDto&&(identical(other.sessionId, _this.sessionId) || other.sessionId == _this.sessionId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as OmpCompactionStartDto;
  return Object.hash(runtimeType,_this.sessionId);
}

@override
String toString() {
  final _this = this as OmpCompactionStartDto;
  return 'OmpCompactionStartDto(sessionId: ${_this.sessionId})';
}


}

/// @nodoc
abstract mixin class $OmpCompactionStartDtoCopyWith<$Res>  {
  factory $OmpCompactionStartDtoCopyWith(OmpCompactionStartDto value, $Res Function(OmpCompactionStartDto) _then) = _$OmpCompactionStartDtoCopyWithImpl;
@useResult
$Res call({
 String sessionId
});




}
/// @nodoc
class _$OmpCompactionStartDtoCopyWithImpl<$Res>
    implements $OmpCompactionStartDtoCopyWith<$Res> {
  _$OmpCompactionStartDtoCopyWithImpl(this._self, this._then);

  final OmpCompactionStartDto _self;
  final $Res Function(OmpCompactionStartDto) _then;

/// Create a copy of OmpCompactionStartDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = null,}) {
  return _then(OmpCompactionStartDto(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _OmpCompactionStartDto implements OmpCompactionStartDto {
  const _OmpCompactionStartDto({required this.sessionId});
  factory _OmpCompactionStartDto.fromJson(Map<String, dynamic> json) => _$OmpCompactionStartDtoFromJson(json);

@override final  String sessionId;

/// Create a copy of OmpCompactionStartDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OmpCompactionStartDtoCopyWith<_OmpCompactionStartDto> get copyWith => __$OmpCompactionStartDtoCopyWithImpl<_OmpCompactionStartDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _OmpCompactionStartDto&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,sessionId);
}

@override
String toString() {
    return 'OmpCompactionStartDto(sessionId: $sessionId)';
}


}

/// @nodoc
abstract mixin class _$OmpCompactionStartDtoCopyWith<$Res> implements $OmpCompactionStartDtoCopyWith<$Res> {
  factory _$OmpCompactionStartDtoCopyWith(_OmpCompactionStartDto value, $Res Function(_OmpCompactionStartDto) _then) = __$OmpCompactionStartDtoCopyWithImpl;
@override @useResult
$Res call({
 String sessionId
});




}
/// @nodoc
class __$OmpCompactionStartDtoCopyWithImpl<$Res>
    implements _$OmpCompactionStartDtoCopyWith<$Res> {
  __$OmpCompactionStartDtoCopyWithImpl(this._self, this._then);

  final _OmpCompactionStartDto _self;
  final $Res Function(_OmpCompactionStartDto) _then;

/// Create a copy of OmpCompactionStartDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = null,}) {
  return _then(_OmpCompactionStartDto(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$OmpCompactionEndDto {

 String get sessionId; bool? get aborted;/// OMP's benign skip: nothing to compact yet, or no model to compact with.
 bool? get skipped; String? get errorMessage;
/// Create a copy of OmpCompactionEndDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OmpCompactionEndDtoCopyWith<OmpCompactionEndDto> get copyWith => _$OmpCompactionEndDtoCopyWithImpl<OmpCompactionEndDto>(this as OmpCompactionEndDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as OmpCompactionEndDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OmpCompactionEndDto&&(identical(other.sessionId, _this.sessionId) || other.sessionId == _this.sessionId)&&(identical(other.aborted, _this.aborted) || other.aborted == _this.aborted)&&(identical(other.skipped, _this.skipped) || other.skipped == _this.skipped)&&(identical(other.errorMessage, _this.errorMessage) || other.errorMessage == _this.errorMessage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as OmpCompactionEndDto;
  return Object.hash(runtimeType,_this.sessionId,_this.aborted,_this.skipped,_this.errorMessage);
}

@override
String toString() {
  final _this = this as OmpCompactionEndDto;
  return 'OmpCompactionEndDto(sessionId: ${_this.sessionId}, aborted: ${_this.aborted}, skipped: ${_this.skipped}, errorMessage: ${_this.errorMessage})';
}


}

/// @nodoc
abstract mixin class $OmpCompactionEndDtoCopyWith<$Res>  {
  factory $OmpCompactionEndDtoCopyWith(OmpCompactionEndDto value, $Res Function(OmpCompactionEndDto) _then) = _$OmpCompactionEndDtoCopyWithImpl;
@useResult
$Res call({
 String sessionId, bool? aborted, bool? skipped, String? errorMessage
});




}
/// @nodoc
class _$OmpCompactionEndDtoCopyWithImpl<$Res>
    implements $OmpCompactionEndDtoCopyWith<$Res> {
  _$OmpCompactionEndDtoCopyWithImpl(this._self, this._then);

  final OmpCompactionEndDto _self;
  final $Res Function(OmpCompactionEndDto) _then;

/// Create a copy of OmpCompactionEndDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = null,Object? aborted = freezed,Object? skipped = freezed,Object? errorMessage = freezed,}) {
  return _then(OmpCompactionEndDto(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,aborted: freezed == aborted ? _self.aborted : aborted // ignore: cast_nullable_to_non_nullable
as bool?,skipped: freezed == skipped ? _self.skipped : skipped // ignore: cast_nullable_to_non_nullable
as bool?,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _OmpCompactionEndDto implements OmpCompactionEndDto {
  const _OmpCompactionEndDto({required this.sessionId, required this.aborted, required this.skipped, required this.errorMessage});
  factory _OmpCompactionEndDto.fromJson(Map<String, dynamic> json) => _$OmpCompactionEndDtoFromJson(json);

@override final  String sessionId;
@override final  bool? aborted;
/// OMP's benign skip: nothing to compact yet, or no model to compact with.
@override final  bool? skipped;
@override final  String? errorMessage;

/// Create a copy of OmpCompactionEndDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OmpCompactionEndDtoCopyWith<_OmpCompactionEndDto> get copyWith => __$OmpCompactionEndDtoCopyWithImpl<_OmpCompactionEndDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _OmpCompactionEndDto&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.aborted, aborted) || other.aborted == aborted)&&(identical(other.skipped, skipped) || other.skipped == skipped)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,sessionId,aborted,skipped,errorMessage);
}

@override
String toString() {
    return 'OmpCompactionEndDto(sessionId: $sessionId, aborted: $aborted, skipped: $skipped, errorMessage: $errorMessage)';
}


}

/// @nodoc
abstract mixin class _$OmpCompactionEndDtoCopyWith<$Res> implements $OmpCompactionEndDtoCopyWith<$Res> {
  factory _$OmpCompactionEndDtoCopyWith(_OmpCompactionEndDto value, $Res Function(_OmpCompactionEndDto) _then) = __$OmpCompactionEndDtoCopyWithImpl;
@override @useResult
$Res call({
 String sessionId, bool? aborted, bool? skipped, String? errorMessage
});




}
/// @nodoc
class __$OmpCompactionEndDtoCopyWithImpl<$Res>
    implements _$OmpCompactionEndDtoCopyWith<$Res> {
  __$OmpCompactionEndDtoCopyWithImpl(this._self, this._then);

  final _OmpCompactionEndDto _self;
  final $Res Function(_OmpCompactionEndDto) _then;

/// Create a copy of OmpCompactionEndDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? aborted = freezed,Object? skipped = freezed,Object? errorMessage = freezed,}) {
  return _then(_OmpCompactionEndDto(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,aborted: freezed == aborted ? _self.aborted : aborted // ignore: cast_nullable_to_non_nullable
as bool?,skipped: freezed == skipped ? _self.skipped : skipped // ignore: cast_nullable_to_non_nullable
as bool?,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
