// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'health_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$HealthResponse {

 bool get healthy; String get version;// COMPATIBILITY 2026-07-17 (v1.5.1): Bridges before per-plugin health omit plugins. Remove @Default and require plugins once pre-v1.5.1 bridges are unsupported.
 List<PluginHealth> get plugins;// Whether the bridge detected degraded host filesystem access at startup
// (e.g. macOS Full Disk Access not granted), so the phone can proactively
// warn the user. Nullable for backward compatibility: an older bridge that
// never sends it decodes to null and is treated as "not degraded".
// COMPATIBILITY 2026-06-27 (v1.2.0): Old bridges omit filesystem-access state. Make this non-null and remove client null fallbacks once those bridges are unsupported.
 bool? get filesystemAccessDegraded;
/// Create a copy of HealthResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HealthResponseCopyWith<HealthResponse> get copyWith => _$HealthResponseCopyWithImpl<HealthResponse>(this as HealthResponse, _$identity);

  /// Serializes this HealthResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HealthResponse&&(identical(other.healthy, healthy) || other.healthy == healthy)&&(identical(other.version, version) || other.version == version)&&const DeepCollectionEquality().equals(other.plugins, plugins)&&(identical(other.filesystemAccessDegraded, filesystemAccessDegraded) || other.filesystemAccessDegraded == filesystemAccessDegraded));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,healthy,version,const DeepCollectionEquality().hash(plugins),filesystemAccessDegraded);

@override
String toString() {
  return 'HealthResponse(healthy: $healthy, version: $version, plugins: $plugins, filesystemAccessDegraded: $filesystemAccessDegraded)';
}


}

