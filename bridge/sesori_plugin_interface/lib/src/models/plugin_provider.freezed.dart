// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plugin_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PluginModel {

 String get id; String get name; String? get family; bool get isAvailable; DateTime? get releaseDate;
/// Create a copy of PluginModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginModelCopyWith<PluginModel> get copyWith => _$PluginModelCopyWithImpl<PluginModel>(this as PluginModel, _$identity);

  /// Serializes this PluginModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginModel&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.family, family) || other.family == family)&&(identical(other.isAvailable, isAvailable) || other.isAvailable == isAvailable)&&(identical(other.releaseDate, releaseDate) || other.releaseDate == releaseDate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,family,isAvailable,releaseDate);

@override
String toString() {
  return 'PluginModel(id: $id, name: $name, family: $family, isAvailable: $isAvailable, releaseDate: $releaseDate)';
}


}

/// @nodoc
abstract mixin class $PluginModelCopyWith<$Res>  {
  factory $PluginModelCopyWith(PluginModel value, $Res Function(PluginModel) _then) = _$PluginModelCopyWithImpl;
@useResult
$Res call({
 String id, String name, String? family, bool isAvailable, DateTime? releaseDate
});




}
/// @nodoc
class _$PluginModelCopyWithImpl<$Res>
    implements $PluginModelCopyWith<$Res> {
  _$PluginModelCopyWithImpl(this._self, this._then);

  final PluginModel _self;
  final $Res Function(PluginModel) _then;

/// Create a copy of PluginModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? family = freezed,Object? isAvailable = null,Object? releaseDate = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,family: freezed == family ? _self.family : family // ignore: cast_nullable_to_non_nullable
as String?,isAvailable: null == isAvailable ? _self.isAvailable : isAvailable // ignore: cast_nullable_to_non_nullable
as bool,releaseDate: freezed == releaseDate ? _self.releaseDate : releaseDate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}



/// @nodoc
@JsonSerializable(createFactory: false)

class _PluginModel implements PluginModel {
  const _PluginModel({required this.id, required this.name, this.family, this.isAvailable = true, this.releaseDate});
  

@override final  String id;
@override final  String name;
@override final  String? family;
@override@JsonKey() final  bool isAvailable;
@override final  DateTime? releaseDate;

/// Create a copy of PluginModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginModelCopyWith<_PluginModel> get copyWith => __$PluginModelCopyWithImpl<_PluginModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginModel&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.family, family) || other.family == family)&&(identical(other.isAvailable, isAvailable) || other.isAvailable == isAvailable)&&(identical(other.releaseDate, releaseDate) || other.releaseDate == releaseDate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,family,isAvailable,releaseDate);

@override
String toString() {
  return 'PluginModel(id: $id, name: $name, family: $family, isAvailable: $isAvailable, releaseDate: $releaseDate)';
}


}

