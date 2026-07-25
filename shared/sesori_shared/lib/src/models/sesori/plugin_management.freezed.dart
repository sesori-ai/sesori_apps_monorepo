// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plugin_management.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PluginManagementMetadata {

 PluginSetupMetadata get setup;@JsonKey(unknownEnumValue: PluginRuntimeState.unknown) PluginRuntimeState get runtimeState;@JsonKey(unknownEnumValue: PluginManagementWorkState.unknown) PluginManagementWorkState get workState; int get idleTimeoutMins; bool get hasIdleTimeoutOverride; String? get actionHint;
/// Create a copy of PluginManagementMetadata
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginManagementMetadataCopyWith<PluginManagementMetadata> get copyWith => _$PluginManagementMetadataCopyWithImpl<PluginManagementMetadata>(this as PluginManagementMetadata, _$identity);

  /// Serializes this PluginManagementMetadata to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginManagementMetadata&&(identical(other.setup, setup) || other.setup == setup)&&(identical(other.runtimeState, runtimeState) || other.runtimeState == runtimeState)&&(identical(other.workState, workState) || other.workState == workState)&&(identical(other.idleTimeoutMins, idleTimeoutMins) || other.idleTimeoutMins == idleTimeoutMins)&&(identical(other.hasIdleTimeoutOverride, hasIdleTimeoutOverride) || other.hasIdleTimeoutOverride == hasIdleTimeoutOverride)&&(identical(other.actionHint, actionHint) || other.actionHint == actionHint));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,setup,runtimeState,workState,idleTimeoutMins,hasIdleTimeoutOverride,actionHint);

@override
String toString() {
  return 'PluginManagementMetadata(setup: $setup, runtimeState: $runtimeState, workState: $workState, idleTimeoutMins: $idleTimeoutMins, hasIdleTimeoutOverride: $hasIdleTimeoutOverride, actionHint: $actionHint)';
}


}

