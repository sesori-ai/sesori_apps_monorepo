// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plugin_list_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PluginMetadata {

 String get id; String get displayName; bool get isDefault;@JsonKey(unknownEnumValue: PluginLifecycleState.unavailable) PluginLifecycleState get state; String? get actionHint;/// Set while the bridge holds this harness back after a refused request,
/// which lists it although its [state] is unavailable, so the user can
/// pick it, read why and check setup again; [actionHint] then says what to
/// fix. Null for every other harness.
@JsonKey(unknownEnumValue: PluginFailureBlock.unknown) PluginFailureBlock? get failureBlock; bool get supportsPromptAttachments;/// Where this harness answers MCP inventory; empty when it has no MCP
/// support. Mirrors `PluginManagementMetadata.mcpScopes`.
@JsonKey(unknownEnumValue: McpScopeKind.unknown) Set<McpScopeKind>? get mcpScopes;/// Why a failed harness could not start, in words its plugin wrote for the
/// user. Mirrors `PluginManagementMetadata.failureReason`: null when the
/// harness has not failed or gave no such reason; older bridges omit it,
/// which reads the same.
 String? get failureReason;
/// Create a copy of PluginMetadata
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginMetadataCopyWith<PluginMetadata> get copyWith => _$PluginMetadataCopyWithImpl<PluginMetadata>(this as PluginMetadata, _$identity);

  /// Serializes this PluginMetadata to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PluginMetadata;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginMetadata&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.displayName, _this.displayName) || other.displayName == _this.displayName)&&(identical(other.isDefault, _this.isDefault) || other.isDefault == _this.isDefault)&&(identical(other.state, _this.state) || other.state == _this.state)&&(identical(other.actionHint, _this.actionHint) || other.actionHint == _this.actionHint)&&(identical(other.failureBlock, _this.failureBlock) || other.failureBlock == _this.failureBlock)&&(identical(other.supportsPromptAttachments, _this.supportsPromptAttachments) || other.supportsPromptAttachments == _this.supportsPromptAttachments)&&const DeepCollectionEquality().equals(other.mcpScopes, _this.mcpScopes)&&(identical(other.failureReason, _this.failureReason) || other.failureReason == _this.failureReason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PluginMetadata;
  return Object.hash(runtimeType,_this.id,_this.displayName,_this.isDefault,_this.state,_this.actionHint,_this.failureBlock,_this.supportsPromptAttachments,const DeepCollectionEquality().hash(_this.mcpScopes),_this.failureReason);
}

@override
String toString() {
  final _this = this as PluginMetadata;
  return 'PluginMetadata(id: ${_this.id}, displayName: ${_this.displayName}, isDefault: ${_this.isDefault}, state: ${_this.state}, actionHint: ${_this.actionHint}, failureBlock: ${_this.failureBlock}, supportsPromptAttachments: ${_this.supportsPromptAttachments}, mcpScopes: ${_this.mcpScopes}, failureReason: ${_this.failureReason})';
}


}

