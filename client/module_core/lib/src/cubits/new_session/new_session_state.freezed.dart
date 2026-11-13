// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'new_session_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$NewSessionOptionsLoadState {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is NewSessionOptionsLoadState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'NewSessionOptionsLoadState()';
}


}

/// @nodoc
class $NewSessionOptionsLoadStateCopyWith<$Res>  {
$NewSessionOptionsLoadStateCopyWith(NewSessionOptionsLoadState _, $Res Function(NewSessionOptionsLoadState) __);
}



/// @nodoc


class NewSessionOptionsLoadingState implements NewSessionOptionsLoadState {
  const NewSessionOptionsLoadingState({required this.source});
  

 final  NewSessionOptionsSource? source;

/// Create a copy of NewSessionOptionsLoadState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NewSessionOptionsLoadingStateCopyWith<NewSessionOptionsLoadingState> get copyWith => _$NewSessionOptionsLoadingStateCopyWithImpl<NewSessionOptionsLoadingState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is NewSessionOptionsLoadingState&&(identical(other.source, source) || other.source == source));
}


@override
int get hashCode {
    return Object.hash(runtimeType,source);
}

@override
String toString() {
    return 'NewSessionOptionsLoadState.loading(source: $source)';
}


}

/// @nodoc
abstract mixin class $NewSessionOptionsLoadingStateCopyWith<$Res> implements $NewSessionOptionsLoadStateCopyWith<$Res> {
  factory $NewSessionOptionsLoadingStateCopyWith(NewSessionOptionsLoadingState value, $Res Function(NewSessionOptionsLoadingState) _then) = _$NewSessionOptionsLoadingStateCopyWithImpl;
@useResult
$Res call({
 NewSessionOptionsSource? source
});




}
/// @nodoc
class _$NewSessionOptionsLoadingStateCopyWithImpl<$Res>
    implements $NewSessionOptionsLoadingStateCopyWith<$Res> {
  _$NewSessionOptionsLoadingStateCopyWithImpl(this._self, this._then);

  final NewSessionOptionsLoadingState _self;
  final $Res Function(NewSessionOptionsLoadingState) _then;

/// Create a copy of NewSessionOptionsLoadState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? source = freezed,}) {
  return _then(NewSessionOptionsLoadingState(
source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as NewSessionOptionsSource?,
  ));
}


}

/// @nodoc


class NewSessionOptionsRefreshingState implements NewSessionOptionsLoadState {
  const NewSessionOptionsRefreshingState({required this.options, required this.source});
  

 final  NewSessionOptionsData options;
 final  NewSessionOptionsSource source;

/// Create a copy of NewSessionOptionsLoadState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NewSessionOptionsRefreshingStateCopyWith<NewSessionOptionsRefreshingState> get copyWith => _$NewSessionOptionsRefreshingStateCopyWithImpl<NewSessionOptionsRefreshingState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is NewSessionOptionsRefreshingState&&(identical(other.options, options) || other.options == options)&&(identical(other.source, source) || other.source == source));
}


@override
int get hashCode {
    return Object.hash(runtimeType,options,source);
}

@override
String toString() {
    return 'NewSessionOptionsLoadState.refreshing(options: $options, source: $source)';
}


}

/// @nodoc
abstract mixin class $NewSessionOptionsRefreshingStateCopyWith<$Res> implements $NewSessionOptionsLoadStateCopyWith<$Res> {
  factory $NewSessionOptionsRefreshingStateCopyWith(NewSessionOptionsRefreshingState value, $Res Function(NewSessionOptionsRefreshingState) _then) = _$NewSessionOptionsRefreshingStateCopyWithImpl;
@useResult
$Res call({
 NewSessionOptionsData options, NewSessionOptionsSource source
});


$NewSessionOptionsDataCopyWith<$Res> get options;

}
/// @nodoc
class _$NewSessionOptionsRefreshingStateCopyWithImpl<$Res>
    implements $NewSessionOptionsRefreshingStateCopyWith<$Res> {
  _$NewSessionOptionsRefreshingStateCopyWithImpl(this._self, this._then);

  final NewSessionOptionsRefreshingState _self;
  final $Res Function(NewSessionOptionsRefreshingState) _then;

/// Create a copy of NewSessionOptionsLoadState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? options = null,Object? source = null,}) {
  return _then(NewSessionOptionsRefreshingState(
options: null == options ? _self.options : options // ignore: cast_nullable_to_non_nullable
as NewSessionOptionsData,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as NewSessionOptionsSource,
  ));
}

/// Create a copy of NewSessionOptionsLoadState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NewSessionOptionsDataCopyWith<$Res> get options {
  
  return $NewSessionOptionsDataCopyWith<$Res>(_self.options, (value) {
    return _then(_self.copyWith(options: value));
  });
}
}

/// @nodoc


class NewSessionOptionsAvailableState implements NewSessionOptionsLoadState {
  const NewSessionOptionsAvailableState({required this.options, required this.source});
  

 final  NewSessionOptionsData options;
 final  NewSessionOptionsSource source;

/// Create a copy of NewSessionOptionsLoadState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NewSessionOptionsAvailableStateCopyWith<NewSessionOptionsAvailableState> get copyWith => _$NewSessionOptionsAvailableStateCopyWithImpl<NewSessionOptionsAvailableState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is NewSessionOptionsAvailableState&&(identical(other.options, options) || other.options == options)&&(identical(other.source, source) || other.source == source));
}


@override
int get hashCode {
    return Object.hash(runtimeType,options,source);
}

@override
String toString() {
    return 'NewSessionOptionsLoadState.available(options: $options, source: $source)';
}


}

/// @nodoc
abstract mixin class $NewSessionOptionsAvailableStateCopyWith<$Res> implements $NewSessionOptionsLoadStateCopyWith<$Res> {
  factory $NewSessionOptionsAvailableStateCopyWith(NewSessionOptionsAvailableState value, $Res Function(NewSessionOptionsAvailableState) _then) = _$NewSessionOptionsAvailableStateCopyWithImpl;
@useResult
$Res call({
 NewSessionOptionsData options, NewSessionOptionsSource source
});


$NewSessionOptionsDataCopyWith<$Res> get options;

}
/// @nodoc
class _$NewSessionOptionsAvailableStateCopyWithImpl<$Res>
    implements $NewSessionOptionsAvailableStateCopyWith<$Res> {
  _$NewSessionOptionsAvailableStateCopyWithImpl(this._self, this._then);

  final NewSessionOptionsAvailableState _self;
  final $Res Function(NewSessionOptionsAvailableState) _then;

/// Create a copy of NewSessionOptionsLoadState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? options = null,Object? source = null,}) {
  return _then(NewSessionOptionsAvailableState(
options: null == options ? _self.options : options // ignore: cast_nullable_to_non_nullable
as NewSessionOptionsData,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as NewSessionOptionsSource,
  ));
}

