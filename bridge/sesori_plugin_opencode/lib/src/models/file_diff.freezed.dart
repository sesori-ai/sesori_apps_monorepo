// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'file_diff.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FileDiff {

 String get file; String get patch; int get additions; int get deletions; FileDiffStatus? get status;
/// Create a copy of FileDiff
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FileDiffCopyWith<FileDiff> get copyWith => _$FileDiffCopyWithImpl<FileDiff>(this as FileDiff, _$identity);

  /// Serializes this FileDiff to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FileDiff&&(identical(other.file, file) || other.file == file)&&(identical(other.patch, patch) || other.patch == patch)&&(identical(other.additions, additions) || other.additions == additions)&&(identical(other.deletions, deletions) || other.deletions == deletions)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,file,patch,additions,deletions,status);

@override
String toString() {
  return 'FileDiff(file: $file, patch: $patch, additions: $additions, deletions: $deletions, status: $status)';
}


}

/// @nodoc
abstract mixin class $FileDiffCopyWith<$Res>  {
  factory $FileDiffCopyWith(FileDiff value, $Res Function(FileDiff) _then) = _$FileDiffCopyWithImpl;
@useResult
$Res call({
 String file, String patch, int additions, int deletions, FileDiffStatus? status
});




}
/// @nodoc
class _$FileDiffCopyWithImpl<$Res>
    implements $FileDiffCopyWith<$Res> {
  _$FileDiffCopyWithImpl(this._self, this._then);

  final FileDiff _self;
  final $Res Function(FileDiff) _then;

/// Create a copy of FileDiff
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? file = null,Object? patch = null,Object? additions = null,Object? deletions = null,Object? status = freezed,}) {
  return _then(_self.copyWith(
file: null == file ? _self.file : file // ignore: cast_nullable_to_non_nullable
as String,patch: null == patch ? _self.patch : patch // ignore: cast_nullable_to_non_nullable
as String,additions: null == additions ? _self.additions : additions // ignore: cast_nullable_to_non_nullable
as int,deletions: null == deletions ? _self.deletions : deletions // ignore: cast_nullable_to_non_nullable
as int,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as FileDiffStatus?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _FileDiff implements FileDiff {
  const _FileDiff({required this.file, required this.patch, required this.additions, required this.deletions, this.status});
  factory _FileDiff.fromJson(Map<String, dynamic> json) => _$FileDiffFromJson(json);

@override final  String file;
@override final  String patch;
@override final  int additions;
@override final  int deletions;
@override final  FileDiffStatus? status;

/// Create a copy of FileDiff
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FileDiffCopyWith<_FileDiff> get copyWith => __$FileDiffCopyWithImpl<_FileDiff>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FileDiffToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FileDiff&&(identical(other.file, file) || other.file == file)&&(identical(other.patch, patch) || other.patch == patch)&&(identical(other.additions, additions) || other.additions == additions)&&(identical(other.deletions, deletions) || other.deletions == deletions)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,file,patch,additions,deletions,status);

@override
String toString() {
  return 'FileDiff(file: $file, patch: $patch, additions: $additions, deletions: $deletions, status: $status)';
}


}

/// @nodoc
abstract mixin class _$FileDiffCopyWith<$Res> implements $FileDiffCopyWith<$Res> {
  factory _$FileDiffCopyWith(_FileDiff value, $Res Function(_FileDiff) _then) = __$FileDiffCopyWithImpl;
@override @useResult
$Res call({
 String file, String patch, int additions, int deletions, FileDiffStatus? status
});




}
/// @nodoc
class __$FileDiffCopyWithImpl<$Res>
    implements _$FileDiffCopyWith<$Res> {
  __$FileDiffCopyWithImpl(this._self, this._then);

  final _FileDiff _self;
  final $Res Function(_FileDiff) _then;

/// Create a copy of FileDiff
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? file = null,Object? patch = null,Object? additions = null,Object? deletions = null,Object? status = freezed,}) {
  return _then(_FileDiff(
file: null == file ? _self.file : file // ignore: cast_nullable_to_non_nullable
as String,patch: null == patch ? _self.patch : patch // ignore: cast_nullable_to_non_nullable
as String,additions: null == additions ? _self.additions : additions // ignore: cast_nullable_to_non_nullable
as int,deletions: null == deletions ? _self.deletions : deletions // ignore: cast_nullable_to_non_nullable
as int,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as FileDiffStatus?,
  ));
}


}

// dart format on
