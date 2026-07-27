// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plugin_setup_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PluginSetupMetadata {

 String get id; String get displayName;@JsonKey(unknownEnumValue: PluginSetupState.unknown) PluginSetupState get state; String? get actionHint;
/// Create a copy of PluginSetupMetadata
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginSetupMetadataCopyWith<PluginSetupMetadata> get copyWith => _$PluginSetupMetadataCopyWithImpl<PluginSetupMetadata>(this as PluginSetupMetadata, _$identity);

  /// Serializes this PluginSetupMetadata to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginSetupMetadata&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.state, state) || other.state == state)&&(identical(other.actionHint, actionHint) || other.actionHint == actionHint));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,displayName,state,actionHint);

@override
String toString() {
  return 'PluginSetupMetadata(id: $id, displayName: $displayName, state: $state, actionHint: $actionHint)';
}


}

/// @nodoc
abstract mixin class $PluginSetupMetadataCopyWith<$Res>  {
  factory $PluginSetupMetadataCopyWith(PluginSetupMetadata value, $Res Function(PluginSetupMetadata) _then) = _$PluginSetupMetadataCopyWithImpl;
@useResult
$Res call({
 String id, String displayName,@JsonKey(unknownEnumValue: PluginSetupState.unknown) PluginSetupState state, String? actionHint
});




}
/// @nodoc
class _$PluginSetupMetadataCopyWithImpl<$Res>
    implements $PluginSetupMetadataCopyWith<$Res> {
  _$PluginSetupMetadataCopyWithImpl(this._self, this._then);

  final PluginSetupMetadata _self;
  final $Res Function(PluginSetupMetadata) _then;

/// Create a copy of PluginSetupMetadata
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? displayName = null,Object? state = null,Object? actionHint = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as PluginSetupState,actionHint: freezed == actionHint ? _self.actionHint : actionHint // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _PluginSetupMetadata implements PluginSetupMetadata {
  const _PluginSetupMetadata({required this.id, required this.displayName, @JsonKey(unknownEnumValue: PluginSetupState.unknown) required this.state, required this.actionHint});
  factory _PluginSetupMetadata.fromJson(Map<String, dynamic> json) => _$PluginSetupMetadataFromJson(json);

@override final  String id;
@override final  String displayName;
@override@JsonKey(unknownEnumValue: PluginSetupState.unknown) final  PluginSetupState state;
@override final  String? actionHint;

/// Create a copy of PluginSetupMetadata
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginSetupMetadataCopyWith<_PluginSetupMetadata> get copyWith => __$PluginSetupMetadataCopyWithImpl<_PluginSetupMetadata>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginSetupMetadataToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginSetupMetadata&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.state, state) || other.state == state)&&(identical(other.actionHint, actionHint) || other.actionHint == actionHint));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,displayName,state,actionHint);

@override
String toString() {
  return 'PluginSetupMetadata(id: $id, displayName: $displayName, state: $state, actionHint: $actionHint)';
}


}

/// @nodoc
abstract mixin class _$PluginSetupMetadataCopyWith<$Res> implements $PluginSetupMetadataCopyWith<$Res> {
  factory _$PluginSetupMetadataCopyWith(_PluginSetupMetadata value, $Res Function(_PluginSetupMetadata) _then) = __$PluginSetupMetadataCopyWithImpl;
@override @useResult
$Res call({
 String id, String displayName,@JsonKey(unknownEnumValue: PluginSetupState.unknown) PluginSetupState state, String? actionHint
});




}
/// @nodoc
class __$PluginSetupMetadataCopyWithImpl<$Res>
    implements _$PluginSetupMetadataCopyWith<$Res> {
  __$PluginSetupMetadataCopyWithImpl(this._self, this._then);

  final _PluginSetupMetadata _self;
  final $Res Function(_PluginSetupMetadata) _then;

/// Create a copy of PluginSetupMetadata
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? displayName = null,Object? state = null,Object? actionHint = freezed,}) {
  return _then(_PluginSetupMetadata(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as PluginSetupState,actionHint: freezed == actionHint ? _self.actionHint : actionHint // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$PluginSetupResponse {

 List<PluginSetupMetadata> get plugins;
/// Create a copy of PluginSetupResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginSetupResponseCopyWith<PluginSetupResponse> get copyWith => _$PluginSetupResponseCopyWithImpl<PluginSetupResponse>(this as PluginSetupResponse, _$identity);

  /// Serializes this PluginSetupResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginSetupResponse&&const DeepCollectionEquality().equals(other.plugins, plugins));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(plugins));

@override
String toString() {
  return 'PluginSetupResponse(plugins: $plugins)';
}


}

/// @nodoc
abstract mixin class $PluginSetupResponseCopyWith<$Res>  {
  factory $PluginSetupResponseCopyWith(PluginSetupResponse value, $Res Function(PluginSetupResponse) _then) = _$PluginSetupResponseCopyWithImpl;
@useResult
$Res call({
 List<PluginSetupMetadata> plugins
});




}
/// @nodoc
class _$PluginSetupResponseCopyWithImpl<$Res>
    implements $PluginSetupResponseCopyWith<$Res> {
  _$PluginSetupResponseCopyWithImpl(this._self, this._then);

  final PluginSetupResponse _self;
  final $Res Function(PluginSetupResponse) _then;

/// Create a copy of PluginSetupResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? plugins = null,}) {
  return _then(_self.copyWith(
plugins: null == plugins ? _self.plugins : plugins // ignore: cast_nullable_to_non_nullable
as List<PluginSetupMetadata>,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _PluginSetupResponse implements PluginSetupResponse {
  const _PluginSetupResponse({required final  List<PluginSetupMetadata> plugins}): _plugins = plugins;
  factory _PluginSetupResponse.fromJson(Map<String, dynamic> json) => _$PluginSetupResponseFromJson(json);

 final  List<PluginSetupMetadata> _plugins;
@override List<PluginSetupMetadata> get plugins {
  if (_plugins is EqualUnmodifiableListView) return _plugins;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_plugins);
}


/// Create a copy of PluginSetupResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginSetupResponseCopyWith<_PluginSetupResponse> get copyWith => __$PluginSetupResponseCopyWithImpl<_PluginSetupResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginSetupResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginSetupResponse&&const DeepCollectionEquality().equals(other._plugins, _plugins));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_plugins));

@override
String toString() {
  return 'PluginSetupResponse(plugins: $plugins)';
}


}

/// @nodoc
abstract mixin class _$PluginSetupResponseCopyWith<$Res> implements $PluginSetupResponseCopyWith<$Res> {
  factory _$PluginSetupResponseCopyWith(_PluginSetupResponse value, $Res Function(_PluginSetupResponse) _then) = __$PluginSetupResponseCopyWithImpl;
@override @useResult
$Res call({
 List<PluginSetupMetadata> plugins
});




}
/// @nodoc
class __$PluginSetupResponseCopyWithImpl<$Res>
    implements _$PluginSetupResponseCopyWith<$Res> {
  __$PluginSetupResponseCopyWithImpl(this._self, this._then);

  final _PluginSetupResponse _self;
  final $Res Function(_PluginSetupResponse) _then;

/// Create a copy of PluginSetupResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? plugins = null,}) {
  return _then(_PluginSetupResponse(
plugins: null == plugins ? _self._plugins : plugins // ignore: cast_nullable_to_non_nullable
as List<PluginSetupMetadata>,
  ));
}


}

// dart format on
