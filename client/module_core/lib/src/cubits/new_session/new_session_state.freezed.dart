// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'new_session_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

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
int get hashCode => Object.hash(runtimeType,source);

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
int get hashCode => Object.hash(runtimeType,options,source);

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
int get hashCode => Object.hash(runtimeType,options,source);

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
int get hashCode => Object.hash(runtimeType,reason,source);

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


class NewSessionOptionsRefreshFailureRetainedState implements NewSessionOptionsLoadState {
  const NewSessionOptionsRefreshFailureRetainedState({required this.options, required this.source});
  

 final  NewSessionOptionsData options;
 final  NewSessionOptionsSource source;

/// Create a copy of NewSessionOptionsLoadState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NewSessionOptionsRefreshFailureRetainedStateCopyWith<NewSessionOptionsRefreshFailureRetainedState> get copyWith => _$NewSessionOptionsRefreshFailureRetainedStateCopyWithImpl<NewSessionOptionsRefreshFailureRetainedState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NewSessionOptionsRefreshFailureRetainedState&&(identical(other.options, options) || other.options == options)&&(identical(other.source, source) || other.source == source));
}


@override
int get hashCode => Object.hash(runtimeType,options,source);

@override
String toString() {
  return 'NewSessionOptionsLoadState.refreshFailureRetained(options: $options, source: $source)';
}


}

/// @nodoc
abstract mixin class $NewSessionOptionsRefreshFailureRetainedStateCopyWith<$Res> implements $NewSessionOptionsLoadStateCopyWith<$Res> {
  factory $NewSessionOptionsRefreshFailureRetainedStateCopyWith(NewSessionOptionsRefreshFailureRetainedState value, $Res Function(NewSessionOptionsRefreshFailureRetainedState) _then) = _$NewSessionOptionsRefreshFailureRetainedStateCopyWithImpl;
@useResult
$Res call({
 NewSessionOptionsData options, NewSessionOptionsSource source
});


$NewSessionOptionsDataCopyWith<$Res> get options;

}
/// @nodoc
class _$NewSessionOptionsRefreshFailureRetainedStateCopyWithImpl<$Res>
    implements $NewSessionOptionsRefreshFailureRetainedStateCopyWith<$Res> {
  _$NewSessionOptionsRefreshFailureRetainedStateCopyWithImpl(this._self, this._then);

  final NewSessionOptionsRefreshFailureRetainedState _self;
  final $Res Function(NewSessionOptionsRefreshFailureRetainedState) _then;

/// Create a copy of NewSessionOptionsLoadState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? options = null,Object? source = null,}) {
  return _then(NewSessionOptionsRefreshFailureRetainedState(
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
mixin _$NewSessionState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NewSessionState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'NewSessionState()';
}


}

/// @nodoc
class $NewSessionStateCopyWith<$Res>  {
$NewSessionStateCopyWith(NewSessionState _, $Res Function(NewSessionState) __);
}



/// @nodoc


class NewSessionIdle implements NewSessionState {
  const NewSessionIdle({required final  List<PluginMetadata> availablePlugins, required this.selectedPlugin, required this.options, required this.isPluginDiscoveryInFlight, required this.supportsDedicatedWorktrees}): _availablePlugins = availablePlugins;
  

 final  List<PluginMetadata> _availablePlugins;
 List<PluginMetadata> get availablePlugins {
  if (_availablePlugins is EqualUnmodifiableListView) return _availablePlugins;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_availablePlugins);
}

 final  PluginMetadata? selectedPlugin;
 final  NewSessionOptionsLoadState options;
 final  bool isPluginDiscoveryInFlight;
 final  bool supportsDedicatedWorktrees;

/// Create a copy of NewSessionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NewSessionIdleCopyWith<NewSessionIdle> get copyWith => _$NewSessionIdleCopyWithImpl<NewSessionIdle>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NewSessionIdle&&const DeepCollectionEquality().equals(other._availablePlugins, _availablePlugins)&&(identical(other.selectedPlugin, selectedPlugin) || other.selectedPlugin == selectedPlugin)&&(identical(other.options, options) || other.options == options)&&(identical(other.isPluginDiscoveryInFlight, isPluginDiscoveryInFlight) || other.isPluginDiscoveryInFlight == isPluginDiscoveryInFlight)&&(identical(other.supportsDedicatedWorktrees, supportsDedicatedWorktrees) || other.supportsDedicatedWorktrees == supportsDedicatedWorktrees));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_availablePlugins),selectedPlugin,options,isPluginDiscoveryInFlight,supportsDedicatedWorktrees);

@override
String toString() {
  return 'NewSessionState.idle(availablePlugins: $availablePlugins, selectedPlugin: $selectedPlugin, options: $options, isPluginDiscoveryInFlight: $isPluginDiscoveryInFlight, supportsDedicatedWorktrees: $supportsDedicatedWorktrees)';
}


}