/// Create a copy of NewSessionOptionsLoadState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NewSessionOptionsDataCopyWith<$Res> get options {
  
  return $NewSessionOptionsDataCopyWith<$Res>(_self.options, (value) {
    return _then(_self.copyWith(options: value));
  });
}
}

/// @nodoc


class NewSessionOptionsUnsupportedState implements NewSessionOptionsLoadState {
  const NewSessionOptionsUnsupportedState();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is NewSessionOptionsUnsupportedState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'NewSessionOptionsLoadState.unsupported()';
}


}




/// @nodoc


class NewSessionOptionsUnavailableState implements NewSessionOptionsLoadState {
  const NewSessionOptionsUnavailableState();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is NewSessionOptionsUnavailableState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'NewSessionOptionsLoadState.unavailable()';
}


}




/// @nodoc


class NewSessionOptionsLoadFailureUnavailableState implements NewSessionOptionsLoadState {
  const NewSessionOptionsLoadFailureUnavailableState();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is NewSessionOptionsLoadFailureUnavailableState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'NewSessionOptionsLoadState.loadFailureUnavailable()';
}


}




/// @nodoc


class NewSessionOptionsAuthenticationRequiredUnavailableState implements NewSessionOptionsLoadState {
  const NewSessionOptionsAuthenticationRequiredUnavailableState({required this.actionHint});
  

 final  String actionHint;

/// Create a copy of NewSessionOptionsLoadState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NewSessionOptionsAuthenticationRequiredUnavailableStateCopyWith<NewSessionOptionsAuthenticationRequiredUnavailableState> get copyWith => _$NewSessionOptionsAuthenticationRequiredUnavailableStateCopyWithImpl<NewSessionOptionsAuthenticationRequiredUnavailableState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is NewSessionOptionsAuthenticationRequiredUnavailableState&&(identical(other.actionHint, actionHint) || other.actionHint == actionHint));
}


@override
int get hashCode {
    return Object.hash(runtimeType,actionHint);
}

@override
String toString() {
    return 'NewSessionOptionsLoadState.authenticationRequiredUnavailable(actionHint: $actionHint)';
}


}

/// @nodoc
abstract mixin class $NewSessionOptionsAuthenticationRequiredUnavailableStateCopyWith<$Res> implements $NewSessionOptionsLoadStateCopyWith<$Res> {
  factory $NewSessionOptionsAuthenticationRequiredUnavailableStateCopyWith(NewSessionOptionsAuthenticationRequiredUnavailableState value, $Res Function(NewSessionOptionsAuthenticationRequiredUnavailableState) _then) = _$NewSessionOptionsAuthenticationRequiredUnavailableStateCopyWithImpl;
@useResult
$Res call({
 String actionHint
});




}
/// @nodoc
class _$NewSessionOptionsAuthenticationRequiredUnavailableStateCopyWithImpl<$Res>
    implements $NewSessionOptionsAuthenticationRequiredUnavailableStateCopyWith<$Res> {
  _$NewSessionOptionsAuthenticationRequiredUnavailableStateCopyWithImpl(this._self, this._then);

  final NewSessionOptionsAuthenticationRequiredUnavailableState _self;
  final $Res Function(NewSessionOptionsAuthenticationRequiredUnavailableState) _then;

/// Create a copy of NewSessionOptionsLoadState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? actionHint = null,}) {
  return _then(NewSessionOptionsAuthenticationRequiredUnavailableState(
actionHint: null == actionHint ? _self.actionHint : actionHint // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class NewSessionOptionsAuthenticationRequiredRetainedState implements NewSessionOptionsLoadState {
  const NewSessionOptionsAuthenticationRequiredRetainedState({required this.actionHint, required this.options, required this.source});
  

 final  String actionHint;
 final  NewSessionOptionsData options;
 final  NewSessionOptionsSource source;

/// Create a copy of NewSessionOptionsLoadState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NewSessionOptionsAuthenticationRequiredRetainedStateCopyWith<NewSessionOptionsAuthenticationRequiredRetainedState> get copyWith => _$NewSessionOptionsAuthenticationRequiredRetainedStateCopyWithImpl<NewSessionOptionsAuthenticationRequiredRetainedState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is NewSessionOptionsAuthenticationRequiredRetainedState&&(identical(other.actionHint, actionHint) || other.actionHint == actionHint)&&(identical(other.options, options) || other.options == options)&&(identical(other.source, source) || other.source == source));
}


@override
int get hashCode {
    return Object.hash(runtimeType,actionHint,options,source);
}

@override
String toString() {
    return 'NewSessionOptionsLoadState.authenticationRequiredRetained(actionHint: $actionHint, options: $options, source: $source)';
}


}

/// @nodoc
abstract mixin class $NewSessionOptionsAuthenticationRequiredRetainedStateCopyWith<$Res> implements $NewSessionOptionsLoadStateCopyWith<$Res> {
  factory $NewSessionOptionsAuthenticationRequiredRetainedStateCopyWith(NewSessionOptionsAuthenticationRequiredRetainedState value, $Res Function(NewSessionOptionsAuthenticationRequiredRetainedState) _then) = _$NewSessionOptionsAuthenticationRequiredRetainedStateCopyWithImpl;
@useResult
$Res call({
 String actionHint, NewSessionOptionsData options, NewSessionOptionsSource source
});


$NewSessionOptionsDataCopyWith<$Res> get options;

}
/// @nodoc
class _$NewSessionOptionsAuthenticationRequiredRetainedStateCopyWithImpl<$Res>
    implements $NewSessionOptionsAuthenticationRequiredRetainedStateCopyWith<$Res> {
  _$NewSessionOptionsAuthenticationRequiredRetainedStateCopyWithImpl(this._self, this._then);

  final NewSessionOptionsAuthenticationRequiredRetainedState _self;
  final $Res Function(NewSessionOptionsAuthenticationRequiredRetainedState) _then;

/// Create a copy of NewSessionOptionsLoadState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? actionHint = null,Object? options = null,Object? source = null,}) {
  return _then(NewSessionOptionsAuthenticationRequiredRetainedState(
actionHint: null == actionHint ? _self.actionHint : actionHint // ignore: cast_nullable_to_non_nullable
as String,options: null == options ? _self.options : options // ignore: cast_nullable_to_non_nullable
as NewSessionOptionsData,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as NewSessionOptionsSource,
  ));
}

/// Create a copy of NewSessionOptionsLoadState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NewSessionOptionsDataCopyWith<$Res> get options {
  
  return $NewSessionOptionsDataCopyWith<$Res>(_self.options, (value) {
    return _then(_self.copyWith(options: value));
  });
}
}

