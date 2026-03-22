// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plugin_file_diff.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PluginFileDiff {

 String get file; String get before; String get after; int get additions; int get deletions; String? get status;
/// Create a copy of PluginFileDiff
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginFileDiffCopyWith<PluginFileDiff> get copyWith => _$PluginFileDiffCopyWithImpl<PluginFileDiff>(this as PluginFileDiff, _$identity);

  /// Serializes this PluginFileDiff to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginFileDiff&&(identical(other.file, file) || other.file == file)&&(identical(other.before, before) || other.before == before)&&(identical(other.after, after) || other.after == after)&&(identical(other.additions, additions) || other.additions == additions)&&(identical(other.deletions, deletions) || other.deletions == deletions)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,file,before,after,additions,deletions,status);

@override
String toString() {
  return 'PluginFileDiff(file: $file, before: $before, after: $after, additions: $additions, deletions: $deletions, status: $status)';
}


}

/// @nodoc
abstract mixin class $PluginFileDiffCopyWith<$Res>  {
  factory $PluginFileDiffCopyWith(PluginFileDiff value, $Res Function(PluginFileDiff) _then) = _$PluginFileDiffCopyWithImpl;
@useResult
$Res call({
 String file, String before, String after, int additions, int deletions, String? status
});




}
/// @nodoc
class _$PluginFileDiffCopyWithImpl<$Res>
    implements $PluginFileDiffCopyWith<$Res> {
  _$PluginFileDiffCopyWithImpl(this._self, this._then);

  final PluginFileDiff _self;
  final $Res Function(PluginFileDiff) _then;

/// Create a copy of PluginFileDiff
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? file = null,Object? before = null,Object? after = null,Object? additions = null,Object? deletions = null,Object? status = freezed,}) {
  return _then(_self.copyWith(
file: null == file ? _self.file : file // ignore: cast_nullable_to_non_nullable
as String,before: null == before ? _self.before : before // ignore: cast_nullable_to_non_nullable
as String,after: null == after ? _self.after : after // ignore: cast_nullable_to_non_nullable
as String,additions: null == additions ? _self.additions : additions // ignore: cast_nullable_to_non_nullable
as int,deletions: null == deletions ? _self.deletions : deletions // ignore: cast_nullable_to_non_nullable
as int,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _PluginFileDiff implements PluginFileDiff {
  const _PluginFileDiff({required this.file, required this.before, required this.after, required this.additions, required this.deletions, this.status});
  factory _PluginFileDiff.fromJson(Map<String, dynamic> json) => _$PluginFileDiffFromJson(json);

@override final  String file;
@override final  String before;
@override final  String after;
@override final  int additions;
@override final  int deletions;
@override final  String? status;

/// Create a copy of PluginFileDiff
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginFileDiffCopyWith<_PluginFileDiff> get copyWith => __$PluginFileDiffCopyWithImpl<_PluginFileDiff>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginFileDiffToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginFileDiff&&(identical(other.file, file) || other.file == file)&&(identical(other.before, before) || other.before == before)&&(identical(other.after, after) || other.after == after)&&(identical(other.additions, additions) || other.additions == additions)&&(identical(other.deletions, deletions) || other.deletions == deletions)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,file,before,after,additions,deletions,status);

@override
String toString() {
  return 'PluginFileDiff(file: $file, before: $before, after: $after, additions: $additions, deletions: $deletions, status: $status)';
}


}

/// @nodoc
abstract mixin class _$PluginFileDiffCopyWith<$Res> implements $PluginFileDiffCopyWith<$Res> {
  factory _$PluginFileDiffCopyWith(_PluginFileDiff value, $Res Function(_PluginFileDiff) _then) = __$PluginFileDiffCopyWithImpl;
@override @useResult
$Res call({
 String file, String before, String after, int additions, int deletions, String? status
});




}
/// @nodoc
class __$PluginFileDiffCopyWithImpl<$Res>
    implements _$PluginFileDiffCopyWith<$Res> {
  __$PluginFileDiffCopyWithImpl(this._self, this._then);

  final _PluginFileDiff _self;
  final $Res Function(_PluginFileDiff) _then;

/// Create a copy of PluginFileDiff
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? file = null,Object? before = null,Object? after = null,Object? additions = null,Object? deletions = null,Object? status = freezed,}) {
  return _then(_PluginFileDiff(
file: null == file ? _self.file : file // ignore: cast_nullable_to_non_nullable
as String,before: null == before ? _self.before : before // ignore: cast_nullable_to_non_nullable
as String,after: null == after ? _self.after : after // ignore: cast_nullable_to_non_nullable
as String,additions: null == additions ? _self.additions : additions // ignore: cast_nullable_to_non_nullable
as int,deletions: null == deletions ? _self.deletions : deletions // ignore: cast_nullable_to_non_nullable
as int,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
