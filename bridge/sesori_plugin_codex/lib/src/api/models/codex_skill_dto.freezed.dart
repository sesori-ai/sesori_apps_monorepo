// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'codex_skill_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CodexSkillsListResponseDto {

 List<CodexSkillsListEntryDto> get data;
/// Create a copy of CodexSkillsListResponseDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexSkillsListResponseDtoCopyWith<CodexSkillsListResponseDto> get copyWith => _$CodexSkillsListResponseDtoCopyWithImpl<CodexSkillsListResponseDto>(this as CodexSkillsListResponseDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexSkillsListResponseDto&&const DeepCollectionEquality().equals(other.data, data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(data));

@override
String toString() {
  return 'CodexSkillsListResponseDto(data: $data)';
}


}

/// @nodoc
abstract mixin class $CodexSkillsListResponseDtoCopyWith<$Res>  {
  factory $CodexSkillsListResponseDtoCopyWith(CodexSkillsListResponseDto value, $Res Function(CodexSkillsListResponseDto) _then) = _$CodexSkillsListResponseDtoCopyWithImpl;
@useResult
$Res call({
 List<CodexSkillsListEntryDto> data
});




}
/// @nodoc
class _$CodexSkillsListResponseDtoCopyWithImpl<$Res>
    implements $CodexSkillsListResponseDtoCopyWith<$Res> {
  _$CodexSkillsListResponseDtoCopyWithImpl(this._self, this._then);

  final CodexSkillsListResponseDto _self;
  final $Res Function(CodexSkillsListResponseDto) _then;

/// Create a copy of CodexSkillsListResponseDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<CodexSkillsListEntryDto>,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CodexSkillsListResponseDto implements CodexSkillsListResponseDto {
  const _CodexSkillsListResponseDto({required final  List<CodexSkillsListEntryDto> data}): _data = data;
  factory _CodexSkillsListResponseDto.fromJson(Map<String, dynamic> json) => _$CodexSkillsListResponseDtoFromJson(json);

 final  List<CodexSkillsListEntryDto> _data;
@override List<CodexSkillsListEntryDto> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}


/// Create a copy of CodexSkillsListResponseDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexSkillsListResponseDtoCopyWith<_CodexSkillsListResponseDto> get copyWith => __$CodexSkillsListResponseDtoCopyWithImpl<_CodexSkillsListResponseDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexSkillsListResponseDto&&const DeepCollectionEquality().equals(other._data, _data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_data));

@override
String toString() {
  return 'CodexSkillsListResponseDto(data: $data)';
}


}

/// @nodoc
abstract mixin class _$CodexSkillsListResponseDtoCopyWith<$Res> implements $CodexSkillsListResponseDtoCopyWith<$Res> {
  factory _$CodexSkillsListResponseDtoCopyWith(_CodexSkillsListResponseDto value, $Res Function(_CodexSkillsListResponseDto) _then) = __$CodexSkillsListResponseDtoCopyWithImpl;
@override @useResult
$Res call({
 List<CodexSkillsListEntryDto> data
});




}
/// @nodoc
class __$CodexSkillsListResponseDtoCopyWithImpl<$Res>
    implements _$CodexSkillsListResponseDtoCopyWith<$Res> {
  __$CodexSkillsListResponseDtoCopyWithImpl(this._self, this._then);

  final _CodexSkillsListResponseDto _self;
  final $Res Function(_CodexSkillsListResponseDto) _then;

/// Create a copy of CodexSkillsListResponseDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_CodexSkillsListResponseDto(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<CodexSkillsListEntryDto>,
  ));
}


}


/// @nodoc
mixin _$CodexSkillsListEntryDto {

 String get cwd; List<CodexSkillDto> get skills;
/// Create a copy of CodexSkillsListEntryDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexSkillsListEntryDtoCopyWith<CodexSkillsListEntryDto> get copyWith => _$CodexSkillsListEntryDtoCopyWithImpl<CodexSkillsListEntryDto>(this as CodexSkillsListEntryDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexSkillsListEntryDto&&(identical(other.cwd, cwd) || other.cwd == cwd)&&const DeepCollectionEquality().equals(other.skills, skills));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,cwd,const DeepCollectionEquality().hash(skills));

@override
String toString() {
  return 'CodexSkillsListEntryDto(cwd: $cwd, skills: $skills)';
}


}

