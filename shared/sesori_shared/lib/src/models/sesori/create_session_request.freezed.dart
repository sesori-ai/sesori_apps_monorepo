// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'create_session_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CreateSessionRequest {

 String get projectId; List<PromptPart> get parts; String? get agent; PromptModel? get model; String? get command; SessionVariant? get variant; bool get dedicatedWorktree;
/// Create a copy of CreateSessionRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CreateSessionRequestCopyWith<CreateSessionRequest> get copyWith => _$CreateSessionRequestCopyWithImpl<CreateSessionRequest>(this as CreateSessionRequest, _$identity);

  /// Serializes this CreateSessionRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CreateSessionRequest&&(identical(other.projectId, projectId) || other.projectId == projectId)&&const DeepCollectionEquality().equals(other.parts, parts)&&(identical(other.agent, agent) || other.agent == agent)&&(identical(other.model, model) || other.model == model)&&(identical(other.command, command) || other.command == command)&&(identical(other.variant, variant) || other.variant == variant)&&(identical(other.dedicatedWorktree, dedicatedWorktree) || other.dedicatedWorktree == dedicatedWorktree));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,projectId,const DeepCollectionEquality().hash(parts),agent,model,command,variant,dedicatedWorktree);

@override
String toString() {
  return 'CreateSessionRequest(projectId: $projectId, parts: $parts, agent: $agent, model: $model, command: $command, variant: $variant, dedicatedWorktree: $dedicatedWorktree)';
}


}

/// @nodoc
abstract mixin class $CreateSessionRequestCopyWith<$Res>  {
  factory $CreateSessionRequestCopyWith(CreateSessionRequest value, $Res Function(CreateSessionRequest) _then) = _$CreateSessionRequestCopyWithImpl;
@useResult
$Res call({
 String projectId, List<PromptPart> parts, String? agent, PromptModel? model, String? command, SessionVariant? variant, bool dedicatedWorktree
});


$PromptModelCopyWith<$Res>? get model;$SessionVariantCopyWith<$Res>? get variant;

}
/// @nodoc
class _$CreateSessionRequestCopyWithImpl<$Res>
    implements $CreateSessionRequestCopyWith<$Res> {
  _$CreateSessionRequestCopyWithImpl(this._self, this._then);

  final CreateSessionRequest _self;
  final $Res Function(CreateSessionRequest) _then;

/// Create a copy of CreateSessionRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? projectId = null,Object? parts = null,Object? agent = freezed,Object? model = freezed,Object? command = freezed,Object? variant = freezed,Object? dedicatedWorktree = null,}) {
  return _then(_self.copyWith(
projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,parts: null == parts ? _self.parts : parts // ignore: cast_nullable_to_non_nullable
as List<PromptPart>,agent: freezed == agent ? _self.agent : agent // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as PromptModel?,command: freezed == command ? _self.command : command // ignore: cast_nullable_to_non_nullable
as String?,variant: freezed == variant ? _self.variant : variant // ignore: cast_nullable_to_non_nullable
as SessionVariant?,dedicatedWorktree: null == dedicatedWorktree ? _self.dedicatedWorktree : dedicatedWorktree // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of CreateSessionRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PromptModelCopyWith<$Res>? get model {
    if (_self.model == null) {
    return null;
  }

  return $PromptModelCopyWith<$Res>(_self.model!, (value) {
    return _then(_self.copyWith(model: value));
  });
}/// Create a copy of CreateSessionRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SessionVariantCopyWith<$Res>? get variant {
    if (_self.variant == null) {
    return null;
  }

  return $SessionVariantCopyWith<$Res>(_self.variant!, (value) {
    return _then(_self.copyWith(variant: value));
  });
}
}



/// @nodoc
@JsonSerializable()

