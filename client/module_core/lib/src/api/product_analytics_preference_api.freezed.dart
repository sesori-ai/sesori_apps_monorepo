// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'product_analytics_preference_api.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ProductAnalyticsPreferenceApiRecord {

 ProductAnalyticsPreference get preference; int get revision; String get userKey;
/// Create a copy of ProductAnalyticsPreferenceApiRecord
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProductAnalyticsPreferenceApiRecordCopyWith<ProductAnalyticsPreferenceApiRecord> get copyWith => _$ProductAnalyticsPreferenceApiRecordCopyWithImpl<ProductAnalyticsPreferenceApiRecord>(this as ProductAnalyticsPreferenceApiRecord, _$identity);

  /// Serializes this ProductAnalyticsPreferenceApiRecord to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProductAnalyticsPreferenceApiRecord&&(identical(other.preference, preference) || other.preference == preference)&&(identical(other.revision, revision) || other.revision == revision)&&(identical(other.userKey, userKey) || other.userKey == userKey));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,preference,revision,userKey);

@override
String toString() {
  return 'ProductAnalyticsPreferenceApiRecord(preference: $preference, revision: $revision, userKey: $userKey)';
}


}

/// @nodoc
abstract mixin class $ProductAnalyticsPreferenceApiRecordCopyWith<$Res>  {
  factory $ProductAnalyticsPreferenceApiRecordCopyWith(ProductAnalyticsPreferenceApiRecord value, $Res Function(ProductAnalyticsPreferenceApiRecord) _then) = _$ProductAnalyticsPreferenceApiRecordCopyWithImpl;
@useResult
$Res call({
 ProductAnalyticsPreference preference, int revision, String userKey
});




}
/// @nodoc
class _$ProductAnalyticsPreferenceApiRecordCopyWithImpl<$Res>
    implements $ProductAnalyticsPreferenceApiRecordCopyWith<$Res> {
  _$ProductAnalyticsPreferenceApiRecordCopyWithImpl(this._self, this._then);

  final ProductAnalyticsPreferenceApiRecord _self;
  final $Res Function(ProductAnalyticsPreferenceApiRecord) _then;

/// Create a copy of ProductAnalyticsPreferenceApiRecord
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? preference = null,Object? revision = null,Object? userKey = null,}) {
  return _then(_self.copyWith(
preference: null == preference ? _self.preference : preference // ignore: cast_nullable_to_non_nullable
as ProductAnalyticsPreference,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,userKey: null == userKey ? _self.userKey : userKey // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _ProductAnalyticsPreferenceApiRecord implements ProductAnalyticsPreferenceApiRecord {
  const _ProductAnalyticsPreferenceApiRecord({required this.preference, required this.revision, required this.userKey});
  factory _ProductAnalyticsPreferenceApiRecord.fromJson(Map<String, dynamic> json) => _$ProductAnalyticsPreferenceApiRecordFromJson(json);

@override final  ProductAnalyticsPreference preference;
@override final  int revision;
@override final  String userKey;

/// Create a copy of ProductAnalyticsPreferenceApiRecord
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProductAnalyticsPreferenceApiRecordCopyWith<_ProductAnalyticsPreferenceApiRecord> get copyWith => __$ProductAnalyticsPreferenceApiRecordCopyWithImpl<_ProductAnalyticsPreferenceApiRecord>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProductAnalyticsPreferenceApiRecordToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProductAnalyticsPreferenceApiRecord&&(identical(other.preference, preference) || other.preference == preference)&&(identical(other.revision, revision) || other.revision == revision)&&(identical(other.userKey, userKey) || other.userKey == userKey));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,preference,revision,userKey);

@override
String toString() {
  return 'ProductAnalyticsPreferenceApiRecord(preference: $preference, revision: $revision, userKey: $userKey)';
}


}