/// @nodoc
abstract mixin class $PluginManagementMetadataCopyWith<$Res>  {
  factory $PluginManagementMetadataCopyWith(PluginManagementMetadata value, $Res Function(PluginManagementMetadata) _then) = _$PluginManagementMetadataCopyWithImpl;
@useResult
$Res call({
 PluginSetupMetadata setup,@JsonKey(unknownEnumValue: PluginRuntimeState.unknown) PluginRuntimeState runtimeState,@JsonKey(unknownEnumValue: PluginManagementWorkState.unknown) PluginManagementWorkState workState, int idleTimeoutMins, bool hasIdleTimeoutOverride, String? actionHint
});


$PluginSetupMetadataCopyWith<$Res> get setup;

}
/// @nodoc
class _$PluginManagementMetadataCopyWithImpl<$Res>
    implements $PluginManagementMetadataCopyWith<$Res> {
  _$PluginManagementMetadataCopyWithImpl(this._self, this._then);

  final PluginManagementMetadata _self;
  final $Res Function(PluginManagementMetadata) _then;

/// Create a copy of PluginManagementMetadata
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? setup = null,Object? runtimeState = null,Object? workState = null,Object? idleTimeoutMins = null,Object? hasIdleTimeoutOverride = null,Object? actionHint = freezed,}) {
  return _then(_self.copyWith(
setup: null == setup ? _self.setup : setup // ignore: cast_nullable_to_non_nullable
as PluginSetupMetadata,runtimeState: null == runtimeState ? _self.runtimeState : runtimeState // ignore: cast_nullable_to_non_nullable
as PluginRuntimeState,workState: null == workState ? _self.workState : workState // ignore: cast_nullable_to_non_nullable
as PluginManagementWorkState,idleTimeoutMins: null == idleTimeoutMins ? _self.idleTimeoutMins : idleTimeoutMins // ignore: cast_nullable_to_non_nullable
as int,hasIdleTimeoutOverride: null == hasIdleTimeoutOverride ? _self.hasIdleTimeoutOverride : hasIdleTimeoutOverride // ignore: cast_nullable_to_non_nullable
as bool,actionHint: freezed == actionHint ? _self.actionHint : actionHint // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of PluginManagementMetadata
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginSetupMetadataCopyWith<$Res> get setup {
  
  return $PluginSetupMetadataCopyWith<$Res>(_self.setup, (value) {
    return _then(_self.copyWith(setup: value));
  });
}
}



/// @nodoc
@JsonSerializable()

class _PluginManagementMetadata implements PluginManagementMetadata {
  const _PluginManagementMetadata({required this.setup, @JsonKey(unknownEnumValue: PluginRuntimeState.unknown) required this.runtimeState, @JsonKey(unknownEnumValue: PluginManagementWorkState.unknown) required this.workState, required this.idleTimeoutMins, required this.hasIdleTimeoutOverride, required this.actionHint});
  factory _PluginManagementMetadata.fromJson(Map<String, dynamic> json) => _$PluginManagementMetadataFromJson(json);

@override final  PluginSetupMetadata setup;
@override@JsonKey(unknownEnumValue: PluginRuntimeState.unknown) final  PluginRuntimeState runtimeState;
@override@JsonKey(unknownEnumValue: PluginManagementWorkState.unknown) final  PluginManagementWorkState workState;
@override final  int idleTimeoutMins;
@override final  bool hasIdleTimeoutOverride;
@override final  String? actionHint;

/// Create a copy of PluginManagementMetadata
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginManagementMetadataCopyWith<_PluginManagementMetadata> get copyWith => __$PluginManagementMetadataCopyWithImpl<_PluginManagementMetadata>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginManagementMetadataToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginManagementMetadata&&(identical(other.setup, setup) || other.setup == setup)&&(identical(other.runtimeState, runtimeState) || other.runtimeState == runtimeState)&&(identical(other.workState, workState) || other.workState == workState)&&(identical(other.idleTimeoutMins, idleTimeoutMins) || other.idleTimeoutMins == idleTimeoutMins)&&(identical(other.hasIdleTimeoutOverride, hasIdleTimeoutOverride) || other.hasIdleTimeoutOverride == hasIdleTimeoutOverride)&&(identical(other.actionHint, actionHint) || other.actionHint == actionHint));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,setup,runtimeState,workState,idleTimeoutMins,hasIdleTimeoutOverride,actionHint);

@override
String toString() {
  return 'PluginManagementMetadata(setup: $setup, runtimeState: $runtimeState, workState: $workState, idleTimeoutMins: $idleTimeoutMins, hasIdleTimeoutOverride: $hasIdleTimeoutOverride, actionHint: $actionHint)';
}


}

