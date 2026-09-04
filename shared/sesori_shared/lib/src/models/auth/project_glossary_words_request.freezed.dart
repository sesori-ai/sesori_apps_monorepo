// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'project_glossary_words_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ProjectGlossaryWordsRequest {

 ProjectGlossaryScope get scope; List<String> get words;
/// Create a copy of ProjectGlossaryWordsRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectGlossaryWordsRequestCopyWith<ProjectGlossaryWordsRequest> get copyWith => _$ProjectGlossaryWordsRequestCopyWithImpl<ProjectGlossaryWordsRequest>(this as ProjectGlossaryWordsRequest, _$identity);

  /// Serializes this ProjectGlossaryWordsRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectGlossaryWordsRequest&&(identical(other.scope, scope) || other.scope == scope)&&const DeepCollectionEquality().equals(other.words, words));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,scope,const DeepCollectionEquality().hash(words));

@override
String toString() {
  return 'ProjectGlossaryWordsRequest(scope: $scope, words: $words)';
}


}

/// @nodoc
abstract mixin class $ProjectGlossaryWordsRequestCopyWith<$Res>  {
  factory $ProjectGlossaryWordsRequestCopyWith(ProjectGlossaryWordsRequest value, $Res Function(ProjectGlossaryWordsRequest) _then) = _$ProjectGlossaryWordsRequestCopyWithImpl;
@useResult
$Res call({
 ProjectGlossaryScope scope, List<String> words
});


$ProjectGlossaryScopeCopyWith<$Res> get scope;

}
/// @nodoc
class _$ProjectGlossaryWordsRequestCopyWithImpl<$Res>
    implements $ProjectGlossaryWordsRequestCopyWith<$Res> {
  _$ProjectGlossaryWordsRequestCopyWithImpl(this._self, this._then);

  final ProjectGlossaryWordsRequest _self;
  final $Res Function(ProjectGlossaryWordsRequest) _then;

/// Create a copy of ProjectGlossaryWordsRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? scope = null,Object? words = null,}) {
  return _then(ProjectGlossaryWordsRequest(
scope: null == scope ? _self.scope : scope // ignore: cast_nullable_to_non_nullable
as ProjectGlossaryScope,words: null == words ? _self.words : words // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}
/// Create a copy of ProjectGlossaryWordsRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProjectGlossaryScopeCopyWith<$Res> get scope {
  
  return $ProjectGlossaryScopeCopyWith<$Res>(_self.scope, (value) {
    return _then(_self.copyWith(scope: value));
  });
}
}



/// @nodoc
@JsonSerializable()

class _ProjectGlossaryWordsRequest implements ProjectGlossaryWordsRequest {
  const _ProjectGlossaryWordsRequest({required this.scope, required  List<String> words}): _words = words;
  factory _ProjectGlossaryWordsRequest.fromJson(Map<String, dynamic> json) => _$ProjectGlossaryWordsRequestFromJson(json);

@override final  ProjectGlossaryScope scope;
 final  List<String> _words;
@override List<String> get words {
  if (_words is EqualUnmodifiableListView) return _words;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_words);
}


/// Create a copy of ProjectGlossaryWordsRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProjectGlossaryWordsRequestCopyWith<_ProjectGlossaryWordsRequest> get copyWith => __$ProjectGlossaryWordsRequestCopyWithImpl<_ProjectGlossaryWordsRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProjectGlossaryWordsRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProjectGlossaryWordsRequest&&(identical(other.scope, scope) || other.scope == scope)&&const DeepCollectionEquality().equals(other._words, _words));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,scope,const DeepCollectionEquality().hash(_words));

@override
String toString() {
  return 'ProjectGlossaryWordsRequest(scope: $scope, words: $words)';
}


}

/// @nodoc
abstract mixin class _$ProjectGlossaryWordsRequestCopyWith<$Res> implements $ProjectGlossaryWordsRequestCopyWith<$Res> {
  factory _$ProjectGlossaryWordsRequestCopyWith(_ProjectGlossaryWordsRequest value, $Res Function(_ProjectGlossaryWordsRequest) _then) = __$ProjectGlossaryWordsRequestCopyWithImpl;
@override @useResult
$Res call({
 ProjectGlossaryScope scope, List<String> words
});


@override $ProjectGlossaryScopeCopyWith<$Res> get scope;

}
/// @nodoc
class __$ProjectGlossaryWordsRequestCopyWithImpl<$Res>
    implements _$ProjectGlossaryWordsRequestCopyWith<$Res> {
  __$ProjectGlossaryWordsRequestCopyWithImpl(this._self, this._then);

  final _ProjectGlossaryWordsRequest _self;
  final $Res Function(_ProjectGlossaryWordsRequest) _then;

/// Create a copy of ProjectGlossaryWordsRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? scope = null,Object? words = null,}) {
  return _then(_ProjectGlossaryWordsRequest(
scope: null == scope ? _self.scope : scope // ignore: cast_nullable_to_non_nullable
as ProjectGlossaryScope,words: null == words ? _self._words : words // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

/// Create a copy of ProjectGlossaryWordsRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProjectGlossaryScopeCopyWith<$Res> get scope {
  
  return $ProjectGlossaryScopeCopyWith<$Res>(_self.scope, (value) {
    return _then(_self.copyWith(scope: value));
  });
}
}

// dart format on