/// @nodoc
abstract mixin class _$ProductAnalyticsPreferenceApiRecordCopyWith<$Res> implements $ProductAnalyticsPreferenceApiRecordCopyWith<$Res> {
  factory _$ProductAnalyticsPreferenceApiRecordCopyWith(_ProductAnalyticsPreferenceApiRecord value, $Res Function(_ProductAnalyticsPreferenceApiRecord) _then) = __$ProductAnalyticsPreferenceApiRecordCopyWithImpl;
@override @useResult
$Res call({
 ProductAnalyticsPreference preference, int revision, String userKey
});




}
/// @nodoc
class __$ProductAnalyticsPreferenceApiRecordCopyWithImpl<$Res>
    implements _$ProductAnalyticsPreferenceApiRecordCopyWith<$Res> {
  __$ProductAnalyticsPreferenceApiRecordCopyWithImpl(this._self, this._then);

  final _ProductAnalyticsPreferenceApiRecord _self;
  final $Res Function(_ProductAnalyticsPreferenceApiRecord) _then;

/// Create a copy of ProductAnalyticsPreferenceApiRecord
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? preference = null,Object? revision = null,Object? userKey = null,}) {
  return _then(_ProductAnalyticsPreferenceApiRecord(
preference: null == preference ? _self.preference : preference // ignore: cast_nullable_to_non_nullable
as ProductAnalyticsPreference,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,userKey: null == userKey ? _self.userKey : userKey // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$ProductAnalyticsPreferenceApiResult {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProductAnalyticsPreferenceApiResult);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ProductAnalyticsPreferenceApiResult()';
}


}

/// @nodoc
class $ProductAnalyticsPreferenceApiResultCopyWith<$Res>  {
$ProductAnalyticsPreferenceApiResultCopyWith(ProductAnalyticsPreferenceApiResult _, $Res Function(ProductAnalyticsPreferenceApiResult) __);
}



/// @nodoc


class ProductAnalyticsPreferenceApiSuccess implements ProductAnalyticsPreferenceApiResult {
  const ProductAnalyticsPreferenceApiSuccess({required this.record});
  

 final  ProductAnalyticsPreferenceApiRecord record;

/// Create a copy of ProductAnalyticsPreferenceApiResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProductAnalyticsPreferenceApiSuccessCopyWith<ProductAnalyticsPreferenceApiSuccess> get copyWith => _$ProductAnalyticsPreferenceApiSuccessCopyWithImpl<ProductAnalyticsPreferenceApiSuccess>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProductAnalyticsPreferenceApiSuccess&&(identical(other.record, record) || other.record == record));
}


@override
int get hashCode => Object.hash(runtimeType,record);

@override
String toString() {
  return 'ProductAnalyticsPreferenceApiResult.success(record: $record)';
}


}

/// @nodoc
abstract mixin class $ProductAnalyticsPreferenceApiSuccessCopyWith<$Res> implements $ProductAnalyticsPreferenceApiResultCopyWith<$Res> {
  factory $ProductAnalyticsPreferenceApiSuccessCopyWith(ProductAnalyticsPreferenceApiSuccess value, $Res Function(ProductAnalyticsPreferenceApiSuccess) _then) = _$ProductAnalyticsPreferenceApiSuccessCopyWithImpl;
@useResult
$Res call({
 ProductAnalyticsPreferenceApiRecord record
});


$ProductAnalyticsPreferenceApiRecordCopyWith<$Res> get record;

}
/// @nodoc
class _$ProductAnalyticsPreferenceApiSuccessCopyWithImpl<$Res>
    implements $ProductAnalyticsPreferenceApiSuccessCopyWith<$Res> {
  _$ProductAnalyticsPreferenceApiSuccessCopyWithImpl(this._self, this._then);

  final ProductAnalyticsPreferenceApiSuccess _self;
  final $Res Function(ProductAnalyticsPreferenceApiSuccess) _then;

/// Create a copy of ProductAnalyticsPreferenceApiResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? record = null,}) {
  return _then(ProductAnalyticsPreferenceApiSuccess(
record: null == record ? _self.record : record // ignore: cast_nullable_to_non_nullable
as ProductAnalyticsPreferenceApiRecord,
  ));
}

/// Create a copy of ProductAnalyticsPreferenceApiResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProductAnalyticsPreferenceApiRecordCopyWith<$Res> get record {
  
  return $ProductAnalyticsPreferenceApiRecordCopyWith<$Res>(_self.record, (value) {
    return _then(_self.copyWith(record: value));
  });
}
}

/// @nodoc


class ProductAnalyticsPreferenceApiConflict implements ProductAnalyticsPreferenceApiResult {
  const ProductAnalyticsPreferenceApiConflict({required this.record});
  