class _CreateSessionRequest implements CreateSessionRequest {
  const _CreateSessionRequest({required this.projectId, required final  List<PromptPart> parts, required this.agent, required this.model, required this.command, required this.variant, required this.dedicatedWorktree}): _parts = parts;
  factory _CreateSessionRequest.fromJson(Map<String, dynamic> json) => _$CreateSessionRequestFromJson(json);

@override final  String projectId;
 final  List<PromptPart> _parts;
@override List<PromptPart> get parts {
  if (_parts is EqualUnmodifiableListView) return _parts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_parts);
}

@override final  String? agent;
@override final  PromptModel? model;
@override final  String? command;
@override final  SessionVariant? variant;
@override final  bool dedicatedWorktree;

/// Create a copy of CreateSessionRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CreateSessionRequestCopyWith<_CreateSessionRequest> get copyWith => __$CreateSessionRequestCopyWithImpl<_CreateSessionRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CreateSessionRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CreateSessionRequest&&(identical(other.projectId, projectId) || other.projectId == projectId)&&const DeepCollectionEquality().equals(other._parts, _parts)&&(identical(other.agent, agent) || other.agent == agent)&&(identical(other.model, model) || other.model == model)&&(identical(other.command, command) || other.command == command)&&(identical(other.variant, variant) || other.variant == variant)&&(identical(other.dedicatedWorktree, dedicatedWorktree) || other.dedicatedWorktree == dedicatedWorktree));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,projectId,const DeepCollectionEquality().hash(_parts),agent,model,command,variant,dedicatedWorktree);

@override
String toString() {
  return 'CreateSessionRequest(projectId: $projectId, parts: $parts, agent: $agent, model: $model, command: $command, variant: $variant, dedicatedWorktree: $dedicatedWorktree)';
}


}

/// @nodoc
abstract mixin class _$CreateSessionRequestCopyWith<$Res> implements $CreateSessionRequestCopyWith<$Res> {
  factory _$CreateSessionRequestCopyWith(_CreateSessionRequest value, $Res Function(_CreateSessionRequest) _then) = __$CreateSessionRequestCopyWithImpl;
@override @useResult
$Res call({
 String projectId, List<PromptPart> parts, String? agent, PromptModel? model, String? command, SessionVariant? variant, bool dedicatedWorktree
});


@override $PromptModelCopyWith<$Res>? get model;@override $SessionVariantCopyWith<$Res>? get variant;

}
/// @nodoc
class __$CreateSessionRequestCopyWithImpl<$Res>
    implements _$CreateSessionRequestCopyWith<$Res> {
  __$CreateSessionRequestCopyWithImpl(this._self, this._then);

  final _CreateSessionRequest _self;
  final $Res Function(_CreateSessionRequest) _then;

/// Create a copy of CreateSessionRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? projectId = null,Object? parts = null,Object? agent = freezed,Object? model = freezed,Object? command = freezed,Object? variant = freezed,Object? dedicatedWorktree = null,}) {
  return _then(_CreateSessionRequest(
projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,parts: null == parts ? _self._parts : parts // ignore: cast_nullable_to_non_nullable
as List<PromptPart>,agent: freezed == agent ? _self.agent : agent // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as PromptModel?,command: freezed == command ? _self.command : command // ignore: cast_nullable_to_non_nullable
as String?,variant: freezed == variant ? _self.variant : variant // ignore: cast_nullable_to_non_nullable
as SessionVariant?,dedicatedWorktree: null == dedicatedWorktree ? _self.dedicatedWorktree : dedicatedWorktree // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of CreateSessionRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PromptModelCopyWith<$Res>? get model {
    if (_self.model == null) {
    return null;
  }

  return $PromptModelCopyWith<$Res>(_self.model!, (value) {
    return _then(_self.copyWith(model: value));
  });
}/// Create a copy of CreateSessionRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SessionVariantCopyWith<$Res>? get variant {
    if (_self.variant == null) {
    return null;
  }

  return $SessionVariantCopyWith<$Res>(_self.variant!, (value) {
    return _then(_self.copyWith(variant: value));
  });
}
}

// dart format on
