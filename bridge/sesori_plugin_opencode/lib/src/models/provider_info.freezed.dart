// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'provider_info.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ProviderInfo {

 String get id; String get name; Map<String, ProviderModel> get models;
/// Create a copy of ProviderInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProviderInfoCopyWith<ProviderInfo> get copyWith => _$ProviderInfoCopyWithImpl<ProviderInfo>(this as ProviderInfo, _$identity);

  /// Serializes this ProviderInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProviderInfo&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other.models, models));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,const DeepCollectionEquality().hash(models));

@override
String toString() {
  return 'ProviderInfo(id: $id, name: $name, models: $models)';
}


}

/// @nodoc
abstract mixin class $ProviderInfoCopyWith<$Res>  {
  factory $ProviderInfoCopyWith(ProviderInfo value, $Res Function(ProviderInfo) _then) = _$ProviderInfoCopyWithImpl;
@useResult
$Res call({
 String id, String name, Map<String, ProviderModel> models
});




}
/// @nodoc
class _$ProviderInfoCopyWithImpl<$Res>
    implements $ProviderInfoCopyWith<$Res> {
  _$ProviderInfoCopyWithImpl(this._self, this._then);

  final ProviderInfo _self;
  final $Res Function(ProviderInfo) _then;

/// Create a copy of ProviderInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? models = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,models: null == models ? _self.models : models // ignore: cast_nullable_to_non_nullable
as Map<String, ProviderModel>,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _ProviderInfo implements ProviderInfo {
  const _ProviderInfo({required this.id, required this.name, required final  Map<String, ProviderModel> models}): _models = models;
  factory _ProviderInfo.fromJson(Map<String, dynamic> json) => _$ProviderInfoFromJson(json);

@override final  String id;
@override final  String name;
 final  Map<String, ProviderModel> _models;
@override Map<String, ProviderModel> get models {
  if (_models is EqualUnmodifiableMapView) return _models;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_models);
}


/// Create a copy of ProviderInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProviderInfoCopyWith<_ProviderInfo> get copyWith => __$ProviderInfoCopyWithImpl<_ProviderInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProviderInfoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProviderInfo&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other._models, _models));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,const DeepCollectionEquality().hash(_models));

@override
String toString() {
  return 'ProviderInfo(id: $id, name: $name, models: $models)';
}


}

/// @nodoc
abstract mixin class _$ProviderInfoCopyWith<$Res> implements $ProviderInfoCopyWith<$Res> {
  factory _$ProviderInfoCopyWith(_ProviderInfo value, $Res Function(_ProviderInfo) _then) = __$ProviderInfoCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, Map<String, ProviderModel> models
});




}
/// @nodoc
class __$ProviderInfoCopyWithImpl<$Res>
    implements _$ProviderInfoCopyWith<$Res> {
  __$ProviderInfoCopyWithImpl(this._self, this._then);

  final _ProviderInfo _self;
  final $Res Function(_ProviderInfo) _then;

/// Create a copy of ProviderInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? models = null,}) {
  return _then(_ProviderInfo(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,models: null == models ? _self._models : models // ignore: cast_nullable_to_non_nullable
as Map<String, ProviderModel>,
  ));
}


}


/// @nodoc
mixin _$ProviderModel {

 String get id; String get providerID; String get name; String? get family; String get status;@JsonKey(name: "release_date") String? get releaseDate;
/// Create a copy of ProviderModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProviderModelCopyWith<ProviderModel> get copyWith => _$ProviderModelCopyWithImpl<ProviderModel>(this as ProviderModel, _$identity);

  /// Serializes this ProviderModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProviderModel&&(identical(other.id, id) || other.id == id)&&(identical(other.providerID, providerID) || other.providerID == providerID)&&(identical(other.name, name) || other.name == name)&&(identical(other.family, family) || other.family == family)&&(identical(other.status, status) || other.status == status)&&(identical(other.releaseDate, releaseDate) || other.releaseDate == releaseDate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,providerID,name,family,status,releaseDate);

@override
String toString() {
  return 'ProviderModel(id: $id, providerID: $providerID, name: $name, family: $family, status: $status, releaseDate: $releaseDate)';
}


}