/// @nodoc
abstract mixin class $CodexSkillsListEntryDtoCopyWith<$Res>  {
  factory $CodexSkillsListEntryDtoCopyWith(CodexSkillsListEntryDto value, $Res Function(CodexSkillsListEntryDto) _then) = _$CodexSkillsListEntryDtoCopyWithImpl;
@useResult
$Res call({
 String cwd, List<CodexSkillDto> skills
});




}
/// @nodoc
class _$CodexSkillsListEntryDtoCopyWithImpl<$Res>
    implements $CodexSkillsListEntryDtoCopyWith<$Res> {
  _$CodexSkillsListEntryDtoCopyWithImpl(this._self, this._then);

  final CodexSkillsListEntryDto _self;
  final $Res Function(CodexSkillsListEntryDto) _then;

/// Create a copy of CodexSkillsListEntryDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? cwd = null,Object? skills = null,}) {
  return _then(_self.copyWith(
cwd: null == cwd ? _self.cwd : cwd // ignore: cast_nullable_to_non_nullable
as String,skills: null == skills ? _self.skills : skills // ignore: cast_nullable_to_non_nullable
as List<CodexSkillDto>,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CodexSkillsListEntryDto implements CodexSkillsListEntryDto {
  const _CodexSkillsListEntryDto({required this.cwd, required final  List<CodexSkillDto> skills}): _skills = skills;
  factory _CodexSkillsListEntryDto.fromJson(Map<String, dynamic> json) => _$CodexSkillsListEntryDtoFromJson(json);

@override final  String cwd;
 final  List<CodexSkillDto> _skills;
@override List<CodexSkillDto> get skills {
  if (_skills is EqualUnmodifiableListView) return _skills;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_skills);
}


/// Create a copy of CodexSkillsListEntryDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexSkillsListEntryDtoCopyWith<_CodexSkillsListEntryDto> get copyWith => __$CodexSkillsListEntryDtoCopyWithImpl<_CodexSkillsListEntryDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexSkillsListEntryDto&&(identical(other.cwd, cwd) || other.cwd == cwd)&&const DeepCollectionEquality().equals(other._skills, _skills));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,cwd,const DeepCollectionEquality().hash(_skills));

@override
String toString() {
  return 'CodexSkillsListEntryDto(cwd: $cwd, skills: $skills)';
}


}

/// @nodoc
abstract mixin class _$CodexSkillsListEntryDtoCopyWith<$Res> implements $CodexSkillsListEntryDtoCopyWith<$Res> {
  factory _$CodexSkillsListEntryDtoCopyWith(_CodexSkillsListEntryDto value, $Res Function(_CodexSkillsListEntryDto) _then) = __$CodexSkillsListEntryDtoCopyWithImpl;
@override @useResult
$Res call({
 String cwd, List<CodexSkillDto> skills
});




}
/// @nodoc
class __$CodexSkillsListEntryDtoCopyWithImpl<$Res>
    implements _$CodexSkillsListEntryDtoCopyWith<$Res> {
  __$CodexSkillsListEntryDtoCopyWithImpl(this._self, this._then);

  final _CodexSkillsListEntryDto _self;
  final $Res Function(_CodexSkillsListEntryDto) _then;

/// Create a copy of CodexSkillsListEntryDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? cwd = null,Object? skills = null,}) {
  return _then(_CodexSkillsListEntryDto(
cwd: null == cwd ? _self.cwd : cwd // ignore: cast_nullable_to_non_nullable
as String,skills: null == skills ? _self._skills : skills // ignore: cast_nullable_to_non_nullable
as List<CodexSkillDto>,
  ));
}


}


/// @nodoc
mixin _$CodexSkillDto {

 String get name; String get description; String? get shortDescription; CodexSkillInterfaceDto? get interface; bool get enabled;
/// Create a copy of CodexSkillDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexSkillDtoCopyWith<CodexSkillDto> get copyWith => _$CodexSkillDtoCopyWithImpl<CodexSkillDto>(this as CodexSkillDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexSkillDto&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.shortDescription, shortDescription) || other.shortDescription == shortDescription)&&(identical(other.interface, interface) || other.interface == interface)&&(identical(other.enabled, enabled) || other.enabled == enabled));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,description,shortDescription,interface,enabled);

@override
String toString() {
  return 'CodexSkillDto(name: $name, description: $description, shortDescription: $shortDescription, interface: $interface, enabled: $enabled)';
}


}

/// @nodoc
abstract mixin class $CodexSkillDtoCopyWith<$Res>  {
  factory $CodexSkillDtoCopyWith(CodexSkillDto value, $Res Function(CodexSkillDto) _then) = _$CodexSkillDtoCopyWithImpl;
@useResult
$Res call({
 String name, String description, String? shortDescription, CodexSkillInterfaceDto? interface, bool enabled
});


$CodexSkillInterfaceDtoCopyWith<$Res>? get interface;

}
/// @nodoc
class _$CodexSkillDtoCopyWithImpl<$Res>
    implements $CodexSkillDtoCopyWith<$Res> {
  _$CodexSkillDtoCopyWithImpl(this._self, this._then);

  final CodexSkillDto _self;
  final $Res Function(CodexSkillDto) _then;

/// Create a copy of CodexSkillDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? description = null,Object? shortDescription = freezed,Object? interface = freezed,Object? enabled = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,shortDescription: freezed == shortDescription ? _self.shortDescription : shortDescription // ignore: cast_nullable_to_non_nullable
as String?,interface: freezed == interface ? _self.interface : interface // ignore: cast_nullable_to_non_nullable
as CodexSkillInterfaceDto?,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of CodexSkillDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexSkillInterfaceDtoCopyWith<$Res>? get interface {
    if (_self.interface == null) {
    return null;
  }

  return $CodexSkillInterfaceDtoCopyWith<$Res>(_self.interface!, (value) {
    return _then(_self.copyWith(interface: value));
  });
}
}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CodexSkillDto implements CodexSkillDto {
  const _CodexSkillDto({required this.name, required this.description, required this.shortDescription, required this.interface, required this.enabled});
  factory _CodexSkillDto.fromJson(Map<String, dynamic> json) => _$CodexSkillDtoFromJson(json);

@override final  String name;
@override final  String description;
@override final  String? shortDescription;
@override final  CodexSkillInterfaceDto? interface;
@override final  bool enabled;

/// Create a copy of CodexSkillDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexSkillDtoCopyWith<_CodexSkillDto> get copyWith => __$CodexSkillDtoCopyWithImpl<_CodexSkillDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexSkillDto&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.shortDescription, shortDescription) || other.shortDescription == shortDescription)&&(identical(other.interface, interface) || other.interface == interface)&&(identical(other.enabled, enabled) || other.enabled == enabled));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,description,shortDescription,interface,enabled);

@override
String toString() {
  return 'CodexSkillDto(name: $name, description: $description, shortDescription: $shortDescription, interface: $interface, enabled: $enabled)';
}


}

/// @nodoc
abstract mixin class _$CodexSkillDtoCopyWith<$Res> implements $CodexSkillDtoCopyWith<$Res> {
  factory _$CodexSkillDtoCopyWith(_CodexSkillDto value, $Res Function(_CodexSkillDto) _then) = __$CodexSkillDtoCopyWithImpl;
@override @useResult
$Res call({
 String name, String description, String? shortDescription, CodexSkillInterfaceDto? interface, bool enabled
});


@override $CodexSkillInterfaceDtoCopyWith<$Res>? get interface;

}
/// @nodoc
class __$CodexSkillDtoCopyWithImpl<$Res>
    implements _$CodexSkillDtoCopyWith<$Res> {
  __$CodexSkillDtoCopyWithImpl(this._self, this._then);

  final _CodexSkillDto _self;
  final $Res Function(_CodexSkillDto) _then;

/// Create a copy of CodexSkillDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? description = null,Object? shortDescription = freezed,Object? interface = freezed,Object? enabled = null,}) {
  return _then(_CodexSkillDto(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,shortDescription: freezed == shortDescription ? _self.shortDescription : shortDescription // ignore: cast_nullable_to_non_nullable
as String?,interface: freezed == interface ? _self.interface : interface // ignore: cast_nullable_to_non_nullable
as CodexSkillInterfaceDto?,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of CodexSkillDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexSkillInterfaceDtoCopyWith<$Res>? get interface {
    if (_self.interface == null) {
    return null;
  }

  return $CodexSkillInterfaceDtoCopyWith<$Res>(_self.interface!, (value) {
    return _then(_self.copyWith(interface: value));
  });
}
}


/// @nodoc
mixin _$CodexSkillInterfaceDto {

 String? get shortDescription;
/// Create a copy of CodexSkillInterfaceDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexSkillInterfaceDtoCopyWith<CodexSkillInterfaceDto> get copyWith => _$CodexSkillInterfaceDtoCopyWithImpl<CodexSkillInterfaceDto>(this as CodexSkillInterfaceDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexSkillInterfaceDto&&(identical(other.shortDescription, shortDescription) || other.shortDescription == shortDescription));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,shortDescription);

@override
String toString() {
  return 'CodexSkillInterfaceDto(shortDescription: $shortDescription)';
}


}

/// @nodoc
abstract mixin class $CodexSkillInterfaceDtoCopyWith<$Res>  {
  factory $CodexSkillInterfaceDtoCopyWith(CodexSkillInterfaceDto value, $Res Function(CodexSkillInterfaceDto) _then) = _$CodexSkillInterfaceDtoCopyWithImpl;
@useResult
$Res call({
 String? shortDescription
});




}
/// @nodoc
class _$CodexSkillInterfaceDtoCopyWithImpl<$Res>
    implements $CodexSkillInterfaceDtoCopyWith<$Res> {
  _$CodexSkillInterfaceDtoCopyWithImpl(this._self, this._then);

  final CodexSkillInterfaceDto _self;
  final $Res Function(CodexSkillInterfaceDto) _then;

/// Create a copy of CodexSkillInterfaceDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? shortDescription = freezed,}) {
  return _then(_self.copyWith(
shortDescription: freezed == shortDescription ? _self.shortDescription : shortDescription // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CodexSkillInterfaceDto implements CodexSkillInterfaceDto {
  const _CodexSkillInterfaceDto({required this.shortDescription});
  factory _CodexSkillInterfaceDto.fromJson(Map<String, dynamic> json) => _$CodexSkillInterfaceDtoFromJson(json);

@override final  String? shortDescription;

/// Create a copy of CodexSkillInterfaceDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexSkillInterfaceDtoCopyWith<_CodexSkillInterfaceDto> get copyWith => __$CodexSkillInterfaceDtoCopyWithImpl<_CodexSkillInterfaceDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexSkillInterfaceDto&&(identical(other.shortDescription, shortDescription) || other.shortDescription == shortDescription));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,shortDescription);

@override
String toString() {
  return 'CodexSkillInterfaceDto(shortDescription: $shortDescription)';
}


}

/// @nodoc
abstract mixin class _$CodexSkillInterfaceDtoCopyWith<$Res> implements $CodexSkillInterfaceDtoCopyWith<$Res> {
  factory _$CodexSkillInterfaceDtoCopyWith(_CodexSkillInterfaceDto value, $Res Function(_CodexSkillInterfaceDto) _then) = __$CodexSkillInterfaceDtoCopyWithImpl;
@override @useResult
$Res call({
 String? shortDescription
});




}
/// @nodoc
class __$CodexSkillInterfaceDtoCopyWithImpl<$Res>
    implements _$CodexSkillInterfaceDtoCopyWith<$Res> {
  __$CodexSkillInterfaceDtoCopyWithImpl(this._self, this._then);

  final _CodexSkillInterfaceDto _self;
  final $Res Function(_CodexSkillInterfaceDto) _then;

/// Create a copy of CodexSkillInterfaceDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? shortDescription = freezed,}) {
  return _then(_CodexSkillInterfaceDto(
shortDescription: freezed == shortDescription ? _self.shortDescription : shortDescription // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
