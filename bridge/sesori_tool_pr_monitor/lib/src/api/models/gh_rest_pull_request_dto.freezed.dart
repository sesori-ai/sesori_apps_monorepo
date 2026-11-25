// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'gh_rest_pull_request_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GhRestPullRequestDto {

 GhRestPullRequestStateDto get state; bool get merged; String get title; GhRestHeadDto get head;
/// Create a copy of GhRestPullRequestDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GhRestPullRequestDtoCopyWith<GhRestPullRequestDto> get copyWith => _$GhRestPullRequestDtoCopyWithImpl<GhRestPullRequestDto>(this as GhRestPullRequestDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as GhRestPullRequestDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GhRestPullRequestDto&&(identical(other.state, _this.state) || other.state == _this.state)&&(identical(other.merged, _this.merged) || other.merged == _this.merged)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.head, _this.head) || other.head == _this.head));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GhRestPullRequestDto;
  return Object.hash(runtimeType,_this.state,_this.merged,_this.title,_this.head);
}

@override
String toString() {
  final _this = this as GhRestPullRequestDto;
  return 'GhRestPullRequestDto(state: ${_this.state}, merged: ${_this.merged}, title: ${_this.title}, head: ${_this.head})';
}


}

/// @nodoc
abstract mixin class $GhRestPullRequestDtoCopyWith<$Res>  {
  factory $GhRestPullRequestDtoCopyWith(GhRestPullRequestDto value, $Res Function(GhRestPullRequestDto) _then) = _$GhRestPullRequestDtoCopyWithImpl;
@useResult
$Res call({
 GhRestPullRequestStateDto state, bool merged, String title, GhRestHeadDto head
});


$GhRestHeadDtoCopyWith<$Res> get head;

}
/// @nodoc
class _$GhRestPullRequestDtoCopyWithImpl<$Res>
    implements $GhRestPullRequestDtoCopyWith<$Res> {
  _$GhRestPullRequestDtoCopyWithImpl(this._self, this._then);

  final GhRestPullRequestDto _self;
  final $Res Function(GhRestPullRequestDto) _then;

/// Create a copy of GhRestPullRequestDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? state = null,Object? merged = null,Object? title = null,Object? head = null,}) {
  return _then(GhRestPullRequestDto(
state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as GhRestPullRequestStateDto,merged: null == merged ? _self.merged : merged // ignore: cast_nullable_to_non_nullable
as bool,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,head: null == head ? _self.head : head // ignore: cast_nullable_to_non_nullable
as GhRestHeadDto,
  ));
}
/// Create a copy of GhRestPullRequestDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GhRestHeadDtoCopyWith<$Res> get head {
  
  return $GhRestHeadDtoCopyWith<$Res>(_self.head, (value) {
    return _then(_self.copyWith(head: value));
  });
}
}



/// @nodoc
@JsonSerializable(createToJson: false)

class _GhRestPullRequestDto implements GhRestPullRequestDto {
  const _GhRestPullRequestDto({required this.state, required this.merged, required this.title, required this.head});
  factory _GhRestPullRequestDto.fromJson(Map<String, dynamic> json) => _$GhRestPullRequestDtoFromJson(json);

@override final  GhRestPullRequestStateDto state;
@override final  bool merged;
@override final  String title;
@override final  GhRestHeadDto head;

/// Create a copy of GhRestPullRequestDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GhRestPullRequestDtoCopyWith<_GhRestPullRequestDto> get copyWith => __$GhRestPullRequestDtoCopyWithImpl<_GhRestPullRequestDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GhRestPullRequestDto&&(identical(other.state, state) || other.state == state)&&(identical(other.merged, merged) || other.merged == merged)&&(identical(other.title, title) || other.title == title)&&(identical(other.head, head) || other.head == head));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,state,merged,title,head);
}

@override
String toString() {
    return 'GhRestPullRequestDto(state: $state, merged: $merged, title: $title, head: $head)';
}


}