/// @nodoc
abstract mixin class $ProviderModelCopyWith<$Res>  {
  factory $ProviderModelCopyWith(ProviderModel value, $Res Function(ProviderModel) _then) = _$ProviderModelCopyWithImpl;
@useResult
$Res call({
 String id, String providerID, String name, String? family, String status,@JsonKey(name: "release_date") String? releaseDate
});




}
/// @nodoc
class _$ProviderModelCopyWithImpl<$Res>
    implements $ProviderModelCopyWith<$Res> {
  _$ProviderModelCopyWithImpl(this._self, this._then);

  final ProviderModel _self;
  final $Res Function(ProviderModel) _then;

/// Create a copy of ProviderModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? providerID = null,Object? name = null,Object? family = freezed,Object? status = null,Object? releaseDate = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,providerID: null == providerID ? _self.providerID : providerID // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,family: freezed == family ? _self.family : family // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,releaseDate: freezed == releaseDate ? _self.releaseDate : releaseDate // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _ProviderModel implements ProviderModel {
  const _ProviderModel({required this.id, required this.providerID, required this.name, this.family, this.status = "active", @JsonKey(name: "release_date") this.releaseDate});
  factory _ProviderModel.fromJson(Map<String, dynamic> json) => _$ProviderModelFromJson(json);

@override final  String id;
@override final  String providerID;
@override final  String name;
@override final  String? family;
@override@JsonKey() final  String status;
@override@JsonKey(name: "release_date") final  String? releaseDate;

/// Create a copy of ProviderModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProviderModelCopyWith<_ProviderModel> get copyWith => __$ProviderModelCopyWithImpl<_ProviderModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProviderModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProviderModel&&(identical(other.id, id) || other.id == id)&&(identical(other.providerID, providerID) || other.providerID == providerID)&&(identical(other.name, name) || other.name == name)&&(identical(other.family, family) || other.family == family)&&(identical(other.status, status) || other.status == status)&&(identical(other.releaseDate, releaseDate) || other.releaseDate == releaseDate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,providerID,name,family,status,releaseDate);

@override
String toString() {
  return 'ProviderModel(id: $id, providerID: $providerID, name: $name, family: $family, status: $status, releaseDate: $releaseDate)';
}


}