/// @nodoc


class NewSessionOptionsFailureState implements NewSessionOptionsLoadState {
  const NewSessionOptionsFailureState({required this.reason, required this.source});
  

 final  RemoteFailureReason reason;
 final  NewSessionOptionsSource source;

/// Create a copy of NewSessionOptionsLoadState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NewSessionOptionsFailureStateCopyWith<NewSessionOptionsFailureState> get copyWith => _$NewSessionOptionsFailureStateCopyWithImpl<NewSessionOptionsFailureState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is NewSessionOptionsFailureState&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.source, source) || other.source == source));
}


@override
int get hashCode {
    return Object.hash(runtimeType,reason,source);
}

@override
String toString() {
    return 'NewSessionOptionsLoadState.failure(reason: $reason, source: $source)';
}


}

/// @nodoc
abstract mixin class $NewSessionOptionsFailureStateCopyWith<$Res> implements $NewSessionOptionsLoadStateCopyWith<$Res> {
  factory $NewSessionOptionsFailureStateCopyWith(NewSessionOptionsFailureState value, $Res Function(NewSessionOptionsFailureState) _then) = _$NewSessionOptionsFailureStateCopyWithImpl;
@useResult
$Res call({
 RemoteFailureReason reason, NewSessionOptionsSource source
});




}
/// @nodoc
class _$NewSessionOptionsFailureStateCopyWithImpl<$Res>
    implements $NewSessionOptionsFailureStateCopyWith<$Res> {
  _$NewSessionOptionsFailureStateCopyWithImpl(this._self, this._then);

  final NewSessionOptionsFailureState _self;
  final $Res Function(NewSessionOptionsFailureState) _then;

/// Create a copy of NewSessionOptionsLoadState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? reason = null,Object? source = null,}) {
  return _then(NewSessionOptionsFailureState(
reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as RemoteFailureReason,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as NewSessionOptionsSource,
  ));
}


}

/// @nodoc


class NewSessionOptionsFailureRetainedState implements NewSessionOptionsLoadState {
  const NewSessionOptionsFailureRetainedState({required this.options, required this.source});
  

 final  NewSessionOptionsData options;
 final  NewSessionOptionsSource source;

/// Create a copy of NewSessionOptionsLoadState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NewSessionOptionsFailureRetainedStateCopyWith<NewSessionOptionsFailureRetainedState> get copyWith => _$NewSessionOptionsFailureRetainedStateCopyWithImpl<NewSessionOptionsFailureRetainedState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is NewSessionOptionsFailureRetainedState&&(identical(other.options, options) || other.options == options)&&(identical(other.source, source) || other.source == source));
}


@override
int get hashCode {
    return Object.hash(runtimeType,options,source);
}

@override
String toString() {
    return 'NewSessionOptionsLoadState.failureRetained(options: $options, source: $source)';
}


}

/// @nodoc
abstract mixin class $NewSessionOptionsFailureRetainedStateCopyWith<$Res> implements $NewSessionOptionsLoadStateCopyWith<$Res> {
  factory $NewSessionOptionsFailureRetainedStateCopyWith(NewSessionOptionsFailureRetainedState value, $Res Function(NewSessionOptionsFailureRetainedState) _then) = _$NewSessionOptionsFailureRetainedStateCopyWithImpl;
@useResult
$Res call({
 NewSessionOptionsData options, NewSessionOptionsSource source
});


$NewSessionOptionsDataCopyWith<$Res> get options;

}
/// @nodoc
class _$NewSessionOptionsFailureRetainedStateCopyWithImpl<$Res>
    implements $NewSessionOptionsFailureRetainedStateCopyWith<$Res> {
  _$NewSessionOptionsFailureRetainedStateCopyWithImpl(this._self, this._then);

  final NewSessionOptionsFailureRetainedState _self;
  final $Res Function(NewSessionOptionsFailureRetainedState) _then;

/// Create a copy of NewSessionOptionsLoadState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? options = null,Object? source = null,}) {
  return _then(NewSessionOptionsFailureRetainedState(
options: null == options ? _self.options : options // ignore: cast_nullable_to_non_nullable
as NewSessionOptionsData,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as NewSessionOptionsSource,
  ));
}

/// Create a copy of NewSessionOptionsLoadState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NewSessionOptionsDataCopyWith<$Res> get options {
  
  return $NewSessionOptionsDataCopyWith<$Res>(_self.options, (value) {
    return _then(_self.copyWith(options: value));
  });
}
}

/// @nodoc


class NewSessionOptionsRefreshFailureUnavailableState implements NewSessionOptionsLoadState {
  const NewSessionOptionsRefreshFailureUnavailableState();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is NewSessionOptionsRefreshFailureUnavailableState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'NewSessionOptionsLoadState.refreshFailureUnavailable()';
}


}




/// @nodoc
mixin _$NewSessionComposeConfig {

/// The harnesses the bridge last reported, kept until another answer
/// replaces them; null until a bridge has answered at all.
 List<PluginMetadata>? get availablePlugins; PluginMetadata? get selectedPlugin;/// Whether the bridge last reported saving prompt files that are not
/// inline images, kept like [availablePlugins]; false until it answers.
 bool get supportsFileUploads; NewSessionOptionsLoadState get options; NewSessionBackendScope get backendScope; bool get isPluginDiscoveryInFlight; NewSessionProjectWorktreeCapability get projectWorktreeCapability;
/// Create a copy of NewSessionComposeConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NewSessionComposeConfigCopyWith<NewSessionComposeConfig> get copyWith => _$NewSessionComposeConfigCopyWithImpl<NewSessionComposeConfig>(this as NewSessionComposeConfig, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as NewSessionComposeConfig;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NewSessionComposeConfig&&const DeepCollectionEquality().equals(other.availablePlugins, _this.availablePlugins)&&(identical(other.selectedPlugin, _this.selectedPlugin) || other.selectedPlugin == _this.selectedPlugin)&&(identical(other.supportsFileUploads, _this.supportsFileUploads) || other.supportsFileUploads == _this.supportsFileUploads)&&(identical(other.options, _this.options) || other.options == _this.options)&&(identical(other.backendScope, _this.backendScope) || other.backendScope == _this.backendScope)&&(identical(other.isPluginDiscoveryInFlight, _this.isPluginDiscoveryInFlight) || other.isPluginDiscoveryInFlight == _this.isPluginDiscoveryInFlight)&&(identical(other.projectWorktreeCapability, _this.projectWorktreeCapability) || other.projectWorktreeCapability == _this.projectWorktreeCapability));
}


