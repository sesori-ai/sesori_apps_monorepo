// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'api_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ApiResponse<T> {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ApiResponse<T>);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ApiResponse<$T>()';
}


}

/// @nodoc
class $ApiResponseCopyWith<T,$Res>  {
$ApiResponseCopyWith(ApiResponse<T> _, $Res Function(ApiResponse<T>) __);
}



/// @nodoc


class SuccessResponse<T> extends ApiResponse<T> {
   SuccessResponse(this.data): super._();
  

 final  T data;

/// Create a copy of ApiResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SuccessResponseCopyWith<T, SuccessResponse<T>> get copyWith => _$SuccessResponseCopyWithImpl<T, SuccessResponse<T>>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SuccessResponse<T>&&const DeepCollectionEquality().equals(other.data, data));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(data));

@override
String toString() {
  return 'ApiResponse<$T>.success(data: $data)';
}


}

/// @nodoc
abstract mixin class $SuccessResponseCopyWith<T,$Res> implements $ApiResponseCopyWith<T, $Res> {
  factory $SuccessResponseCopyWith(SuccessResponse<T> value, $Res Function(SuccessResponse<T>) _then) = _$SuccessResponseCopyWithImpl;
@useResult
$Res call({
 T data
});




}
/// @nodoc
class _$SuccessResponseCopyWithImpl<T,$Res>
    implements $SuccessResponseCopyWith<T, $Res> {
  _$SuccessResponseCopyWithImpl(this._self, this._then);

  final SuccessResponse<T> _self;
  final $Res Function(SuccessResponse<T>) _then;

/// Create a copy of ApiResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? data = freezed,}) {
  return _then(SuccessResponse<T>(
freezed == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as T,
  ));
}


}

/// @nodoc


class ErrorResponse<T> extends ApiResponse<T> {
   ErrorResponse(this.error): super._();
  

 final  ApiError error;

/// Create a copy of ApiResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ErrorResponseCopyWith<T, ErrorResponse<T>> get copyWith => _$ErrorResponseCopyWithImpl<T, ErrorResponse<T>>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ErrorResponse<T>&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,error);

@override
String toString() {
  return 'ApiResponse<$T>.error(error: $error)';
}


}

/// @nodoc
abstract mixin class $ErrorResponseCopyWith<T,$Res> implements $ApiResponseCopyWith<T, $Res> {
  factory $ErrorResponseCopyWith(ErrorResponse<T> value, $Res Function(ErrorResponse<T>) _then) = _$ErrorResponseCopyWithImpl;
@useResult
$Res call({
 ApiError error
});


$ApiErrorCopyWith<$Res> get error;

}
/// @nodoc
class _$ErrorResponseCopyWithImpl<T,$Res>
    implements $ErrorResponseCopyWith<T, $Res> {
  _$ErrorResponseCopyWithImpl(this._self, this._then);

  final ErrorResponse<T> _self;
  final $Res Function(ErrorResponse<T>) _then;

/// Create a copy of ApiResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? error = null,}) {
  return _then(ErrorResponse<T>(
null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as ApiError,
  ));
}

/// Create a copy of ApiResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ApiErrorCopyWith<$Res> get error {
  
  return $ApiErrorCopyWith<$Res>(_self.error, (value) {
    return _then(_self.copyWith(error: value));
  });
}
}

// dart format on
