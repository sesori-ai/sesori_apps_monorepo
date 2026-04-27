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

 String get id; String get name; Map<String, ProviderModel> get models; String? get defaultModelID;
/// Create a copy of ProviderInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProviderInfoCopyWith<ProviderInfo> get copyWith => _$ProviderInfoCopyWithImpl<ProviderInfo>(this as ProviderInfo, _$identity);

  /// Serializes this ProviderInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProviderInfo&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other.models, models)&&(identical(other.defaultModelID, defaultModelID) || other.defaultModelID == defaultModelID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,const DeepCollectionEquality().hash(models),defaultModelID);

@override
String toString() {
  return 'ProviderInfo(id: $id, name: $name, models: $models, defaultModelID: $defaultModelID)';
}


}

/// @nodoc
abstract mixin class $ProviderInfoCopyWith<$Res>  {
  factory $ProviderInfoCopyWith(ProviderInfo value, $Res Function(ProviderInfo) _then) = _$ProviderInfoCopyWithImpl;
@useResult
$Res call({
 String id, String name, Map<String, ProviderModel> models, String? defaultModelID
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? models = null,Object? defaultModelID = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,models: null == models ? _self.models : models // ignore: cast_nullable_to_non_nullable
as Map<String, ProviderModel>,defaultModelID: freezed == defaultModelID ? _self.defaultModelID : defaultModelID // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _ProviderInfo implements ProviderInfo {
  const _ProviderInfo({required this.id, required this.name, required final  Map<String, ProviderModel> models, required this.defaultModelID}): _models = models;
  factory _ProviderInfo.fromJson(Map<String, dynamic> json) => _$ProviderInfoFromJson(json);

@override final  String id;
@override final  String name;
 final  Map<String, ProviderModel> _models;
@override Map<String, ProviderModel> get models {
  if (_models is EqualUnmodifiableMapView) return _models;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_models);
}

@override final  String? defaultModelID;

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProviderInfo&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other._models, _models)&&(identical(other.defaultModelID, defaultModelID) || other.defaultModelID == defaultModelID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,const DeepCollectionEquality().hash(_models),defaultModelID);

@override
String toString() {
  return 'ProviderInfo(id: $id, name: $name, models: $models, defaultModelID: $defaultModelID)';
}


}