@override
int get hashCode {
  final _this = this as NewSessionComposeConfig;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.availablePlugins),_this.selectedPlugin,_this.supportsFileUploads,_this.options,_this.backendScope,_this.isPluginDiscoveryInFlight,_this.projectWorktreeCapability);
}

@override
String toString() {
  final _this = this as NewSessionComposeConfig;
  return 'NewSessionComposeConfig(availablePlugins: ${_this.availablePlugins}, selectedPlugin: ${_this.selectedPlugin}, supportsFileUploads: ${_this.supportsFileUploads}, options: ${_this.options}, backendScope: ${_this.backendScope}, isPluginDiscoveryInFlight: ${_this.isPluginDiscoveryInFlight}, projectWorktreeCapability: ${_this.projectWorktreeCapability})';
}


}

/// @nodoc
abstract mixin class $NewSessionComposeConfigCopyWith<$Res>  {
  factory $NewSessionComposeConfigCopyWith(NewSessionComposeConfig value, $Res Function(NewSessionComposeConfig) _then) = _$NewSessionComposeConfigCopyWithImpl;
@useResult
$Res call({
 List<PluginMetadata>? availablePlugins, PluginMetadata? selectedPlugin, bool supportsFileUploads, NewSessionOptionsLoadState options, NewSessionBackendScope backendScope, bool isPluginDiscoveryInFlight, NewSessionProjectWorktreeCapability projectWorktreeCapability
});


$PluginMetadataCopyWith<$Res>? get selectedPlugin;$NewSessionOptionsLoadStateCopyWith<$Res> get options;$NewSessionBackendScopeCopyWith<$Res> get backendScope;

}
/// @nodoc
class _$NewSessionComposeConfigCopyWithImpl<$Res>
    implements $NewSessionComposeConfigCopyWith<$Res> {
  _$NewSessionComposeConfigCopyWithImpl(this._self, this._then);

  final NewSessionComposeConfig _self;
  final $Res Function(NewSessionComposeConfig) _then;

/// Create a copy of NewSessionComposeConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? availablePlugins = freezed,Object? selectedPlugin = freezed,Object? supportsFileUploads = null,Object? options = null,Object? backendScope = null,Object? isPluginDiscoveryInFlight = null,Object? projectWorktreeCapability = null,}) {
  return _then(NewSessionComposeConfig(
availablePlugins: freezed == availablePlugins ? _self.availablePlugins : availablePlugins // ignore: cast_nullable_to_non_nullable
as List<PluginMetadata>?,selectedPlugin: freezed == selectedPlugin ? _self.selectedPlugin : selectedPlugin // ignore: cast_nullable_to_non_nullable
as PluginMetadata?,supportsFileUploads: null == supportsFileUploads ? _self.supportsFileUploads : supportsFileUploads // ignore: cast_nullable_to_non_nullable
as bool,options: null == options ? _self.options : options // ignore: cast_nullable_to_non_nullable
as NewSessionOptionsLoadState,backendScope: null == backendScope ? _self.backendScope : backendScope // ignore: cast_nullable_to_non_nullable
as NewSessionBackendScope,isPluginDiscoveryInFlight: null == isPluginDiscoveryInFlight ? _self.isPluginDiscoveryInFlight : isPluginDiscoveryInFlight // ignore: cast_nullable_to_non_nullable
as bool,projectWorktreeCapability: null == projectWorktreeCapability ? _self.projectWorktreeCapability : projectWorktreeCapability // ignore: cast_nullable_to_non_nullable
as NewSessionProjectWorktreeCapability,
  ));
}
/// Create a copy of NewSessionComposeConfig
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginMetadataCopyWith<$Res>? get selectedPlugin {
    if (_self.selectedPlugin == null) {
    return null;
  }

  return $PluginMetadataCopyWith<$Res>(_self.selectedPlugin!, (value) {
    return _then(_self.copyWith(selectedPlugin: value));
  });
}/// Create a copy of NewSessionComposeConfig
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NewSessionOptionsLoadStateCopyWith<$Res> get options {
  
  return $NewSessionOptionsLoadStateCopyWith<$Res>(_self.options, (value) {
    return _then(_self.copyWith(options: value));
  });
}/// Create a copy of NewSessionComposeConfig
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NewSessionBackendScopeCopyWith<$Res> get backendScope {
  
  return $NewSessionBackendScopeCopyWith<$Res>(_self.backendScope, (value) {
    return _then(_self.copyWith(backendScope: value));
  });
}
}



/// @nodoc


class _NewSessionComposeConfig implements NewSessionComposeConfig {
  const _NewSessionComposeConfig({required  List<PluginMetadata>? availablePlugins, required this.selectedPlugin, required this.supportsFileUploads, required this.options, required this.backendScope, required this.isPluginDiscoveryInFlight, required this.projectWorktreeCapability}): _availablePlugins = availablePlugins;
  

/// The harnesses the bridge last reported, kept until another answer
/// replaces them; null until a bridge has answered at all.
 final  List<PluginMetadata>? _availablePlugins;
/// The harnesses the bridge last reported, kept until another answer
/// replaces them; null until a bridge has answered at all.
@override List<PluginMetadata>? get availablePlugins {
  final value = _availablePlugins;
  if (value == null) return null;
  if (_availablePlugins is EqualUnmodifiableListView) return _availablePlugins;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  PluginMetadata? selectedPlugin;
/// Whether the bridge last reported saving prompt files that are not
/// inline images, kept like [availablePlugins]; false until it answers.
@override final  bool supportsFileUploads;
@override final  NewSessionOptionsLoadState options;
@override final  NewSessionBackendScope backendScope;
@override final  bool isPluginDiscoveryInFlight;
@override final  NewSessionProjectWorktreeCapability projectWorktreeCapability;

/// Create a copy of NewSessionComposeConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NewSessionComposeConfigCopyWith<_NewSessionComposeConfig> get copyWith => __$NewSessionComposeConfigCopyWithImpl<_NewSessionComposeConfig>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _NewSessionComposeConfig&&const DeepCollectionEquality().equals(other.availablePlugins, _availablePlugins)&&(identical(other.selectedPlugin, selectedPlugin) || other.selectedPlugin == selectedPlugin)&&(identical(other.supportsFileUploads, supportsFileUploads) || other.supportsFileUploads == supportsFileUploads)&&(identical(other.options, options) || other.options == options)&&(identical(other.backendScope, backendScope) || other.backendScope == backendScope)&&(identical(other.isPluginDiscoveryInFlight, isPluginDiscoveryInFlight) || other.isPluginDiscoveryInFlight == isPluginDiscoveryInFlight)&&(identical(other.projectWorktreeCapability, projectWorktreeCapability) || other.projectWorktreeCapability == projectWorktreeCapability));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_availablePlugins),selectedPlugin,supportsFileUploads,options,backendScope,isPluginDiscoveryInFlight,projectWorktreeCapability);
}

@override
String toString() {
    return 'NewSessionComposeConfig(availablePlugins: $availablePlugins, selectedPlugin: $selectedPlugin, supportsFileUploads: $supportsFileUploads, options: $options, backendScope: $backendScope, isPluginDiscoveryInFlight: $isPluginDiscoveryInFlight, projectWorktreeCapability: $projectWorktreeCapability)';
}


}