/// @nodoc
abstract mixin class $HealthResponseCopyWith<$Res>  {
  factory $HealthResponseCopyWith(HealthResponse value, $Res Function(HealthResponse) _then) = _$HealthResponseCopyWithImpl;
@useResult
$Res call({
 bool healthy, String version, List<PluginHealth> plugins, bool? filesystemAccessDegraded
});




}
/// @nodoc
class _$HealthResponseCopyWithImpl<$Res>
    implements $HealthResponseCopyWith<$Res> {
  _$HealthResponseCopyWithImpl(this._self, this._then);

  final HealthResponse _self;
  final $Res Function(HealthResponse) _then;

/// Create a copy of HealthResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? healthy = null,Object? version = null,Object? plugins = null,Object? filesystemAccessDegraded = freezed,}) {
  return _then(_self.copyWith(
healthy: null == healthy ? _self.healthy : healthy // ignore: cast_nullable_to_non_nullable
as bool,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,plugins: null == plugins ? _self.plugins : plugins // ignore: cast_nullable_to_non_nullable
as List<PluginHealth>,filesystemAccessDegraded: freezed == filesystemAccessDegraded ? _self.filesystemAccessDegraded : filesystemAccessDegraded // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _HealthResponse implements HealthResponse {
  const _HealthResponse({required this.healthy, required this.version, final  List<PluginHealth> plugins = const <PluginHealth>[], required this.filesystemAccessDegraded}): _plugins = plugins;
  factory _HealthResponse.fromJson(Map<String, dynamic> json) => _$HealthResponseFromJson(json);

@override final  bool healthy;
@override final  String version;
// COMPATIBILITY 2026-07-17 (v1.5.1): Bridges before per-plugin health omit plugins. Remove @Default and require plugins once pre-v1.5.1 bridges are unsupported.
 final  List<PluginHealth> _plugins;
// COMPATIBILITY 2026-07-17 (v1.5.1): Bridges before per-plugin health omit plugins. Remove @Default and require plugins once pre-v1.5.1 bridges are unsupported.
@override@JsonKey() List<PluginHealth> get plugins {
  if (_plugins is EqualUnmodifiableListView) return _plugins;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_plugins);
}

// Whether the bridge detected degraded host filesystem access at startup
// (e.g. macOS Full Disk Access not granted), so the phone can proactively
// warn the user. Nullable for backward compatibility: an older bridge that
// never sends it decodes to null and is treated as "not degraded".
// COMPATIBILITY 2026-06-27 (v1.2.0): Old bridges omit filesystem-access state. Make this non-null and remove client null fallbacks once those bridges are unsupported.
@override final  bool? filesystemAccessDegraded;

/// Create a copy of HealthResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HealthResponseCopyWith<_HealthResponse> get copyWith => __$HealthResponseCopyWithImpl<_HealthResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$HealthResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _HealthResponse&&(identical(other.healthy, healthy) || other.healthy == healthy)&&(identical(other.version, version) || other.version == version)&&const DeepCollectionEquality().equals(other._plugins, _plugins)&&(identical(other.filesystemAccessDegraded, filesystemAccessDegraded) || other.filesystemAccessDegraded == filesystemAccessDegraded));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,healthy,version,const DeepCollectionEquality().hash(_plugins),filesystemAccessDegraded);

@override
String toString() {
  return 'HealthResponse(healthy: $healthy, version: $version, plugins: $plugins, filesystemAccessDegraded: $filesystemAccessDegraded)';
}


}

/// @nodoc
abstract mixin class _$HealthResponseCopyWith<$Res> implements $HealthResponseCopyWith<$Res> {
  factory _$HealthResponseCopyWith(_HealthResponse value, $Res Function(_HealthResponse) _then) = __$HealthResponseCopyWithImpl;
@override @useResult
$Res call({
 bool healthy, String version, List<PluginHealth> plugins, bool? filesystemAccessDegraded
});




}
/// @nodoc
class __$HealthResponseCopyWithImpl<$Res>
    implements _$HealthResponseCopyWith<$Res> {
  __$HealthResponseCopyWithImpl(this._self, this._then);

  final _HealthResponse _self;
  final $Res Function(_HealthResponse) _then;

/// Create a copy of HealthResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? healthy = null,Object? version = null,Object? plugins = null,Object? filesystemAccessDegraded = freezed,}) {
  return _then(_HealthResponse(
healthy: null == healthy ? _self.healthy : healthy // ignore: cast_nullable_to_non_nullable
as bool,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,plugins: null == plugins ? _self._plugins : plugins // ignore: cast_nullable_to_non_nullable
as List<PluginHealth>,filesystemAccessDegraded: freezed == filesystemAccessDegraded ? _self.filesystemAccessDegraded : filesystemAccessDegraded // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}


}


/// @nodoc
mixin _$PluginHealth {

 String get pluginId; bool get healthy;
/// Create a copy of PluginHealth
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginHealthCopyWith<PluginHealth> get copyWith => _$PluginHealthCopyWithImpl<PluginHealth>(this as PluginHealth, _$identity);

  /// Serializes this PluginHealth to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginHealth&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId)&&(identical(other.healthy, healthy) || other.healthy == healthy));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,pluginId,healthy);

@override
String toString() {
  return 'PluginHealth(pluginId: $pluginId, healthy: $healthy)';
}


}

/// @nodoc
abstract mixin class $PluginHealthCopyWith<$Res>  {
  factory $PluginHealthCopyWith(PluginHealth value, $Res Function(PluginHealth) _then) = _$PluginHealthCopyWithImpl;
@useResult
$Res call({
 String pluginId, bool healthy
});




}
/// @nodoc
class _$PluginHealthCopyWithImpl<$Res>
    implements $PluginHealthCopyWith<$Res> {
  _$PluginHealthCopyWithImpl(this._self, this._then);

  final PluginHealth _self;
  final $Res Function(PluginHealth) _then;

/// Create a copy of PluginHealth
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? pluginId = null,Object? healthy = null,}) {
  return _then(_self.copyWith(
pluginId: null == pluginId ? _self.pluginId : pluginId // ignore: cast_nullable_to_non_nullable
as String,healthy: null == healthy ? _self.healthy : healthy // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _PluginHealth implements PluginHealth {
  const _PluginHealth({required this.pluginId, required this.healthy});
  factory _PluginHealth.fromJson(Map<String, dynamic> json) => _$PluginHealthFromJson(json);

@override final  String pluginId;
@override final  bool healthy;

/// Create a copy of PluginHealth
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginHealthCopyWith<_PluginHealth> get copyWith => __$PluginHealthCopyWithImpl<_PluginHealth>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginHealthToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginHealth&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId)&&(identical(other.healthy, healthy) || other.healthy == healthy));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,pluginId,healthy);

@override
String toString() {
  return 'PluginHealth(pluginId: $pluginId, healthy: $healthy)';
}


}

/// @nodoc
abstract mixin class _$PluginHealthCopyWith<$Res> implements $PluginHealthCopyWith<$Res> {
  factory _$PluginHealthCopyWith(_PluginHealth value, $Res Function(_PluginHealth) _then) = __$PluginHealthCopyWithImpl;
@override @useResult
$Res call({
 String pluginId, bool healthy
});




}
/// @nodoc
class __$PluginHealthCopyWithImpl<$Res>
    implements _$PluginHealthCopyWith<$Res> {
  __$PluginHealthCopyWithImpl(this._self, this._then);

  final _PluginHealth _self;
  final $Res Function(_PluginHealth) _then;

/// Create a copy of PluginHealth
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? pluginId = null,Object? healthy = null,}) {
  return _then(_PluginHealth(
pluginId: null == pluginId ? _self.pluginId : pluginId // ignore: cast_nullable_to_non_nullable
as String,healthy: null == healthy ? _self.healthy : healthy // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
