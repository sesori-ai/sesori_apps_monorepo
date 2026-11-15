// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'rewind_session_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RewindSessionRequest {

 String get sessionId; String get messageId;/// Client-generated identity of the edited prompt, stable across retries.
/// A retry of an accepted edit succeeds without rewinding again.
 String get promptId; List<PromptPart> get parts; String? get agent; PromptModel? get model; SessionVariant? get variant;/// Whether this and later turns run in the backend's fast mode.
 bool get fastMode;
/// Create a copy of RewindSessionRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RewindSessionRequestCopyWith<RewindSessionRequest> get copyWith => _$RewindSessionRequestCopyWithImpl<RewindSessionRequest>(this as RewindSessionRequest, _$identity);

  /// Serializes this RewindSessionRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RewindSessionRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RewindSessionRequest&&(identical(other.sessionId, _this.sessionId) || other.sessionId == _this.sessionId)&&(identical(other.messageId, _this.messageId) || other.messageId == _this.messageId)&&(identical(other.promptId, _this.promptId) || other.promptId == _this.promptId)&&const DeepCollectionEquality().equals(other.parts, _this.parts)&&(identical(other.agent, _this.agent) || other.agent == _this.agent)&&(identical(other.model, _this.model) || other.model == _this.model)&&(identical(other.variant, _this.variant) || other.variant == _this.variant)&&(identical(other.fastMode, _this.fastMode) || other.fastMode == _this.fastMode));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RewindSessionRequest;
  return Object.hash(runtimeType,_this.sessionId,_this.messageId,_this.promptId,const DeepCollectionEquality().hash(_this.parts),_this.agent,_this.model,_this.variant,_this.fastMode);
}

@override
String toString() {
  final _this = this as RewindSessionRequest;
  return 'RewindSessionRequest(sessionId: ${_this.sessionId}, messageId: ${_this.messageId}, promptId: ${_this.promptId}, parts: ${_this.parts}, agent: ${_this.agent}, model: ${_this.model}, variant: ${_this.variant}, fastMode: ${_this.fastMode})';
}


}

/// @nodoc
abstract mixin class $RewindSessionRequestCopyWith<$Res>  {
  factory $RewindSessionRequestCopyWith(RewindSessionRequest value, $Res Function(RewindSessionRequest) _then) = _$RewindSessionRequestCopyWithImpl;
@useResult
$Res call({
 String sessionId, String messageId, String promptId, List<PromptPart> parts, String? agent, PromptModel? model, SessionVariant? variant, bool fastMode
});


$PromptModelCopyWith<$Res>? get model;$SessionVariantCopyWith<$Res>? get variant;

}
/// @nodoc
class _$RewindSessionRequestCopyWithImpl<$Res>
    implements $RewindSessionRequestCopyWith<$Res> {
  _$RewindSessionRequestCopyWithImpl(this._self, this._then);

  final RewindSessionRequest _self;
  final $Res Function(RewindSessionRequest) _then;

/// Create a copy of RewindSessionRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = null,Object? messageId = null,Object? promptId = null,Object? parts = null,Object? agent = freezed,Object? model = freezed,Object? variant = freezed,Object? fastMode = null,}) {
  return _then(RewindSessionRequest(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,promptId: null == promptId ? _self.promptId : promptId // ignore: cast_nullable_to_non_nullable
as String,parts: null == parts ? _self.parts : parts // ignore: cast_nullable_to_non_nullable
as List<PromptPart>,agent: freezed == agent ? _self.agent : agent // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as PromptModel?,variant: freezed == variant ? _self.variant : variant // ignore: cast_nullable_to_non_nullable
as SessionVariant?,fastMode: null == fastMode ? _self.fastMode : fastMode // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of RewindSessionRequest
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
}/// Create a copy of RewindSessionRequest
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

class _RewindSessionRequest implements RewindSessionRequest {
  const _RewindSessionRequest({required this.sessionId, required this.messageId, required this.promptId, required  List<PromptPart> parts, required this.agent, required this.model, required this.variant, required this.fastMode}): _parts = parts;
  factory _RewindSessionRequest.fromJson(Map<String, dynamic> json) => _$RewindSessionRequestFromJson(json);

@override final  String sessionId;
@override final  String messageId;
/// Client-generated identity of the edited prompt, stable across retries.
/// A retry of an accepted edit succeeds without rewinding again.
@override final  String promptId;
 final  List<PromptPart> _parts;
@override List<PromptPart> get parts {
  if (_parts is EqualUnmodifiableListView) return _parts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_parts);
}

@override final  String? agent;
@override final  PromptModel? model;
@override final  SessionVariant? variant;
/// Whether this and later turns run in the backend's fast mode.
@override final  bool fastMode;

/// Create a copy of RewindSessionRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RewindSessionRequestCopyWith<_RewindSessionRequest> get copyWith => __$RewindSessionRequestCopyWithImpl<_RewindSessionRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RewindSessionRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RewindSessionRequest&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.promptId, promptId) || other.promptId == promptId)&&const DeepCollectionEquality().equals(other.parts, _parts)&&(identical(other.agent, agent) || other.agent == agent)&&(identical(other.model, model) || other.model == model)&&(identical(other.variant, variant) || other.variant == variant)&&(identical(other.fastMode, fastMode) || other.fastMode == fastMode));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,sessionId,messageId,promptId,const DeepCollectionEquality().hash(_parts),agent,model,variant,fastMode);
}

@override
String toString() {
    return 'RewindSessionRequest(sessionId: $sessionId, messageId: $messageId, promptId: $promptId, parts: $parts, agent: $agent, model: $model, variant: $variant, fastMode: $fastMode)';
}


}

/// @nodoc
abstract mixin class _$RewindSessionRequestCopyWith<$Res> implements $RewindSessionRequestCopyWith<$Res> {
  factory _$RewindSessionRequestCopyWith(_RewindSessionRequest value, $Res Function(_RewindSessionRequest) _then) = __$RewindSessionRequestCopyWithImpl;
@override @useResult
$Res call({
 String sessionId, String messageId, String promptId, List<PromptPart> parts, String? agent, PromptModel? model, SessionVariant? variant, bool fastMode
});


@override $PromptModelCopyWith<$Res>? get model;@override $SessionVariantCopyWith<$Res>? get variant;

}
/// @nodoc
class __$RewindSessionRequestCopyWithImpl<$Res>
    implements _$RewindSessionRequestCopyWith<$Res> {
  __$RewindSessionRequestCopyWithImpl(this._self, this._then);

  final _RewindSessionRequest _self;
  final $Res Function(_RewindSessionRequest) _then;

/// Create a copy of RewindSessionRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? messageId = null,Object? promptId = null,Object? parts = null,Object? agent = freezed,Object? model = freezed,Object? variant = freezed,Object? fastMode = null,}) {
  return _then(_RewindSessionRequest(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,promptId: null == promptId ? _self.promptId : promptId // ignore: cast_nullable_to_non_nullable
as String,parts: null == parts ? _self._parts : parts // ignore: cast_nullable_to_non_nullable
as List<PromptPart>,agent: freezed == agent ? _self.agent : agent // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as PromptModel?,variant: freezed == variant ? _self.variant : variant // ignore: cast_nullable_to_non_nullable
as SessionVariant?,fastMode: null == fastMode ? _self.fastMode : fastMode // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of RewindSessionRequest
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
}/// Create a copy of RewindSessionRequest
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
