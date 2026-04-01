// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'base_branch_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BaseBranchResponse {

 String? get baseBranch;
/// Create a copy of BaseBranchResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BaseBranchResponseCopyWith<BaseBranchResponse> get copyWith => _$BaseBranchResponseCopyWithImpl<BaseBranchResponse>(this as BaseBranchResponse, _$identity);

  /// Serializes this BaseBranchResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BaseBranchResponse&&(identical(other.baseBranch, baseBranch) || other.baseBranch == baseBranch));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,baseBranch);

@override
String toString() {
  return 'BaseBranchResponse(baseBranch: $baseBranch)';
}


}

/// @nodoc
abstract mixin class $BaseBranchResponseCopyWith<$Res>  {
  factory $BaseBranchResponseCopyWith(BaseBranchResponse value, $Res Function(BaseBranchResponse) _then) = _$BaseBranchResponseCopyWithImpl;
@useResult
$Res call({
 String? baseBranch
});




}
/// @nodoc
class _$BaseBranchResponseCopyWithImpl<$Res>
    implements $BaseBranchResponseCopyWith<$Res> {
  _$BaseBranchResponseCopyWithImpl(this._self, this._then);

  final BaseBranchResponse _self;
  final $Res Function(BaseBranchResponse) _then;

/// Create a copy of BaseBranchResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? baseBranch = freezed,}) {
  return _then(_self.copyWith(
baseBranch: freezed == baseBranch ? _self.baseBranch : baseBranch // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _BaseBranchResponse implements BaseBranchResponse {
  const _BaseBranchResponse({required this.baseBranch});
  factory _BaseBranchResponse.fromJson(Map<String, dynamic> json) => _$BaseBranchResponseFromJson(json);

@override final  String? baseBranch;

/// Create a copy of BaseBranchResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BaseBranchResponseCopyWith<_BaseBranchResponse> get copyWith => __$BaseBranchResponseCopyWithImpl<_BaseBranchResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BaseBranchResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BaseBranchResponse&&(identical(other.baseBranch, baseBranch) || other.baseBranch == baseBranch));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,baseBranch);

@override
String toString() {
  return 'BaseBranchResponse(baseBranch: $baseBranch)';
}


}

/// @nodoc
abstract mixin class _$BaseBranchResponseCopyWith<$Res> implements $BaseBranchResponseCopyWith<$Res> {
  factory _$BaseBranchResponseCopyWith(_BaseBranchResponse value, $Res Function(_BaseBranchResponse) _then) = __$BaseBranchResponseCopyWithImpl;
@override @useResult
$Res call({
 String? baseBranch
});




}
/// @nodoc
class __$BaseBranchResponseCopyWithImpl<$Res>
    implements _$BaseBranchResponseCopyWith<$Res> {
  __$BaseBranchResponseCopyWithImpl(this._self, this._then);

  final _BaseBranchResponse _self;
  final $Res Function(_BaseBranchResponse) _then;

/// Create a copy of BaseBranchResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? baseBranch = freezed,}) {
  return _then(_BaseBranchResponse(
baseBranch: freezed == baseBranch ? _self.baseBranch : baseBranch // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
