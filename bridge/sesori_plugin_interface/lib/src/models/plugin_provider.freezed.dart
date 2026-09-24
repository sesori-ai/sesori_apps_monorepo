// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plugin_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PluginModel {

 String get id; String get name;/// Effort/thinking variants in the order pickers list them.
 List<String> get variants;/// The variant a session runs at when none was chosen. Null means the
/// first of [variants], or nothing when the model offers none.
 String? get defaultVariant; String? get family; bool get isAvailable; DateTime? get releaseDate;/// The model's fast mode, or null when the model has none.
 PluginFastModeSupport? get fastMode;
/// Create a copy of PluginModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginModelCopyWith<PluginModel> get copyWith => _$PluginModelCopyWithImpl<PluginModel>(this as PluginModel, _$identity);

  /// Serializes this PluginModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PluginModel;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginModel&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&const DeepCollectionEquality().equals(other.variants, _this.variants)&&(identical(other.defaultVariant, _this.defaultVariant) || other.defaultVariant == _this.defaultVariant)&&(identical(other.family, _this.family) || other.family == _this.family)&&(identical(other.isAvailable, _this.isAvailable) || other.isAvailable == _this.isAvailable)&&(identical(other.releaseDate, _this.releaseDate) || other.releaseDate == _this.releaseDate)&&(identical(other.fastMode, _this.fastMode) || other.fastMode == _this.fastMode));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PluginModel;
  return Object.hash(runtimeType,_this.id,_this.name,const DeepCollectionEquality().hash(_this.variants),_this.defaultVariant,_this.family,_this.isAvailable,_this.releaseDate,_this.fastMode);
}

@override
String toString() {
  final _this = this as PluginModel;
  return 'PluginModel(id: ${_this.id}, name: ${_this.name}, variants: ${_this.variants}, defaultVariant: ${_this.defaultVariant}, family: ${_this.family}, isAvailable: ${_this.isAvailable}, releaseDate: ${_this.releaseDate}, fastMode: ${_this.fastMode})';
}


}

/// @nodoc
abstract mixin class $PluginModelCopyWith<$Res>  {
  factory $PluginModelCopyWith(PluginModel value, $Res Function(PluginModel) _then) = _$PluginModelCopyWithImpl;
@useResult
$Res call({
 String id, String name, List<String> variants, String? defaultVariant, String? family, bool isAvailable, DateTime? releaseDate, PluginFastModeSupport? fastMode
});


$PluginFastModeSupportCopyWith<$Res>? get fastMode;

}
/// @nodoc
class _$PluginModelCopyWithImpl<$Res>
    implements $PluginModelCopyWith<$Res> {
  _$PluginModelCopyWithImpl(this._self, this._then);

  final PluginModel _self;
  final $Res Function(PluginModel) _then;

/// Create a copy of PluginModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? variants = null,Object? defaultVariant = freezed,Object? family = freezed,Object? isAvailable = null,Object? releaseDate = freezed,Object? fastMode = freezed,}) {
  return _then(PluginModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,variants: null == variants ? _self.variants : variants // ignore: cast_nullable_to_non_nullable
as List<String>,defaultVariant: freezed == defaultVariant ? _self.defaultVariant : defaultVariant // ignore: cast_nullable_to_non_nullable
as String?,family: freezed == family ? _self.family : family // ignore: cast_nullable_to_non_nullable
as String?,isAvailable: null == isAvailable ? _self.isAvailable : isAvailable // ignore: cast_nullable_to_non_nullable
as bool,releaseDate: freezed == releaseDate ? _self.releaseDate : releaseDate // ignore: cast_nullable_to_non_nullable
as DateTime?,fastMode: freezed == fastMode ? _self.fastMode : fastMode // ignore: cast_nullable_to_non_nullable
as PluginFastModeSupport?,
  ));
}
/// Create a copy of PluginModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginFastModeSupportCopyWith<$Res>? get fastMode {
    if (_self.fastMode == null) {
    return null;
  }

  return $PluginFastModeSupportCopyWith<$Res>(_self.fastMode!, (value) {
    return _then(_self.copyWith(fastMode: value));
  });
}
}



/// @nodoc
@JsonSerializable(createFactory: false)

class _PluginModel implements PluginModel {
  const _PluginModel({required this.id, required this.name, required  List<String> variants, this.defaultVariant, this.family, this.isAvailable = true, this.releaseDate, required this.fastMode}): _variants = variants;
  

@override final  String id;
@override final  String name;
/// Effort/thinking variants in the order pickers list them.
 final  List<String> _variants;
/// Effort/thinking variants in the order pickers list them.
@override List<String> get variants {
  if (_variants is EqualUnmodifiableListView) return _variants;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_variants);
}

