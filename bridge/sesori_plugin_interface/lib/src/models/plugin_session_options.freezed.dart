// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plugin_session_options.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PluginSessionOptions {

 List<PluginAgent> get agents; PluginProvidersResult get providers; List<PluginCommand> get commands; PluginSessionOptionsCompleteness get completeness;
/// Create a copy of PluginSessionOptions
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginSessionOptionsCopyWith<PluginSessionOptions> get copyWith => _$PluginSessionOptionsCopyWithImpl<PluginSessionOptions>(this as PluginSessionOptions, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginSessionOptions&&const DeepCollectionEquality().equals(other.agents, agents)&&(identical(other.providers, providers) || other.providers == providers)&&const DeepCollectionEquality().equals(other.commands, commands)&&(identical(other.completeness, completeness) || other.completeness == completeness));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(agents),providers,const DeepCollectionEquality().hash(commands),completeness);

@override
String toString() {
  return 'PluginSessionOptions(agents: $agents, providers: $providers, commands: $commands, completeness: $completeness)';
}


}

/// @nodoc
abstract mixin class $PluginSessionOptionsCopyWith<$Res>  {
  factory $PluginSessionOptionsCopyWith(PluginSessionOptions value, $Res Function(PluginSessionOptions) _then) = _$PluginSessionOptionsCopyWithImpl;
@useResult
$Res call({
 List<PluginAgent> agents, PluginProvidersResult providers, List<PluginCommand> commands, PluginSessionOptionsCompleteness completeness
});


$PluginProvidersResultCopyWith<$Res> get providers;

}
/// @nodoc
class _$PluginSessionOptionsCopyWithImpl<$Res>
    implements $PluginSessionOptionsCopyWith<$Res> {
  _$PluginSessionOptionsCopyWithImpl(this._self, this._then);

  final PluginSessionOptions _self;
  final $Res Function(PluginSessionOptions) _then;

/// Create a copy of PluginSessionOptions
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? agents = null,Object? providers = null,Object? commands = null,Object? completeness = null,}) {
  return _then(PluginSessionOptions(
agents: null == agents ? _self.agents : agents // ignore: cast_nullable_to_non_nullable
as List<PluginAgent>,providers: null == providers ? _self.providers : providers // ignore: cast_nullable_to_non_nullable
as PluginProvidersResult,commands: null == commands ? _self.commands : commands // ignore: cast_nullable_to_non_nullable
as List<PluginCommand>,completeness: null == completeness ? _self.completeness : completeness // ignore: cast_nullable_to_non_nullable
as PluginSessionOptionsCompleteness,
  ));
}
/// Create a copy of PluginSessionOptions
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginProvidersResultCopyWith<$Res> get providers {
  
  return $PluginProvidersResultCopyWith<$Res>(_self.providers, (value) {
    return _then(_self.copyWith(providers: value));
  });
}
}



/// @nodoc


class _PluginSessionOptions implements PluginSessionOptions {
  const _PluginSessionOptions({required  List<PluginAgent> agents, required this.providers, required  List<PluginCommand> commands, required this.completeness}): _agents = agents,_commands = commands;
  

 final  List<PluginAgent> _agents;
@override List<PluginAgent> get agents {
  if (_agents is EqualUnmodifiableListView) return _agents;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_agents);
}

@override final  PluginProvidersResult providers;
 final  List<PluginCommand> _commands;
@override List<PluginCommand> get commands {
  if (_commands is EqualUnmodifiableListView) return _commands;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_commands);
}

@override final  PluginSessionOptionsCompleteness completeness;

/// Create a copy of PluginSessionOptions
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginSessionOptionsCopyWith<_PluginSessionOptions> get copyWith => __$PluginSessionOptionsCopyWithImpl<_PluginSessionOptions>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginSessionOptions&&const DeepCollectionEquality().equals(other._agents, _agents)&&(identical(other.providers, providers) || other.providers == providers)&&const DeepCollectionEquality().equals(other._commands, _commands)&&(identical(other.completeness, completeness) || other.completeness == completeness));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_agents),providers,const DeepCollectionEquality().hash(_commands),completeness);

@override
String toString() {
  return 'PluginSessionOptions(agents: $agents, providers: $providers, commands: $commands, completeness: $completeness)';
}


}