/// @nodoc
abstract mixin class $NewSessionIdleCopyWith<$Res> implements $NewSessionStateCopyWith<$Res> {
  factory $NewSessionIdleCopyWith(NewSessionIdle value, $Res Function(NewSessionIdle) _then) = _$NewSessionIdleCopyWithImpl;
@useResult
$Res call({
 List<PluginMetadata> availablePlugins, PluginMetadata? selectedPlugin, NewSessionOptionsLoadState options, bool isPluginDiscoveryInFlight, bool supportsDedicatedWorktrees
});


$PluginMetadataCopyWith<$Res>? get selectedPlugin;$NewSessionOptionsLoadStateCopyWith<$Res> get options;

}
/// @nodoc
class _$NewSessionIdleCopyWithImpl<$Res>
    implements $NewSessionIdleCopyWith<$Res> {
  _$NewSessionIdleCopyWithImpl(this._self, this._then);

  final NewSessionIdle _self;
  final $Res Function(NewSessionIdle) _then;

/// Create a copy of NewSessionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? availablePlugins = null,Object? selectedPlugin = freezed,Object? options = null,Object? isPluginDiscoveryInFlight = null,Object? supportsDedicatedWorktrees = null,}) {
  return _then(NewSessionIdle(
availablePlugins: null == availablePlugins ? _self._availablePlugins : availablePlugins // ignore: cast_nullable_to_non_nullable
as List<PluginMetadata>,selectedPlugin: freezed == selectedPlugin ? _self.selectedPlugin : selectedPlugin // ignore: cast_nullable_to_non_nullable
as PluginMetadata?,options: null == options ? _self.options : options // ignore: cast_nullable_to_non_nullable
as NewSessionOptionsLoadState,isPluginDiscoveryInFlight: null == isPluginDiscoveryInFlight ? _self.isPluginDiscoveryInFlight : isPluginDiscoveryInFlight // ignore: cast_nullable_to_non_nullable
as bool,supportsDedicatedWorktrees: null == supportsDedicatedWorktrees ? _self.supportsDedicatedWorktrees : supportsDedicatedWorktrees // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of NewSessionState
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
}/// Create a copy of NewSessionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NewSessionOptionsLoadStateCopyWith<$Res> get options {
  
  return $NewSessionOptionsLoadStateCopyWith<$Res>(_self.options, (value) {
    return _then(_self.copyWith(options: value));
  });
}
}

/// @nodoc


class NewSessionSending implements NewSessionState {
  const NewSessionSending({required final  List<PluginMetadata> availablePlugins, required this.selectedPlugin, required this.options, required this.isPluginDiscoveryInFlight, required this.supportsDedicatedWorktrees}): _availablePlugins = availablePlugins;
  

 final  List<PluginMetadata> _availablePlugins;
 List<PluginMetadata> get availablePlugins {
  if (_availablePlugins is EqualUnmodifiableListView) return _availablePlugins;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_availablePlugins);
}

 final  PluginMetadata? selectedPlugin;
 final  NewSessionOptionsLoadState options;
 final  bool isPluginDiscoveryInFlight;
 final  bool supportsDedicatedWorktrees;

/// Create a copy of NewSessionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NewSessionSendingCopyWith<NewSessionSending> get copyWith => _$NewSessionSendingCopyWithImpl<NewSessionSending>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NewSessionSending&&const DeepCollectionEquality().equals(other._availablePlugins, _availablePlugins)&&(identical(other.selectedPlugin, selectedPlugin) || other.selectedPlugin == selectedPlugin)&&(identical(other.options, options) || other.options == options)&&(identical(other.isPluginDiscoveryInFlight, isPluginDiscoveryInFlight) || other.isPluginDiscoveryInFlight == isPluginDiscoveryInFlight)&&(identical(other.supportsDedicatedWorktrees, supportsDedicatedWorktrees) || other.supportsDedicatedWorktrees == supportsDedicatedWorktrees));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_availablePlugins),selectedPlugin,options,isPluginDiscoveryInFlight,supportsDedicatedWorktrees);

