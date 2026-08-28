// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'project_glossary_scope.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
ProjectGlossaryScope _$ProjectGlossaryScopeFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'repository':
          return RepositoryProjectGlossaryScope.fromJson(
            json
          );
                case 'bridge_local':
          return BridgeLocalProjectGlossaryScope.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'type',
  'ProjectGlossaryScope',
  'Invalid union type "${json['type']}"!'
);
        }
      
}

/// @nodoc
mixin _$ProjectGlossaryScope {

@ProjectGlossaryKeyJsonConverter() ProjectGlossaryKey get projectKey;
/// Create a copy of ProjectGlossaryScope
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectGlossaryScopeCopyWith<ProjectGlossaryScope> get copyWith => _$ProjectGlossaryScopeCopyWithImpl<ProjectGlossaryScope>(this as ProjectGlossaryScope, _$identity);

  /// Serializes this ProjectGlossaryScope to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectGlossaryScope&&(identical(other.projectKey, projectKey) || other.projectKey == projectKey));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,projectKey);

@override
String toString() {
  return 'ProjectGlossaryScope(projectKey: $projectKey)';
}


}

/// @nodoc
abstract mixin class $ProjectGlossaryScopeCopyWith<$Res>  {
  factory $ProjectGlossaryScopeCopyWith(ProjectGlossaryScope value, $Res Function(ProjectGlossaryScope) _then) = _$ProjectGlossaryScopeCopyWithImpl;
@useResult
$Res call({
@ProjectGlossaryKeyJsonConverter() ProjectGlossaryKey projectKey
});




}
/// @nodoc
class _$ProjectGlossaryScopeCopyWithImpl<$Res>
    implements $ProjectGlossaryScopeCopyWith<$Res> {
  _$ProjectGlossaryScopeCopyWithImpl(this._self, this._then);

  final ProjectGlossaryScope _self;
  final $Res Function(ProjectGlossaryScope) _then;

/// Create a copy of ProjectGlossaryScope
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? projectKey = null,}) {
  return _then(_self.copyWith(
projectKey: null == projectKey ? _self.projectKey : projectKey // ignore: cast_nullable_to_non_nullable
as ProjectGlossaryKey,
  ));
}

}



/// @nodoc
@JsonSerializable()

class RepositoryProjectGlossaryScope implements ProjectGlossaryScope {
  const RepositoryProjectGlossaryScope({@ProjectGlossaryKeyJsonConverter() required this.projectKey,  String? $type}): $type = $type ?? 'repository';
  factory RepositoryProjectGlossaryScope.fromJson(Map<String, dynamic> json) => _$RepositoryProjectGlossaryScopeFromJson(json);

@override@ProjectGlossaryKeyJsonConverter() final  ProjectGlossaryKey projectKey;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of ProjectGlossaryScope
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RepositoryProjectGlossaryScopeCopyWith<RepositoryProjectGlossaryScope> get copyWith => _$RepositoryProjectGlossaryScopeCopyWithImpl<RepositoryProjectGlossaryScope>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RepositoryProjectGlossaryScopeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RepositoryProjectGlossaryScope&&(identical(other.projectKey, projectKey) || other.projectKey == projectKey));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,projectKey);

@override
String toString() {
  return 'ProjectGlossaryScope.repository(projectKey: $projectKey)';
}


}

/// @nodoc
abstract mixin class $RepositoryProjectGlossaryScopeCopyWith<$Res> implements $ProjectGlossaryScopeCopyWith<$Res> {
  factory $RepositoryProjectGlossaryScopeCopyWith(RepositoryProjectGlossaryScope value, $Res Function(RepositoryProjectGlossaryScope) _then) = _$RepositoryProjectGlossaryScopeCopyWithImpl;
@override @useResult
$Res call({
@ProjectGlossaryKeyJsonConverter() ProjectGlossaryKey projectKey
});




}
/// @nodoc
class _$RepositoryProjectGlossaryScopeCopyWithImpl<$Res>
    implements $RepositoryProjectGlossaryScopeCopyWith<$Res> {
  _$RepositoryProjectGlossaryScopeCopyWithImpl(this._self, this._then);

  final RepositoryProjectGlossaryScope _self;
  final $Res Function(RepositoryProjectGlossaryScope) _then;

/// Create a copy of ProjectGlossaryScope
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? projectKey = null,}) {
  return _then(RepositoryProjectGlossaryScope(
projectKey: null == projectKey ? _self.projectKey : projectKey // ignore: cast_nullable_to_non_nullable
as ProjectGlossaryKey,
  ));
}


}

/// @nodoc
@JsonSerializable()

class BridgeLocalProjectGlossaryScope implements ProjectGlossaryScope {
  const BridgeLocalProjectGlossaryScope({@ProjectGlossaryKeyJsonConverter() required this.projectKey, required this.bridgeId,  String? $type}): $type = $type ?? 'bridge_local';
  factory BridgeLocalProjectGlossaryScope.fromJson(Map<String, dynamic> json) => _$BridgeLocalProjectGlossaryScopeFromJson(json);

@override@ProjectGlossaryKeyJsonConverter() final  ProjectGlossaryKey projectKey;
 final  String bridgeId;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of ProjectGlossaryScope
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BridgeLocalProjectGlossaryScopeCopyWith<BridgeLocalProjectGlossaryScope> get copyWith => _$BridgeLocalProjectGlossaryScopeCopyWithImpl<BridgeLocalProjectGlossaryScope>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BridgeLocalProjectGlossaryScopeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BridgeLocalProjectGlossaryScope&&(identical(other.projectKey, projectKey) || other.projectKey == projectKey)&&(identical(other.bridgeId, bridgeId) || other.bridgeId == bridgeId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,projectKey,bridgeId);

@override
String toString() {
  return 'ProjectGlossaryScope.bridgeLocal(projectKey: $projectKey, bridgeId: $bridgeId)';
}


}

/// @nodoc
abstract mixin class $BridgeLocalProjectGlossaryScopeCopyWith<$Res> implements $ProjectGlossaryScopeCopyWith<$Res> {
  factory $BridgeLocalProjectGlossaryScopeCopyWith(BridgeLocalProjectGlossaryScope value, $Res Function(BridgeLocalProjectGlossaryScope) _then) = _$BridgeLocalProjectGlossaryScopeCopyWithImpl;
@override @useResult
$Res call({
@ProjectGlossaryKeyJsonConverter() ProjectGlossaryKey projectKey, String bridgeId
});




}
/// @nodoc
class _$BridgeLocalProjectGlossaryScopeCopyWithImpl<$Res>
    implements $BridgeLocalProjectGlossaryScopeCopyWith<$Res> {
  _$BridgeLocalProjectGlossaryScopeCopyWithImpl(this._self, this._then);

  final BridgeLocalProjectGlossaryScope _self;
  final $Res Function(BridgeLocalProjectGlossaryScope) _then;

/// Create a copy of ProjectGlossaryScope
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? projectKey = null,Object? bridgeId = null,}) {
  return _then(BridgeLocalProjectGlossaryScope(
projectKey: null == projectKey ? _self.projectKey : projectKey // ignore: cast_nullable_to_non_nullable
as ProjectGlossaryKey,bridgeId: null == bridgeId ? _self.bridgeId : bridgeId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