 final  ProductAnalyticsPreferenceApiRecord record;

/// Create a copy of ProductAnalyticsPreferenceApiResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProductAnalyticsPreferenceApiConflictCopyWith<ProductAnalyticsPreferenceApiConflict> get copyWith => _$ProductAnalyticsPreferenceApiConflictCopyWithImpl<ProductAnalyticsPreferenceApiConflict>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProductAnalyticsPreferenceApiConflict&&(identical(other.record, record) || other.record == record));
}


@override
int get hashCode => Object.hash(runtimeType,record);

@override
String toString() {
  return 'ProductAnalyticsPreferenceApiResult.conflict(record: $record)';
}


}

/// @nodoc
abstract mixin class $ProductAnalyticsPreferenceApiConflictCopyWith<$Res> implements $ProductAnalyticsPreferenceApiResultCopyWith<$Res> {
  factory $ProductAnalyticsPreferenceApiConflictCopyWith(ProductAnalyticsPreferenceApiConflict value, $Res Function(ProductAnalyticsPreferenceApiConflict) _then) = _$ProductAnalyticsPreferenceApiConflictCopyWithImpl;
@useResult
$Res call({
 ProductAnalyticsPreferenceApiRecord record
});


$ProductAnalyticsPreferenceApiRecordCopyWith<$Res> get record;

}
/// @nodoc
class _$ProductAnalyticsPreferenceApiConflictCopyWithImpl<$Res>
    implements $ProductAnalyticsPreferenceApiConflictCopyWith<$Res> {
  _$ProductAnalyticsPreferenceApiConflictCopyWithImpl(this._self, this._then);

  final ProductAnalyticsPreferenceApiConflict _self;
  final $Res Function(ProductAnalyticsPreferenceApiConflict) _then;

/// Create a copy of ProductAnalyticsPreferenceApiResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? record = null,}) {
  return _then(ProductAnalyticsPreferenceApiConflict(
record: null == record ? _self.record : record // ignore: cast_nullable_to_non_nullable
as ProductAnalyticsPreferenceApiRecord,
  ));
}

/// Create a copy of ProductAnalyticsPreferenceApiResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProductAnalyticsPreferenceApiRecordCopyWith<$Res> get record {
  
  return $ProductAnalyticsPreferenceApiRecordCopyWith<$Res>(_self.record, (value) {
    return _then(_self.copyWith(record: value));
  });
}
}

/// @nodoc


class ProductAnalyticsPreferenceApiTimeout implements ProductAnalyticsPreferenceApiResult {
  const ProductAnalyticsPreferenceApiTimeout();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProductAnalyticsPreferenceApiTimeout);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ProductAnalyticsPreferenceApiResult.timeout()';
}


}




/// @nodoc


class ProductAnalyticsPreferenceApiFailure implements ProductAnalyticsPreferenceApiResult {
  const ProductAnalyticsPreferenceApiFailure();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProductAnalyticsPreferenceApiFailure);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ProductAnalyticsPreferenceApiResult.failure()';
}


}





/// @nodoc
mixin _$ProductAnalyticsPreferenceConflictResponse {

 ProductAnalyticsPreferenceConflictError get error; ProductAnalyticsPreference get preference; int get revision; String get userKey;
/// Create a copy of ProductAnalyticsPreferenceConflictResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProductAnalyticsPreferenceConflictResponseCopyWith<ProductAnalyticsPreferenceConflictResponse> get copyWith => _$ProductAnalyticsPreferenceConflictResponseCopyWithImpl<ProductAnalyticsPreferenceConflictResponse>(this as ProductAnalyticsPreferenceConflictResponse, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProductAnalyticsPreferenceConflictResponse&&(identical(other.error, error) || other.error == error)&&(identical(other.preference, preference) || other.preference == preference)&&(identical(other.revision, revision) || other.revision == revision)&&(identical(other.userKey, userKey) || other.userKey == userKey));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,error,preference,revision,userKey);

@override
String toString() {
  return 'ProductAnalyticsPreferenceConflictResponse(error: $error, preference: $preference, revision: $revision, userKey: $userKey)';
}


}