@override
String toString() {
  return 'NewSessionState.sending(availablePlugins: $availablePlugins, selectedPlugin: $selectedPlugin, options: $options, isPluginDiscoveryInFlight: $isPluginDiscoveryInFlight, supportsDedicatedWorktrees: $supportsDedicatedWorktrees)';
}


}

/// @nodoc
abstract mixin class $NewSessionSendingCopyWith<$Res> implements $NewSessionStateCopyWith<$Res> {
  factory $NewSessionSendingCopyWith(NewSessionSending value, $Res Function(NewSessionSending) _then) = _$NewSessionSendingCopyWithImpl;
@useResult
$Res call({
 List<PluginMetadata> availablePlugins, PluginMetadata? selectedPlugin, NewSessionOptionsLoadState options, bool isPluginDiscoveryInFlight, bool supportsDedicatedWorktrees
});


$PluginMetadataCopyWith<$Res>? get selectedPlugin;$NewSessionOptionsLoadStateCopyWith<$Res> get options;

}
/// @nodoc
class _$NewSessionSendingCopyWithImpl<$Res>
    implements $NewSessionSendingCopyWith<$Res> {
  _$NewSessionSendingCopyWithImpl(this._self, this._then);

  final NewSessionSending _self;
  final $Res Function(NewSessionSending) _then;

/// Create a copy of NewSessionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? availablePlugins = null,Object? selectedPlugin = freezed,Object? options = null,Object? isPluginDiscoveryInFlight = null,Object? supportsDedicatedWorktrees = null,}) {
  return _then(NewSessionSending(
availablePlugins: null == availablePlugins ? _self._availablePlugins : availablePlugins // ignore: cast_nullable_to_non_nullable
as List<PluginMetadata>,selectedPlugin: freezed == selectedPlugin ? _self.selectedPlugin : selectedPlugin // ignore: cast_nullable_to_non_nullable
as PluginMetadata?,options: null == options ? _self.options : options // ignore: cast_nullable_to_non_nullable
as NewSessionOptionsLoadState,isPluginDiscoveryInFlight: null == isPluginDiscoveryInFlight ? _self.isPluginDiscoveryInFlight : isPluginDiscoveryInFlight // ignore: cast_nullable_to_non_nullable
as bool,supportsDedicatedWorktrees: null == supportsDedicatedWorktrees ? _self.supportsDedicatedWorktrees : supportsDedicatedWorktrees // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of NewSessionState
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
}/// Create a copy of NewSessionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NewSessionOptionsLoadStateCopyWith<$Res> get options {
  
  return $NewSessionOptionsLoadStateCopyWith<$Res>(_self.options, (value) {
    return _then(_self.copyWith(options: value));
  });
}
}

/// @nodoc


class NewSessionError implements NewSessionState {
  const NewSessionError({required this.reason, required final  List<PluginMetadata> availablePlugins, required this.selectedPlugin, required this.options, required this.isPluginDiscoveryInFlight, required this.supportsDedicatedWorktrees}): _availablePlugins = availablePlugins;
  

 final  RemoteFailureReason reason;
 final  List<PluginMetadata> _availablePlugins;
 List<PluginMetadata> get availablePlugins {
  if (_availablePlugins is EqualUnmodifiableListView) return _availablePlugins;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_availablePlugins);
}

 final  PluginMetadata? selectedPlugin;
 final  NewSessionOptionsLoadState options;
 final  bool isPluginDiscoveryInFlight;
 final  bool supportsDedicatedWorktrees;

/// Create a copy of NewSessionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NewSessionErrorCopyWith<NewSessionError> get copyWith => _$NewSessionErrorCopyWithImpl<NewSessionError>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NewSessionError&&(identical(other.reason, reason) || other.reason == reason)&&const DeepCollectionEquality().equals(other._availablePlugins, _availablePlugins)&&(identical(other.selectedPlugin, selectedPlugin) || other.selectedPlugin == selectedPlugin)&&(identical(other.options, options) || other.options == options)&&(identical(other.isPluginDiscoveryInFlight, isPluginDiscoveryInFlight) || other.isPluginDiscoveryInFlight == isPluginDiscoveryInFlight)&&(identical(other.supportsDedicatedWorktrees, supportsDedicatedWorktrees) || other.supportsDedicatedWorktrees == supportsDedicatedWorktrees));
}