/// @nodoc
abstract mixin class _$PluginManagementMetadataCopyWith<$Res> implements $PluginManagementMetadataCopyWith<$Res> {
  factory _$PluginManagementMetadataCopyWith(_PluginManagementMetadata value, $Res Function(_PluginManagementMetadata) _then) = __$PluginManagementMetadataCopyWithImpl;
@override @useResult
$Res call({
 PluginSetupMetadata setup,@JsonKey(unknownEnumValue: PluginRuntimeState.unknown) PluginRuntimeState runtimeState,@JsonKey(unknownEnumValue: PluginManagementWorkState.unknown) PluginManagementWorkState workState, int idleTimeoutMins, bool hasIdleTimeoutOverride, String? actionHint
});


@override $PluginSetupMetadataCopyWith<$Res> get setup;

}
/// @nodoc
class __$PluginManagementMetadataCopyWithImpl<$Res>
    implements _$PluginManagementMetadataCopyWith<$Res> {
  __$PluginManagementMetadataCopyWithImpl(this._self, this._then);

  final _PluginManagementMetadata _self;
  final $Res Function(_PluginManagementMetadata) _then;

/// Create a copy of PluginManagementMetadata
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? setup = null,Object? runtimeState = null,Object? workState = null,Object? idleTimeoutMins = null,Object? hasIdleTimeoutOverride = null,Object? actionHint = freezed,}) {
  return _then(_PluginManagementMetadata(
setup: null == setup ? _self.setup : setup // ignore: cast_nullable_to_non_nullable
as PluginSetupMetadata,runtimeState: null == runtimeState ? _self.runtimeState : runtimeState // ignore: cast_nullable_to_non_nullable
as PluginRuntimeState,workState: null == workState ? _self.workState : workState // ignore: cast_nullable_to_non_nullable
as PluginManagementWorkState,idleTimeoutMins: null == idleTimeoutMins ? _self.idleTimeoutMins : idleTimeoutMins // ignore: cast_nullable_to_non_nullable
as int,hasIdleTimeoutOverride: null == hasIdleTimeoutOverride ? _self.hasIdleTimeoutOverride : hasIdleTimeoutOverride // ignore: cast_nullable_to_non_nullable
as bool,actionHint: freezed == actionHint ? _self.actionHint : actionHint // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of PluginManagementMetadata
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginSetupMetadataCopyWith<$Res> get setup {
  
  return $PluginSetupMetadataCopyWith<$Res>(_self.setup, (value) {
    return _then(_self.copyWith(setup: value));
  });
}
}


/// @nodoc
mixin _$PluginManagementResponse {

// COMPATIBILITY 2026-07-25 (v1.6.1): Stage 12-P02 and older bridge payloads
// omit snapshotToken; null means that peer cannot identify snapshot changes.
// Make non-null when those bridge versions are unsupported.
 String? get snapshotToken; String? get defaultPluginId; int get defaultIdleTimeoutMins; List<PluginManagementMetadata> get plugins;
/// Create a copy of PluginManagementResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginManagementResponseCopyWith<PluginManagementResponse> get copyWith => _$PluginManagementResponseCopyWithImpl<PluginManagementResponse>(this as PluginManagementResponse, _$identity);

  /// Serializes this PluginManagementResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginManagementResponse&&(identical(other.snapshotToken, snapshotToken) || other.snapshotToken == snapshotToken)&&(identical(other.defaultPluginId, defaultPluginId) || other.defaultPluginId == defaultPluginId)&&(identical(other.defaultIdleTimeoutMins, defaultIdleTimeoutMins) || other.defaultIdleTimeoutMins == defaultIdleTimeoutMins)&&const DeepCollectionEquality().equals(other.plugins, plugins));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,snapshotToken,defaultPluginId,defaultIdleTimeoutMins,const DeepCollectionEquality().hash(plugins));

@override
String toString() {
  return 'PluginManagementResponse(snapshotToken: $snapshotToken, defaultPluginId: $defaultPluginId, defaultIdleTimeoutMins: $defaultIdleTimeoutMins, plugins: $plugins)';
}


}

/// @nodoc
abstract mixin class $PluginManagementResponseCopyWith<$Res>  {
  factory $PluginManagementResponseCopyWith(PluginManagementResponse value, $Res Function(PluginManagementResponse) _then) = _$PluginManagementResponseCopyWithImpl;
@useResult
$Res call({
 String? snapshotToken, String? defaultPluginId, int defaultIdleTimeoutMins, List<PluginManagementMetadata> plugins
});




}
/// @nodoc
class _$PluginManagementResponseCopyWithImpl<$Res>
    implements $PluginManagementResponseCopyWith<$Res> {
  _$PluginManagementResponseCopyWithImpl(this._self, this._then);

  final PluginManagementResponse _self;
  final $Res Function(PluginManagementResponse) _then;

/// Create a copy of PluginManagementResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? snapshotToken = freezed,Object? defaultPluginId = freezed,Object? defaultIdleTimeoutMins = null,Object? plugins = null,}) {
  return _then(_self.copyWith(
snapshotToken: freezed == snapshotToken ? _self.snapshotToken : snapshotToken // ignore: cast_nullable_to_non_nullable
as String?,defaultPluginId: freezed == defaultPluginId ? _self.defaultPluginId : defaultPluginId // ignore: cast_nullable_to_non_nullable
as String?,defaultIdleTimeoutMins: null == defaultIdleTimeoutMins ? _self.defaultIdleTimeoutMins : defaultIdleTimeoutMins // ignore: cast_nullable_to_non_nullable
as int,plugins: null == plugins ? _self.plugins : plugins // ignore: cast_nullable_to_non_nullable
as List<PluginManagementMetadata>,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _PluginManagementResponse implements PluginManagementResponse {
  const _PluginManagementResponse({required this.snapshotToken, required this.defaultPluginId, required this.defaultIdleTimeoutMins, required final  List<PluginManagementMetadata> plugins}): _plugins = plugins;
  factory _PluginManagementResponse.fromJson(Map<String, dynamic> json) => _$PluginManagementResponseFromJson(json);

// COMPATIBILITY 2026-07-25 (v1.6.1): Stage 12-P02 and older bridge payloads
// omit snapshotToken; null means that peer cannot identify snapshot changes.
// Make non-null when those bridge versions are unsupported.
@override final  String? snapshotToken;
@override final  String? defaultPluginId;
@override final  int defaultIdleTimeoutMins;
 final  List<PluginManagementMetadata> _plugins;
@override List<PluginManagementMetadata> get plugins {
  if (_plugins is EqualUnmodifiableListView) return _plugins;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_plugins);
}


/// Create a copy of PluginManagementResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginManagementResponseCopyWith<_PluginManagementResponse> get copyWith => __$PluginManagementResponseCopyWithImpl<_PluginManagementResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginManagementResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginManagementResponse&&(identical(other.snapshotToken, snapshotToken) || other.snapshotToken == snapshotToken)&&(identical(other.defaultPluginId, defaultPluginId) || other.defaultPluginId == defaultPluginId)&&(identical(other.defaultIdleTimeoutMins, defaultIdleTimeoutMins) || other.defaultIdleTimeoutMins == defaultIdleTimeoutMins)&&const DeepCollectionEquality().equals(other._plugins, _plugins));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,snapshotToken,defaultPluginId,defaultIdleTimeoutMins,const DeepCollectionEquality().hash(_plugins));

@override
String toString() {
  return 'PluginManagementResponse(snapshotToken: $snapshotToken, defaultPluginId: $defaultPluginId, defaultIdleTimeoutMins: $defaultIdleTimeoutMins, plugins: $plugins)';
}


}

/// @nodoc
abstract mixin class _$PluginManagementResponseCopyWith<$Res> implements $PluginManagementResponseCopyWith<$Res> {
  factory _$PluginManagementResponseCopyWith(_PluginManagementResponse value, $Res Function(_PluginManagementResponse) _then) = __$PluginManagementResponseCopyWithImpl;
@override @useResult
$Res call({
 String? snapshotToken, String? defaultPluginId, int defaultIdleTimeoutMins, List<PluginManagementMetadata> plugins
});




}
/// @nodoc
class __$PluginManagementResponseCopyWithImpl<$Res>
    implements _$PluginManagementResponseCopyWith<$Res> {
  __$PluginManagementResponseCopyWithImpl(this._self, this._then);

  final _PluginManagementResponse _self;
  final $Res Function(_PluginManagementResponse) _then;

/// Create a copy of PluginManagementResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? snapshotToken = freezed,Object? defaultPluginId = freezed,Object? defaultIdleTimeoutMins = null,Object? plugins = null,}) {
  return _then(_PluginManagementResponse(
snapshotToken: freezed == snapshotToken ? _self.snapshotToken : snapshotToken // ignore: cast_nullable_to_non_nullable
as String?,defaultPluginId: freezed == defaultPluginId ? _self.defaultPluginId : defaultPluginId // ignore: cast_nullable_to_non_nullable
as String?,defaultIdleTimeoutMins: null == defaultIdleTimeoutMins ? _self.defaultIdleTimeoutMins : defaultIdleTimeoutMins // ignore: cast_nullable_to_non_nullable
as int,plugins: null == plugins ? _self._plugins : plugins // ignore: cast_nullable_to_non_nullable
as List<PluginManagementMetadata>,
  ));
}


}

PluginLifecycleCommandRequest _$PluginLifecycleCommandRequestFromJson(
  Map<String, dynamic> json
) {
    return PluginLifecycleDisableRequest.fromJson(
      json
    );
}

/// @nodoc
mixin _$PluginLifecycleCommandRequest {

 PluginStopMode get mode;@JsonKey(name: "type", includeFromJson: false, includeToJson: true, toJson: _disableCommandTypeToJson) String get wireType;

  /// Serializes this PluginLifecycleCommandRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginLifecycleCommandRequest&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.wireType, wireType) || other.wireType == wireType));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,mode,wireType);

@override
String toString() {
  return 'PluginLifecycleCommandRequest(mode: $mode, wireType: $wireType)';
}


}





/// @nodoc
@JsonSerializable()

class PluginLifecycleDisableRequest implements PluginLifecycleCommandRequest {
  const PluginLifecycleDisableRequest({required this.mode, @JsonKey(name: "type", includeFromJson: false, includeToJson: true, toJson: _disableCommandTypeToJson) this.wireType = "disable"});
  factory PluginLifecycleDisableRequest.fromJson(Map<String, dynamic> json) => _$PluginLifecycleDisableRequestFromJson(json);

@override final  PluginStopMode mode;
@override@JsonKey(name: "type", includeFromJson: false, includeToJson: true, toJson: _disableCommandTypeToJson) final  String wireType;


@override
Map<String, dynamic> toJson() {
  return _$PluginLifecycleDisableRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginLifecycleDisableRequest&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.wireType, wireType) || other.wireType == wireType));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,mode,wireType);

@override
String toString() {
  return 'PluginLifecycleCommandRequest.disable(mode: $mode, wireType: $wireType)';
}


}




