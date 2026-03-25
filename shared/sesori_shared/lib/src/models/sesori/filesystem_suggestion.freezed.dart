// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'filesystem_suggestion.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FilesystemSuggestion {

 String get path; String get name; bool get isGitRepo;
/// Create a copy of FilesystemSuggestion
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FilesystemSuggestionCopyWith<FilesystemSuggestion> get copyWith => _$FilesystemSuggestionCopyWithImpl<FilesystemSuggestion>(this as FilesystemSuggestion, _$identity);

  /// Serializes this FilesystemSuggestion to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FilesystemSuggestion&&(identical(other.path, path) || other.path == path)&&(identical(other.name, name) || other.name == name)&&(identical(other.isGitRepo, isGitRepo) || other.isGitRepo == isGitRepo));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,path,name,isGitRepo);

@override
String toString() {
  return 'FilesystemSuggestion(path: $path, name: $name, isGitRepo: $isGitRepo)';
}


}

/// @nodoc
abstract mixin class $FilesystemSuggestionCopyWith<$Res>  {
  factory $FilesystemSuggestionCopyWith(FilesystemSuggestion value, $Res Function(FilesystemSuggestion) _then) = _$FilesystemSuggestionCopyWithImpl;
@useResult
$Res call({
 String path, String name, bool isGitRepo
});




}
/// @nodoc
class _$FilesystemSuggestionCopyWithImpl<$Res>
    implements $FilesystemSuggestionCopyWith<$Res> {
  _$FilesystemSuggestionCopyWithImpl(this._self, this._then);

  final FilesystemSuggestion _self;
  final $Res Function(FilesystemSuggestion) _then;

/// Create a copy of FilesystemSuggestion
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? path = null,Object? name = null,Object? isGitRepo = null,}) {
  return _then(_self.copyWith(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,isGitRepo: null == isGitRepo ? _self.isGitRepo : isGitRepo // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _FilesystemSuggestion implements FilesystemSuggestion {
  const _FilesystemSuggestion({required this.path, required this.name, required this.isGitRepo});
  factory _FilesystemSuggestion.fromJson(Map<String, dynamic> json) => _$FilesystemSuggestionFromJson(json);

@override final  String path;
@override final  String name;
@override final  bool isGitRepo;

/// Create a copy of FilesystemSuggestion
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FilesystemSuggestionCopyWith<_FilesystemSuggestion> get copyWith => __$FilesystemSuggestionCopyWithImpl<_FilesystemSuggestion>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FilesystemSuggestionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FilesystemSuggestion&&(identical(other.path, path) || other.path == path)&&(identical(other.name, name) || other.name == name)&&(identical(other.isGitRepo, isGitRepo) || other.isGitRepo == isGitRepo));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,path,name,isGitRepo);

@override
String toString() {
  return 'FilesystemSuggestion(path: $path, name: $name, isGitRepo: $isGitRepo)';
}


}

/// @nodoc
abstract mixin class _$FilesystemSuggestionCopyWith<$Res> implements $FilesystemSuggestionCopyWith<$Res> {
  factory _$FilesystemSuggestionCopyWith(_FilesystemSuggestion value, $Res Function(_FilesystemSuggestion) _then) = __$FilesystemSuggestionCopyWithImpl;
@override @useResult
$Res call({
 String path, String name, bool isGitRepo
});




}
/// @nodoc
class __$FilesystemSuggestionCopyWithImpl<$Res>
    implements _$FilesystemSuggestionCopyWith<$Res> {
  __$FilesystemSuggestionCopyWithImpl(this._self, this._then);

  final _FilesystemSuggestion _self;
  final $Res Function(_FilesystemSuggestion) _then;

/// Create a copy of FilesystemSuggestion
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? path = null,Object? name = null,Object? isGitRepo = null,}) {
  return _then(_FilesystemSuggestion(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,isGitRepo: null == isGitRepo ? _self.isGitRepo : isGitRepo // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