@override
int get hashCode => Object.hash(runtimeType,reason,const DeepCollectionEquality().hash(_availablePlugins),selectedPlugin,options,isPluginDiscoveryInFlight,supportsDedicatedWorktrees);

@override
String toString() {
  return 'NewSessionState.error(reason: $reason, availablePlugins: $availablePlugins, selectedPlugin: $selectedPlugin, options: $options, isPluginDiscoveryInFlight: $isPluginDiscoveryInFlight, supportsDedicatedWorktrees: $supportsDedicatedWorktrees)';
}


}

/// @nodoc
abstract mixin class $NewSessionErrorCopyWith<$Res> implements $NewSessionStateCopyWith<$Res> {
  factory $NewSessionErrorCopyWith(NewSessionError value, $Res Function(NewSessionError) _then) = _$NewSessionErrorCopyWithImpl;
@useResult
$Res call({
 RemoteFailureReason reason, List<PluginMetadata> availablePlugins, PluginMetadata? selectedPlugin, NewSessionOptionsLoadState options, bool isPluginDiscoveryInFlight, bool supportsDedicatedWorktrees
});


$PluginMetadataCopyWith<$Res>? get selectedPlugin;$NewSessionOptionsLoadStateCopyWith<$Res> get options;

}
/// @nodoc
class _$NewSessionErrorCopyWithImpl<$Res>
    implements $NewSessionErrorCopyWith<$Res> {
  _$NewSessionErrorCopyWithImpl(this._self, this._then);

  final NewSessionError _self;
  final $Res Function(NewSessionError) _then;

/// Create a copy of NewSessionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? reason = null,Object? availablePlugins = null,Object? selectedPlugin = freezed,Object? options = null,Object? isPluginDiscoveryInFlight = null,Object? supportsDedicatedWorktrees = null,}) {
  return _then(NewSessionError(
reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as RemoteFailureReason,availablePlugins: null == availablePlugins ? _self._availablePlugins : availablePlugins // ignore: cast_nullable_to_non_nullable
as List<PluginMetadata>,selectedPlugin: freezed == selectedPlugin ? _self.selectedPlugin : selectedPlugin // ignore: cast_nullable_to_non_nullable
as PluginMetadata?,options: null == options ? _self.options : options // ignore: cast_nullable_to_non_nullable
as NewSessionOptionsLoadState,isPluginDiscoveryInFlight: null == isPluginDiscoveryInFlight ? _self.isPluginDiscoveryInFlight : isPluginDiscoveryInFlight // ignore: cast_nullable_to_non_nullable
as bool,supportsDedicatedWorktrees: null == supportsDedicatedWorktrees ? _self.supportsDedicatedWorktrees : supportsDedicatedWorktrees // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of NewSessionState
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
}/// Create a copy of NewSessionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NewSessionOptionsLoadStateCopyWith<$Res> get options {
  
  return $NewSessionOptionsLoadStateCopyWith<$Res>(_self.options, (value) {
    return _then(_self.copyWith(options: value));
  });
}
}

/// @nodoc


class NewSessionCreated implements NewSessionState {
  const NewSessionCreated({required this.session});
  

 final  Session session;

/// Create a copy of NewSessionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NewSessionCreatedCopyWith<NewSessionCreated> get copyWith => _$NewSessionCreatedCopyWithImpl<NewSessionCreated>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NewSessionCreated&&(identical(other.session, session) || other.session == session));
}


@override
int get hashCode => Object.hash(runtimeType,session);

@override
String toString() {
  return 'NewSessionState.created(session: $session)';
}


}

/// @nodoc
abstract mixin class $NewSessionCreatedCopyWith<$Res> implements $NewSessionStateCopyWith<$Res> {
  factory $NewSessionCreatedCopyWith(NewSessionCreated value, $Res Function(NewSessionCreated) _then) = _$NewSessionCreatedCopyWithImpl;
@useResult
$Res call({
 Session session
});


$SessionCopyWith<$Res> get session;

}
/// @nodoc
class _$NewSessionCreatedCopyWithImpl<$Res>
    implements $NewSessionCreatedCopyWith<$Res> {
  _$NewSessionCreatedCopyWithImpl(this._self, this._then);

  final NewSessionCreated _self;
  final $Res Function(NewSessionCreated) _then;

/// Create a copy of NewSessionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? session = null,}) {
  return _then(NewSessionCreated(
session: null == session ? _self.session : session // ignore: cast_nullable_to_non_nullable
as Session,
  ));
}

/// Create a copy of NewSessionState
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