PluginIdleTimeoutUpdateRequest _$PluginIdleTimeoutUpdateRequestFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'applyAll':
          return PluginIdleTimeoutApplyAllRequest.fromJson(
            json
          );
                case 'setOverride':
          return PluginIdleTimeoutSetOverrideRequest.fromJson(
            json
          );
                case 'clearOverride':
          return PluginIdleTimeoutClearOverrideRequest.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'type',
  'PluginIdleTimeoutUpdateRequest',
  'Invalid union type "${json['type']}"!'
);
        }
      
}

/// @nodoc
mixin _$PluginIdleTimeoutUpdateRequest {



  /// Serializes this PluginIdleTimeoutUpdateRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginIdleTimeoutUpdateRequest);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PluginIdleTimeoutUpdateRequest()';
}


}





/// @nodoc
@JsonSerializable()

class PluginIdleTimeoutApplyAllRequest implements PluginIdleTimeoutUpdateRequest {
  const PluginIdleTimeoutApplyAllRequest({@JsonKey(fromJson: _strictIntFromJson) required this.idleTimeoutMins, final  String? $type}): $type = $type ?? 'applyAll';
  factory PluginIdleTimeoutApplyAllRequest.fromJson(Map<String, dynamic> json) => _$PluginIdleTimeoutApplyAllRequestFromJson(json);

@JsonKey(fromJson: _strictIntFromJson) final  int idleTimeoutMins;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$PluginIdleTimeoutApplyAllRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginIdleTimeoutApplyAllRequest&&(identical(other.idleTimeoutMins, idleTimeoutMins) || other.idleTimeoutMins == idleTimeoutMins));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,idleTimeoutMins);