/// The variant a session runs at when none was chosen. Null means the
/// first of [variants], or nothing when the model offers none.
@override final  String? defaultVariant;
@override final  String? family;
@override@JsonKey() final  bool isAvailable;
@override final  DateTime? releaseDate;
/// The model's fast mode, or null when the model has none.
@override final  PluginFastModeSupport? fastMode;

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
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginModel&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other.variants, _variants)&&(identical(other.defaultVariant, defaultVariant) || other.defaultVariant == defaultVariant)&&(identical(other.family, family) || other.family == family)&&(identical(other.isAvailable, isAvailable) || other.isAvailable == isAvailable)&&(identical(other.releaseDate, releaseDate) || other.releaseDate == releaseDate)&&(identical(other.fastMode, fastMode) || other.fastMode == fastMode));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,name,const DeepCollectionEquality().hash(_variants),defaultVariant,family,isAvailable,releaseDate,fastMode);
}

@override
String toString() {
    return 'PluginModel(id: $id, name: $name, variants: $variants, defaultVariant: $defaultVariant, family: $family, isAvailable: $isAvailable, releaseDate: $releaseDate, fastMode: $fastMode)';
}


}

/// @nodoc
abstract mixin class _$PluginModelCopyWith<$Res> implements $PluginModelCopyWith<$Res> {
  factory _$PluginModelCopyWith(_PluginModel value, $Res Function(_PluginModel) _then) = __$PluginModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, List<String> variants, String? defaultVariant, String? family, bool isAvailable, DateTime? releaseDate, PluginFastModeSupport? fastMode
});


@override $PluginFastModeSupportCopyWith<$Res>? get fastMode;

}
/// @nodoc
class __$PluginModelCopyWithImpl<$Res>
    implements _$PluginModelCopyWith<$Res> {
  __$PluginModelCopyWithImpl(this._self, this._then);

  final _PluginModel _self;
  final $Res Function(_PluginModel) _then;

/// Create a copy of PluginModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? variants = null,Object? defaultVariant = freezed,Object? family = freezed,Object? isAvailable = null,Object? releaseDate = freezed,Object? fastMode = freezed,}) {
  return _then(_PluginModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,variants: null == variants ? _self._variants : variants // ignore: cast_nullable_to_non_nullable
as List<String>,defaultVariant: freezed == defaultVariant ? _self.defaultVariant : defaultVariant // ignore: cast_nullable_to_non_nullable
as String?,family: freezed == family ? _self.family : family // ignore: cast_nullable_to_non_nullable
as String?,isAvailable: null == isAvailable ? _self.isAvailable : isAvailable // ignore: cast_nullable_to_non_nullable
as bool,releaseDate: freezed == releaseDate ? _self.releaseDate : releaseDate // ignore: cast_nullable_to_non_nullable
as DateTime?,fastMode: freezed == fastMode ? _self.fastMode : fastMode // ignore: cast_nullable_to_non_nullable
as PluginFastModeSupport?,
  ));
}

/// Create a copy of PluginModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginFastModeSupportCopyWith<$Res>? get fastMode {
    if (_self.fastMode == null) {
    return null;
  }

  return $PluginFastModeSupportCopyWith<$Res>(_self.fastMode!, (value) {
    return _then(_self.copyWith(fastMode: value));
  });
}
}

/// @nodoc
mixin _$PluginFastModeSupport {



  /// Serializes this PluginFastModeSupport to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginFastModeSupport);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'PluginFastModeSupport()';
}


}

/// @nodoc
class $PluginFastModeSupportCopyWith<$Res>  {
$PluginFastModeSupportCopyWith(PluginFastModeSupport _, $Res Function(PluginFastModeSupport) __);
}



/// @nodoc
@JsonSerializable(createFactory: false)

class PluginFastModeAvailable implements PluginFastModeSupport {
  const PluginFastModeAvailable({required this.promptCacheTtlSeconds,  String? $type}): $type = $type ?? 'available';
  

 final  int promptCacheTtlSeconds;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of PluginFastModeSupport
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginFastModeAvailableCopyWith<PluginFastModeAvailable> get copyWith => _$PluginFastModeAvailableCopyWithImpl<PluginFastModeAvailable>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginFastModeAvailableToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginFastModeAvailable&&(identical(other.promptCacheTtlSeconds, promptCacheTtlSeconds) || other.promptCacheTtlSeconds == promptCacheTtlSeconds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,promptCacheTtlSeconds);
}

@override
String toString() {
    return 'PluginFastModeSupport.available(promptCacheTtlSeconds: $promptCacheTtlSeconds)';
}


}