/// @nodoc
abstract mixin class _$NewSessionComposeConfigCopyWith<$Res> implements $NewSessionComposeConfigCopyWith<$Res> {
  factory _$NewSessionComposeConfigCopyWith(_NewSessionComposeConfig value, $Res Function(_NewSessionComposeConfig) _then) = __$NewSessionComposeConfigCopyWithImpl;
@override @useResult
$Res call({
 List<PluginMetadata>? availablePlugins, PluginMetadata? selectedPlugin, bool supportsFileUploads, NewSessionOptionsLoadState options, NewSessionBackendScope backendScope, bool isPluginDiscoveryInFlight, NewSessionProjectWorktreeCapability projectWorktreeCapability
});


@override $PluginMetadataCopyWith<$Res>? get selectedPlugin;@override $NewSessionOptionsLoadStateCopyWith<$Res> get options;@override $NewSessionBackendScopeCopyWith<$Res> get backendScope;

}
/// @nodoc
class __$NewSessionComposeConfigCopyWithImpl<$Res>
    implements _$NewSessionComposeConfigCopyWith<$Res> {
  __$NewSessionComposeConfigCopyWithImpl(this._self, this._then);

  final _NewSessionComposeConfig _self;
  final $Res Function(_NewSessionComposeConfig) _then;

/// Create a copy of NewSessionComposeConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? availablePlugins = freezed,Object? selectedPlugin = freezed,Object? supportsFileUploads = null,Object? options = null,Object? backendScope = null,Object? isPluginDiscoveryInFlight = null,Object? projectWorktreeCapability = null,}) {
  return _then(_NewSessionComposeConfig(
availablePlugins: freezed == availablePlugins ? _self._availablePlugins : availablePlugins // ignore: cast_nullable_to_non_nullable
as List<PluginMetadata>?,selectedPlugin: freezed == selectedPlugin ? _self.selectedPlugin : selectedPlugin // ignore: cast_nullable_to_non_nullable
as PluginMetadata?,supportsFileUploads: null == supportsFileUploads ? _self.supportsFileUploads : supportsFileUploads // ignore: cast_nullable_to_non_nullable
as bool,options: null == options ? _self.options : options // ignore: cast_nullable_to_non_nullable
as NewSessionOptionsLoadState,backendScope: null == backendScope ? _self.backendScope : backendScope // ignore: cast_nullable_to_non_nullable
as NewSessionBackendScope,isPluginDiscoveryInFlight: null == isPluginDiscoveryInFlight ? _self.isPluginDiscoveryInFlight : isPluginDiscoveryInFlight // ignore: cast_nullable_to_non_nullable
as bool,projectWorktreeCapability: null == projectWorktreeCapability ? _self.projectWorktreeCapability : projectWorktreeCapability // ignore: cast_nullable_to_non_nullable
as NewSessionProjectWorktreeCapability,
  ));
}

/// Create a copy of NewSessionComposeConfig
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginMetadataCopyWith<$Res>? get selectedPlugin {
    if (_self.selectedPlugin == null) {
    return null;
  }

  return $PluginMetadataCopyWith<$Res>(_self.selectedPlugin!, (value) {
    return _then(_self.copyWith(selectedPlugin: value));
  });
}/// Create a copy of NewSessionComposeConfig
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NewSessionOptionsLoadStateCopyWith<$Res> get options {
  
  return $NewSessionOptionsLoadStateCopyWith<$Res>(_self.options, (value) {
    return _then(_self.copyWith(options: value));
  });
}/// Create a copy of NewSessionComposeConfig
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NewSessionBackendScopeCopyWith<$Res> get backendScope {
  
  return $NewSessionBackendScopeCopyWith<$Res>(_self.backendScope, (value) {
    return _then(_self.copyWith(backendScope: value));
  });
}
}

/// @nodoc
mixin _$NewSessionPhase {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is NewSessionPhase);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'NewSessionPhase()';
}


}

/// @nodoc
class $NewSessionPhaseCopyWith<$Res>  {
$NewSessionPhaseCopyWith(NewSessionPhase _, $Res Function(NewSessionPhase) __);
}



/// @nodoc


class NewSessionPhaseIdle implements NewSessionPhase {
  const NewSessionPhaseIdle();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is NewSessionPhaseIdle);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'NewSessionPhase.idle()';
}


}




/// @nodoc


class NewSessionPhaseSending implements NewSessionPhase {
  const NewSessionPhaseSending({required this.submission, required this.launchId, required this.startedAt, required  List<LaunchFollowUp> followUps, required this.promptTurnShapes}): _followUps = followUps;
  

 final  NewSessionSubmissionSnapshot submission;
/// The launch carrying [submission], whose outcome this phase waits for.
 final  String launchId;
/// When Send committed; the sending bubble's slow-send copy counts from it.
 final  DateTime startedAt;
/// The messages sent after [submission], as the launch holds them.
 final  List<LaunchFollowUp> _followUps;
/// The messages sent after [submission], as the launch holds them.
 List<LaunchFollowUp> get followUps {
  if (_followUps is EqualUnmodifiableListView) return _followUps;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_followUps);
}

/// Whether [submission] and each of [followUps] shows as a card or a
/// bubble, as the cubit resolved it.
 final  PromptTurnShapes promptTurnShapes;