@override
String toString() {
  return 'PluginIdleTimeoutUpdateRequest.applyAll(idleTimeoutMins: $idleTimeoutMins)';
}


}




/// @nodoc
@JsonSerializable()

class PluginIdleTimeoutSetOverrideRequest implements PluginIdleTimeoutUpdateRequest {
  const PluginIdleTimeoutSetOverrideRequest({required this.pluginId, @JsonKey(fromJson: _strictIntFromJson) required this.idleTimeoutMins, final  String? $type}): $type = $type ?? 'setOverride';
  factory PluginIdleTimeoutSetOverrideRequest.fromJson(Map<String, dynamic> json) => _$PluginIdleTimeoutSetOverrideRequestFromJson(json);

 final  String pluginId;
@JsonKey(fromJson: _strictIntFromJson) final  int idleTimeoutMins;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$PluginIdleTimeoutSetOverrideRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginIdleTimeoutSetOverrideRequest&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId)&&(identical(other.idleTimeoutMins, idleTimeoutMins) || other.idleTimeoutMins == idleTimeoutMins));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,pluginId,idleTimeoutMins);

@override
String toString() {
  return 'PluginIdleTimeoutUpdateRequest.setOverride(pluginId: $pluginId, idleTimeoutMins: $idleTimeoutMins)';
}


}