/// @nodoc
abstract mixin class _$PluginModelCopyWith<$Res> implements $PluginModelCopyWith<$Res> {
  factory _$PluginModelCopyWith(_PluginModel value, $Res Function(_PluginModel) _then) = __$PluginModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String? family, bool isAvailable, DateTime? releaseDate
});




}
/// @nodoc
class __$PluginModelCopyWithImpl<$Res>
    implements _$PluginModelCopyWith<$Res> {
  __$PluginModelCopyWithImpl(this._self, this._then);

  final _PluginModel _self;
  final $Res Function(_PluginModel) _then;

/// Create a copy of PluginModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? family = freezed,Object? isAvailable = null,Object? releaseDate = freezed,}) {
  return _then(_PluginModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,family: freezed == family ? _self.family : family // ignore: cast_nullable_to_non_nullable
as String?,isAvailable: null == isAvailable ? _self.isAvailable : isAvailable // ignore: cast_nullable_to_non_nullable
as bool,releaseDate: freezed == releaseDate ? _self.releaseDate : releaseDate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc
mixin _$PluginProvider {

 String get id; String get name; PluginProviderAuthType get authType; List<PluginModel> get models; String? get defaultModelID;
/// Create a copy of PluginProvider
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginProviderCopyWith<PluginProvider> get copyWith => _$PluginProviderCopyWithImpl<PluginProvider>(this as PluginProvider, _$identity);

  /// Serializes this PluginProvider to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginProvider&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.authType, authType) || other.authType == authType)&&const DeepCollectionEquality().equals(other.models, models)&&(identical(other.defaultModelID, defaultModelID) || other.defaultModelID == defaultModelID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,authType,const DeepCollectionEquality().hash(models),defaultModelID);

@override
String toString() {
  return 'PluginProvider(id: $id, name: $name, authType: $authType, models: $models, defaultModelID: $defaultModelID)';
}


}

/// @nodoc
abstract mixin class $PluginProviderCopyWith<$Res>  {
  factory $PluginProviderCopyWith(PluginProvider value, $Res Function(PluginProvider) _then) = _$PluginProviderCopyWithImpl;
@useResult
$Res call({
 String id, String name, PluginProviderAuthType authType, List<PluginModel> models, String? defaultModelID
});




}
/// @nodoc
class _$PluginProviderCopyWithImpl<$Res>
    implements $PluginProviderCopyWith<$Res> {
  _$PluginProviderCopyWithImpl(this._self, this._then);

  final PluginProvider _self;
  final $Res Function(PluginProvider) _then;

/// Create a copy of PluginProvider
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? authType = null,Object? models = null,Object? defaultModelID = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,authType: null == authType ? _self.authType : authType // ignore: cast_nullable_to_non_nullable
as PluginProviderAuthType,models: null == models ? _self.models : models // ignore: cast_nullable_to_non_nullable
as List<PluginModel>,defaultModelID: freezed == defaultModelID ? _self.defaultModelID : defaultModelID // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable(createFactory: false)

class PluginProviderAnthropic implements PluginProvider {
  const PluginProviderAnthropic({required this.id, required this.name, required this.authType, required final  List<PluginModel> models, required this.defaultModelID, final  String? $type}): _models = models,$type = $type ?? 'anthropic';
  

@override final  String id;
@override final  String name;
@override final  PluginProviderAuthType authType;
 final  List<PluginModel> _models;
@override List<PluginModel> get models {
  if (_models is EqualUnmodifiableListView) return _models;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_models);
}

@override final  String? defaultModelID;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of PluginProvider
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginProviderAnthropicCopyWith<PluginProviderAnthropic> get copyWith => _$PluginProviderAnthropicCopyWithImpl<PluginProviderAnthropic>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginProviderAnthropicToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginProviderAnthropic&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.authType, authType) || other.authType == authType)&&const DeepCollectionEquality().equals(other._models, _models)&&(identical(other.defaultModelID, defaultModelID) || other.defaultModelID == defaultModelID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,authType,const DeepCollectionEquality().hash(_models),defaultModelID);

@override
String toString() {
  return 'PluginProvider.anthropic(id: $id, name: $name, authType: $authType, models: $models, defaultModelID: $defaultModelID)';
}


}

/// @nodoc
abstract mixin class $PluginProviderAnthropicCopyWith<$Res> implements $PluginProviderCopyWith<$Res> {
  factory $PluginProviderAnthropicCopyWith(PluginProviderAnthropic value, $Res Function(PluginProviderAnthropic) _then) = _$PluginProviderAnthropicCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, PluginProviderAuthType authType, List<PluginModel> models, String? defaultModelID
});




}
/// @nodoc
class _$PluginProviderAnthropicCopyWithImpl<$Res>
    implements $PluginProviderAnthropicCopyWith<$Res> {
  _$PluginProviderAnthropicCopyWithImpl(this._self, this._then);

  final PluginProviderAnthropic _self;
  final $Res Function(PluginProviderAnthropic) _then;

/// Create a copy of PluginProvider
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? authType = null,Object? models = null,Object? defaultModelID = freezed,}) {
  return _then(PluginProviderAnthropic(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,authType: null == authType ? _self.authType : authType // ignore: cast_nullable_to_non_nullable
as PluginProviderAuthType,models: null == models ? _self._models : models // ignore: cast_nullable_to_non_nullable
as List<PluginModel>,defaultModelID: freezed == defaultModelID ? _self.defaultModelID : defaultModelID // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable(createFactory: false)

class PluginProviderOpenAI implements PluginProvider {
  const PluginProviderOpenAI({required this.id, required this.name, required this.authType, required final  List<PluginModel> models, required this.defaultModelID, final  String? $type}): _models = models,$type = $type ?? 'openAI';
  

@override final  String id;
@override final  String name;
@override final  PluginProviderAuthType authType;
 final  List<PluginModel> _models;
@override List<PluginModel> get models {
  if (_models is EqualUnmodifiableListView) return _models;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_models);
}

@override final  String? defaultModelID;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of PluginProvider
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginProviderOpenAICopyWith<PluginProviderOpenAI> get copyWith => _$PluginProviderOpenAICopyWithImpl<PluginProviderOpenAI>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginProviderOpenAIToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginProviderOpenAI&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.authType, authType) || other.authType == authType)&&const DeepCollectionEquality().equals(other._models, _models)&&(identical(other.defaultModelID, defaultModelID) || other.defaultModelID == defaultModelID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,authType,const DeepCollectionEquality().hash(_models),defaultModelID);

@override
String toString() {
  return 'PluginProvider.openAI(id: $id, name: $name, authType: $authType, models: $models, defaultModelID: $defaultModelID)';
}


}

