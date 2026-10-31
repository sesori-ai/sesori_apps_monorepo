// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'product_analytics_event_client.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ProductAnalyticsEventRequest {

 ProductAnalyticsEventSchemaVersion get schemaVersion; ProductAnalyticsEventPlatform get platform; String get appVersion; String get name; int get occurredAtMicros; Map<String, String> get params;
/// Create a copy of ProductAnalyticsEventRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProductAnalyticsEventRequestCopyWith<ProductAnalyticsEventRequest> get copyWith => _$ProductAnalyticsEventRequestCopyWithImpl<ProductAnalyticsEventRequest>(this as ProductAnalyticsEventRequest, _$identity);

  /// Serializes this ProductAnalyticsEventRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ProductAnalyticsEventRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProductAnalyticsEventRequest&&(identical(other.schemaVersion, _this.schemaVersion) || other.schemaVersion == _this.schemaVersion)&&(identical(other.platform, _this.platform) || other.platform == _this.platform)&&(identical(other.appVersion, _this.appVersion) || other.appVersion == _this.appVersion)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.occurredAtMicros, _this.occurredAtMicros) || other.occurredAtMicros == _this.occurredAtMicros)&&const DeepCollectionEquality().equals(other.params, _this.params));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ProductAnalyticsEventRequest;
  return Object.hash(runtimeType,_this.schemaVersion,_this.platform,_this.appVersion,_this.name,_this.occurredAtMicros,const DeepCollectionEquality().hash(_this.params));
}

@override
String toString() {
  final _this = this as ProductAnalyticsEventRequest;
  return 'ProductAnalyticsEventRequest(schemaVersion: ${_this.schemaVersion}, platform: ${_this.platform}, appVersion: ${_this.appVersion}, name: ${_this.name}, occurredAtMicros: ${_this.occurredAtMicros}, params: ${_this.params})';
}


}

/// @nodoc
abstract mixin class $ProductAnalyticsEventRequestCopyWith<$Res>  {
  factory $ProductAnalyticsEventRequestCopyWith(ProductAnalyticsEventRequest value, $Res Function(ProductAnalyticsEventRequest) _then) = _$ProductAnalyticsEventRequestCopyWithImpl;
@useResult
$Res call({
 ProductAnalyticsEventSchemaVersion schemaVersion, ProductAnalyticsEventPlatform platform, String appVersion, String name, int occurredAtMicros, Map<String, String> params
});




}
/// @nodoc
class _$ProductAnalyticsEventRequestCopyWithImpl<$Res>
    implements $ProductAnalyticsEventRequestCopyWith<$Res> {
  _$ProductAnalyticsEventRequestCopyWithImpl(this._self, this._then);

  final ProductAnalyticsEventRequest _self;
  final $Res Function(ProductAnalyticsEventRequest) _then;

/// Create a copy of ProductAnalyticsEventRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? schemaVersion = null,Object? platform = null,Object? appVersion = null,Object? name = null,Object? occurredAtMicros = null,Object? params = null,}) {
  return _then(ProductAnalyticsEventRequest(
schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as ProductAnalyticsEventSchemaVersion,platform: null == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as ProductAnalyticsEventPlatform,appVersion: null == appVersion ? _self.appVersion : appVersion // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,occurredAtMicros: null == occurredAtMicros ? _self.occurredAtMicros : occurredAtMicros // ignore: cast_nullable_to_non_nullable
as int,params: null == params ? _self.params : params // ignore: cast_nullable_to_non_nullable
as Map<String, String>,
  ));
}

}



/// @nodoc
@JsonSerializable(createFactory: false)

class _ProductAnalyticsEventRequest implements ProductAnalyticsEventRequest {
  const _ProductAnalyticsEventRequest({required this.schemaVersion, required this.platform, required this.appVersion, required this.name, required this.occurredAtMicros, required  Map<String, String> params}): _params = params;
  

@override final  ProductAnalyticsEventSchemaVersion schemaVersion;
@override final  ProductAnalyticsEventPlatform platform;
@override final  String appVersion;
@override final  String name;
@override final  int occurredAtMicros;
 final  Map<String, String> _params;
@override Map<String, String> get params {
  if (_params is EqualUnmodifiableMapView) return _params;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_params);
}


