// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'api_error.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
ApiError _$ApiErrorFromJson(
  Map<String, dynamic> json
) {
        switch (json['runtimeType']) {
                  case 'jsonParsing':
          return JsonParsingError.fromJson(
            json
          );
                case 'dartHttpClient':
          return DartHttpClientError.fromJson(
            json
          );
                case 'generic':
          return GenericError.fromJson(
            json
          );
                case 'notAuthenticated':
          return NotAuthenticatedError.fromJson(
            json
          );
                case 'nonSuccessCode':
          return NonSuccessCodeError.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'runtimeType',
  'ApiError',
  'Invalid union type "${json['runtimeType']}"!'
);
        }
      
}

/// @nodoc
mixin _$ApiError {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ApiError);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ApiError()';
}


}

/// @nodoc
class $ApiErrorCopyWith<$Res>  {
$ApiErrorCopyWith(ApiError _, $Res Function(ApiError) __);
}



/// @nodoc
@JsonSerializable(createToJson: false)

class JsonParsingError extends ApiError {
   JsonParsingError(this.jsonString, {final  String? $type}): $type = $type ?? 'jsonParsing',super._();
  factory JsonParsingError.fromJson(Map<String, dynamic> json) => _$JsonParsingErrorFromJson(json);

 final  String jsonString;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of ApiError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$JsonParsingErrorCopyWith<JsonParsingError> get copyWith => _$JsonParsingErrorCopyWithImpl<JsonParsingError>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is JsonParsingError&&(identical(other.jsonString, jsonString) || other.jsonString == jsonString));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,jsonString);

@override
String toString() {
  return 'ApiError.jsonParsing(jsonString: $jsonString)';
}


}

/// @nodoc
abstract mixin class $JsonParsingErrorCopyWith<$Res> implements $ApiErrorCopyWith<$Res> {
  factory $JsonParsingErrorCopyWith(JsonParsingError value, $Res Function(JsonParsingError) _then) = _$JsonParsingErrorCopyWithImpl;
@useResult
$Res call({
 String jsonString
});




}
/// @nodoc
class _$JsonParsingErrorCopyWithImpl<$Res>
    implements $JsonParsingErrorCopyWith<$Res> {
  _$JsonParsingErrorCopyWithImpl(this._self, this._then);

  final JsonParsingError _self;
  final $Res Function(JsonParsingError) _then;

/// Create a copy of ApiError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? jsonString = null,}) {
  return _then(JsonParsingError(
null == jsonString ? _self.jsonString : jsonString // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class DartHttpClientError extends ApiError {
   DartHttpClientError(this.innerError, {final  String? $type}): $type = $type ?? 'dartHttpClient',super._();
  factory DartHttpClientError.fromJson(Map<String, dynamic> json) => _$DartHttpClientErrorFromJson(json);

 final  Object innerError;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of ApiError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DartHttpClientErrorCopyWith<DartHttpClientError> get copyWith => _$DartHttpClientErrorCopyWithImpl<DartHttpClientError>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DartHttpClientError&&const DeepCollectionEquality().equals(other.innerError, innerError));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(innerError));

@override
String toString() {
  return 'ApiError.dartHttpClient(innerError: $innerError)';
}


}

/// @nodoc
abstract mixin class $DartHttpClientErrorCopyWith<$Res> implements $ApiErrorCopyWith<$Res> {
  factory $DartHttpClientErrorCopyWith(DartHttpClientError value, $Res Function(DartHttpClientError) _then) = _$DartHttpClientErrorCopyWithImpl;
@useResult
$Res call({
 Object innerError
});




}
/// @nodoc
class _$DartHttpClientErrorCopyWithImpl<$Res>
    implements $DartHttpClientErrorCopyWith<$Res> {
  _$DartHttpClientErrorCopyWithImpl(this._self, this._then);

  final DartHttpClientError _self;
  final $Res Function(DartHttpClientError) _then;

/// Create a copy of ApiError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? innerError = null,}) {
  return _then(DartHttpClientError(
null == innerError ? _self.innerError : innerError ,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class GenericError extends ApiError {
   GenericError({final  String? $type}): $type = $type ?? 'generic',super._();
  factory GenericError.fromJson(Map<String, dynamic> json) => _$GenericErrorFromJson(json);



@JsonKey(name: 'runtimeType')
final String $type;





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GenericError);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ApiError.generic()';
}


}




/// @nodoc
@JsonSerializable(createToJson: false)

class NotAuthenticatedError extends ApiError {
   NotAuthenticatedError({final  String? $type}): $type = $type ?? 'notAuthenticated',super._();
  factory NotAuthenticatedError.fromJson(Map<String, dynamic> json) => _$NotAuthenticatedErrorFromJson(json);



@JsonKey(name: 'runtimeType')
final String $type;





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NotAuthenticatedError);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ApiError.notAuthenticated()';
}


}




/// @nodoc
@JsonSerializable(createToJson: false)

class NonSuccessCodeError extends ApiError {
   NonSuccessCodeError({required this.errorCode, required this.rawErrorString, final  String? $type}): $type = $type ?? 'nonSuccessCode',super._();
  factory NonSuccessCodeError.fromJson(Map<String, dynamic> json) => _$NonSuccessCodeErrorFromJson(json);

 final  int errorCode;
 final  String? rawErrorString;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of ApiError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NonSuccessCodeErrorCopyWith<NonSuccessCodeError> get copyWith => _$NonSuccessCodeErrorCopyWithImpl<NonSuccessCodeError>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NonSuccessCodeError&&(identical(other.errorCode, errorCode) || other.errorCode == errorCode)&&(identical(other.rawErrorString, rawErrorString) || other.rawErrorString == rawErrorString));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,errorCode,rawErrorString);

@override
String toString() {
  return 'ApiError.nonSuccessCode(errorCode: $errorCode, rawErrorString: $rawErrorString)';
}


}

/// @nodoc
abstract mixin class $NonSuccessCodeErrorCopyWith<$Res> implements $ApiErrorCopyWith<$Res> {
  factory $NonSuccessCodeErrorCopyWith(NonSuccessCodeError value, $Res Function(NonSuccessCodeError) _then) = _$NonSuccessCodeErrorCopyWithImpl;
@useResult
$Res call({
 int errorCode, String? rawErrorString
});




}
/// @nodoc
class _$NonSuccessCodeErrorCopyWithImpl<$Res>
    implements $NonSuccessCodeErrorCopyWith<$Res> {
  _$NonSuccessCodeErrorCopyWithImpl(this._self, this._then);

  final NonSuccessCodeError _self;
  final $Res Function(NonSuccessCodeError) _then;

/// Create a copy of ApiError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? errorCode = null,Object? rawErrorString = freezed,}) {
  return _then(NonSuccessCodeError(
errorCode: null == errorCode ? _self.errorCode : errorCode // ignore: cast_nullable_to_non_nullable
as int,rawErrorString: freezed == rawErrorString ? _self.rawErrorString : rawErrorString // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
