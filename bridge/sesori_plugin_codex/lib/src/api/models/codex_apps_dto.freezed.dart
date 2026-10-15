// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'codex_apps_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CodexAppsPageDto {

 List<CodexAppInfoDto> get data; String? get nextCursor;



@override
bool operator ==(Object other) {
  final _this = this as CodexAppsPageDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexAppsPageDto&&const DeepCollectionEquality().equals(other.data, _this.data)&&(identical(other.nextCursor, _this.nextCursor) || other.nextCursor == _this.nextCursor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CodexAppsPageDto;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.data),_this.nextCursor);
}



}





/// @nodoc
@JsonSerializable(createToJson: false)

class _CodexAppsPageDto implements CodexAppsPageDto {
  const _CodexAppsPageDto({required  List<CodexAppInfoDto> data, required this.nextCursor}): _data = data;
  factory _CodexAppsPageDto.fromJson(Map<String, dynamic> json) => _$CodexAppsPageDtoFromJson(json);

 final  List<CodexAppInfoDto> _data;
@override List<CodexAppInfoDto> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}

@override final  String? nextCursor;




@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexAppsPageDto&&const DeepCollectionEquality().equals(other.data, _data)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_data),nextCursor);
}



}





/// @nodoc
mixin _$CodexAppInfoDto {

 String get id; String get name; String? get description; String? get installUrl; bool get isAccessible; bool get isEnabled;



@override
bool operator ==(Object other) {
  final _this = this as CodexAppInfoDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexAppInfoDto&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.description, _this.description) || other.description == _this.description)&&(identical(other.installUrl, _this.installUrl) || other.installUrl == _this.installUrl)&&(identical(other.isAccessible, _this.isAccessible) || other.isAccessible == _this.isAccessible)&&(identical(other.isEnabled, _this.isEnabled) || other.isEnabled == _this.isEnabled));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CodexAppInfoDto;
  return Object.hash(runtimeType,_this.id,_this.name,_this.description,_this.installUrl,_this.isAccessible,_this.isEnabled);
}



}





/// @nodoc
@JsonSerializable(createToJson: false)

class _CodexAppInfoDto implements CodexAppInfoDto {
  const _CodexAppInfoDto({required this.id, required this.name, required this.description, required this.installUrl, this.isAccessible = false, this.isEnabled = true});
  factory _CodexAppInfoDto.fromJson(Map<String, dynamic> json) => _$CodexAppInfoDtoFromJson(json);

@override final  String id;
@override final  String name;
@override final  String? description;
@override final  String? installUrl;
@override@JsonKey() final  bool isAccessible;
@override@JsonKey() final  bool isEnabled;




@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexAppInfoDto&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.installUrl, installUrl) || other.installUrl == installUrl)&&(identical(other.isAccessible, isAccessible) || other.isAccessible == isAccessible)&&(identical(other.isEnabled, isEnabled) || other.isEnabled == isEnabled));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,name,description,installUrl,isAccessible,isEnabled);
}



}




// dart format on