/// @nodoc
abstract mixin class $PluginProviderOpenAICopyWith<$Res> implements $PluginProviderCopyWith<$Res> {
  factory $PluginProviderOpenAICopyWith(PluginProviderOpenAI value, $Res Function(PluginProviderOpenAI) _then) = _$PluginProviderOpenAICopyWithImpl;
@override @useResult
$Res call({
 String id, String name, PluginProviderAuthType authType, List<PluginModel> models, String? defaultModelID
});




}
/// @nodoc
class _$PluginProviderOpenAICopyWithImpl<$Res>
    implements $PluginProviderOpenAICopyWith<$Res> {
  _$PluginProviderOpenAICopyWithImpl(this._self, this._then);

  final PluginProviderOpenAI _self;
  final $Res Function(PluginProviderOpenAI) _then;

/// Create a copy of PluginProvider
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? authType = null,Object? models = null,Object? defaultModelID = freezed,}) {
  return _then(PluginProviderOpenAI(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,authType: null == authType ? _self.authType : authType // ignore: cast_nullable_to_non_nullable
as PluginProviderAuthType,models: null == models ? _self._models : models // ignore: cast_nullable_to_non_nullable
as List<PluginModel>,defaultModelID: freezed == defaultModelID ? _self.defaultModelID : defaultModelID // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable(createFactory: false)

class PluginProviderGoogle implements PluginProvider {
  const PluginProviderGoogle({required this.id, required this.name, required this.authType, required final  List<PluginModel> models, required this.defaultModelID, final  String? $type}): _models = models,$type = $type ?? 'google';
  

@override final  String id;
@override final  String name;
@override final  PluginProviderAuthType authType;
 final  List<PluginModel> _models;
@override List<PluginModel> get models {
  if (_models is EqualUnmodifiableListView) return _models;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_models);
}

@override final  String? defaultModelID;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of PluginProvider
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginProviderGoogleCopyWith<PluginProviderGoogle> get copyWith => _$PluginProviderGoogleCopyWithImpl<PluginProviderGoogle>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginProviderGoogleToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginProviderGoogle&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.authType, authType) || other.authType == authType)&&const DeepCollectionEquality().equals(other._models, _models)&&(identical(other.defaultModelID, defaultModelID) || other.defaultModelID == defaultModelID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,authType,const DeepCollectionEquality().hash(_models),defaultModelID);

@override
String toString() {
  return 'PluginProvider.google(id: $id, name: $name, authType: $authType, models: $models, defaultModelID: $defaultModelID)';
}


}

