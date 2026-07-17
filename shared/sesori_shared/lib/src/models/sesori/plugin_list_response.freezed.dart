// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plugin_list_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PluginMetadata {

 String get id; String get displayName; bool get isDefault; PluginLifecycleState get state; String? get actionHint;
/// Create a copy of PluginMetadata
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginMetadataCopyWith<PluginMetadata> get copyWith => _$PluginMetadataCopyWithImpl<PluginMetadata>(this as PluginMetadata, _$identity);

  /// Serializes this PluginMetadata to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginMetadata&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.isDefault, isDefault) || other.isDefault == isDefault)&&(identical(other.state, state) || other.state == state)&&(identical(other.actionHint, actionHint) || other.actionHint == actionHint));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,displayName,isDefault,state,actionHint);

@override
String toString() {
  return 'PluginMetadata(id: $id, displayName: $displayName, isDefault: $isDefault, state: $state, actionHint: $actionHint)';
}


}

/// @nodoc
abstract mixin class $PluginMetadataCopyWith<$Res>  {
  factory $PluginMetadataCopyWith(PluginMetadata value, $Res Function(PluginMetadata) _then) = _$PluginMetadataCopyWithImpl;
@useResult
$Res call({
 String id, String displayName, bool isDefault, PluginLifecycleState state, String? actionHint
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? displayName = null,Object? isDefault = null,Object? state = null,Object? actionHint = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,isDefault: null == isDefault ? _self.isDefault : isDefault // ignore: cast_nullable_to_non_nullable
as bool,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as PluginLifecycleState,actionHint: freezed == actionHint ? _self.actionHint : actionHint // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _PluginMetadata implements PluginMetadata {
  const _PluginMetadata({required this.id, required this.displayName, required this.isDefault, required this.state, required this.actionHint});
  factory _PluginMetadata.fromJson(Map<String, dynamic> json) => _$PluginMetadataFromJson(json);

@override final  String id;
@override final  String displayName;
@override final  bool isDefault;
@override final  PluginLifecycleState state;
@override final  String? actionHint;

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginMetadata&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.isDefault, isDefault) || other.isDefault == isDefault)&&(identical(other.state, state) || other.state == state)&&(identical(other.actionHint, actionHint) || other.actionHint == actionHint));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,displayName,isDefault,state,actionHint);

@override
String toString() {
  return 'PluginMetadata(id: $id, displayName: $displayName, isDefault: $isDefault, state: $state, actionHint: $actionHint)';
}


}

/// @nodoc
abstract mixin class _$PluginMetadataCopyWith<$Res> implements $PluginMetadataCopyWith<$Res> {
  factory _$PluginMetadataCopyWith(_PluginMetadata value, $Res Function(_PluginMetadata) _then) = __$PluginMetadataCopyWithImpl;
@override @useResult
$Res call({
 String id, String displayName, bool isDefault, PluginLifecycleState state, String? actionHint
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? displayName = null,Object? isDefault = null,Object? state = null,Object? actionHint = freezed,}) {
  return _then(_PluginMetadata(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,isDefault: null == isDefault ? _self.isDefault : isDefault // ignore: cast_nullable_to_non_nullable
as bool,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as PluginLifecycleState,actionHint: freezed == actionHint ? _self.actionHint : actionHint // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$PluginListResponse {

 List<PluginMetadata> get plugins;
/// Create a copy of PluginListResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginListResponseCopyWith<PluginListResponse> get copyWith => _$PluginListResponseCopyWithImpl<PluginListResponse>(this as PluginListResponse, _$identity);

  /// Serializes this PluginListResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginListResponse&&const DeepCollectionEquality().equals(other.plugins, plugins));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(plugins));

@override
String toString() {
  return 'PluginListResponse(plugins: $plugins)';
}


}

/// @nodoc
abstract mixin class $PluginListResponseCopyWith<$Res>  {
  factory $PluginListResponseCopyWith(PluginListResponse value, $Res Function(PluginListResponse) _then) = _$PluginListResponseCopyWithImpl;
@useResult
$Res call({
 List<PluginMetadata> plugins
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
@pragma('vm:prefer-inline') @override $Res call({Object? plugins = null,}) {
  return _then(_self.copyWith(
plugins: null == plugins ? _self.plugins : plugins // ignore: cast_nullable_to_non_nullable
as List<PluginMetadata>,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _PluginListResponse implements PluginListResponse {
  const _PluginListResponse({required final  List<PluginMetadata> plugins}): _plugins = plugins;
  factory _PluginListResponse.fromJson(Map<String, dynamic> json) => _$PluginListResponseFromJson(json);

 final  List<PluginMetadata> _plugins;
@override List<PluginMetadata> get plugins {
  if (_plugins is EqualUnmodifiableListView) return _plugins;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_plugins);
}


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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginListResponse&&const DeepCollectionEquality().equals(other._plugins, _plugins));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_plugins));

@override
String toString() {
  return 'PluginListResponse(plugins: $plugins)';
}


}

/// @nodoc
abstract mixin class _$PluginListResponseCopyWith<$Res> implements $PluginListResponseCopyWith<$Res> {
  factory _$PluginListResponseCopyWith(_PluginListResponse value, $Res Function(_PluginListResponse) _then) = __$PluginListResponseCopyWithImpl;
@override @useResult
$Res call({
 List<PluginMetadata> plugins
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
@override @pragma('vm:prefer-inline') $Res call({Object? plugins = null,}) {
  return _then(_PluginListResponse(
plugins: null == plugins ? _self._plugins : plugins // ignore: cast_nullable_to_non_nullable
as List<PluginMetadata>,
  ));
}


}

// dart format on