/// @nodoc
abstract mixin class $ProductAnalyticsPreferenceConflictResponseCopyWith<$Res>  {
  factory $ProductAnalyticsPreferenceConflictResponseCopyWith(ProductAnalyticsPreferenceConflictResponse value, $Res Function(ProductAnalyticsPreferenceConflictResponse) _then) = _$ProductAnalyticsPreferenceConflictResponseCopyWithImpl;
@useResult
$Res call({
 ProductAnalyticsPreferenceConflictError error, ProductAnalyticsPreference preference, int revision, String userKey
});




}
/// @nodoc
class _$ProductAnalyticsPreferenceConflictResponseCopyWithImpl<$Res>
    implements $ProductAnalyticsPreferenceConflictResponseCopyWith<$Res> {
  _$ProductAnalyticsPreferenceConflictResponseCopyWithImpl(this._self, this._then);

  final ProductAnalyticsPreferenceConflictResponse _self;
  final $Res Function(ProductAnalyticsPreferenceConflictResponse) _then;

/// Create a copy of ProductAnalyticsPreferenceConflictResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? error = null,Object? preference = null,Object? revision = null,Object? userKey = null,}) {
  return _then(_self.copyWith(
error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as ProductAnalyticsPreferenceConflictError,preference: null == preference ? _self.preference : preference // ignore: cast_nullable_to_non_nullable
as ProductAnalyticsPreference,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,userKey: null == userKey ? _self.userKey : userKey // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _ProductAnalyticsPreferenceConflictResponse extends ProductAnalyticsPreferenceConflictResponse {
  const _ProductAnalyticsPreferenceConflictResponse({required this.error, required this.preference, required this.revision, required this.userKey}): super._();
  factory _ProductAnalyticsPreferenceConflictResponse.fromJson(Map<String, dynamic> json) => _$ProductAnalyticsPreferenceConflictResponseFromJson(json);

@override final  ProductAnalyticsPreferenceConflictError error;
@override final  ProductAnalyticsPreference preference;
@override final  int revision;
@override final  String userKey;

/// Create a copy of ProductAnalyticsPreferenceConflictResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProductAnalyticsPreferenceConflictResponseCopyWith<_ProductAnalyticsPreferenceConflictResponse> get copyWith => __$ProductAnalyticsPreferenceConflictResponseCopyWithImpl<_ProductAnalyticsPreferenceConflictResponse>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProductAnalyticsPreferenceConflictResponse&&(identical(other.error, error) || other.error == error)&&(identical(other.preference, preference) || other.preference == preference)&&(identical(other.revision, revision) || other.revision == revision)&&(identical(other.userKey, userKey) || other.userKey == userKey));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,error,preference,revision,userKey);

@override
String toString() {
  return 'ProductAnalyticsPreferenceConflictResponse(error: $error, preference: $preference, revision: $revision, userKey: $userKey)';
}


}

/// @nodoc
abstract mixin class _$ProductAnalyticsPreferenceConflictResponseCopyWith<$Res> implements $ProductAnalyticsPreferenceConflictResponseCopyWith<$Res> {
  factory _$ProductAnalyticsPreferenceConflictResponseCopyWith(_ProductAnalyticsPreferenceConflictResponse value, $Res Function(_ProductAnalyticsPreferenceConflictResponse) _then) = __$ProductAnalyticsPreferenceConflictResponseCopyWithImpl;
@override @useResult
$Res call({
 ProductAnalyticsPreferenceConflictError error, ProductAnalyticsPreference preference, int revision, String userKey
});




}
/// @nodoc
class __$ProductAnalyticsPreferenceConflictResponseCopyWithImpl<$Res>
    implements _$ProductAnalyticsPreferenceConflictResponseCopyWith<$Res> {
  __$ProductAnalyticsPreferenceConflictResponseCopyWithImpl(this._self, this._then);

  final _ProductAnalyticsPreferenceConflictResponse _self;
  final $Res Function(_ProductAnalyticsPreferenceConflictResponse) _then;

/// Create a copy of ProductAnalyticsPreferenceConflictResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? error = null,Object? preference = null,Object? revision = null,Object? userKey = null,}) {
  return _then(_ProductAnalyticsPreferenceConflictResponse(
error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as ProductAnalyticsPreferenceConflictError,preference: null == preference ? _self.preference : preference // ignore: cast_nullable_to_non_nullable
as ProductAnalyticsPreference,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,userKey: null == userKey ? _self.userKey : userKey // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