/// @nodoc
abstract mixin class $PluginProviderGoogleCopyWith<$Res> implements $PluginProviderCopyWith<$Res> {
  factory $PluginProviderGoogleCopyWith(PluginProviderGoogle value, $Res Function(PluginProviderGoogle) _then) = _$PluginProviderGoogleCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, PluginProviderAuthType authType, List<PluginModel> models, String? defaultModelID
});




}
/// @nodoc
class _$PluginProviderGoogleCopyWithImpl<$Res>
    implements $PluginProviderGoogleCopyWith<$Res> {
  _$PluginProviderGoogleCopyWithImpl(this._self, this._then);

  final PluginProviderGoogle _self;
  final $Res Function(PluginProviderGoogle) _then;

/// Create a copy of PluginProvider
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? authType = null,Object? models = null,Object? defaultModelID = freezed,}) {
  return _then(PluginProviderGoogle(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,authType: null == authType ? _self.authType : authType // ignore: cast_nullable_to_non_nullable
as PluginProviderAuthType,models: null == models ? _self._models : models // ignore: cast_nullable_to_non_nullable
as List<PluginModel>,defaultModelID: freezed == defaultModelID ? _self.defaultModelID : defaultModelID // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable(createFactory: false)

class PluginProviderMistral implements PluginProvider {
  const PluginProviderMistral({required this.id, required this.name, required this.authType, required final  List<PluginModel> models, required this.defaultModelID, final  String? $type}): _models = models,$type = $type ?? 'mistral';
  

@override final  String id;
@override final  String name;
@override final  PluginProviderAuthType authType;
 final  List<PluginModel> _models;
@override List<PluginModel> get models {
  if (_models is EqualUnmodifiableListView) return _models;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_models);
}

@override final  String? defaultModelID;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of PluginProvider
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginProviderMistralCopyWith<PluginProviderMistral> get copyWith => _$PluginProviderMistralCopyWithImpl<PluginProviderMistral>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginProviderMistralToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginProviderMistral&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.authType, authType) || other.authType == authType)&&const DeepCollectionEquality().equals(other._models, _models)&&(identical(other.defaultModelID, defaultModelID) || other.defaultModelID == defaultModelID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,authType,const DeepCollectionEquality().hash(_models),defaultModelID);

@override
String toString() {
  return 'PluginProvider.mistral(id: $id, name: $name, authType: $authType, models: $models, defaultModelID: $defaultModelID)';
}


}

/// @nodoc
abstract mixin class $PluginProviderMistralCopyWith<$Res> implements $PluginProviderCopyWith<$Res> {
  factory $PluginProviderMistralCopyWith(PluginProviderMistral value, $Res Function(PluginProviderMistral) _then) = _$PluginProviderMistralCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, PluginProviderAuthType authType, List<PluginModel> models, String? defaultModelID
});




}
/// @nodoc
class _$PluginProviderMistralCopyWithImpl<$Res>
    implements $PluginProviderMistralCopyWith<$Res> {
  _$PluginProviderMistralCopyWithImpl(this._self, this._then);

  final PluginProviderMistral _self;
  final $Res Function(PluginProviderMistral) _then;

/// Create a copy of PluginProvider
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? authType = null,Object? models = null,Object? defaultModelID = freezed,}) {
  return _then(PluginProviderMistral(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,authType: null == authType ? _self.authType : authType // ignore: cast_nullable_to_non_nullable
as PluginProviderAuthType,models: null == models ? _self._models : models // ignore: cast_nullable_to_non_nullable
as List<PluginModel>,defaultModelID: freezed == defaultModelID ? _self.defaultModelID : defaultModelID // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable(createFactory: false)

class PluginProviderGroq implements PluginProvider {
  const PluginProviderGroq({required this.id, required this.name, required this.authType, required final  List<PluginModel> models, required this.defaultModelID, final  String? $type}): _models = models,$type = $type ?? 'groq';
  

@override final  String id;
@override final  String name;
@override final  PluginProviderAuthType authType;
 final  List<PluginModel> _models;
@override List<PluginModel> get models {
  if (_models is EqualUnmodifiableListView) return _models;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_models);
}

@override final  String? defaultModelID;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of PluginProvider
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginProviderGroqCopyWith<PluginProviderGroq> get copyWith => _$PluginProviderGroqCopyWithImpl<PluginProviderGroq>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginProviderGroqToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginProviderGroq&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.authType, authType) || other.authType == authType)&&const DeepCollectionEquality().equals(other._models, _models)&&(identical(other.defaultModelID, defaultModelID) || other.defaultModelID == defaultModelID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,authType,const DeepCollectionEquality().hash(_models),defaultModelID);

@override
String toString() {
  return 'PluginProvider.groq(id: $id, name: $name, authType: $authType, models: $models, defaultModelID: $defaultModelID)';
}


}