/// @nodoc
@JsonSerializable()

class PluginIdleTimeoutClearOverrideRequest implements PluginIdleTimeoutUpdateRequest {
  const PluginIdleTimeoutClearOverrideRequest({required this.pluginId, final  String? $type}): $type = $type ?? 'clearOverride';
  factory PluginIdleTimeoutClearOverrideRequest.fromJson(Map<String, dynamic> json) => _$PluginIdleTimeoutClearOverrideRequestFromJson(json);

 final  String pluginId;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$PluginIdleTimeoutClearOverrideRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginIdleTimeoutClearOverrideRequest&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,pluginId);

@override
String toString() {
  return 'PluginIdleTimeoutUpdateRequest.clearOverride(pluginId: $pluginId)';
}


}





/// @nodoc
mixin _$PluginLifecycleConflict {

 String get pluginId;@JsonKey(unknownEnumValue: PluginLifecycleConflictReason.unknown) List<PluginLifecycleConflictReason> get reasons; PluginManagementMetadata get current;
/// Create a copy of PluginLifecycleConflict
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginLifecycleConflictCopyWith<PluginLifecycleConflict> get copyWith => _$PluginLifecycleConflictCopyWithImpl<PluginLifecycleConflict>(this as PluginLifecycleConflict, _$identity);

  /// Serializes this PluginLifecycleConflict to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginLifecycleConflict&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId)&&const DeepCollectionEquality().equals(other.reasons, reasons)&&(identical(other.current, current) || other.current == current));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,pluginId,const DeepCollectionEquality().hash(reasons),current);

@override
String toString() {
  return 'PluginLifecycleConflict(pluginId: $pluginId, reasons: $reasons, current: $current)';
}


}

/// @nodoc
abstract mixin class $PluginLifecycleConflictCopyWith<$Res>  {
  factory $PluginLifecycleConflictCopyWith(PluginLifecycleConflict value, $Res Function(PluginLifecycleConflict) _then) = _$PluginLifecycleConflictCopyWithImpl;
@useResult
$Res call({
 String pluginId,@JsonKey(unknownEnumValue: PluginLifecycleConflictReason.unknown) List<PluginLifecycleConflictReason> reasons, PluginManagementMetadata current
});


$PluginManagementMetadataCopyWith<$Res> get current;

}
/// @nodoc
class _$PluginLifecycleConflictCopyWithImpl<$Res>
    implements $PluginLifecycleConflictCopyWith<$Res> {
  _$PluginLifecycleConflictCopyWithImpl(this._self, this._then);

  final PluginLifecycleConflict _self;
  final $Res Function(PluginLifecycleConflict) _then;

/// Create a copy of PluginLifecycleConflict
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? pluginId = null,Object? reasons = null,Object? current = null,}) {
  return _then(_self.copyWith(
pluginId: null == pluginId ? _self.pluginId : pluginId // ignore: cast_nullable_to_non_nullable
as String,reasons: null == reasons ? _self.reasons : reasons // ignore: cast_nullable_to_non_nullable
as List<PluginLifecycleConflictReason>,current: null == current ? _self.current : current // ignore: cast_nullable_to_non_nullable
as PluginManagementMetadata,
  ));
}
/// Create a copy of PluginLifecycleConflict
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginManagementMetadataCopyWith<$Res> get current {
  
  return $PluginManagementMetadataCopyWith<$Res>(_self.current, (value) {
    return _then(_self.copyWith(current: value));
  });
}
}



