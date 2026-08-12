// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'product_analytics_preference_update_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ProductAnalyticsPreferenceUpdateRequest {

 ProductAnalyticsPreferenceUpdateValue get preference; int get expectedRevision; String get operationId;
/// Create a copy of ProductAnalyticsPreferenceUpdateRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProductAnalyticsPreferenceUpdateRequestCopyWith<ProductAnalyticsPreferenceUpdateRequest> get copyWith => _$ProductAnalyticsPreferenceUpdateRequestCopyWithImpl<ProductAnalyticsPreferenceUpdateRequest>(this as ProductAnalyticsPreferenceUpdateRequest, _$identity);

  /// Serializes this ProductAnalyticsPreferenceUpdateRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProductAnalyticsPreferenceUpdateRequest&&(identical(other.preference, preference) || other.preference == preference)&&(identical(other.expectedRevision, expectedRevision) || other.expectedRevision == expectedRevision)&&(identical(other.operationId, operationId) || other.operationId == operationId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,preference,expectedRevision,operationId);

@override
String toString() {
  return 'ProductAnalyticsPreferenceUpdateRequest(preference: $preference, expectedRevision: $expectedRevision, operationId: $operationId)';
}


}

/// @nodoc
abstract mixin class $ProductAnalyticsPreferenceUpdateRequestCopyWith<$Res>  {
  factory $ProductAnalyticsPreferenceUpdateRequestCopyWith(ProductAnalyticsPreferenceUpdateRequest value, $Res Function(ProductAnalyticsPreferenceUpdateRequest) _then) = _$ProductAnalyticsPreferenceUpdateRequestCopyWithImpl;
@useResult
$Res call({
 ProductAnalyticsPreferenceUpdateValue preference, int expectedRevision, String operationId
});




}
/// @nodoc
class _$ProductAnalyticsPreferenceUpdateRequestCopyWithImpl<$Res>
    implements $ProductAnalyticsPreferenceUpdateRequestCopyWith<$Res> {
  _$ProductAnalyticsPreferenceUpdateRequestCopyWithImpl(this._self, this._then);

  final ProductAnalyticsPreferenceUpdateRequest _self;
  final $Res Function(ProductAnalyticsPreferenceUpdateRequest) _then;

/// Create a copy of ProductAnalyticsPreferenceUpdateRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? preference = null,Object? expectedRevision = null,Object? operationId = null,}) {
  return _then(ProductAnalyticsPreferenceUpdateRequest(
preference: null == preference ? _self.preference : preference // ignore: cast_nullable_to_non_nullable
as ProductAnalyticsPreferenceUpdateValue,expectedRevision: null == expectedRevision ? _self.expectedRevision : expectedRevision // ignore: cast_nullable_to_non_nullable
as int,operationId: null == operationId ? _self.operationId : operationId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _ProductAnalyticsPreferenceUpdateRequest implements ProductAnalyticsPreferenceUpdateRequest {
  const _ProductAnalyticsPreferenceUpdateRequest({required this.preference, required this.expectedRevision, required this.operationId});
  factory _ProductAnalyticsPreferenceUpdateRequest.fromJson(Map<String, dynamic> json) => _$ProductAnalyticsPreferenceUpdateRequestFromJson(json);

@override final  ProductAnalyticsPreferenceUpdateValue preference;
@override final  int expectedRevision;
@override final  String operationId;

/// Create a copy of ProductAnalyticsPreferenceUpdateRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProductAnalyticsPreferenceUpdateRequestCopyWith<_ProductAnalyticsPreferenceUpdateRequest> get copyWith => __$ProductAnalyticsPreferenceUpdateRequestCopyWithImpl<_ProductAnalyticsPreferenceUpdateRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProductAnalyticsPreferenceUpdateRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProductAnalyticsPreferenceUpdateRequest&&(identical(other.preference, preference) || other.preference == preference)&&(identical(other.expectedRevision, expectedRevision) || other.expectedRevision == expectedRevision)&&(identical(other.operationId, operationId) || other.operationId == operationId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,preference,expectedRevision,operationId);

@override
String toString() {
  return 'ProductAnalyticsPreferenceUpdateRequest(preference: $preference, expectedRevision: $expectedRevision, operationId: $operationId)';
}


}

/// @nodoc
abstract mixin class _$ProductAnalyticsPreferenceUpdateRequestCopyWith<$Res> implements $ProductAnalyticsPreferenceUpdateRequestCopyWith<$Res> {
  factory _$ProductAnalyticsPreferenceUpdateRequestCopyWith(_ProductAnalyticsPreferenceUpdateRequest value, $Res Function(_ProductAnalyticsPreferenceUpdateRequest) _then) = __$ProductAnalyticsPreferenceUpdateRequestCopyWithImpl;
@override @useResult
$Res call({
 ProductAnalyticsPreferenceUpdateValue preference, int expectedRevision, String operationId
});




}
/// @nodoc
class __$ProductAnalyticsPreferenceUpdateRequestCopyWithImpl<$Res>
    implements _$ProductAnalyticsPreferenceUpdateRequestCopyWith<$Res> {
  __$ProductAnalyticsPreferenceUpdateRequestCopyWithImpl(this._self, this._then);

  final _ProductAnalyticsPreferenceUpdateRequest _self;
  final $Res Function(_ProductAnalyticsPreferenceUpdateRequest) _then;

/// Create a copy of ProductAnalyticsPreferenceUpdateRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? preference = null,Object? expectedRevision = null,Object? operationId = null,}) {
  return _then(_ProductAnalyticsPreferenceUpdateRequest(
preference: null == preference ? _self.preference : preference // ignore: cast_nullable_to_non_nullable
as ProductAnalyticsPreferenceUpdateValue,expectedRevision: null == expectedRevision ? _self.expectedRevision : expectedRevision // ignore: cast_nullable_to_non_nullable
as int,operationId: null == operationId ? _self.operationId : operationId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
