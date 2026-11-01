// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'product_analytics_event_delivery.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ProductAnalyticsEventDeliveryResult {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ProductAnalyticsEventDeliveryResult);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ProductAnalyticsEventDeliveryResult()';
}


}

/// @nodoc
class $ProductAnalyticsEventDeliveryResultCopyWith<$Res>  {
$ProductAnalyticsEventDeliveryResultCopyWith(ProductAnalyticsEventDeliveryResult _, $Res Function(ProductAnalyticsEventDeliveryResult) __);
}



/// @nodoc


class ProductAnalyticsEventDelivered implements ProductAnalyticsEventDeliveryResult {
  const ProductAnalyticsEventDelivered();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ProductAnalyticsEventDelivered);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ProductAnalyticsEventDeliveryResult.delivered()';
}


}




/// @nodoc


class ProductAnalyticsEventPermanentFailure implements ProductAnalyticsEventDeliveryResult {
  const ProductAnalyticsEventPermanentFailure({required this.description, required this.cause});
  

 final  String description;
 final  ApiError? cause;

/// Create a copy of ProductAnalyticsEventDeliveryResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProductAnalyticsEventPermanentFailureCopyWith<ProductAnalyticsEventPermanentFailure> get copyWith => _$ProductAnalyticsEventPermanentFailureCopyWithImpl<ProductAnalyticsEventPermanentFailure>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ProductAnalyticsEventPermanentFailure&&(identical(other.description, description) || other.description == description)&&(identical(other.cause, cause) || other.cause == cause));
}


@override
int get hashCode {
    return Object.hash(runtimeType,description,cause);
}

@override
String toString() {
    return 'ProductAnalyticsEventDeliveryResult.permanentFailure(description: $description, cause: $cause)';
}


}

/// @nodoc
abstract mixin class $ProductAnalyticsEventPermanentFailureCopyWith<$Res> implements $ProductAnalyticsEventDeliveryResultCopyWith<$Res> {
  factory $ProductAnalyticsEventPermanentFailureCopyWith(ProductAnalyticsEventPermanentFailure value, $Res Function(ProductAnalyticsEventPermanentFailure) _then) = _$ProductAnalyticsEventPermanentFailureCopyWithImpl;
@useResult
$Res call({
 String description, ApiError? cause
});


$ApiErrorCopyWith<$Res>? get cause;

}
/// @nodoc
class _$ProductAnalyticsEventPermanentFailureCopyWithImpl<$Res>
    implements $ProductAnalyticsEventPermanentFailureCopyWith<$Res> {
  _$ProductAnalyticsEventPermanentFailureCopyWithImpl(this._self, this._then);

  final ProductAnalyticsEventPermanentFailure _self;
  final $Res Function(ProductAnalyticsEventPermanentFailure) _then;

/// Create a copy of ProductAnalyticsEventDeliveryResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? description = null,Object? cause = freezed,}) {
  return _then(ProductAnalyticsEventPermanentFailure(
description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,cause: freezed == cause ? _self.cause : cause // ignore: cast_nullable_to_non_nullable
as ApiError?,
  ));
}

/// Create a copy of ProductAnalyticsEventDeliveryResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ApiErrorCopyWith<$Res>? get cause {
    if (_self.cause == null) {
    return null;
  }

  return $ApiErrorCopyWith<$Res>(_self.cause!, (value) {
    return _then(_self.copyWith(cause: value));
  });
}
}

/// @nodoc


class ProductAnalyticsEventTransientFailure implements ProductAnalyticsEventDeliveryResult {
  const ProductAnalyticsEventTransientFailure({required this.description, required this.cause, required this.stackTrace});
  

 final  String description;
 final  Object? cause;
 final  StackTrace? stackTrace;

/// Create a copy of ProductAnalyticsEventDeliveryResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProductAnalyticsEventTransientFailureCopyWith<ProductAnalyticsEventTransientFailure> get copyWith => _$ProductAnalyticsEventTransientFailureCopyWithImpl<ProductAnalyticsEventTransientFailure>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ProductAnalyticsEventTransientFailure&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other.cause, cause)&&(identical(other.stackTrace, stackTrace) || other.stackTrace == stackTrace));
}


@override
int get hashCode {
    return Object.hash(runtimeType,description,const DeepCollectionEquality().hash(cause),stackTrace);
}

@override
String toString() {
    return 'ProductAnalyticsEventDeliveryResult.transientFailure(description: $description, cause: $cause, stackTrace: $stackTrace)';
}


}

/// @nodoc
abstract mixin class $ProductAnalyticsEventTransientFailureCopyWith<$Res> implements $ProductAnalyticsEventDeliveryResultCopyWith<$Res> {
  factory $ProductAnalyticsEventTransientFailureCopyWith(ProductAnalyticsEventTransientFailure value, $Res Function(ProductAnalyticsEventTransientFailure) _then) = _$ProductAnalyticsEventTransientFailureCopyWithImpl;
@useResult
$Res call({
 String description, Object? cause, StackTrace? stackTrace
});




}
/// @nodoc
class _$ProductAnalyticsEventTransientFailureCopyWithImpl<$Res>
    implements $ProductAnalyticsEventTransientFailureCopyWith<$Res> {
  _$ProductAnalyticsEventTransientFailureCopyWithImpl(this._self, this._then);

  final ProductAnalyticsEventTransientFailure _self;
  final $Res Function(ProductAnalyticsEventTransientFailure) _then;

/// Create a copy of ProductAnalyticsEventDeliveryResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? description = null,Object? cause = freezed,Object? stackTrace = freezed,}) {
  return _then(ProductAnalyticsEventTransientFailure(
description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,cause: freezed == cause ? _self.cause : cause ,stackTrace: freezed == stackTrace ? _self.stackTrace : stackTrace // ignore: cast_nullable_to_non_nullable
as StackTrace?,
  ));
}


}

// dart format on