/// Create a copy of ProductAnalyticsEventRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProductAnalyticsEventRequestCopyWith<_ProductAnalyticsEventRequest> get copyWith => __$ProductAnalyticsEventRequestCopyWithImpl<_ProductAnalyticsEventRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProductAnalyticsEventRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProductAnalyticsEventRequest&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion)&&(identical(other.platform, platform) || other.platform == platform)&&(identical(other.appVersion, appVersion) || other.appVersion == appVersion)&&(identical(other.name, name) || other.name == name)&&(identical(other.occurredAtMicros, occurredAtMicros) || other.occurredAtMicros == occurredAtMicros)&&const DeepCollectionEquality().equals(other.params, _params));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,schemaVersion,platform,appVersion,name,occurredAtMicros,const DeepCollectionEquality().hash(_params));
}

@override
String toString() {
    return 'ProductAnalyticsEventRequest(schemaVersion: $schemaVersion, platform: $platform, appVersion: $appVersion, name: $name, occurredAtMicros: $occurredAtMicros, params: $params)';
}


}

/// @nodoc
abstract mixin class _$ProductAnalyticsEventRequestCopyWith<$Res> implements $ProductAnalyticsEventRequestCopyWith<$Res> {
  factory _$ProductAnalyticsEventRequestCopyWith(_ProductAnalyticsEventRequest value, $Res Function(_ProductAnalyticsEventRequest) _then) = __$ProductAnalyticsEventRequestCopyWithImpl;
@override @useResult
$Res call({
 ProductAnalyticsEventSchemaVersion schemaVersion, ProductAnalyticsEventPlatform platform, String appVersion, String name, int occurredAtMicros, Map<String, String> params
});




}
/// @nodoc
class __$ProductAnalyticsEventRequestCopyWithImpl<$Res>
    implements _$ProductAnalyticsEventRequestCopyWith<$Res> {
  __$ProductAnalyticsEventRequestCopyWithImpl(this._self, this._then);

  final _ProductAnalyticsEventRequest _self;
  final $Res Function(_ProductAnalyticsEventRequest) _then;

/// Create a copy of ProductAnalyticsEventRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? schemaVersion = null,Object? platform = null,Object? appVersion = null,Object? name = null,Object? occurredAtMicros = null,Object? params = null,}) {
  return _then(_ProductAnalyticsEventRequest(
schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as ProductAnalyticsEventSchemaVersion,platform: null == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as ProductAnalyticsEventPlatform,appVersion: null == appVersion ? _self.appVersion : appVersion // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,occurredAtMicros: null == occurredAtMicros ? _self.occurredAtMicros : occurredAtMicros // ignore: cast_nullable_to_non_nullable
as int,params: null == params ? _self._params : params // ignore: cast_nullable_to_non_nullable
as Map<String, String>,
  ));
}


}

/// @nodoc
mixin _$ProductAnalyticsEventClientResult {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ProductAnalyticsEventClientResult);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ProductAnalyticsEventClientResult()';
}


}

/// @nodoc
class $ProductAnalyticsEventClientResultCopyWith<$Res>  {
$ProductAnalyticsEventClientResultCopyWith(ProductAnalyticsEventClientResult _, $Res Function(ProductAnalyticsEventClientResult) __);
}



/// @nodoc


class ProductAnalyticsEventClientDelivered implements ProductAnalyticsEventClientResult {
  const ProductAnalyticsEventClientDelivered();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ProductAnalyticsEventClientDelivered);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ProductAnalyticsEventClientResult.delivered()';
}


}




/// @nodoc


class ProductAnalyticsEventClientPermanentFailure implements ProductAnalyticsEventClientResult {
  const ProductAnalyticsEventClientPermanentFailure({required this.description, required this.cause});
  

 final  String description;
 final  Object? cause;

/// Create a copy of ProductAnalyticsEventClientResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProductAnalyticsEventClientPermanentFailureCopyWith<ProductAnalyticsEventClientPermanentFailure> get copyWith => _$ProductAnalyticsEventClientPermanentFailureCopyWithImpl<ProductAnalyticsEventClientPermanentFailure>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ProductAnalyticsEventClientPermanentFailure&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other.cause, cause));
}