/// @nodoc
abstract mixin class $PluginProviderGroqCopyWith<$Res> implements $PluginProviderCopyWith<$Res> {
  factory $PluginProviderGroqCopyWith(PluginProviderGroq value, $Res Function(PluginProviderGroq) _then) = _$PluginProviderGroqCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, PluginProviderAuthType authType, List<PluginModel> models, String? defaultModelID
});




}
/// @nodoc
class _$PluginProviderGroqCopyWithImpl<$Res>
    implements $PluginProviderGroqCopyWith<$Res> {
  _$PluginProviderGroqCopyWithImpl(this._self, this._then);

  final PluginProviderGroq _self;
  final $Res Function(PluginProviderGroq) _then;

/// Create a copy of PluginProvider
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? authType = null,Object? models = null,Object? defaultModelID = freezed,}) {
  return _then(PluginProviderGroq(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,authType: null == authType ? _self.authType : authType // ignore: cast_nullable_to_non_nullable
as PluginProviderAuthType,models: null == models ? _self._models : models // ignore: cast_nullable_to_non_nullable
as List<PluginModel>,defaultModelID: freezed == defaultModelID ? _self.defaultModelID : defaultModelID // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable(createFactory: false)

class PluginProviderXAI implements PluginProvider {
  const PluginProviderXAI({required this.id, required this.name, required this.authType, required final  List<PluginModel> models, required this.defaultModelID, final  String? $type}): _models = models,$type = $type ?? 'xAI';
  

@override final  String id;
@override final  String name;
@override final  PluginProviderAuthType authType;
 final  List<PluginModel> _models;
@override List<PluginModel> get models {
  if (_models is EqualUnmodifiableListView) return _models;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_models);
}

@override final  String? defaultModelID;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of PluginProvider
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginProviderXAICopyWith<PluginProviderXAI> get copyWith => _$PluginProviderXAICopyWithImpl<PluginProviderXAI>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginProviderXAIToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginProviderXAI&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.authType, authType) || other.authType == authType)&&const DeepCollectionEquality().equals(other._models, _models)&&(identical(other.defaultModelID, defaultModelID) || other.defaultModelID == defaultModelID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,authType,const DeepCollectionEquality().hash(_models),defaultModelID);

@override
String toString() {
  return 'PluginProvider.xAI(id: $id, name: $name, authType: $authType, models: $models, defaultModelID: $defaultModelID)';
}


}

/// @nodoc
abstract mixin class $PluginProviderXAICopyWith<$Res> implements $PluginProviderCopyWith<$Res> {
  factory $PluginProviderXAICopyWith(PluginProviderXAI value, $Res Function(PluginProviderXAI) _then) = _$PluginProviderXAICopyWithImpl;
@override @useResult
$Res call({
 String id, String name, PluginProviderAuthType authType, List<PluginModel> models, String? defaultModelID
});




}
/// @nodoc
class _$PluginProviderXAICopyWithImpl<$Res>
    implements $PluginProviderXAICopyWith<$Res> {
  _$PluginProviderXAICopyWithImpl(this._self, this._then);

  final PluginProviderXAI _self;
  final $Res Function(PluginProviderXAI) _then;

/// Create a copy of PluginProvider
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? authType = null,Object? models = null,Object? defaultModelID = freezed,}) {
  return _then(PluginProviderXAI(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,authType: null == authType ? _self.authType : authType // ignore: cast_nullable_to_non_nullable
as PluginProviderAuthType,models: null == models ? _self._models : models // ignore: cast_nullable_to_non_nullable
as List<PluginModel>,defaultModelID: freezed == defaultModelID ? _self.defaultModelID : defaultModelID // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable(createFactory: false)

class PluginProviderDeepseek implements PluginProvider {
  const PluginProviderDeepseek({required this.id, required this.name, required this.authType, required final  List<PluginModel> models, required this.defaultModelID, final  String? $type}): _models = models,$type = $type ?? 'deepseek';
  

@override final  String id;
@override final  String name;
@override final  PluginProviderAuthType authType;
 final  List<PluginModel> _models;
@override List<PluginModel> get models {
  if (_models is EqualUnmodifiableListView) return _models;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_models);
}

@override final  String? defaultModelID;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of PluginProvider
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginProviderDeepseekCopyWith<PluginProviderDeepseek> get copyWith => _$PluginProviderDeepseekCopyWithImpl<PluginProviderDeepseek>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginProviderDeepseekToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginProviderDeepseek&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.authType, authType) || other.authType == authType)&&const DeepCollectionEquality().equals(other._models, _models)&&(identical(other.defaultModelID, defaultModelID) || other.defaultModelID == defaultModelID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,authType,const DeepCollectionEquality().hash(_models),defaultModelID);

@override
String toString() {
  return 'PluginProvider.deepseek(id: $id, name: $name, authType: $authType, models: $models, defaultModelID: $defaultModelID)';
}


}