/// Create a copy of NewSessionPhase
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NewSessionPhaseSendingCopyWith<NewSessionPhaseSending> get copyWith => _$NewSessionPhaseSendingCopyWithImpl<NewSessionPhaseSending>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is NewSessionPhaseSending&&(identical(other.submission, submission) || other.submission == submission)&&(identical(other.launchId, launchId) || other.launchId == launchId)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&const DeepCollectionEquality().equals(other.followUps, _followUps)&&(identical(other.promptTurnShapes, promptTurnShapes) || other.promptTurnShapes == promptTurnShapes));
}


@override
int get hashCode {
    return Object.hash(runtimeType,submission,launchId,startedAt,const DeepCollectionEquality().hash(_followUps),promptTurnShapes);
}

@override
String toString() {
    return 'NewSessionPhase.sending(submission: $submission, launchId: $launchId, startedAt: $startedAt, followUps: $followUps, promptTurnShapes: $promptTurnShapes)';
}


}

/// @nodoc
abstract mixin class $NewSessionPhaseSendingCopyWith<$Res> implements $NewSessionPhaseCopyWith<$Res> {
  factory $NewSessionPhaseSendingCopyWith(NewSessionPhaseSending value, $Res Function(NewSessionPhaseSending) _then) = _$NewSessionPhaseSendingCopyWithImpl;
@useResult
$Res call({
 NewSessionSubmissionSnapshot submission, String launchId, DateTime startedAt, List<LaunchFollowUp> followUps, PromptTurnShapes promptTurnShapes
});


$NewSessionSubmissionSnapshotCopyWith<$Res> get submission;$PromptTurnShapesCopyWith<$Res> get promptTurnShapes;

}
/// @nodoc
class _$NewSessionPhaseSendingCopyWithImpl<$Res>
    implements $NewSessionPhaseSendingCopyWith<$Res> {
  _$NewSessionPhaseSendingCopyWithImpl(this._self, this._then);

  final NewSessionPhaseSending _self;
  final $Res Function(NewSessionPhaseSending) _then;

/// Create a copy of NewSessionPhase
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? submission = null,Object? launchId = null,Object? startedAt = null,Object? followUps = null,Object? promptTurnShapes = null,}) {
  return _then(NewSessionPhaseSending(
submission: null == submission ? _self.submission : submission // ignore: cast_nullable_to_non_nullable
as NewSessionSubmissionSnapshot,launchId: null == launchId ? _self.launchId : launchId // ignore: cast_nullable_to_non_nullable
as String,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,followUps: null == followUps ? _self._followUps : followUps // ignore: cast_nullable_to_non_nullable
as List<LaunchFollowUp>,promptTurnShapes: null == promptTurnShapes ? _self.promptTurnShapes : promptTurnShapes // ignore: cast_nullable_to_non_nullable
as PromptTurnShapes,
  ));
}

/// Create a copy of NewSessionPhase
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NewSessionSubmissionSnapshotCopyWith<$Res> get submission {
  
  return $NewSessionSubmissionSnapshotCopyWith<$Res>(_self.submission, (value) {
    return _then(_self.copyWith(submission: value));
  });
}/// Create a copy of NewSessionPhase
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PromptTurnShapesCopyWith<$Res> get promptTurnShapes {
  
  return $PromptTurnShapesCopyWith<$Res>(_self.promptTurnShapes, (value) {
    return _then(_self.copyWith(promptTurnShapes: value));
  });
}
}

/// @nodoc


class NewSessionPhaseRestoringSubmission implements NewSessionPhase {
  const NewSessionPhaseRestoringSubmission({required this.submission, required this.reason});
  

 final  NewSessionSubmissionSnapshot submission;
 final  RemoteFailureReason reason;

/// Create a copy of NewSessionPhase
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NewSessionPhaseRestoringSubmissionCopyWith<NewSessionPhaseRestoringSubmission> get copyWith => _$NewSessionPhaseRestoringSubmissionCopyWithImpl<NewSessionPhaseRestoringSubmission>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is NewSessionPhaseRestoringSubmission&&(identical(other.submission, submission) || other.submission == submission)&&(identical(other.reason, reason) || other.reason == reason));
}


@override
int get hashCode {
    return Object.hash(runtimeType,submission,reason);
}

@override
String toString() {
    return 'NewSessionPhase.restoringSubmission(submission: $submission, reason: $reason)';
}


}

/// @nodoc
abstract mixin class $NewSessionPhaseRestoringSubmissionCopyWith<$Res> implements $NewSessionPhaseCopyWith<$Res> {
  factory $NewSessionPhaseRestoringSubmissionCopyWith(NewSessionPhaseRestoringSubmission value, $Res Function(NewSessionPhaseRestoringSubmission) _then) = _$NewSessionPhaseRestoringSubmissionCopyWithImpl;
@useResult
$Res call({
 NewSessionSubmissionSnapshot submission, RemoteFailureReason reason
});


$NewSessionSubmissionSnapshotCopyWith<$Res> get submission;

}
/// @nodoc
class _$NewSessionPhaseRestoringSubmissionCopyWithImpl<$Res>
    implements $NewSessionPhaseRestoringSubmissionCopyWith<$Res> {
  _$NewSessionPhaseRestoringSubmissionCopyWithImpl(this._self, this._then);

  final NewSessionPhaseRestoringSubmission _self;
  final $Res Function(NewSessionPhaseRestoringSubmission) _then;

/// Create a copy of NewSessionPhase
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? submission = null,Object? reason = null,}) {
  return _then(NewSessionPhaseRestoringSubmission(
submission: null == submission ? _self.submission : submission // ignore: cast_nullable_to_non_nullable
as NewSessionSubmissionSnapshot,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as RemoteFailureReason,
  ));
}

/// Create a copy of NewSessionPhase
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NewSessionSubmissionSnapshotCopyWith<$Res> get submission {
  
  return $NewSessionSubmissionSnapshotCopyWith<$Res>(_self.submission, (value) {
    return _then(_self.copyWith(submission: value));
  });
}
}

/// @nodoc


class NewSessionPhaseCreationError implements NewSessionPhase {
  const NewSessionPhaseCreationError({required this.reason});
  

 final  RemoteFailureReason reason;

/// Create a copy of NewSessionPhase
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NewSessionPhaseCreationErrorCopyWith<NewSessionPhaseCreationError> get copyWith => _$NewSessionPhaseCreationErrorCopyWithImpl<NewSessionPhaseCreationError>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is NewSessionPhaseCreationError&&(identical(other.reason, reason) || other.reason == reason));
}


@override
int get hashCode {
    return Object.hash(runtimeType,reason);
}

@override
String toString() {
    return 'NewSessionPhase.creationError(reason: $reason)';
}


}