/// @nodoc
abstract mixin class $PluginFastModeAvailableCopyWith<$Res> implements $PluginFastModeSupportCopyWith<$Res> {
  factory $PluginFastModeAvailableCopyWith(PluginFastModeAvailable value, $Res Function(PluginFastModeAvailable) _then) = _$PluginFastModeAvailableCopyWithImpl;
@useResult
$Res call({
 int promptCacheTtlSeconds
});




}
/// @nodoc
class _$PluginFastModeAvailableCopyWithImpl<$Res>
    implements $PluginFastModeAvailableCopyWith<$Res> {
  _$PluginFastModeAvailableCopyWithImpl(this._self, this._then);

  final PluginFastModeAvailable _self;
  final $Res Function(PluginFastModeAvailable) _then;

/// Create a copy of PluginFastModeSupport
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? promptCacheTtlSeconds = null,}) {
  return _then(PluginFastModeAvailable(
promptCacheTtlSeconds: null == promptCacheTtlSeconds ? _self.promptCacheTtlSeconds : promptCacheTtlSeconds // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
@JsonSerializable(createFactory: false)

class PluginFastModeUnavailable implements PluginFastModeSupport {
  const PluginFastModeUnavailable({required this.reason,  String? $type}): $type = $type ?? 'unavailable';
  

 final  PluginFastModeUnavailableReason reason;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of PluginFastModeSupport
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginFastModeUnavailableCopyWith<PluginFastModeUnavailable> get copyWith => _$PluginFastModeUnavailableCopyWithImpl<PluginFastModeUnavailable>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginFastModeUnavailableToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginFastModeUnavailable&&(identical(other.reason, reason) || other.reason == reason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,reason);
}

@override
String toString() {
    return 'PluginFastModeSupport.unavailable(reason: $reason)';
}


}

/// @nodoc
abstract mixin class $PluginFastModeUnavailableCopyWith<$Res> implements $PluginFastModeSupportCopyWith<$Res> {
  factory $PluginFastModeUnavailableCopyWith(PluginFastModeUnavailable value, $Res Function(PluginFastModeUnavailable) _then) = _$PluginFastModeUnavailableCopyWithImpl;
@useResult
$Res call({
 PluginFastModeUnavailableReason reason
});




}
/// @nodoc
class _$PluginFastModeUnavailableCopyWithImpl<$Res>
    implements $PluginFastModeUnavailableCopyWith<$Res> {
  _$PluginFastModeUnavailableCopyWithImpl(this._self, this._then);

  final PluginFastModeUnavailable _self;
  final $Res Function(PluginFastModeUnavailable) _then;

/// Create a copy of PluginFastModeSupport
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? reason = null,}) {
  return _then(PluginFastModeUnavailable(
reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as PluginFastModeUnavailableReason,
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
  final _this = this as PluginProvider;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginProvider&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.authType, _this.authType) || other.authType == _this.authType)&&const DeepCollectionEquality().equals(other.models, _this.models)&&(identical(other.defaultModelID, _this.defaultModelID) || other.defaultModelID == _this.defaultModelID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PluginProvider;
  return Object.hash(runtimeType,_this.id,_this.name,_this.authType,const DeepCollectionEquality().hash(_this.models),_this.defaultModelID);
}

@override
String toString() {
  final _this = this as PluginProvider;
  return 'PluginProvider(id: ${_this.id}, name: ${_this.name}, authType: ${_this.authType}, models: ${_this.models}, defaultModelID: ${_this.defaultModelID})';
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
  return _then(PluginProvider(
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

class _PluginProvider implements PluginProvider {
  const _PluginProvider({required this.id, required this.name, required this.authType, required  List<PluginModel> models, required this.defaultModelID}): _models = models;
  

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

/// Create a copy of PluginProvider
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginProviderCopyWith<_PluginProvider> get copyWith => __$PluginProviderCopyWithImpl<_PluginProvider>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginProviderToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginProvider&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.authType, authType) || other.authType == authType)&&const DeepCollectionEquality().equals(other.models, _models)&&(identical(other.defaultModelID, defaultModelID) || other.defaultModelID == defaultModelID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,name,authType,const DeepCollectionEquality().hash(_models),defaultModelID);
}

@override
String toString() {
    return 'PluginProvider(id: $id, name: $name, authType: $authType, models: $models, defaultModelID: $defaultModelID)';
}


}

/// @nodoc
abstract mixin class _$PluginProviderCopyWith<$Res> implements $PluginProviderCopyWith<$Res> {
  factory _$PluginProviderCopyWith(_PluginProvider value, $Res Function(_PluginProvider) _then) = __$PluginProviderCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, PluginProviderAuthType authType, List<PluginModel> models, String? defaultModelID
});




}
/// @nodoc
class __$PluginProviderCopyWithImpl<$Res>
    implements _$PluginProviderCopyWith<$Res> {
  __$PluginProviderCopyWithImpl(this._self, this._then);

  final _PluginProvider _self;
  final $Res Function(_PluginProvider) _then;

/// Create a copy of PluginProvider
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? authType = null,Object? models = null,Object? defaultModelID = freezed,}) {
  return _then(_PluginProvider(
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
  final _this = this as PluginProvidersResult;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginProvidersResult&&const DeepCollectionEquality().equals(other.providers, _this.providers));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PluginProvidersResult;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.providers));
}

@override
String toString() {
  final _this = this as PluginProvidersResult;
  return 'PluginProvidersResult(providers: ${_this.providers})';
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
  return _then(PluginProvidersResult(
providers: null == providers ? _self.providers : providers // ignore: cast_nullable_to_non_nullable
as List<PluginProvider>,
  ));
}

}



/// @nodoc
@JsonSerializable(createFactory: false)

class _PluginProvidersResult implements PluginProvidersResult {
  const _PluginProvidersResult({required  List<PluginProvider> providers}): _providers = providers;
  

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
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginProvidersResult&&const DeepCollectionEquality().equals(other.providers, _providers));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_providers));
}

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