/// @nodoc
abstract mixin class $PluginProviderDeepseekCopyWith<$Res> implements $PluginProviderCopyWith<$Res> {
  factory $PluginProviderDeepseekCopyWith(PluginProviderDeepseek value, $Res Function(PluginProviderDeepseek) _then) = _$PluginProviderDeepseekCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, PluginProviderAuthType authType, List<PluginModel> models, String? defaultModelID
});




}
/// @nodoc
class _$PluginProviderDeepseekCopyWithImpl<$Res>
    implements $PluginProviderDeepseekCopyWith<$Res> {
  _$PluginProviderDeepseekCopyWithImpl(this._self, this._then);

  final PluginProviderDeepseek _self;
  final $Res Function(PluginProviderDeepseek) _then;

/// Create a copy of PluginProvider
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? authType = null,Object? models = null,Object? defaultModelID = freezed,}) {
  return _then(PluginProviderDeepseek(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,authType: null == authType ? _self.authType : authType // ignore: cast_nullable_to_non_nullable
as PluginProviderAuthType,models: null == models ? _self._models : models // ignore: cast_nullable_to_non_nullable
as List<PluginModel>,defaultModelID: freezed == defaultModelID ? _self.defaultModelID : defaultModelID // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable(createFactory: false)

class PluginProviderAmazonBedrock implements PluginProvider {
  const PluginProviderAmazonBedrock({required this.id, required this.name, required this.authType, required final  List<PluginModel> models, required this.defaultModelID, final  String? $type}): _models = models,$type = $type ?? 'amazonBedrock';
  

@override final  String id;
@override final  String name;
@override final  PluginProviderAuthType authType;
 final  List<PluginModel> _models;
@override List<PluginModel> get models {
  if (_models is EqualUnmodifiableListView) return _models;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_models);
}

@override final  String? defaultModelID;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of PluginProvider
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginProviderAmazonBedrockCopyWith<PluginProviderAmazonBedrock> get copyWith => _$PluginProviderAmazonBedrockCopyWithImpl<PluginProviderAmazonBedrock>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginProviderAmazonBedrockToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginProviderAmazonBedrock&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.authType, authType) || other.authType == authType)&&const DeepCollectionEquality().equals(other._models, _models)&&(identical(other.defaultModelID, defaultModelID) || other.defaultModelID == defaultModelID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,authType,const DeepCollectionEquality().hash(_models),defaultModelID);

@override
String toString() {
  return 'PluginProvider.amazonBedrock(id: $id, name: $name, authType: $authType, models: $models, defaultModelID: $defaultModelID)';
}


}

