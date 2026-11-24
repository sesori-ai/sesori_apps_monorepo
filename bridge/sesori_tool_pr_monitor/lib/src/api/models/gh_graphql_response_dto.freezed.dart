// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'gh_graphql_response_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GhGraphQlResponseDto {

 Map<String, dynamic>? get data; List<GhGraphQlErrorDto> get errors;
/// Create a copy of GhGraphQlResponseDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GhGraphQlResponseDtoCopyWith<GhGraphQlResponseDto> get copyWith => _$GhGraphQlResponseDtoCopyWithImpl<GhGraphQlResponseDto>(this as GhGraphQlResponseDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as GhGraphQlResponseDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GhGraphQlResponseDto&&const DeepCollectionEquality().equals(other.data, _this.data)&&const DeepCollectionEquality().equals(other.errors, _this.errors));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GhGraphQlResponseDto;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.data),const DeepCollectionEquality().hash(_this.errors));
}

@override
String toString() {
  final _this = this as GhGraphQlResponseDto;
  return 'GhGraphQlResponseDto(data: ${_this.data}, errors: ${_this.errors})';
}


}

/// @nodoc
abstract mixin class $GhGraphQlResponseDtoCopyWith<$Res>  {
  factory $GhGraphQlResponseDtoCopyWith(GhGraphQlResponseDto value, $Res Function(GhGraphQlResponseDto) _then) = _$GhGraphQlResponseDtoCopyWithImpl;
@useResult
$Res call({
 Map<String, dynamic>? data, List<GhGraphQlErrorDto> errors
});




}
/// @nodoc
class _$GhGraphQlResponseDtoCopyWithImpl<$Res>
    implements $GhGraphQlResponseDtoCopyWith<$Res> {
  _$GhGraphQlResponseDtoCopyWithImpl(this._self, this._then);

  final GhGraphQlResponseDto _self;
  final $Res Function(GhGraphQlResponseDto) _then;

/// Create a copy of GhGraphQlResponseDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = freezed,Object? errors = null,}) {
  return _then(GhGraphQlResponseDto(
data: freezed == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,errors: null == errors ? _self.errors : errors // ignore: cast_nullable_to_non_nullable
as List<GhGraphQlErrorDto>,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _GhGraphQlResponseDto implements GhGraphQlResponseDto {
  const _GhGraphQlResponseDto({required  Map<String, dynamic>? data,  List<GhGraphQlErrorDto> errors = const <GhGraphQlErrorDto>[]}): _data = data,_errors = errors;
  factory _GhGraphQlResponseDto.fromJson(Map<String, dynamic> json) => _$GhGraphQlResponseDtoFromJson(json);

 final  Map<String, dynamic>? _data;
@override Map<String, dynamic>? get data {
  final value = _data;
  if (value == null) return null;
  if (_data is EqualUnmodifiableMapView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  List<GhGraphQlErrorDto> _errors;
@override@JsonKey() List<GhGraphQlErrorDto> get errors {
  if (_errors is EqualUnmodifiableListView) return _errors;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_errors);
}


/// Create a copy of GhGraphQlResponseDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GhGraphQlResponseDtoCopyWith<_GhGraphQlResponseDto> get copyWith => __$GhGraphQlResponseDtoCopyWithImpl<_GhGraphQlResponseDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GhGraphQlResponseDto&&const DeepCollectionEquality().equals(other.data, _data)&&const DeepCollectionEquality().equals(other.errors, _errors));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_data),const DeepCollectionEquality().hash(_errors));
}

@override
String toString() {
    return 'GhGraphQlResponseDto(data: $data, errors: $errors)';
}


}

/// @nodoc
abstract mixin class _$GhGraphQlResponseDtoCopyWith<$Res> implements $GhGraphQlResponseDtoCopyWith<$Res> {
  factory _$GhGraphQlResponseDtoCopyWith(_GhGraphQlResponseDto value, $Res Function(_GhGraphQlResponseDto) _then) = __$GhGraphQlResponseDtoCopyWithImpl;
@override @useResult
$Res call({
 Map<String, dynamic>? data, List<GhGraphQlErrorDto> errors
});




}
/// @nodoc
class __$GhGraphQlResponseDtoCopyWithImpl<$Res>
    implements _$GhGraphQlResponseDtoCopyWith<$Res> {
  __$GhGraphQlResponseDtoCopyWithImpl(this._self, this._then);

  final _GhGraphQlResponseDto _self;
  final $Res Function(_GhGraphQlResponseDto) _then;

/// Create a copy of GhGraphQlResponseDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = freezed,Object? errors = null,}) {
  return _then(_GhGraphQlResponseDto(
data: freezed == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,errors: null == errors ? _self._errors : errors // ignore: cast_nullable_to_non_nullable
as List<GhGraphQlErrorDto>,
  ));
}


}


/// @nodoc
mixin _$GhGraphQlErrorDto {

 String? get message;
/// Create a copy of GhGraphQlErrorDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GhGraphQlErrorDtoCopyWith<GhGraphQlErrorDto> get copyWith => _$GhGraphQlErrorDtoCopyWithImpl<GhGraphQlErrorDto>(this as GhGraphQlErrorDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as GhGraphQlErrorDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GhGraphQlErrorDto&&(identical(other.message, _this.message) || other.message == _this.message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GhGraphQlErrorDto;
  return Object.hash(runtimeType,_this.message);
}

@override
String toString() {
  final _this = this as GhGraphQlErrorDto;
  return 'GhGraphQlErrorDto(message: ${_this.message})';
}


}

/// @nodoc
abstract mixin class $GhGraphQlErrorDtoCopyWith<$Res>  {
  factory $GhGraphQlErrorDtoCopyWith(GhGraphQlErrorDto value, $Res Function(GhGraphQlErrorDto) _then) = _$GhGraphQlErrorDtoCopyWithImpl;
@useResult
$Res call({
 String? message
});




}
/// @nodoc
class _$GhGraphQlErrorDtoCopyWithImpl<$Res>
    implements $GhGraphQlErrorDtoCopyWith<$Res> {
  _$GhGraphQlErrorDtoCopyWithImpl(this._self, this._then);

  final GhGraphQlErrorDto _self;
  final $Res Function(GhGraphQlErrorDto) _then;

/// Create a copy of GhGraphQlErrorDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? message = freezed,}) {
  return _then(GhGraphQlErrorDto(
message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _GhGraphQlErrorDto implements GhGraphQlErrorDto {
  const _GhGraphQlErrorDto({required this.message});
  factory _GhGraphQlErrorDto.fromJson(Map<String, dynamic> json) => _$GhGraphQlErrorDtoFromJson(json);

@override final  String? message;

/// Create a copy of GhGraphQlErrorDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GhGraphQlErrorDtoCopyWith<_GhGraphQlErrorDto> get copyWith => __$GhGraphQlErrorDtoCopyWithImpl<_GhGraphQlErrorDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GhGraphQlErrorDto&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,message);
}

@override
String toString() {
    return 'GhGraphQlErrorDto(message: $message)';
}


}

/// @nodoc
abstract mixin class _$GhGraphQlErrorDtoCopyWith<$Res> implements $GhGraphQlErrorDtoCopyWith<$Res> {
  factory _$GhGraphQlErrorDtoCopyWith(_GhGraphQlErrorDto value, $Res Function(_GhGraphQlErrorDto) _then) = __$GhGraphQlErrorDtoCopyWithImpl;
@override @useResult
$Res call({
 String? message
});




}
/// @nodoc
class __$GhGraphQlErrorDtoCopyWithImpl<$Res>
    implements _$GhGraphQlErrorDtoCopyWith<$Res> {
  __$GhGraphQlErrorDtoCopyWithImpl(this._self, this._then);

  final _GhGraphQlErrorDto _self;
  final $Res Function(_GhGraphQlErrorDto) _then;

/// Create a copy of GhGraphQlErrorDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? message = freezed,}) {
  return _then(_GhGraphQlErrorDto(
message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