/// @nodoc
abstract mixin class $PluginMetadataCopyWith<$Res>  {
  factory $PluginMetadataCopyWith(PluginMetadata value, $Res Function(PluginMetadata) _then) = _$PluginMetadataCopyWithImpl;
@useResult
$Res call({
 String id, String displayName, bool isDefault,@JsonKey(unknownEnumValue: PluginLifecycleState.unavailable) PluginLifecycleState state, String? actionHint,@JsonKey(unknownEnumValue: PluginFailureBlock.unknown) PluginFailureBlock? failureBlock, bool supportsPromptAttachments,@JsonKey(unknownEnumValue: McpScopeKind.unknown) Set<McpScopeKind>? mcpScopes, String? failureReason
});




}
/// @nodoc
class _$PluginMetadataCopyWithImpl<$Res>
    implements $PluginMetadataCopyWith<$Res> {
  _$PluginMetadataCopyWithImpl(this._self, this._then);

  final PluginMetadata _self;
  final $Res Function(PluginMetadata) _then;

/// Create a copy of PluginMetadata
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? displayName = null,Object? isDefault = null,Object? state = null,Object? actionHint = freezed,Object? failureBlock = freezed,Object? supportsPromptAttachments = null,Object? mcpScopes = freezed,Object? failureReason = freezed,}) {
  return _then(PluginMetadata(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,isDefault: null == isDefault ? _self.isDefault : isDefault // ignore: cast_nullable_to_non_nullable
as bool,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as PluginLifecycleState,actionHint: freezed == actionHint ? _self.actionHint : actionHint // ignore: cast_nullable_to_non_nullable
as String?,failureBlock: freezed == failureBlock ? _self.failureBlock : failureBlock // ignore: cast_nullable_to_non_nullable
as PluginFailureBlock?,supportsPromptAttachments: null == supportsPromptAttachments ? _self.supportsPromptAttachments : supportsPromptAttachments // ignore: cast_nullable_to_non_nullable
as bool,mcpScopes: freezed == mcpScopes ? _self.mcpScopes : mcpScopes // ignore: cast_nullable_to_non_nullable
as Set<McpScopeKind>?,failureReason: freezed == failureReason ? _self.failureReason : failureReason // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _PluginMetadata implements PluginMetadata {
  const _PluginMetadata({required this.id, required this.displayName, required this.isDefault, @JsonKey(unknownEnumValue: PluginLifecycleState.unavailable) required this.state, required this.actionHint, @JsonKey(unknownEnumValue: PluginFailureBlock.unknown) required this.failureBlock, this.supportsPromptAttachments = false, @JsonKey(unknownEnumValue: McpScopeKind.unknown) required  Set<McpScopeKind>? mcpScopes, required this.failureReason}): _mcpScopes = mcpScopes;
  factory _PluginMetadata.fromJson(Map<String, dynamic> json) => _$PluginMetadataFromJson(json);

@override final  String id;
@override final  String displayName;
@override final  bool isDefault;
@override@JsonKey(unknownEnumValue: PluginLifecycleState.unavailable) final  PluginLifecycleState state;
@override final  String? actionHint;
/// Set while the bridge holds this harness back after a refused request,
/// which lists it although its [state] is unavailable, so the user can
/// pick it, read why and check setup again; [actionHint] then says what to
/// fix. Null for every other harness.
@override@JsonKey(unknownEnumValue: PluginFailureBlock.unknown) final  PluginFailureBlock? failureBlock;
@override@JsonKey() final  bool supportsPromptAttachments;
/// Where this harness answers MCP inventory; empty when it has no MCP
/// support. Mirrors `PluginManagementMetadata.mcpScopes`.
 final  Set<McpScopeKind>? _mcpScopes;
/// Where this harness answers MCP inventory; empty when it has no MCP
/// support. Mirrors `PluginManagementMetadata.mcpScopes`.
@override@JsonKey(unknownEnumValue: McpScopeKind.unknown) Set<McpScopeKind>? get mcpScopes {
  final value = _mcpScopes;
  if (value == null) return null;
  if (_mcpScopes is EqualUnmodifiableSetView) return _mcpScopes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(value);
}

/// Why a failed harness could not start, in words its plugin wrote for the
/// user. Mirrors `PluginManagementMetadata.failureReason`: null when the
/// harness has not failed or gave no such reason; older bridges omit it,
/// which reads the same.
@override final  String? failureReason;

/// Create a copy of PluginMetadata
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginMetadataCopyWith<_PluginMetadata> get copyWith => __$PluginMetadataCopyWithImpl<_PluginMetadata>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginMetadataToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginMetadata&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.isDefault, isDefault) || other.isDefault == isDefault)&&(identical(other.state, state) || other.state == state)&&(identical(other.actionHint, actionHint) || other.actionHint == actionHint)&&(identical(other.failureBlock, failureBlock) || other.failureBlock == failureBlock)&&(identical(other.supportsPromptAttachments, supportsPromptAttachments) || other.supportsPromptAttachments == supportsPromptAttachments)&&const DeepCollectionEquality().equals(other.mcpScopes, _mcpScopes)&&(identical(other.failureReason, failureReason) || other.failureReason == failureReason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,displayName,isDefault,state,actionHint,failureBlock,supportsPromptAttachments,const DeepCollectionEquality().hash(_mcpScopes),failureReason);
}

@override
String toString() {
    return 'PluginMetadata(id: $id, displayName: $displayName, isDefault: $isDefault, state: $state, actionHint: $actionHint, failureBlock: $failureBlock, supportsPromptAttachments: $supportsPromptAttachments, mcpScopes: $mcpScopes, failureReason: $failureReason)';
}


}

