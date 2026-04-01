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
FileDiff _$FileDiffFromJson(
  Map<String, dynamic> json
) {
        switch (json['runtimeType']) {
                  case 'content':
          return FileDiffContent.fromJson(
            json
          );
                case 'skipped':
          return FileDiffSkipped.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'runtimeType',
  'FileDiff',
  'Invalid union type "${json['runtimeType']}"!'
);
        }
      
}

/// @nodoc
mixin _$FileDiff {

 String get file; FileDiffStatus? get status;
/// Create a copy of FileDiff
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FileDiffCopyWith<FileDiff> get copyWith => _$FileDiffCopyWithImpl<FileDiff>(this as FileDiff, _$identity);

  /// Serializes this FileDiff to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FileDiff&&(identical(other.file, file) || other.file == file)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,file,status);

@override
String toString() {
  return 'FileDiff(file: $file, status: $status)';
}


}

/// @nodoc
abstract mixin class $FileDiffCopyWith<$Res>  {
  factory $FileDiffCopyWith(FileDiff value, $Res Function(FileDiff) _then) = _$FileDiffCopyWithImpl;
@useResult
$Res call({
 String file, FileDiffStatus? status
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
@pragma('vm:prefer-inline') @override $Res call({Object? file = null,Object? status = freezed,}) {
  return _then(_self.copyWith(
file: null == file ? _self.file : file // ignore: cast_nullable_to_non_nullable
as String,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as FileDiffStatus?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class FileDiffContent implements FileDiff {
  const FileDiffContent({required this.file, required this.before, required this.after, required this.additions, required this.deletions, required this.status, final  String? $type}): $type = $type ?? 'content';
  factory FileDiffContent.fromJson(Map<String, dynamic> json) => _$FileDiffContentFromJson(json);

@override final  String file;
 final  String before;
 final  String after;
 final  int additions;
 final  int deletions;
@override final  FileDiffStatus? status;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of FileDiff
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FileDiffContentCopyWith<FileDiffContent> get copyWith => _$FileDiffContentCopyWithImpl<FileDiffContent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FileDiffContentToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FileDiffContent&&(identical(other.file, file) || other.file == file)&&(identical(other.before, before) || other.before == before)&&(identical(other.after, after) || other.after == after)&&(identical(other.additions, additions) || other.additions == additions)&&(identical(other.deletions, deletions) || other.deletions == deletions)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,file,before,after,additions,deletions,status);

@override
String toString() {
  return 'FileDiff.content(file: $file, before: $before, after: $after, additions: $additions, deletions: $deletions, status: $status)';
}


}

/// @nodoc
abstract mixin class $FileDiffContentCopyWith<$Res> implements $FileDiffCopyWith<$Res> {
  factory $FileDiffContentCopyWith(FileDiffContent value, $Res Function(FileDiffContent) _then) = _$FileDiffContentCopyWithImpl;
@override @useResult
$Res call({
 String file, String before, String after, int additions, int deletions, FileDiffStatus? status
});




}
/// @nodoc
class _$FileDiffContentCopyWithImpl<$Res>
    implements $FileDiffContentCopyWith<$Res> {
  _$FileDiffContentCopyWithImpl(this._self, this._then);

  final FileDiffContent _self;
  final $Res Function(FileDiffContent) _then;

/// Create a copy of FileDiff
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? file = null,Object? before = null,Object? after = null,Object? additions = null,Object? deletions = null,Object? status = freezed,}) {
  return _then(FileDiffContent(
file: null == file ? _self.file : file // ignore: cast_nullable_to_non_nullable
as String,before: null == before ? _self.before : before // ignore: cast_nullable_to_non_nullable
as String,after: null == after ? _self.after : after // ignore: cast_nullable_to_non_nullable
as String,additions: null == additions ? _self.additions : additions // ignore: cast_nullable_to_non_nullable
as int,deletions: null == deletions ? _self.deletions : deletions // ignore: cast_nullable_to_non_nullable
as int,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as FileDiffStatus?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class FileDiffSkipped implements FileDiff {
  const FileDiffSkipped({required this.file, required this.reason, required this.status, final  String? $type}): $type = $type ?? 'skipped';
  factory FileDiffSkipped.fromJson(Map<String, dynamic> json) => _$FileDiffSkippedFromJson(json);

@override final  String file;
 final  FileDiffSkipReason reason;
@override final  FileDiffStatus? status;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of FileDiff
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FileDiffSkippedCopyWith<FileDiffSkipped> get copyWith => _$FileDiffSkippedCopyWithImpl<FileDiffSkipped>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FileDiffSkippedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FileDiffSkipped&&(identical(other.file, file) || other.file == file)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,file,reason,status);

@override
String toString() {
  return 'FileDiff.skipped(file: $file, reason: $reason, status: $status)';
}


}

/// @nodoc
abstract mixin class $FileDiffSkippedCopyWith<$Res> implements $FileDiffCopyWith<$Res> {
  factory $FileDiffSkippedCopyWith(FileDiffSkipped value, $Res Function(FileDiffSkipped) _then) = _$FileDiffSkippedCopyWithImpl;
@override @useResult
$Res call({
 String file, FileDiffSkipReason reason, FileDiffStatus? status
});




}
/// @nodoc
class _$FileDiffSkippedCopyWithImpl<$Res>
    implements $FileDiffSkippedCopyWith<$Res> {
  _$FileDiffSkippedCopyWithImpl(this._self, this._then);

  final FileDiffSkipped _self;
  final $Res Function(FileDiffSkipped) _then;

/// Create a copy of FileDiff
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? file = null,Object? reason = null,Object? status = freezed,}) {
  return _then(FileDiffSkipped(
file: null == file ? _self.file : file // ignore: cast_nullable_to_non_nullable
as String,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as FileDiffSkipReason,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as FileDiffStatus?,
  ));
}


}

// dart format on