/// @nodoc
abstract mixin class $NewSessionPhaseCreationErrorCopyWith<$Res> implements $NewSessionPhaseCopyWith<$Res> {
  factory $NewSessionPhaseCreationErrorCopyWith(NewSessionPhaseCreationError value, $Res Function(NewSessionPhaseCreationError) _then) = _$NewSessionPhaseCreationErrorCopyWithImpl;
@useResult
$Res call({
 RemoteFailureReason reason
});




}
/// @nodoc
class _$NewSessionPhaseCreationErrorCopyWithImpl<$Res>
    implements $NewSessionPhaseCreationErrorCopyWith<$Res> {
  _$NewSessionPhaseCreationErrorCopyWithImpl(this._self, this._then);

  final NewSessionPhaseCreationError _self;
  final $Res Function(NewSessionPhaseCreationError) _then;

/// Create a copy of NewSessionPhase
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? reason = null,}) {
  return _then(NewSessionPhaseCreationError(
reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as RemoteFailureReason,
  ));
}


}

/// @nodoc


class NewSessionPhaseDiscoveryError implements NewSessionPhase {
  const NewSessionPhaseDiscoveryError({required this.reason});
  

 final  RemoteFailureReason reason;

/// Create a copy of NewSessionPhase
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NewSessionPhaseDiscoveryErrorCopyWith<NewSessionPhaseDiscoveryError> get copyWith => _$NewSessionPhaseDiscoveryErrorCopyWithImpl<NewSessionPhaseDiscoveryError>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is NewSessionPhaseDiscoveryError&&(identical(other.reason, reason) || other.reason == reason));
}


@override
int get hashCode {
    return Object.hash(runtimeType,reason);
}

@override
String toString() {
    return 'NewSessionPhase.discoveryError(reason: $reason)';
}


}

/// @nodoc
abstract mixin class $NewSessionPhaseDiscoveryErrorCopyWith<$Res> implements $NewSessionPhaseCopyWith<$Res> {
  factory $NewSessionPhaseDiscoveryErrorCopyWith(NewSessionPhaseDiscoveryError value, $Res Function(NewSessionPhaseDiscoveryError) _then) = _$NewSessionPhaseDiscoveryErrorCopyWithImpl;
@useResult
$Res call({
 RemoteFailureReason reason
});




}
/// @nodoc
class _$NewSessionPhaseDiscoveryErrorCopyWithImpl<$Res>
    implements $NewSessionPhaseDiscoveryErrorCopyWith<$Res> {
  _$NewSessionPhaseDiscoveryErrorCopyWithImpl(this._self, this._then);

  final NewSessionPhaseDiscoveryError _self;
  final $Res Function(NewSessionPhaseDiscoveryError) _then;

/// Create a copy of NewSessionPhase
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? reason = null,}) {
  return _then(NewSessionPhaseDiscoveryError(
reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as RemoteFailureReason,
  ));
}


}

/// @nodoc
mixin _$NewSessionProject {

 String get id;/// The project as the composer names it, for an alert about a creation
/// that fails after the user left; null when the composer has no name.
 String? get name;/// Whether the session starts in a folder project or in "No project".
 ProjectKind get kind;
/// Create a copy of NewSessionProject
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NewSessionProjectCopyWith<NewSessionProject> get copyWith => _$NewSessionProjectCopyWithImpl<NewSessionProject>(this as NewSessionProject, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as NewSessionProject;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NewSessionProject&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.kind, _this.kind) || other.kind == _this.kind));
}


@override
int get hashCode {
  final _this = this as NewSessionProject;
  return Object.hash(runtimeType,_this.id,_this.name,_this.kind);
}

@override
String toString() {
  final _this = this as NewSessionProject;
  return 'NewSessionProject(id: ${_this.id}, name: ${_this.name}, kind: ${_this.kind})';
}


}

/// @nodoc
abstract mixin class $NewSessionProjectCopyWith<$Res>  {
  factory $NewSessionProjectCopyWith(NewSessionProject value, $Res Function(NewSessionProject) _then) = _$NewSessionProjectCopyWithImpl;
@useResult
$Res call({
 String id, String? name, ProjectKind kind
});




}
/// @nodoc
class _$NewSessionProjectCopyWithImpl<$Res>
    implements $NewSessionProjectCopyWith<$Res> {
  _$NewSessionProjectCopyWithImpl(this._self, this._then);

  final NewSessionProject _self;
  final $Res Function(NewSessionProject) _then;

/// Create a copy of NewSessionProject
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = freezed,Object? kind = null,}) {
  return _then(NewSessionProject(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as ProjectKind,
  ));
}

}



/// @nodoc


class _NewSessionProject implements NewSessionProject {
  const _NewSessionProject({required this.id, required this.name, required this.kind});
  

@override final  String id;
/// The project as the composer names it, for an alert about a creation
/// that fails after the user left; null when the composer has no name.
@override final  String? name;
/// Whether the session starts in a folder project or in "No project".
@override final  ProjectKind kind;

/// Create a copy of NewSessionProject
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NewSessionProjectCopyWith<_NewSessionProject> get copyWith => __$NewSessionProjectCopyWithImpl<_NewSessionProject>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _NewSessionProject&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.kind, kind) || other.kind == kind));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,name,kind);
}

@override
String toString() {
    return 'NewSessionProject(id: $id, name: $name, kind: $kind)';
}


}

/// @nodoc
abstract mixin class _$NewSessionProjectCopyWith<$Res> implements $NewSessionProjectCopyWith<$Res> {
  factory _$NewSessionProjectCopyWith(_NewSessionProject value, $Res Function(_NewSessionProject) _then) = __$NewSessionProjectCopyWithImpl;
@override @useResult
$Res call({
 String id, String? name, ProjectKind kind
});




}
/// @nodoc
class __$NewSessionProjectCopyWithImpl<$Res>
    implements _$NewSessionProjectCopyWith<$Res> {
  __$NewSessionProjectCopyWithImpl(this._self, this._then);

  final _NewSessionProject _self;
  final $Res Function(_NewSessionProject) _then;

/// Create a copy of NewSessionProject
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = freezed,Object? kind = null,}) {
  return _then(_NewSessionProject(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as ProjectKind,
  ));
}


}

/// @nodoc
mixin _$NewSessionState {

 NewSessionProject get project;
/// Create a copy of NewSessionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NewSessionStateCopyWith<NewSessionState> get copyWith => _$NewSessionStateCopyWithImpl<NewSessionState>(this as NewSessionState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as NewSessionState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NewSessionState&&(identical(other.project, _this.project) || other.project == _this.project));
}


@override
int get hashCode {
  final _this = this as NewSessionState;
  return Object.hash(runtimeType,_this.project);
}

