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
mixin _$FilesystemSuggestionsRequest {

 int get maxResults; String? get prefix;
/// Create a copy of FilesystemSuggestionsRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FilesystemSuggestionsRequestCopyWith<FilesystemSuggestionsRequest> get copyWith => _$FilesystemSuggestionsRequestCopyWithImpl<FilesystemSuggestionsRequest>(this as FilesystemSuggestionsRequest, _$identity);

  /// Serializes this FilesystemSuggestionsRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FilesystemSuggestionsRequest&&(identical(other.maxResults, maxResults) || other.maxResults == maxResults)&&(identical(other.prefix, prefix) || other.prefix == prefix));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,maxResults,prefix);

@override
String toString() {
  return 'FilesystemSuggestionsRequest(maxResults: $maxResults, prefix: $prefix)';
}


}

/// @nodoc
abstract mixin class $FilesystemSuggestionsRequestCopyWith<$Res>  {
  factory $FilesystemSuggestionsRequestCopyWith(FilesystemSuggestionsRequest value, $Res Function(FilesystemSuggestionsRequest) _then) = _$FilesystemSuggestionsRequestCopyWithImpl;
@useResult
$Res call({
 int maxResults, String? prefix
});




}
/// @nodoc
class _$FilesystemSuggestionsRequestCopyWithImpl<$Res>
    implements $FilesystemSuggestionsRequestCopyWith<$Res> {
  _$FilesystemSuggestionsRequestCopyWithImpl(this._self, this._then);

  final FilesystemSuggestionsRequest _self;
  final $Res Function(FilesystemSuggestionsRequest) _then;

/// Create a copy of FilesystemSuggestionsRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? maxResults = null,Object? prefix = freezed,}) {
  return _then(_self.copyWith(
maxResults: null == maxResults ? _self.maxResults : maxResults // ignore: cast_nullable_to_non_nullable
as int,prefix: freezed == prefix ? _self.prefix : prefix // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _FilesystemSuggestionsRequest implements FilesystemSuggestionsRequest {
  const _FilesystemSuggestionsRequest({required this.maxResults, required this.prefix});
  factory _FilesystemSuggestionsRequest.fromJson(Map<String, dynamic> json) => _$FilesystemSuggestionsRequestFromJson(json);

@override final  int maxResults;
@override final  String? prefix;

/// Create a copy of FilesystemSuggestionsRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FilesystemSuggestionsRequestCopyWith<_FilesystemSuggestionsRequest> get copyWith => __$FilesystemSuggestionsRequestCopyWithImpl<_FilesystemSuggestionsRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FilesystemSuggestionsRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FilesystemSuggestionsRequest&&(identical(other.maxResults, maxResults) || other.maxResults == maxResults)&&(identical(other.prefix, prefix) || other.prefix == prefix));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,maxResults,prefix);

@override
String toString() {
  return 'FilesystemSuggestionsRequest(maxResults: $maxResults, prefix: $prefix)';
}


}

/// @nodoc
abstract mixin class _$FilesystemSuggestionsRequestCopyWith<$Res> implements $FilesystemSuggestionsRequestCopyWith<$Res> {
  factory _$FilesystemSuggestionsRequestCopyWith(_FilesystemSuggestionsRequest value, $Res Function(_FilesystemSuggestionsRequest) _then) = __$FilesystemSuggestionsRequestCopyWithImpl;
@override @useResult
$Res call({
 int maxResults, String? prefix
});




}
/// @nodoc
class __$FilesystemSuggestionsRequestCopyWithImpl<$Res>
    implements _$FilesystemSuggestionsRequestCopyWith<$Res> {
  __$FilesystemSuggestionsRequestCopyWithImpl(this._self, this._then);

  final _FilesystemSuggestionsRequest _self;
  final $Res Function(_FilesystemSuggestionsRequest) _then;

/// Create a copy of FilesystemSuggestionsRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? maxResults = null,Object? prefix = freezed,}) {
  return _then(_FilesystemSuggestionsRequest(
maxResults: null == maxResults ? _self.maxResults : maxResults // ignore: cast_nullable_to_non_nullable
as int,prefix: freezed == prefix ? _self.prefix : prefix // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$FilesystemSuggestions {

 List<FilesystemSuggestion> get data;
/// Create a copy of FilesystemSuggestions
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FilesystemSuggestionsCopyWith<FilesystemSuggestions> get copyWith => _$FilesystemSuggestionsCopyWithImpl<FilesystemSuggestions>(this as FilesystemSuggestions, _$identity);

  /// Serializes this FilesystemSuggestions to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FilesystemSuggestions&&const DeepCollectionEquality().equals(other.data, data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(data));

@override
String toString() {
  return 'FilesystemSuggestions(data: $data)';
}


}

/// @nodoc
abstract mixin class $FilesystemSuggestionsCopyWith<$Res>  {
  factory $FilesystemSuggestionsCopyWith(FilesystemSuggestions value, $Res Function(FilesystemSuggestions) _then) = _$FilesystemSuggestionsCopyWithImpl;
@useResult
$Res call({
 List<FilesystemSuggestion> data
});




}
/// @nodoc
class _$FilesystemSuggestionsCopyWithImpl<$Res>
    implements $FilesystemSuggestionsCopyWith<$Res> {
  _$FilesystemSuggestionsCopyWithImpl(this._self, this._then);

  final FilesystemSuggestions _self;
  final $Res Function(FilesystemSuggestions) _then;

/// Create a copy of FilesystemSuggestions
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<FilesystemSuggestion>,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _FilesystemSuggestions implements FilesystemSuggestions {
  const _FilesystemSuggestions({required final  List<FilesystemSuggestion> data}): _data = data;
  factory _FilesystemSuggestions.fromJson(Map<String, dynamic> json) => _$FilesystemSuggestionsFromJson(json);

 final  List<FilesystemSuggestion> _data;
@override List<FilesystemSuggestion> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}


/// Create a copy of FilesystemSuggestions
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FilesystemSuggestionsCopyWith<_FilesystemSuggestions> get copyWith => __$FilesystemSuggestionsCopyWithImpl<_FilesystemSuggestions>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FilesystemSuggestionsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FilesystemSuggestions&&const DeepCollectionEquality().equals(other._data, _data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_data));

@override
String toString() {
  return 'FilesystemSuggestions(data: $data)';
}


}

/// @nodoc
abstract mixin class _$FilesystemSuggestionsCopyWith<$Res> implements $FilesystemSuggestionsCopyWith<$Res> {
  factory _$FilesystemSuggestionsCopyWith(_FilesystemSuggestions value, $Res Function(_FilesystemSuggestions) _then) = __$FilesystemSuggestionsCopyWithImpl;
@override @useResult
$Res call({
 List<FilesystemSuggestion> data
});




}
/// @nodoc
class __$FilesystemSuggestionsCopyWithImpl<$Res>
    implements _$FilesystemSuggestionsCopyWith<$Res> {
  __$FilesystemSuggestionsCopyWithImpl(this._self, this._then);

  final _FilesystemSuggestions _self;
  final $Res Function(_FilesystemSuggestions) _then;

/// Create a copy of FilesystemSuggestions
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_FilesystemSuggestions(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<FilesystemSuggestion>,
  ));
}


}


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
