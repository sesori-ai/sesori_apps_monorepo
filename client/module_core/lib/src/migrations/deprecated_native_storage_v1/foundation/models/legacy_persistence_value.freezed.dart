// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'legacy_persistence_value.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LegacyPersistenceValue {

 String get sourceKey; Object get key; Object get value;



@override
bool operator ==(Object other) {
  final _this = this as LegacyPersistenceValue;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LegacyPersistenceValue&&(identical(other.sourceKey, _this.sourceKey) || other.sourceKey == _this.sourceKey)&&const DeepCollectionEquality().equals(other.key, _this.key)&&const DeepCollectionEquality().equals(other.value, _this.value));
}


@override
int get hashCode {
  final _this = this as LegacyPersistenceValue;
  return Object.hash(runtimeType,_this.sourceKey,const DeepCollectionEquality().hash(_this.key),const DeepCollectionEquality().hash(_this.value));
}



}





/// @nodoc


class LegacyStringValue implements LegacyPersistenceValue {
  const LegacyStringValue({required this.sourceKey, required this.key, required this.value});
  

@override final  String sourceKey;
@override final  StringPersistenceKey key;
@override final  String value;




@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is LegacyStringValue&&(identical(other.sourceKey, sourceKey) || other.sourceKey == sourceKey)&&(identical(other.key, key) || other.key == key)&&(identical(other.value, value) || other.value == value));
}


@override
int get hashCode {
    return Object.hash(runtimeType,sourceKey,key,value);
}



}




/// @nodoc


class LegacyBoolValue implements LegacyPersistenceValue {
  const LegacyBoolValue({required this.sourceKey, required this.key, required this.value});
  

@override final  String sourceKey;
@override final  BoolPersistenceKey key;
@override final  bool value;




@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is LegacyBoolValue&&(identical(other.sourceKey, sourceKey) || other.sourceKey == sourceKey)&&(identical(other.key, key) || other.key == key)&&(identical(other.value, value) || other.value == value));
}


@override
int get hashCode {
    return Object.hash(runtimeType,sourceKey,key,value);
}



}




/// @nodoc


class LegacySecretValue implements LegacyPersistenceValue {
  const LegacySecretValue({required this.sourceKey, required this.key, required this.value});
  

@override final  String sourceKey;
@override final  SecretStorageKey key;
@override final  String value;




@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is LegacySecretValue&&(identical(other.sourceKey, sourceKey) || other.sourceKey == sourceKey)&&(identical(other.key, key) || other.key == key)&&(identical(other.value, value) || other.value == value));
}


@override
int get hashCode {
    return Object.hash(runtimeType,sourceKey,key,value);
}



}




// dart format on
