// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'branch_list_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BranchListResponse {

 List<BranchInfo> get branches; String? get currentBranch;
/// Create a copy of BranchListResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BranchListResponseCopyWith<BranchListResponse> get copyWith => _$BranchListResponseCopyWithImpl<BranchListResponse>(this as BranchListResponse, _$identity);

  /// Serializes this BranchListResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BranchListResponse&&const DeepCollectionEquality().equals(other.branches, branches)&&(identical(other.currentBranch, currentBranch) || other.currentBranch == currentBranch));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(branches),currentBranch);

@override
String toString() {
  return 'BranchListResponse(branches: $branches, currentBranch: $currentBranch)';
}


}

/// @nodoc
abstract mixin class $BranchListResponseCopyWith<$Res>  {
  factory $BranchListResponseCopyWith(BranchListResponse value, $Res Function(BranchListResponse) _then) = _$BranchListResponseCopyWithImpl;
@useResult
$Res call({
 List<BranchInfo> branches, String? currentBranch
});




}
/// @nodoc
class _$BranchListResponseCopyWithImpl<$Res>
    implements $BranchListResponseCopyWith<$Res> {
  _$BranchListResponseCopyWithImpl(this._self, this._then);

  final BranchListResponse _self;
  final $Res Function(BranchListResponse) _then;

/// Create a copy of BranchListResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? branches = null,Object? currentBranch = freezed,}) {
  return _then(_self.copyWith(
branches: null == branches ? _self.branches : branches // ignore: cast_nullable_to_non_nullable
as List<BranchInfo>,currentBranch: freezed == currentBranch ? _self.currentBranch : currentBranch // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _BranchListResponse implements BranchListResponse {
  const _BranchListResponse({required final  List<BranchInfo> branches, required this.currentBranch}): _branches = branches;
  factory _BranchListResponse.fromJson(Map<String, dynamic> json) => _$BranchListResponseFromJson(json);

 final  List<BranchInfo> _branches;
@override List<BranchInfo> get branches {
  if (_branches is EqualUnmodifiableListView) return _branches;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_branches);
}

@override final  String? currentBranch;

/// Create a copy of BranchListResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BranchListResponseCopyWith<_BranchListResponse> get copyWith => __$BranchListResponseCopyWithImpl<_BranchListResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BranchListResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BranchListResponse&&const DeepCollectionEquality().equals(other._branches, _branches)&&(identical(other.currentBranch, currentBranch) || other.currentBranch == currentBranch));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_branches),currentBranch);

@override
String toString() {
  return 'BranchListResponse(branches: $branches, currentBranch: $currentBranch)';
}


}

/// @nodoc
abstract mixin class _$BranchListResponseCopyWith<$Res> implements $BranchListResponseCopyWith<$Res> {
  factory _$BranchListResponseCopyWith(_BranchListResponse value, $Res Function(_BranchListResponse) _then) = __$BranchListResponseCopyWithImpl;
@override @useResult
$Res call({
 List<BranchInfo> branches, String? currentBranch
});




}
/// @nodoc
class __$BranchListResponseCopyWithImpl<$Res>
    implements _$BranchListResponseCopyWith<$Res> {
  __$BranchListResponseCopyWithImpl(this._self, this._then);

  final _BranchListResponse _self;
  final $Res Function(_BranchListResponse) _then;

/// Create a copy of BranchListResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? branches = null,Object? currentBranch = freezed,}) {
  return _then(_BranchListResponse(
branches: null == branches ? _self._branches : branches // ignore: cast_nullable_to_non_nullable
as List<BranchInfo>,currentBranch: freezed == currentBranch ? _self.currentBranch : currentBranch // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