/// @nodoc
abstract mixin class $PluginProviderAmazonBedrockCopyWith<$Res> implements $PluginProviderCopyWith<$Res> {
  factory $PluginProviderAmazonBedrockCopyWith(PluginProviderAmazonBedrock value, $Res Function(PluginProviderAmazonBedrock) _then) = _$PluginProviderAmazonBedrockCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, PluginProviderAuthType authType, List<PluginModel> models, String? defaultModelID
});




}
/// @nodoc
class _$PluginProviderAmazonBedrockCopyWithImpl<$Res>
    implements $PluginProviderAmazonBedrockCopyWith<$Res> {
  _$PluginProviderAmazonBedrockCopyWithImpl(this._self, this._then);

  final PluginProviderAmazonBedrock _self;
  final $Res Function(PluginProviderAmazonBedrock) _then;

/// Create a copy of PluginProvider
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? authType = null,Object? models = null,Object? defaultModelID = freezed,}) {
  return _then(PluginProviderAmazonBedrock(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,authType: null == authType ? _self.authType : authType // ignore: cast_nullable_to_non_nullable
as PluginProviderAuthType,models: null == models ? _self._models : models // ignore: cast_nullable_to_non_nullable
as List<PluginModel>,defaultModelID: freezed == defaultModelID ? _self.defaultModelID : defaultModelID // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable(createFactory: false)

class PluginProviderAzure implements PluginProvider {
  const PluginProviderAzure({required this.id, required this.name, required this.authType, required final  List<PluginModel> models, required this.defaultModelID, final  String? $type}): _models = models,$type = $type ?? 'azure';
  

@override final  String id;
@override final  String name;
@override final  PluginProviderAuthType authType;
 final  List<PluginModel> _models;
@override List<PluginModel> get models {
  if (_models is EqualUnmodifiableListView) return _models;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_models);
}

@override final  String? defaultModelID;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of PluginProvider
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginProviderAzureCopyWith<PluginProviderAzure> get copyWith => _$PluginProviderAzureCopyWithImpl<PluginProviderAzure>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginProviderAzureToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginProviderAzure&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.authType, authType) || other.authType == authType)&&const DeepCollectionEquality().equals(other._models, _models)&&(identical(other.defaultModelID, defaultModelID) || other.defaultModelID == defaultModelID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,authType,const DeepCollectionEquality().hash(_models),defaultModelID);

@override
String toString() {
  return 'PluginProvider.azure(id: $id, name: $name, authType: $authType, models: $models, defaultModelID: $defaultModelID)';
}


}

/// @nodoc
abstract mixin class $PluginProviderAzureCopyWith<$Res> implements $PluginProviderCopyWith<$Res> {
  factory $PluginProviderAzureCopyWith(PluginProviderAzure value, $Res Function(PluginProviderAzure) _then) = _$PluginProviderAzureCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, PluginProviderAuthType authType, List<PluginModel> models, String? defaultModelID
});




}
/// @nodoc
class _$PluginProviderAzureCopyWithImpl<$Res>
    implements $PluginProviderAzureCopyWith<$Res> {
  _$PluginProviderAzureCopyWithImpl(this._self, this._then);

  final PluginProviderAzure _self;
  final $Res Function(PluginProviderAzure) _then;

/// Create a copy of PluginProvider
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? authType = null,Object? models = null,Object? defaultModelID = freezed,}) {
  return _then(PluginProviderAzure(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,authType: null == authType ? _self.authType : authType // ignore: cast_nullable_to_non_nullable
as PluginProviderAuthType,models: null == models ? _self._models : models // ignore: cast_nullable_to_non_nullable
as List<PluginModel>,defaultModelID: freezed == defaultModelID ? _self.defaultModelID : defaultModelID // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable(createFactory: false)

class PluginProviderCustom implements PluginProvider {
  const PluginProviderCustom({required this.id, required this.name, required this.authType, required final  List<PluginModel> models, required this.defaultModelID, final  String? $type}): _models = models,$type = $type ?? 'custom';
  

@override final  String id;
@override final  String name;
@override final  PluginProviderAuthType authType;
 final  List<PluginModel> _models;
@override List<PluginModel> get models {
  if (_models is EqualUnmodifiableListView) return _models;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_models);
}

@override final  String? defaultModelID;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of PluginProvider
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginProviderCustomCopyWith<PluginProviderCustom> get copyWith => _$PluginProviderCustomCopyWithImpl<PluginProviderCustom>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginProviderCustomToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginProviderCustom&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.authType, authType) || other.authType == authType)&&const DeepCollectionEquality().equals(other._models, _models)&&(identical(other.defaultModelID, defaultModelID) || other.defaultModelID == defaultModelID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,authType,const DeepCollectionEquality().hash(_models),defaultModelID);

@override
String toString() {
  return 'PluginProvider.custom(id: $id, name: $name, authType: $authType, models: $models, defaultModelID: $defaultModelID)';
}


}