/// @nodoc
abstract mixin class _$PluginMetadataCopyWith<$Res> implements $PluginMetadataCopyWith<$Res> {
  factory _$PluginMetadataCopyWith(_PluginMetadata value, $Res Function(_PluginMetadata) _then) = __$PluginMetadataCopyWithImpl;
@override @useResult
$Res call({
 String id, String displayName, bool isDefault,@JsonKey(unknownEnumValue: PluginLifecycleState.unavailable) PluginLifecycleState state, String? actionHint,@JsonKey(unknownEnumValue: PluginFailureBlock.unknown) PluginFailureBlock? failureBlock, bool supportsPromptAttachments,@JsonKey(unknownEnumValue: McpScopeKind.unknown) Set<McpScopeKind>? mcpScopes, String? failureReason
});




}
/// @nodoc
class __$PluginMetadataCopyWithImpl<$Res>
    implements _$PluginMetadataCopyWith<$Res> {
  __$PluginMetadataCopyWithImpl(this._self, this._then);

  final _PluginMetadata _self;
  final $Res Function(_PluginMetadata) _then;

/// Create a copy of PluginMetadata
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? displayName = null,Object? isDefault = null,Object? state = null,Object? actionHint = freezed,Object? failureBlock = freezed,Object? supportsPromptAttachments = null,Object? mcpScopes = freezed,Object? failureReason = freezed,}) {
  return _then(_PluginMetadata(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,isDefault: null == isDefault ? _self.isDefault : isDefault // ignore: cast_nullable_to_non_nullable
as bool,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as PluginLifecycleState,actionHint: freezed == actionHint ? _self.actionHint : actionHint // ignore: cast_nullable_to_non_nullable
as String?,failureBlock: freezed == failureBlock ? _self.failureBlock : failureBlock // ignore: cast_nullable_to_non_nullable
as PluginFailureBlock?,supportsPromptAttachments: null == supportsPromptAttachments ? _self.supportsPromptAttachments : supportsPromptAttachments // ignore: cast_nullable_to_non_nullable
as bool,mcpScopes: freezed == mcpScopes ? _self._mcpScopes : mcpScopes // ignore: cast_nullable_to_non_nullable
as Set<McpScopeKind>?,failureReason: freezed == failureReason ? _self.failureReason : failureReason // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$PluginListResponse {

 List<PluginMetadata> get plugins; String? get bridgeId; bool get supportsSessionOptions;/// Whether the bridge saves prompt files that it doesn't pass to the
/// plugin inline, and gives the agent their paths (see
/// `PromptPart.fileData`).
 bool get supportsFileUploads;
/// Create a copy of PluginListResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginListResponseCopyWith<PluginListResponse> get copyWith => _$PluginListResponseCopyWithImpl<PluginListResponse>(this as PluginListResponse, _$identity);

  /// Serializes this PluginListResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PluginListResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginListResponse&&const DeepCollectionEquality().equals(other.plugins, _this.plugins)&&(identical(other.bridgeId, _this.bridgeId) || other.bridgeId == _this.bridgeId)&&(identical(other.supportsSessionOptions, _this.supportsSessionOptions) || other.supportsSessionOptions == _this.supportsSessionOptions)&&(identical(other.supportsFileUploads, _this.supportsFileUploads) || other.supportsFileUploads == _this.supportsFileUploads));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PluginListResponse;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.plugins),_this.bridgeId,_this.supportsSessionOptions,_this.supportsFileUploads);
}

@override
String toString() {
  final _this = this as PluginListResponse;
  return 'PluginListResponse(plugins: ${_this.plugins}, bridgeId: ${_this.bridgeId}, supportsSessionOptions: ${_this.supportsSessionOptions}, supportsFileUploads: ${_this.supportsFileUploads})';
}


}

/// @nodoc
abstract mixin class $PluginListResponseCopyWith<$Res>  {
  factory $PluginListResponseCopyWith(PluginListResponse value, $Res Function(PluginListResponse) _then) = _$PluginListResponseCopyWithImpl;
@useResult
$Res call({
 List<PluginMetadata> plugins, String? bridgeId, bool supportsSessionOptions, bool supportsFileUploads
});




}
/// @nodoc
class _$PluginListResponseCopyWithImpl<$Res>
    implements $PluginListResponseCopyWith<$Res> {
  _$PluginListResponseCopyWithImpl(this._self, this._then);

  final PluginListResponse _self;
  final $Res Function(PluginListResponse) _then;

/// Create a copy of PluginListResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? plugins = null,Object? bridgeId = freezed,Object? supportsSessionOptions = null,Object? supportsFileUploads = null,}) {
  return _then(PluginListResponse(
plugins: null == plugins ? _self.plugins : plugins // ignore: cast_nullable_to_non_nullable
as List<PluginMetadata>,bridgeId: freezed == bridgeId ? _self.bridgeId : bridgeId // ignore: cast_nullable_to_non_nullable
as String?,supportsSessionOptions: null == supportsSessionOptions ? _self.supportsSessionOptions : supportsSessionOptions // ignore: cast_nullable_to_non_nullable
as bool,supportsFileUploads: null == supportsFileUploads ? _self.supportsFileUploads : supportsFileUploads // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _PluginListResponse implements PluginListResponse {
  const _PluginListResponse({required  List<PluginMetadata> plugins, required this.bridgeId, this.supportsSessionOptions = false, this.supportsFileUploads = false}): _plugins = plugins;
  factory _PluginListResponse.fromJson(Map<String, dynamic> json) => _$PluginListResponseFromJson(json);

 final  List<PluginMetadata> _plugins;
@override List<PluginMetadata> get plugins {
  if (_plugins is EqualUnmodifiableListView) return _plugins;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_plugins);
}

@override final  String? bridgeId;
@override@JsonKey() final  bool supportsSessionOptions;
/// Whether the bridge saves prompt files that it doesn't pass to the
/// plugin inline, and gives the agent their paths (see
/// `PromptPart.fileData`).
@override@JsonKey() final  bool supportsFileUploads;

/// Create a copy of PluginListResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginListResponseCopyWith<_PluginListResponse> get copyWith => __$PluginListResponseCopyWithImpl<_PluginListResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginListResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginListResponse&&const DeepCollectionEquality().equals(other.plugins, _plugins)&&(identical(other.bridgeId, bridgeId) || other.bridgeId == bridgeId)&&(identical(other.supportsSessionOptions, supportsSessionOptions) || other.supportsSessionOptions == supportsSessionOptions)&&(identical(other.supportsFileUploads, supportsFileUploads) || other.supportsFileUploads == supportsFileUploads));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_plugins),bridgeId,supportsSessionOptions,supportsFileUploads);
}

@override
String toString() {
    return 'PluginListResponse(plugins: $plugins, bridgeId: $bridgeId, supportsSessionOptions: $supportsSessionOptions, supportsFileUploads: $supportsFileUploads)';
}


}

/// @nodoc
abstract mixin class _$PluginListResponseCopyWith<$Res> implements $PluginListResponseCopyWith<$Res> {
  factory _$PluginListResponseCopyWith(_PluginListResponse value, $Res Function(_PluginListResponse) _then) = __$PluginListResponseCopyWithImpl;
@override @useResult
$Res call({
 List<PluginMetadata> plugins, String? bridgeId, bool supportsSessionOptions, bool supportsFileUploads
});




}
/// @nodoc
class __$PluginListResponseCopyWithImpl<$Res>
    implements _$PluginListResponseCopyWith<$Res> {
  __$PluginListResponseCopyWithImpl(this._self, this._then);

  final _PluginListResponse _self;
  final $Res Function(_PluginListResponse) _then;

/// Create a copy of PluginListResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? plugins = null,Object? bridgeId = freezed,Object? supportsSessionOptions = null,Object? supportsFileUploads = null,}) {
  return _then(_PluginListResponse(
plugins: null == plugins ? _self._plugins : plugins // ignore: cast_nullable_to_non_nullable
as List<PluginMetadata>,bridgeId: freezed == bridgeId ? _self.bridgeId : bridgeId // ignore: cast_nullable_to_non_nullable
as String?,supportsSessionOptions: null == supportsSessionOptions ? _self.supportsSessionOptions : supportsSessionOptions // ignore: cast_nullable_to_non_nullable
as bool,supportsFileUploads: null == supportsFileUploads ? _self.supportsFileUploads : supportsFileUploads // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