@override
int get hashCode {
    return Object.hash(runtimeType,description,const DeepCollectionEquality().hash(cause));
}

@override
String toString() {
    return 'ProductAnalyticsEventClientResult.permanentFailure(description: $description, cause: $cause)';
}


}

/// @nodoc
abstract mixin class $ProductAnalyticsEventClientPermanentFailureCopyWith<$Res> implements $ProductAnalyticsEventClientResultCopyWith<$Res> {
  factory $ProductAnalyticsEventClientPermanentFailureCopyWith(ProductAnalyticsEventClientPermanentFailure value, $Res Function(ProductAnalyticsEventClientPermanentFailure) _then) = _$ProductAnalyticsEventClientPermanentFailureCopyWithImpl;
@useResult
$Res call({
 String description, Object? cause
});




}
/// @nodoc
class _$ProductAnalyticsEventClientPermanentFailureCopyWithImpl<$Res>
    implements $ProductAnalyticsEventClientPermanentFailureCopyWith<$Res> {
  _$ProductAnalyticsEventClientPermanentFailureCopyWithImpl(this._self, this._then);

  final ProductAnalyticsEventClientPermanentFailure _self;
  final $Res Function(ProductAnalyticsEventClientPermanentFailure) _then;

/// Create a copy of ProductAnalyticsEventClientResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? description = null,Object? cause = freezed,}) {
  return _then(ProductAnalyticsEventClientPermanentFailure(
description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,cause: freezed == cause ? _self.cause : cause ,
  ));
}


}

/// @nodoc


class ProductAnalyticsEventClientTransientFailure implements ProductAnalyticsEventClientResult {
  const ProductAnalyticsEventClientTransientFailure({required this.description, required this.cause, required this.stackTrace});
  

 final  String description;
 final  Object? cause;
 final  StackTrace? stackTrace;

/// Create a copy of ProductAnalyticsEventClientResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProductAnalyticsEventClientTransientFailureCopyWith<ProductAnalyticsEventClientTransientFailure> get copyWith => _$ProductAnalyticsEventClientTransientFailureCopyWithImpl<ProductAnalyticsEventClientTransientFailure>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ProductAnalyticsEventClientTransientFailure&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other.cause, cause)&&(identical(other.stackTrace, stackTrace) || other.stackTrace == stackTrace));
}


@override
int get hashCode {
    return Object.hash(runtimeType,description,const DeepCollectionEquality().hash(cause),stackTrace);
}

@override
String toString() {
    return 'ProductAnalyticsEventClientResult.transientFailure(description: $description, cause: $cause, stackTrace: $stackTrace)';
}


}

/// @nodoc
abstract mixin class $ProductAnalyticsEventClientTransientFailureCopyWith<$Res> implements $ProductAnalyticsEventClientResultCopyWith<$Res> {
  factory $ProductAnalyticsEventClientTransientFailureCopyWith(ProductAnalyticsEventClientTransientFailure value, $Res Function(ProductAnalyticsEventClientTransientFailure) _then) = _$ProductAnalyticsEventClientTransientFailureCopyWithImpl;
@useResult
$Res call({
 String description, Object? cause, StackTrace? stackTrace
});




}
/// @nodoc
class _$ProductAnalyticsEventClientTransientFailureCopyWithImpl<$Res>
    implements $ProductAnalyticsEventClientTransientFailureCopyWith<$Res> {
  _$ProductAnalyticsEventClientTransientFailureCopyWithImpl(this._self, this._then);

  final ProductAnalyticsEventClientTransientFailure _self;
  final $Res Function(ProductAnalyticsEventClientTransientFailure) _then;

/// Create a copy of ProductAnalyticsEventClientResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? description = null,Object? cause = freezed,Object? stackTrace = freezed,}) {
  return _then(ProductAnalyticsEventClientTransientFailure(
description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,cause: freezed == cause ? _self.cause : cause ,stackTrace: freezed == stackTrace ? _self.stackTrace : stackTrace // ignore: cast_nullable_to_non_nullable
as StackTrace?,
  ));
}


}

// dart format on
