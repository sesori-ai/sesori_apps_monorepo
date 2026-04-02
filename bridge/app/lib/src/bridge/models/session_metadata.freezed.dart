// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_metadata.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SessionMetadata {

 String get title; String get branchName; String get worktreeName;
/// Create a copy of SessionMetadata
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionMetadataCopyWith<SessionMetadata> get copyWith => _$SessionMetadataCopyWithImpl<SessionMetadata>(this as SessionMetadata, _$identity);

  /// Serializes this SessionMetadata to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionMetadata&&(identical(other.title, title) || other.title == title)&&(identical(other.branchName, branchName) || other.branchName == branchName)&&(identical(other.worktreeName, worktreeName) || other.worktreeName == worktreeName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title,branchName,worktreeName);

@override
String toString() {
  return 'SessionMetadata(title: $title, branchName: $branchName, worktreeName: $worktreeName)';
}


}

/// @nodoc
abstract mixin class $SessionMetadataCopyWith<$Res>  {
  factory $SessionMetadataCopyWith(SessionMetadata value, $Res Function(SessionMetadata) _then) = _$SessionMetadataCopyWithImpl;
@useResult
$Res call({
 String title, String branchName, String worktreeName
});




}
/// @nodoc
class _$SessionMetadataCopyWithImpl<$Res>
    implements $SessionMetadataCopyWith<$Res> {
  _$SessionMetadataCopyWithImpl(this._self, this._then);

  final SessionMetadata _self;
  final $Res Function(SessionMetadata) _then;

/// Create a copy of SessionMetadata
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? title = null,Object? branchName = null,Object? worktreeName = null,}) {
  return _then(_self.copyWith(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,branchName: null == branchName ? _self.branchName : branchName // ignore: cast_nullable_to_non_nullable
as String,worktreeName: null == worktreeName ? _self.worktreeName : worktreeName // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _SessionMetadata implements SessionMetadata {
  const _SessionMetadata({required this.title, required this.branchName, required this.worktreeName});
  factory _SessionMetadata.fromJson(Map<String, dynamic> json) => _$SessionMetadataFromJson(json);

@override final  String title;
@override final  String branchName;
@override final  String worktreeName;

/// Create a copy of SessionMetadata
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionMetadataCopyWith<_SessionMetadata> get copyWith => __$SessionMetadataCopyWithImpl<_SessionMetadata>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionMetadataToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionMetadata&&(identical(other.title, title) || other.title == title)&&(identical(other.branchName, branchName) || other.branchName == branchName)&&(identical(other.worktreeName, worktreeName) || other.worktreeName == worktreeName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title,branchName,worktreeName);

@override
String toString() {
  return 'SessionMetadata(title: $title, branchName: $branchName, worktreeName: $worktreeName)';
}


}

/// @nodoc
abstract mixin class _$SessionMetadataCopyWith<$Res> implements $SessionMetadataCopyWith<$Res> {
  factory _$SessionMetadataCopyWith(_SessionMetadata value, $Res Function(_SessionMetadata) _then) = __$SessionMetadataCopyWithImpl;
@override @useResult
$Res call({
 String title, String branchName, String worktreeName
});




}
/// @nodoc
class __$SessionMetadataCopyWithImpl<$Res>
    implements _$SessionMetadataCopyWith<$Res> {
  __$SessionMetadataCopyWithImpl(this._self, this._then);

  final _SessionMetadata _self;
  final $Res Function(_SessionMetadata) _then;

/// Create a copy of SessionMetadata
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? title = null,Object? branchName = null,Object? worktreeName = null,}) {
  return _then(_SessionMetadata(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,branchName: null == branchName ? _self.branchName : branchName // ignore: cast_nullable_to_non_nullable
as String,worktreeName: null == worktreeName ? _self.worktreeName : worktreeName // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
