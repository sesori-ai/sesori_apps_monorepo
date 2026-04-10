// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'branch_info.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BranchInfo {

 String get name; bool get isRemoteOnly; int? get lastCommitTimestamp; String? get worktreePath;
/// Create a copy of BranchInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BranchInfoCopyWith<BranchInfo> get copyWith => _$BranchInfoCopyWithImpl<BranchInfo>(this as BranchInfo, _$identity);

  /// Serializes this BranchInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BranchInfo&&(identical(other.name, name) || other.name == name)&&(identical(other.isRemoteOnly, isRemoteOnly) || other.isRemoteOnly == isRemoteOnly)&&(identical(other.lastCommitTimestamp, lastCommitTimestamp) || other.lastCommitTimestamp == lastCommitTimestamp)&&(identical(other.worktreePath, worktreePath) || other.worktreePath == worktreePath));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,isRemoteOnly,lastCommitTimestamp,worktreePath);

@override
String toString() {
  return 'BranchInfo(name: $name, isRemoteOnly: $isRemoteOnly, lastCommitTimestamp: $lastCommitTimestamp, worktreePath: $worktreePath)';
}


}

/// @nodoc
abstract mixin class $BranchInfoCopyWith<$Res>  {
  factory $BranchInfoCopyWith(BranchInfo value, $Res Function(BranchInfo) _then) = _$BranchInfoCopyWithImpl;
@useResult
$Res call({
 String name, bool isRemoteOnly, int? lastCommitTimestamp, String? worktreePath
});




}
/// @nodoc
class _$BranchInfoCopyWithImpl<$Res>
    implements $BranchInfoCopyWith<$Res> {
  _$BranchInfoCopyWithImpl(this._self, this._then);

  final BranchInfo _self;
  final $Res Function(BranchInfo) _then;

/// Create a copy of BranchInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? isRemoteOnly = null,Object? lastCommitTimestamp = freezed,Object? worktreePath = freezed,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,isRemoteOnly: null == isRemoteOnly ? _self.isRemoteOnly : isRemoteOnly // ignore: cast_nullable_to_non_nullable
as bool,lastCommitTimestamp: freezed == lastCommitTimestamp ? _self.lastCommitTimestamp : lastCommitTimestamp // ignore: cast_nullable_to_non_nullable
as int?,worktreePath: freezed == worktreePath ? _self.worktreePath : worktreePath // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _BranchInfo implements BranchInfo {
  const _BranchInfo({required this.name, required this.isRemoteOnly, required this.lastCommitTimestamp, required this.worktreePath});
  factory _BranchInfo.fromJson(Map<String, dynamic> json) => _$BranchInfoFromJson(json);

@override final  String name;
@override final  bool isRemoteOnly;
@override final  int? lastCommitTimestamp;
@override final  String? worktreePath;

/// Create a copy of BranchInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BranchInfoCopyWith<_BranchInfo> get copyWith => __$BranchInfoCopyWithImpl<_BranchInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BranchInfoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BranchInfo&&(identical(other.name, name) || other.name == name)&&(identical(other.isRemoteOnly, isRemoteOnly) || other.isRemoteOnly == isRemoteOnly)&&(identical(other.lastCommitTimestamp, lastCommitTimestamp) || other.lastCommitTimestamp == lastCommitTimestamp)&&(identical(other.worktreePath, worktreePath) || other.worktreePath == worktreePath));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,isRemoteOnly,lastCommitTimestamp,worktreePath);

@override
String toString() {
  return 'BranchInfo(name: $name, isRemoteOnly: $isRemoteOnly, lastCommitTimestamp: $lastCommitTimestamp, worktreePath: $worktreePath)';
}


}

/// @nodoc
abstract mixin class _$BranchInfoCopyWith<$Res> implements $BranchInfoCopyWith<$Res> {
  factory _$BranchInfoCopyWith(_BranchInfo value, $Res Function(_BranchInfo) _then) = __$BranchInfoCopyWithImpl;
@override @useResult
$Res call({
 String name, bool isRemoteOnly, int? lastCommitTimestamp, String? worktreePath
});




}
/// @nodoc
class __$BranchInfoCopyWithImpl<$Res>
    implements _$BranchInfoCopyWith<$Res> {
  __$BranchInfoCopyWithImpl(this._self, this._then);

  final _BranchInfo _self;
  final $Res Function(_BranchInfo) _then;

/// Create a copy of BranchInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? isRemoteOnly = null,Object? lastCommitTimestamp = freezed,Object? worktreePath = freezed,}) {
  return _then(_BranchInfo(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,isRemoteOnly: null == isRemoteOnly ? _self.isRemoteOnly : isRemoteOnly // ignore: cast_nullable_to_non_nullable
as bool,lastCommitTimestamp: freezed == lastCommitTimestamp ? _self.lastCommitTimestamp : lastCommitTimestamp // ignore: cast_nullable_to_non_nullable
as int?,worktreePath: freezed == worktreePath ? _self.worktreePath : worktreePath // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