/// @nodoc
abstract mixin class _$PluginSessionOptionsCopyWith<$Res> implements $PluginSessionOptionsCopyWith<$Res> {
  factory _$PluginSessionOptionsCopyWith(_PluginSessionOptions value, $Res Function(_PluginSessionOptions) _then) = __$PluginSessionOptionsCopyWithImpl;
@override @useResult
$Res call({
 List<PluginAgent> agents, PluginProvidersResult providers, List<PluginCommand> commands, PluginSessionOptionsCompleteness completeness
});


@override $PluginProvidersResultCopyWith<$Res> get providers;

}
/// @nodoc
class __$PluginSessionOptionsCopyWithImpl<$Res>
    implements _$PluginSessionOptionsCopyWith<$Res> {
  __$PluginSessionOptionsCopyWithImpl(this._self, this._then);

  final _PluginSessionOptions _self;
  final $Res Function(_PluginSessionOptions) _then;

/// Create a copy of PluginSessionOptions
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? agents = null,Object? providers = null,Object? commands = null,Object? completeness = null,}) {
  return _then(_PluginSessionOptions(
agents: null == agents ? _self._agents : agents // ignore: cast_nullable_to_non_nullable
as List<PluginAgent>,providers: null == providers ? _self.providers : providers // ignore: cast_nullable_to_non_nullable
as PluginProvidersResult,commands: null == commands ? _self._commands : commands // ignore: cast_nullable_to_non_nullable
as List<PluginCommand>,completeness: null == completeness ? _self.completeness : completeness // ignore: cast_nullable_to_non_nullable
as PluginSessionOptionsCompleteness,
  ));
}

/// Create a copy of PluginSessionOptions
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginProvidersResultCopyWith<$Res> get providers {
  
  return $PluginProvidersResultCopyWith<$Res>(_self.providers, (value) {
    return _then(_self.copyWith(providers: value));
  });
}
}

/// @nodoc
mixin _$PluginSessionOptionsDiscoveryResult {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginSessionOptionsDiscoveryResult);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PluginSessionOptionsDiscoveryResult()';
}


}

/// @nodoc
class $PluginSessionOptionsDiscoveryResultCopyWith<$Res>  {
$PluginSessionOptionsDiscoveryResultCopyWith(PluginSessionOptionsDiscoveryResult _, $Res Function(PluginSessionOptionsDiscoveryResult) __);
}



/// @nodoc


class PluginSessionOptionsDiscoveryObserved implements PluginSessionOptionsDiscoveryResult {
  const PluginSessionOptionsDiscoveryObserved({required this.options});
  

 final  PluginSessionOptions options;

/// Create a copy of PluginSessionOptionsDiscoveryResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginSessionOptionsDiscoveryObservedCopyWith<PluginSessionOptionsDiscoveryObserved> get copyWith => _$PluginSessionOptionsDiscoveryObservedCopyWithImpl<PluginSessionOptionsDiscoveryObserved>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginSessionOptionsDiscoveryObserved&&(identical(other.options, options) || other.options == options));
}


@override
int get hashCode => Object.hash(runtimeType,options);

@override
String toString() {
  return 'PluginSessionOptionsDiscoveryResult.observed(options: $options)';
}


}

/// @nodoc
abstract mixin class $PluginSessionOptionsDiscoveryObservedCopyWith<$Res> implements $PluginSessionOptionsDiscoveryResultCopyWith<$Res> {
  factory $PluginSessionOptionsDiscoveryObservedCopyWith(PluginSessionOptionsDiscoveryObserved value, $Res Function(PluginSessionOptionsDiscoveryObserved) _then) = _$PluginSessionOptionsDiscoveryObservedCopyWithImpl;
@useResult
$Res call({
 PluginSessionOptions options
});


$PluginSessionOptionsCopyWith<$Res> get options;

}
/// @nodoc
class _$PluginSessionOptionsDiscoveryObservedCopyWithImpl<$Res>
    implements $PluginSessionOptionsDiscoveryObservedCopyWith<$Res> {
  _$PluginSessionOptionsDiscoveryObservedCopyWithImpl(this._self, this._then);

  final PluginSessionOptionsDiscoveryObserved _self;
  final $Res Function(PluginSessionOptionsDiscoveryObserved) _then;

/// Create a copy of PluginSessionOptionsDiscoveryResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? options = null,}) {
  return _then(PluginSessionOptionsDiscoveryObserved(
options: null == options ? _self.options : options // ignore: cast_nullable_to_non_nullable
as PluginSessionOptions,
  ));
}

/// Create a copy of PluginSessionOptionsDiscoveryResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginSessionOptionsCopyWith<$Res> get options {
  
  return $PluginSessionOptionsCopyWith<$Res>(_self.options, (value) {
    return _then(_self.copyWith(options: value));
  });
}
}

/// @nodoc


class PluginSessionOptionsDiscoveryFailed implements PluginSessionOptionsDiscoveryResult {
  const PluginSessionOptionsDiscoveryFailed();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginSessionOptionsDiscoveryFailed);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PluginSessionOptionsDiscoveryResult.failed()';
}


}




// dart format on
