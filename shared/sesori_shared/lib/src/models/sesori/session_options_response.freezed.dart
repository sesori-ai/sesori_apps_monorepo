// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_options_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SessionOptionsResponse {

 Agents get agents; ProviderListResponse get providers; CommandListResponse get commands;/// Whether the bridge served a cached snapshot older than its freshness
/// window, making it worth a background refresh. Freshly discovered options
/// are never stale, and a bridge that predates the signal never asks for
/// one.
 bool get stale;
/// Create a copy of SessionOptionsResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionOptionsResponseCopyWith<SessionOptionsResponse> get copyWith => _$SessionOptionsResponseCopyWithImpl<SessionOptionsResponse>(this as SessionOptionsResponse, _$identity);

  /// Serializes this SessionOptionsResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionOptionsResponse&&(identical(other.agents, agents) || other.agents == agents)&&(identical(other.providers, providers) || other.providers == providers)&&(identical(other.commands, commands) || other.commands == commands)&&(identical(other.stale, stale) || other.stale == stale));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,agents,providers,commands,stale);

@override
String toString() {
  return 'SessionOptionsResponse(agents: $agents, providers: $providers, commands: $commands, stale: $stale)';
}


}

/// @nodoc
abstract mixin class $SessionOptionsResponseCopyWith<$Res>  {
  factory $SessionOptionsResponseCopyWith(SessionOptionsResponse value, $Res Function(SessionOptionsResponse) _then) = _$SessionOptionsResponseCopyWithImpl;
@useResult
$Res call({
 Agents agents, ProviderListResponse providers, CommandListResponse commands, bool stale
});


$AgentsCopyWith<$Res> get agents;$ProviderListResponseCopyWith<$Res> get providers;$CommandListResponseCopyWith<$Res> get commands;

}
/// @nodoc
class _$SessionOptionsResponseCopyWithImpl<$Res>
    implements $SessionOptionsResponseCopyWith<$Res> {
  _$SessionOptionsResponseCopyWithImpl(this._self, this._then);

  final SessionOptionsResponse _self;
  final $Res Function(SessionOptionsResponse) _then;

/// Create a copy of SessionOptionsResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? agents = null,Object? providers = null,Object? commands = null,Object? stale = null,}) {
  return _then(SessionOptionsResponse(
agents: null == agents ? _self.agents : agents // ignore: cast_nullable_to_non_nullable
as Agents,providers: null == providers ? _self.providers : providers // ignore: cast_nullable_to_non_nullable
as ProviderListResponse,commands: null == commands ? _self.commands : commands // ignore: cast_nullable_to_non_nullable
as CommandListResponse,stale: null == stale ? _self.stale : stale // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of SessionOptionsResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AgentsCopyWith<$Res> get agents {
  
  return $AgentsCopyWith<$Res>(_self.agents, (value) {
    return _then(_self.copyWith(agents: value));
  });
}/// Create a copy of SessionOptionsResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProviderListResponseCopyWith<$Res> get providers {
  
  return $ProviderListResponseCopyWith<$Res>(_self.providers, (value) {
    return _then(_self.copyWith(providers: value));
  });
}/// Create a copy of SessionOptionsResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CommandListResponseCopyWith<$Res> get commands {
  
  return $CommandListResponseCopyWith<$Res>(_self.commands, (value) {
    return _then(_self.copyWith(commands: value));
  });
}
}



/// @nodoc
@JsonSerializable()

class _SessionOptionsResponse implements SessionOptionsResponse {
  const _SessionOptionsResponse({required this.agents, required this.providers, required this.commands, this.stale = false});
  factory _SessionOptionsResponse.fromJson(Map<String, dynamic> json) => _$SessionOptionsResponseFromJson(json);

@override final  Agents agents;
@override final  ProviderListResponse providers;
@override final  CommandListResponse commands;
/// Whether the bridge served a cached snapshot older than its freshness
/// window, making it worth a background refresh. Freshly discovered options
/// are never stale, and a bridge that predates the signal never asks for
/// one.
@override@JsonKey() final  bool stale;

/// Create a copy of SessionOptionsResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionOptionsResponseCopyWith<_SessionOptionsResponse> get copyWith => __$SessionOptionsResponseCopyWithImpl<_SessionOptionsResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionOptionsResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionOptionsResponse&&(identical(other.agents, agents) || other.agents == agents)&&(identical(other.providers, providers) || other.providers == providers)&&(identical(other.commands, commands) || other.commands == commands)&&(identical(other.stale, stale) || other.stale == stale));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,agents,providers,commands,stale);

@override
String toString() {
  return 'SessionOptionsResponse(agents: $agents, providers: $providers, commands: $commands, stale: $stale)';
}


}

/// @nodoc
abstract mixin class _$SessionOptionsResponseCopyWith<$Res> implements $SessionOptionsResponseCopyWith<$Res> {
  factory _$SessionOptionsResponseCopyWith(_SessionOptionsResponse value, $Res Function(_SessionOptionsResponse) _then) = __$SessionOptionsResponseCopyWithImpl;
@override @useResult
$Res call({
 Agents agents, ProviderListResponse providers, CommandListResponse commands, bool stale
});


@override $AgentsCopyWith<$Res> get agents;@override $ProviderListResponseCopyWith<$Res> get providers;@override $CommandListResponseCopyWith<$Res> get commands;

}
/// @nodoc
class __$SessionOptionsResponseCopyWithImpl<$Res>
    implements _$SessionOptionsResponseCopyWith<$Res> {
  __$SessionOptionsResponseCopyWithImpl(this._self, this._then);

  final _SessionOptionsResponse _self;
  final $Res Function(_SessionOptionsResponse) _then;

/// Create a copy of SessionOptionsResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? agents = null,Object? providers = null,Object? commands = null,Object? stale = null,}) {
  return _then(_SessionOptionsResponse(
agents: null == agents ? _self.agents : agents // ignore: cast_nullable_to_non_nullable
as Agents,providers: null == providers ? _self.providers : providers // ignore: cast_nullable_to_non_nullable
as ProviderListResponse,commands: null == commands ? _self.commands : commands // ignore: cast_nullable_to_non_nullable
as CommandListResponse,stale: null == stale ? _self.stale : stale // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of SessionOptionsResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AgentsCopyWith<$Res> get agents {
  
  return $AgentsCopyWith<$Res>(_self.agents, (value) {
    return _then(_self.copyWith(agents: value));
  });
}/// Create a copy of SessionOptionsResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProviderListResponseCopyWith<$Res> get providers {
  
  return $ProviderListResponseCopyWith<$Res>(_self.providers, (value) {
    return _then(_self.copyWith(providers: value));
  });
}/// Create a copy of SessionOptionsResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CommandListResponseCopyWith<$Res> get commands {
  
  return $CommandListResponseCopyWith<$Res>(_self.commands, (value) {
    return _then(_self.copyWith(commands: value));
  });
}
}

// dart format on