/// @nodoc
abstract mixin class _$GhRestPullRequestDtoCopyWith<$Res> implements $GhRestPullRequestDtoCopyWith<$Res> {
  factory _$GhRestPullRequestDtoCopyWith(_GhRestPullRequestDto value, $Res Function(_GhRestPullRequestDto) _then) = __$GhRestPullRequestDtoCopyWithImpl;
@override @useResult
$Res call({
 GhRestPullRequestStateDto state, bool merged, String title, GhRestHeadDto head
});


@override $GhRestHeadDtoCopyWith<$Res> get head;

}
/// @nodoc
class __$GhRestPullRequestDtoCopyWithImpl<$Res>
    implements _$GhRestPullRequestDtoCopyWith<$Res> {
  __$GhRestPullRequestDtoCopyWithImpl(this._self, this._then);

  final _GhRestPullRequestDto _self;
  final $Res Function(_GhRestPullRequestDto) _then;

/// Create a copy of GhRestPullRequestDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? state = null,Object? merged = null,Object? title = null,Object? head = null,}) {
  return _then(_GhRestPullRequestDto(
state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as GhRestPullRequestStateDto,merged: null == merged ? _self.merged : merged // ignore: cast_nullable_to_non_nullable
as bool,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,head: null == head ? _self.head : head // ignore: cast_nullable_to_non_nullable
as GhRestHeadDto,
  ));
}

/// Create a copy of GhRestPullRequestDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GhRestHeadDtoCopyWith<$Res> get head {
  
  return $GhRestHeadDtoCopyWith<$Res>(_self.head, (value) {
    return _then(_self.copyWith(head: value));
  });
}
}


/// @nodoc
mixin _$GhRestHeadDto {

 String get sha;
/// Create a copy of GhRestHeadDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GhRestHeadDtoCopyWith<GhRestHeadDto> get copyWith => _$GhRestHeadDtoCopyWithImpl<GhRestHeadDto>(this as GhRestHeadDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as GhRestHeadDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GhRestHeadDto&&(identical(other.sha, _this.sha) || other.sha == _this.sha));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GhRestHeadDto;
  return Object.hash(runtimeType,_this.sha);
}

@override
String toString() {
  final _this = this as GhRestHeadDto;
  return 'GhRestHeadDto(sha: ${_this.sha})';
}


}