/// @nodoc
@JsonSerializable()

class _PluginLifecycleConflict implements PluginLifecycleConflict {
  const _PluginLifecycleConflict({required this.pluginId, @JsonKey(unknownEnumValue: PluginLifecycleConflictReason.unknown) required final  List<PluginLifecycleConflictReason> reasons, required this.current}): _reasons = reasons;
  factory _PluginLifecycleConflict.fromJson(Map<String, dynamic> json) => _$PluginLifecycleConflictFromJson(json);

@override final  String pluginId;
 final  List<PluginLifecycleConflictReason> _reasons;
@override@JsonKey(unknownEnumValue: PluginLifecycleConflictReason.unknown) List<PluginLifecycleConflictReason> get reasons {
  if (_reasons is EqualUnmodifiableListView) return _reasons;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_reasons);
}

@override final  PluginManagementMetadata current;

/// Create a copy of PluginLifecycleConflict
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginLifecycleConflictCopyWith<_PluginLifecycleConflict> get copyWith => __$PluginLifecycleConflictCopyWithImpl<_PluginLifecycleConflict>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginLifecycleConflictToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginLifecycleConflict&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId)&&const DeepCollectionEquality().equals(other._reasons, _reasons)&&(identical(other.current, current) || other.current == current));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,pluginId,const DeepCollectionEquality().hash(_reasons),current);

@override
String toString() {
  return 'PluginLifecycleConflict(pluginId: $pluginId, reasons: $reasons, current: $current)';
}


}

/// @nodoc
abstract mixin class _$PluginLifecycleConflictCopyWith<$Res> implements $PluginLifecycleConflictCopyWith<$Res> {
  factory _$PluginLifecycleConflictCopyWith(_PluginLifecycleConflict value, $Res Function(_PluginLifecycleConflict) _then) = __$PluginLifecycleConflictCopyWithImpl;
@override @useResult
$Res call({
 String pluginId,@JsonKey(unknownEnumValue: PluginLifecycleConflictReason.unknown) List<PluginLifecycleConflictReason> reasons, PluginManagementMetadata current
});


@override $PluginManagementMetadataCopyWith<$Res> get current;

}
/// @nodoc
class __$PluginLifecycleConflictCopyWithImpl<$Res>
    implements _$PluginLifecycleConflictCopyWith<$Res> {
  __$PluginLifecycleConflictCopyWithImpl(this._self, this._then);

  final _PluginLifecycleConflict _self;
  final $Res Function(_PluginLifecycleConflict) _then;

/// Create a copy of PluginLifecycleConflict
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? pluginId = null,Object? reasons = null,Object? current = null,}) {
  return _then(_PluginLifecycleConflict(
pluginId: null == pluginId ? _self.pluginId : pluginId // ignore: cast_nullable_to_non_nullable
as String,reasons: null == reasons ? _self._reasons : reasons // ignore: cast_nullable_to_non_nullable
as List<PluginLifecycleConflictReason>,current: null == current ? _self.current : current // ignore: cast_nullable_to_non_nullable
as PluginManagementMetadata,
  ));
}

/// Create a copy of PluginLifecycleConflict
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginManagementMetadataCopyWith<$Res> get current {
  
  return $PluginManagementMetadataCopyWith<$Res>(_self.current, (value) {
    return _then(_self.copyWith(current: value));
  });
}
}

// dart format on