@override
String toString() {
  final _this = this as NewSessionState;
  return 'NewSessionState(project: ${_this.project})';
}


}

/// @nodoc
abstract mixin class $NewSessionStateCopyWith<$Res>  {
  factory $NewSessionStateCopyWith(NewSessionState value, $Res Function(NewSessionState) _then) = _$NewSessionStateCopyWithImpl;
@useResult
$Res call({
 NewSessionProject project
});


$NewSessionProjectCopyWith<$Res> get project;

}
/// @nodoc
class _$NewSessionStateCopyWithImpl<$Res>
    implements $NewSessionStateCopyWith<$Res> {
  _$NewSessionStateCopyWithImpl(this._self, this._then);

  final NewSessionState _self;
  final $Res Function(NewSessionState) _then;

/// Create a copy of NewSessionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? project = null,}) {
  return _then(_self.copyWith(
project: null == project ? _self.project : project // ignore: cast_nullable_to_non_nullable
as NewSessionProject,
  ));
}
/// Create a copy of NewSessionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NewSessionProjectCopyWith<$Res> get project {
  
  return $NewSessionProjectCopyWith<$Res>(_self.project, (value) {
    return _then(_self.copyWith(project: value));
  });
}
}



/// @nodoc


class NewSessionComposing implements NewSessionState {
  const NewSessionComposing({required this.project, required this.config, required this.phase});
  

@override final  NewSessionProject project;
 final  NewSessionComposeConfig config;
 final  NewSessionPhase phase;

/// Create a copy of NewSessionState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NewSessionComposingCopyWith<NewSessionComposing> get copyWith => _$NewSessionComposingCopyWithImpl<NewSessionComposing>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is NewSessionComposing&&(identical(other.project, project) || other.project == project)&&(identical(other.config, config) || other.config == config)&&(identical(other.phase, phase) || other.phase == phase));
}


@override
int get hashCode {
    return Object.hash(runtimeType,project,config,phase);
}

@override
String toString() {
    return 'NewSessionState.composing(project: $project, config: $config, phase: $phase)';
}


}

/// @nodoc
abstract mixin class $NewSessionComposingCopyWith<$Res> implements $NewSessionStateCopyWith<$Res> {
  factory $NewSessionComposingCopyWith(NewSessionComposing value, $Res Function(NewSessionComposing) _then) = _$NewSessionComposingCopyWithImpl;
@override @useResult
$Res call({
 NewSessionProject project, NewSessionComposeConfig config, NewSessionPhase phase
});


@override $NewSessionProjectCopyWith<$Res> get project;$NewSessionComposeConfigCopyWith<$Res> get config;$NewSessionPhaseCopyWith<$Res> get phase;

}
/// @nodoc
class _$NewSessionComposingCopyWithImpl<$Res>
    implements $NewSessionComposingCopyWith<$Res> {
  _$NewSessionComposingCopyWithImpl(this._self, this._then);

  final NewSessionComposing _self;
  final $Res Function(NewSessionComposing) _then;

/// Create a copy of NewSessionState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? project = null,Object? config = null,Object? phase = null,}) {
  return _then(NewSessionComposing(
project: null == project ? _self.project : project // ignore: cast_nullable_to_non_nullable
as NewSessionProject,config: null == config ? _self.config : config // ignore: cast_nullable_to_non_nullable
as NewSessionComposeConfig,phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as NewSessionPhase,
  ));
}

/// Create a copy of NewSessionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NewSessionProjectCopyWith<$Res> get project {
  
  return $NewSessionProjectCopyWith<$Res>(_self.project, (value) {
    return _then(_self.copyWith(project: value));
  });
}/// Create a copy of NewSessionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NewSessionComposeConfigCopyWith<$Res> get config {
  
  return $NewSessionComposeConfigCopyWith<$Res>(_self.config, (value) {
    return _then(_self.copyWith(config: value));
  });
}/// Create a copy of NewSessionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NewSessionPhaseCopyWith<$Res> get phase {
  
  return $NewSessionPhaseCopyWith<$Res>(_self.phase, (value) {
    return _then(_self.copyWith(phase: value));
  });
}
}

/// @nodoc


class NewSessionCreated implements NewSessionState {
  const NewSessionCreated({required this.project, required this.session, required this.launchId});
  

@override final  NewSessionProject project;
 final  Session session;
 final  String launchId;

/// Create a copy of NewSessionState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NewSessionCreatedCopyWith<NewSessionCreated> get copyWith => _$NewSessionCreatedCopyWithImpl<NewSessionCreated>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is NewSessionCreated&&(identical(other.project, project) || other.project == project)&&(identical(other.session, session) || other.session == session)&&(identical(other.launchId, launchId) || other.launchId == launchId));
}


@override
int get hashCode {
    return Object.hash(runtimeType,project,session,launchId);
}

@override
String toString() {
    return 'NewSessionState.created(project: $project, session: $session, launchId: $launchId)';
}


}

/// @nodoc
abstract mixin class $NewSessionCreatedCopyWith<$Res> implements $NewSessionStateCopyWith<$Res> {
  factory $NewSessionCreatedCopyWith(NewSessionCreated value, $Res Function(NewSessionCreated) _then) = _$NewSessionCreatedCopyWithImpl;
@override @useResult
$Res call({
 NewSessionProject project, Session session, String launchId
});


@override $NewSessionProjectCopyWith<$Res> get project;$SessionCopyWith<$Res> get session;

}
/// @nodoc
class _$NewSessionCreatedCopyWithImpl<$Res>
    implements $NewSessionCreatedCopyWith<$Res> {
  _$NewSessionCreatedCopyWithImpl(this._self, this._then);

  final NewSessionCreated _self;
  final $Res Function(NewSessionCreated) _then;

/// Create a copy of NewSessionState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? project = null,Object? session = null,Object? launchId = null,}) {
  return _then(NewSessionCreated(
project: null == project ? _self.project : project // ignore: cast_nullable_to_non_nullable
as NewSessionProject,session: null == session ? _self.session : session // ignore: cast_nullable_to_non_nullable
as Session,launchId: null == launchId ? _self.launchId : launchId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

/// Create a copy of NewSessionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NewSessionProjectCopyWith<$Res> get project {
  
  return $NewSessionProjectCopyWith<$Res>(_self.project, (value) {
    return _then(_self.copyWith(project: value));
  });
}/// Create a copy of NewSessionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SessionCopyWith<$Res> get session {
  
  return $SessionCopyWith<$Res>(_self.session, (value) {
    return _then(_self.copyWith(session: value));
  });
}
}

// dart format on