/// @nodoc
abstract mixin class $GhRestHeadDtoCopyWith<$Res>  {
  factory $GhRestHeadDtoCopyWith(GhRestHeadDto value, $Res Function(GhRestHeadDto) _then) = _$GhRestHeadDtoCopyWithImpl;
@useResult
$Res call({
 String sha
});




}
/// @nodoc
class _$GhRestHeadDtoCopyWithImpl<$Res>
    implements $GhRestHeadDtoCopyWith<$Res> {
  _$GhRestHeadDtoCopyWithImpl(this._self, this._then);

  final GhRestHeadDto _self;
  final $Res Function(GhRestHeadDto) _then;

/// Create a copy of GhRestHeadDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sha = null,}) {
  return _then(GhRestHeadDto(
sha: null == sha ? _self.sha : sha // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _GhRestHeadDto implements GhRestHeadDto {
  const _GhRestHeadDto({required this.sha});
  factory _GhRestHeadDto.fromJson(Map<String, dynamic> json) => _$GhRestHeadDtoFromJson(json);

@override final  String sha;

/// Create a copy of GhRestHeadDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GhRestHeadDtoCopyWith<_GhRestHeadDto> get copyWith => __$GhRestHeadDtoCopyWithImpl<_GhRestHeadDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GhRestHeadDto&&(identical(other.sha, sha) || other.sha == sha));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,sha);
}

@override
String toString() {
    return 'GhRestHeadDto(sha: $sha)';
}


}

/// @nodoc
abstract mixin class _$GhRestHeadDtoCopyWith<$Res> implements $GhRestHeadDtoCopyWith<$Res> {
  factory _$GhRestHeadDtoCopyWith(_GhRestHeadDto value, $Res Function(_GhRestHeadDto) _then) = __$GhRestHeadDtoCopyWithImpl;
@override @useResult
$Res call({
 String sha
});




}
/// @nodoc
class __$GhRestHeadDtoCopyWithImpl<$Res>
    implements _$GhRestHeadDtoCopyWith<$Res> {
  __$GhRestHeadDtoCopyWithImpl(this._self, this._then);

  final _GhRestHeadDto _self;
  final $Res Function(_GhRestHeadDto) _then;

/// Create a copy of GhRestHeadDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sha = null,}) {
  return _then(_GhRestHeadDto(
sha: null == sha ? _self.sha : sha // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$GhMergeResultDto {

 bool? get merged; String? get message;
/// Create a copy of GhMergeResultDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GhMergeResultDtoCopyWith<GhMergeResultDto> get copyWith => _$GhMergeResultDtoCopyWithImpl<GhMergeResultDto>(this as GhMergeResultDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as GhMergeResultDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GhMergeResultDto&&(identical(other.merged, _this.merged) || other.merged == _this.merged)&&(identical(other.message, _this.message) || other.message == _this.message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GhMergeResultDto;
  return Object.hash(runtimeType,_this.merged,_this.message);
}

@override
String toString() {
  final _this = this as GhMergeResultDto;
  return 'GhMergeResultDto(merged: ${_this.merged}, message: ${_this.message})';
}


}

/// @nodoc
abstract mixin class $GhMergeResultDtoCopyWith<$Res>  {
  factory $GhMergeResultDtoCopyWith(GhMergeResultDto value, $Res Function(GhMergeResultDto) _then) = _$GhMergeResultDtoCopyWithImpl;
@useResult
$Res call({
 bool? merged, String? message
});




}
/// @nodoc
class _$GhMergeResultDtoCopyWithImpl<$Res>
    implements $GhMergeResultDtoCopyWith<$Res> {
  _$GhMergeResultDtoCopyWithImpl(this._self, this._then);

  final GhMergeResultDto _self;
  final $Res Function(GhMergeResultDto) _then;

/// Create a copy of GhMergeResultDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? merged = freezed,Object? message = freezed,}) {
  return _then(GhMergeResultDto(
merged: freezed == merged ? _self.merged : merged // ignore: cast_nullable_to_non_nullable
as bool?,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _GhMergeResultDto implements GhMergeResultDto {
  const _GhMergeResultDto({required this.merged, required this.message});
  factory _GhMergeResultDto.fromJson(Map<String, dynamic> json) => _$GhMergeResultDtoFromJson(json);

@override final  bool? merged;
@override final  String? message;

/// Create a copy of GhMergeResultDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GhMergeResultDtoCopyWith<_GhMergeResultDto> get copyWith => __$GhMergeResultDtoCopyWithImpl<_GhMergeResultDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GhMergeResultDto&&(identical(other.merged, merged) || other.merged == merged)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,merged,message);
}

@override
String toString() {
    return 'GhMergeResultDto(merged: $merged, message: $message)';
}


}

/// @nodoc
abstract mixin class _$GhMergeResultDtoCopyWith<$Res> implements $GhMergeResultDtoCopyWith<$Res> {
  factory _$GhMergeResultDtoCopyWith(_GhMergeResultDto value, $Res Function(_GhMergeResultDto) _then) = __$GhMergeResultDtoCopyWithImpl;
@override @useResult
$Res call({
 bool? merged, String? message
});




}
/// @nodoc
class __$GhMergeResultDtoCopyWithImpl<$Res>
    implements _$GhMergeResultDtoCopyWith<$Res> {
  __$GhMergeResultDtoCopyWithImpl(this._self, this._then);

  final _GhMergeResultDto _self;
  final $Res Function(_GhMergeResultDto) _then;

/// Create a copy of GhMergeResultDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? merged = freezed,Object? message = freezed,}) {
  return _then(_GhMergeResultDto(
merged: freezed == merged ? _self.merged : merged // ignore: cast_nullable_to_non_nullable
as bool?,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