/// @nodoc
abstract mixin class $PluginProviderCustomCopyWith<$Res> implements $PluginProviderCopyWith<$Res> {
  factory $PluginProviderCustomCopyWith(PluginProviderCustom value, $Res Function(PluginProviderCustom) _then) = _$PluginProviderCustomCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, PluginProviderAuthType authType, List<PluginModel> models, String? defaultModelID
});




}
/// @nodoc
class _$PluginProviderCustomCopyWithImpl<$Res>
    implements $PluginProviderCustomCopyWith<$Res> {
  _$PluginProviderCustomCopyWithImpl(this._self, this._then);

  final PluginProviderCustom _self;
  final $Res Function(PluginProviderCustom) _then;

/// Create a copy of PluginProvider
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? authType = null,Object? models = null,Object? defaultModelID = freezed,}) {
  return _then(PluginProviderCustom(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,authType: null == authType ? _self.authType : authType // ignore: cast_nullable_to_non_nullable
as PluginProviderAuthType,models: null == models ? _self._models : models // ignore: cast_nullable_to_non_nullable
as List<PluginModel>,defaultModelID: freezed == defaultModelID ? _self.defaultModelID : defaultModelID // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$PluginProvidersResult {

 List<PluginProvider> get providers;
/// Create a copy of PluginProvidersResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginProvidersResultCopyWith<PluginProvidersResult> get copyWith => _$PluginProvidersResultCopyWithImpl<PluginProvidersResult>(this as PluginProvidersResult, _$identity);

  /// Serializes this PluginProvidersResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginProvidersResult&&const DeepCollectionEquality().equals(other.providers, providers));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(providers));

@override
String toString() {
  return 'PluginProvidersResult(providers: $providers)';
}


}

/// @nodoc
abstract mixin class $PluginProvidersResultCopyWith<$Res>  {
  factory $PluginProvidersResultCopyWith(PluginProvidersResult value, $Res Function(PluginProvidersResult) _then) = _$PluginProvidersResultCopyWithImpl;
@useResult
$Res call({
 List<PluginProvider> providers
});




}
/// @nodoc
class _$PluginProvidersResultCopyWithImpl<$Res>
    implements $PluginProvidersResultCopyWith<$Res> {
  _$PluginProvidersResultCopyWithImpl(this._self, this._then);

  final PluginProvidersResult _self;
  final $Res Function(PluginProvidersResult) _then;

/// Create a copy of PluginProvidersResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? providers = null,}) {
  return _then(_self.copyWith(
providers: null == providers ? _self.providers : providers // ignore: cast_nullable_to_non_nullable
as List<PluginProvider>,
  ));
}

}



/// @nodoc
@JsonSerializable(createFactory: false)

class _PluginProvidersResult implements PluginProvidersResult {
  const _PluginProvidersResult({required final  List<PluginProvider> providers}): _providers = providers;
  

 final  List<PluginProvider> _providers;
@override List<PluginProvider> get providers {
  if (_providers is EqualUnmodifiableListView) return _providers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_providers);
}


/// Create a copy of PluginProvidersResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginProvidersResultCopyWith<_PluginProvidersResult> get copyWith => __$PluginProvidersResultCopyWithImpl<_PluginProvidersResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginProvidersResultToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginProvidersResult&&const DeepCollectionEquality().equals(other._providers, _providers));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_providers));

@override
String toString() {
  return 'PluginProvidersResult(providers: $providers)';
}


}

/// @nodoc
abstract mixin class _$PluginProvidersResultCopyWith<$Res> implements $PluginProvidersResultCopyWith<$Res> {
  factory _$PluginProvidersResultCopyWith(_PluginProvidersResult value, $Res Function(_PluginProvidersResult) _then) = __$PluginProvidersResultCopyWithImpl;
@override @useResult
$Res call({
 List<PluginProvider> providers
});




}
/// @nodoc
class __$PluginProvidersResultCopyWithImpl<$Res>
    implements _$PluginProvidersResultCopyWith<$Res> {
  __$PluginProvidersResultCopyWithImpl(this._self, this._then);

  final _PluginProvidersResult _self;
  final $Res Function(_PluginProvidersResult) _then;

/// Create a copy of PluginProvidersResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? providers = null,}) {
  return _then(_PluginProvidersResult(
providers: null == providers ? _self._providers : providers // ignore: cast_nullable_to_non_nullable
as List<PluginProvider>,
  ));
}


}

// dart format on