/// @nodoc
abstract mixin class _$ProviderInfoCopyWith<$Res> implements $ProviderInfoCopyWith<$Res> {
  factory _$ProviderInfoCopyWith(_ProviderInfo value, $Res Function(_ProviderInfo) _then) = __$ProviderInfoCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, Map<String, ProviderModel> models, String? defaultModelID
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? models = null,Object? defaultModelID = freezed,}) {
  return _then(_ProviderInfo(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,models: null == models ? _self._models : models // ignore: cast_nullable_to_non_nullable
as Map<String, ProviderModel>,defaultModelID: freezed == defaultModelID ? _self.defaultModelID : defaultModelID // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$ProviderModel {

 String get id; String get providerID; String get name; String? get family; bool get isAvailable;@dateConverter DateTime? get releaseDate;
/// Create a copy of ProviderModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProviderModelCopyWith<ProviderModel> get copyWith => _$ProviderModelCopyWithImpl<ProviderModel>(this as ProviderModel, _$identity);

  /// Serializes this ProviderModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProviderModel&&(identical(other.id, id) || other.id == id)&&(identical(other.providerID, providerID) || other.providerID == providerID)&&(identical(other.name, name) || other.name == name)&&(identical(other.family, family) || other.family == family)&&(identical(other.isAvailable, isAvailable) || other.isAvailable == isAvailable)&&(identical(other.releaseDate, releaseDate) || other.releaseDate == releaseDate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,providerID,name,family,isAvailable,releaseDate);

@override
String toString() {
  return 'ProviderModel(id: $id, providerID: $providerID, name: $name, family: $family, isAvailable: $isAvailable, releaseDate: $releaseDate)';
}


}

/// @nodoc
abstract mixin class $ProviderModelCopyWith<$Res>  {
  factory $ProviderModelCopyWith(ProviderModel value, $Res Function(ProviderModel) _then) = _$ProviderModelCopyWithImpl;
@useResult
$Res call({
 String id, String providerID, String name, String? family, bool isAvailable,@dateConverter DateTime? releaseDate
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? providerID = null,Object? name = null,Object? family = freezed,Object? isAvailable = null,Object? releaseDate = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,providerID: null == providerID ? _self.providerID : providerID // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,family: freezed == family ? _self.family : family // ignore: cast_nullable_to_non_nullable
as String?,isAvailable: null == isAvailable ? _self.isAvailable : isAvailable // ignore: cast_nullable_to_non_nullable
as bool,releaseDate: freezed == releaseDate ? _self.releaseDate : releaseDate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _ProviderModel implements ProviderModel {
  const _ProviderModel({required this.id, required this.providerID, required this.name, required this.family, this.isAvailable = true, @dateConverter required this.releaseDate});
  factory _ProviderModel.fromJson(Map<String, dynamic> json) => _$ProviderModelFromJson(json);

@override final  String id;
@override final  String providerID;
@override final  String name;
@override final  String? family;
@override@JsonKey() final  bool isAvailable;
@override@dateConverter final  DateTime? releaseDate;

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProviderModel&&(identical(other.id, id) || other.id == id)&&(identical(other.providerID, providerID) || other.providerID == providerID)&&(identical(other.name, name) || other.name == name)&&(identical(other.family, family) || other.family == family)&&(identical(other.isAvailable, isAvailable) || other.isAvailable == isAvailable)&&(identical(other.releaseDate, releaseDate) || other.releaseDate == releaseDate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,providerID,name,family,isAvailable,releaseDate);

@override
String toString() {
  return 'ProviderModel(id: $id, providerID: $providerID, name: $name, family: $family, isAvailable: $isAvailable, releaseDate: $releaseDate)';
}


}

/// @nodoc
abstract mixin class _$ProviderModelCopyWith<$Res> implements $ProviderModelCopyWith<$Res> {
  factory _$ProviderModelCopyWith(_ProviderModel value, $Res Function(_ProviderModel) _then) = __$ProviderModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String providerID, String name, String? family, bool isAvailable,@dateConverter DateTime? releaseDate
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? providerID = null,Object? name = null,Object? family = freezed,Object? isAvailable = null,Object? releaseDate = freezed,}) {
  return _then(_ProviderModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,providerID: null == providerID ? _self.providerID : providerID // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,family: freezed == family ? _self.family : family // ignore: cast_nullable_to_non_nullable
as String?,isAvailable: null == isAvailable ? _self.isAvailable : isAvailable // ignore: cast_nullable_to_non_nullable
as bool,releaseDate: freezed == releaseDate ? _self.releaseDate : releaseDate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$ProviderListResponse {

 List<ProviderInfo> get items; bool get connectedOnly;
/// Create a copy of ProviderListResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProviderListResponseCopyWith<ProviderListResponse> get copyWith => _$ProviderListResponseCopyWithImpl<ProviderListResponse>(this as ProviderListResponse, _$identity);

  /// Serializes this ProviderListResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProviderListResponse&&const DeepCollectionEquality().equals(other.items, items)&&(identical(other.connectedOnly, connectedOnly) || other.connectedOnly == connectedOnly));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(items),connectedOnly);

@override
String toString() {
  return 'ProviderListResponse(items: $items, connectedOnly: $connectedOnly)';
}


}

/// @nodoc
abstract mixin class $ProviderListResponseCopyWith<$Res>  {
  factory $ProviderListResponseCopyWith(ProviderListResponse value, $Res Function(ProviderListResponse) _then) = _$ProviderListResponseCopyWithImpl;
@useResult
$Res call({
 List<ProviderInfo> items, bool connectedOnly
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
@pragma('vm:prefer-inline') @override $Res call({Object? items = null,Object? connectedOnly = null,}) {
  return _then(_self.copyWith(
items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<ProviderInfo>,connectedOnly: null == connectedOnly ? _self.connectedOnly : connectedOnly // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _ProviderListResponse implements ProviderListResponse {
  const _ProviderListResponse({required final  List<ProviderInfo> items, required this.connectedOnly}): _items = items;
  factory _ProviderListResponse.fromJson(Map<String, dynamic> json) => _$ProviderListResponseFromJson(json);

 final  List<ProviderInfo> _items;
@override List<ProviderInfo> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override final  bool connectedOnly;

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProviderListResponse&&const DeepCollectionEquality().equals(other._items, _items)&&(identical(other.connectedOnly, connectedOnly) || other.connectedOnly == connectedOnly));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_items),connectedOnly);

@override
String toString() {
  return 'ProviderListResponse(items: $items, connectedOnly: $connectedOnly)';
}


}

/// @nodoc
abstract mixin class _$ProviderListResponseCopyWith<$Res> implements $ProviderListResponseCopyWith<$Res> {
  factory _$ProviderListResponseCopyWith(_ProviderListResponse value, $Res Function(_ProviderListResponse) _then) = __$ProviderListResponseCopyWithImpl;
@override @useResult
$Res call({
 List<ProviderInfo> items, bool connectedOnly
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
@override @pragma('vm:prefer-inline') $Res call({Object? items = null,Object? connectedOnly = null,}) {
  return _then(_ProviderListResponse(
items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<ProviderInfo>,connectedOnly: null == connectedOnly ? _self.connectedOnly : connectedOnly // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
