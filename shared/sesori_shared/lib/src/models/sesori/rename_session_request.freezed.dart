// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'rename_session_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RenameSessionRequest {

 String get title;
/// Create a copy of RenameSessionRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RenameSessionRequestCopyWith<RenameSessionRequest> get copyWith => _$RenameSessionRequestCopyWithImpl<RenameSessionRequest>(this as RenameSessionRequest, _$identity);

  /// Serializes this RenameSessionRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RenameSessionRequest&&(identical(other.title, title) || other.title == title));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title);

@override
String toString() {
  return 'RenameSessionRequest(title: $title)';
}


}

/// @nodoc
abstract mixin class $RenameSessionRequestCopyWith<$Res>  {
  factory $RenameSessionRequestCopyWith(RenameSessionRequest value, $Res Function(RenameSessionRequest) _then) = _$RenameSessionRequestCopyWithImpl;
@useResult
$Res call({
 String title
});




}
/// @nodoc
class _$RenameSessionRequestCopyWithImpl<$Res>
    implements $RenameSessionRequestCopyWith<$Res> {
  _$RenameSessionRequestCopyWithImpl(this._self, this._then);

  final RenameSessionRequest _self;
  final $Res Function(RenameSessionRequest) _then;

/// Create a copy of RenameSessionRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? title = null,}) {
  return _then(_self.copyWith(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _RenameSessionRequest implements RenameSessionRequest {
  const _RenameSessionRequest({required this.title});
  factory _RenameSessionRequest.fromJson(Map<String, dynamic> json) => _$RenameSessionRequestFromJson(json);

@override final  String title;

/// Create a copy of RenameSessionRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RenameSessionRequestCopyWith<_RenameSessionRequest> get copyWith => __$RenameSessionRequestCopyWithImpl<_RenameSessionRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RenameSessionRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RenameSessionRequest&&(identical(other.title, title) || other.title == title));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title);

@override
String toString() {
  return 'RenameSessionRequest(title: $title)';
}


}

/// @nodoc
abstract mixin class _$RenameSessionRequestCopyWith<$Res> implements $RenameSessionRequestCopyWith<$Res> {
  factory _$RenameSessionRequestCopyWith(_RenameSessionRequest value, $Res Function(_RenameSessionRequest) _then) = __$RenameSessionRequestCopyWithImpl;
@override @useResult
$Res call({
 String title
});




}
/// @nodoc
class __$RenameSessionRequestCopyWithImpl<$Res>
    implements _$RenameSessionRequestCopyWith<$Res> {
  __$RenameSessionRequestCopyWithImpl(this._self, this._then);

  final _RenameSessionRequest _self;
  final $Res Function(_RenameSessionRequest) _then;

/// Create a copy of RenameSessionRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? title = null,}) {
  return _then(_RenameSessionRequest(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
