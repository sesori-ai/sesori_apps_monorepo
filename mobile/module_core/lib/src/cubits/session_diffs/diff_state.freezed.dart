// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'diff_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DiffState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DiffState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'DiffState()';
}


}

/// @nodoc
class $DiffStateCopyWith<$Res>  {
$DiffStateCopyWith(DiffState _, $Res Function(DiffState) __);
}



/// @nodoc


class DiffStateLoading implements DiffState {
  const DiffStateLoading();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DiffStateLoading);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'DiffState.loading()';
}


}




/// @nodoc


class DiffStateLoaded implements DiffState {
  const DiffStateLoaded({required final  List<FileDiff> files}): _files = files;
  

 final  List<FileDiff> _files;
 List<FileDiff> get files {
  if (_files is EqualUnmodifiableListView) return _files;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_files);
}


/// Create a copy of DiffState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DiffStateLoadedCopyWith<DiffStateLoaded> get copyWith => _$DiffStateLoadedCopyWithImpl<DiffStateLoaded>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DiffStateLoaded&&const DeepCollectionEquality().equals(other._files, _files));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_files));

@override
String toString() {
  return 'DiffState.loaded(files: $files)';
}


}

/// @nodoc
abstract mixin class $DiffStateLoadedCopyWith<$Res> implements $DiffStateCopyWith<$Res> {
  factory $DiffStateLoadedCopyWith(DiffStateLoaded value, $Res Function(DiffStateLoaded) _then) = _$DiffStateLoadedCopyWithImpl;
@useResult
$Res call({
 List<FileDiff> files
});




}
/// @nodoc
class _$DiffStateLoadedCopyWithImpl<$Res>
    implements $DiffStateLoadedCopyWith<$Res> {
  _$DiffStateLoadedCopyWithImpl(this._self, this._then);

  final DiffStateLoaded _self;
  final $Res Function(DiffStateLoaded) _then;

/// Create a copy of DiffState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? files = null,}) {
  return _then(DiffStateLoaded(
files: null == files ? _self._files : files // ignore: cast_nullable_to_non_nullable
as List<FileDiff>,
  ));
}


}

/// @nodoc


class DiffStateFailed implements DiffState {
  const DiffStateFailed({required this.error});
  

 final  Object error;

/// Create a copy of DiffState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DiffStateFailedCopyWith<DiffStateFailed> get copyWith => _$DiffStateFailedCopyWithImpl<DiffStateFailed>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DiffStateFailed&&const DeepCollectionEquality().equals(other.error, error));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(error));

@override
String toString() {
  return 'DiffState.failed(error: $error)';
}


}

/// @nodoc
abstract mixin class $DiffStateFailedCopyWith<$Res> implements $DiffStateCopyWith<$Res> {
  factory $DiffStateFailedCopyWith(DiffStateFailed value, $Res Function(DiffStateFailed) _then) = _$DiffStateFailedCopyWithImpl;
@useResult
$Res call({
 Object error
});




}
/// @nodoc
class _$DiffStateFailedCopyWithImpl<$Res>
    implements $DiffStateFailedCopyWith<$Res> {
  _$DiffStateFailedCopyWithImpl(this._self, this._then);

  final DiffStateFailed _self;
  final $Res Function(DiffStateFailed) _then;

/// Create a copy of DiffState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? error = null,}) {
  return _then(DiffStateFailed(
error: null == error ? _self.error : error ,
  ));
}


}

// dart format on
