// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'v2_data_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$V2DataResponse<T> {

 T get data;



@override
bool operator ==(Object other) {
  final _this = this as V2DataResponse<T>;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is V2DataResponse<T>&&const DeepCollectionEquality().equals(other.data, _this.data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as V2DataResponse<T>;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.data));
}

@override
String toString() {
  final _this = this as V2DataResponse<T>;
  return 'V2DataResponse<$T>(data: ${_this.data})';
}


}





/// @nodoc
@JsonSerializable(createToJson: false,genericArgumentFactories: true)

class _V2DataResponse<T> implements V2DataResponse<T> {
  const _V2DataResponse({required this.data});
  factory _V2DataResponse.fromJson(Map<String, dynamic> json,T Function(Object?) fromJsonT) => _$V2DataResponseFromJson(json,fromJsonT);

@override final  T data;




@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _V2DataResponse<T>&&const DeepCollectionEquality().equals(other.data, data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(data));
}

@override
String toString() {
    return 'V2DataResponse<$T>(data: $data)';
}


}




// dart format on