/// @nodoc
abstract mixin class _$ProviderModelCopyWith<$Res> implements $ProviderModelCopyWith<$Res> {
  factory _$ProviderModelCopyWith(_ProviderModel value, $Res Function(_ProviderModel) _then) = __$ProviderModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String providerID, String name, String? family, String status,@JsonKey(name: "release_date") String? releaseDate
});




}
/// @nodoc
class __$ProviderModelCopyWithImpl<$Res>
    implements _$ProviderModelCopyWith<$Res> {
  __$ProviderModelCopyWithImpl(this._self, this._then);

  final _ProviderModel _self;
  final $Res Function(_ProviderModel) _then;

/// Create a copy of ProviderModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? providerID = null,Object? name = null,Object? family = freezed,Object? status = null,Object? releaseDate = freezed,}) {
  return _then(_ProviderModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,providerID: null == providerID ? _self.providerID : providerID // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,family: freezed == family ? _self.family : family // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,releaseDate: freezed == releaseDate ? _self.releaseDate : releaseDate // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$ProviderListResponse {

 List<ProviderInfo> get all;@JsonKey(name: "default") Map<String, String> get defaults; List<String> get connected;
/// Create a copy of ProviderListResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProviderListResponseCopyWith<ProviderListResponse> get copyWith => _$ProviderListResponseCopyWithImpl<ProviderListResponse>(this as ProviderListResponse, _$identity);

  /// Serializes this ProviderListResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProviderListResponse&&const DeepCollectionEquality().equals(other.all, all)&&const DeepCollectionEquality().equals(other.defaults, defaults)&&const DeepCollectionEquality().equals(other.connected, connected));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(all),const DeepCollectionEquality().hash(defaults),const DeepCollectionEquality().hash(connected));

@override
String toString() {
  return 'ProviderListResponse(all: $all, defaults: $defaults, connected: $connected)';
}


}

/// @nodoc
abstract mixin class $ProviderListResponseCopyWith<$Res>  {
  factory $ProviderListResponseCopyWith(ProviderListResponse value, $Res Function(ProviderListResponse) _then) = _$ProviderListResponseCopyWithImpl;
@useResult
$Res call({
 List<ProviderInfo> all,@JsonKey(name: "default") Map<String, String> defaults, List<String> connected
});




}
/// @nodoc
class _$ProviderListResponseCopyWithImpl<$Res>
    implements $ProviderListResponseCopyWith<$Res> {
  _$ProviderListResponseCopyWithImpl(this._self, this._then);

  final ProviderListResponse _self;
  final $Res Function(ProviderListResponse) _then;

/// Create a copy of ProviderListResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? all = null,Object? defaults = null,Object? connected = null,}) {
  return _then(_self.copyWith(
all: null == all ? _self.all : all // ignore: cast_nullable_to_non_nullable
as List<ProviderInfo>,defaults: null == defaults ? _self.defaults : defaults // ignore: cast_nullable_to_non_nullable
as Map<String, String>,connected: null == connected ? _self.connected : connected // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _ProviderListResponse implements ProviderListResponse {
  const _ProviderListResponse({required final  List<ProviderInfo> all, @JsonKey(name: "default") required final  Map<String, String> defaults, required final  List<String> connected}): _all = all,_defaults = defaults,_connected = connected;
  factory _ProviderListResponse.fromJson(Map<String, dynamic> json) => _$ProviderListResponseFromJson(json);

 final  List<ProviderInfo> _all;
@override List<ProviderInfo> get all {
  if (_all is EqualUnmodifiableListView) return _all;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_all);
}

 final  Map<String, String> _defaults;
@override@JsonKey(name: "default") Map<String, String> get defaults {
  if (_defaults is EqualUnmodifiableMapView) return _defaults;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_defaults);
}

 final  List<String> _connected;
@override List<String> get connected {
  if (_connected is EqualUnmodifiableListView) return _connected;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_connected);
}


/// Create a copy of ProviderListResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProviderListResponseCopyWith<_ProviderListResponse> get copyWith => __$ProviderListResponseCopyWithImpl<_ProviderListResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProviderListResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProviderListResponse&&const DeepCollectionEquality().equals(other._all, _all)&&const DeepCollectionEquality().equals(other._defaults, _defaults)&&const DeepCollectionEquality().equals(other._connected, _connected));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_all),const DeepCollectionEquality().hash(_defaults),const DeepCollectionEquality().hash(_connected));

@override
String toString() {
  return 'ProviderListResponse(all: $all, defaults: $defaults, connected: $connected)';
}


}

/// @nodoc
abstract mixin class _$ProviderListResponseCopyWith<$Res> implements $ProviderListResponseCopyWith<$Res> {
  factory _$ProviderListResponseCopyWith(_ProviderListResponse value, $Res Function(_ProviderListResponse) _then) = __$ProviderListResponseCopyWithImpl;
@override @useResult
$Res call({
 List<ProviderInfo> all,@JsonKey(name: "default") Map<String, String> defaults, List<String> connected
});




}
/// @nodoc
class __$ProviderListResponseCopyWithImpl<$Res>
    implements _$ProviderListResponseCopyWith<$Res> {
  __$ProviderListResponseCopyWithImpl(this._self, this._then);

  final _ProviderListResponse _self;
  final $Res Function(_ProviderListResponse) _then;

/// Create a copy of ProviderListResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? all = null,Object? defaults = null,Object? connected = null,}) {
  return _then(_ProviderListResponse(
all: null == all ? _self._all : all // ignore: cast_nullable_to_non_nullable
as List<ProviderInfo>,defaults: null == defaults ? _self._defaults : defaults // ignore: cast_nullable_to_non_nullable
as Map<String, String>,connected: null == connected ? _self._connected : connected // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

// dart format on
