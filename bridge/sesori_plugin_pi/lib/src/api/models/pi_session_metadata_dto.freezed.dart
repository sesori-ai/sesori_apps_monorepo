// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pi_session_metadata_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
PiSessionMetadataDto _$PiSessionMetadataDtoFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'session':
          return PiSessionHeaderDto.fromJson(
            json
          );
                case 'session_info':
          return PiSessionInfoDto.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'type',
  'PiSessionMetadataDto',
  'Invalid union type "${json['type']}"!'
);
        }
      
}

/// @nodoc
mixin _$PiSessionMetadataDto {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiSessionMetadataDto);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;



}

/// @nodoc
class $PiSessionMetadataDtoCopyWith<$Res>  {
$PiSessionMetadataDtoCopyWith(PiSessionMetadataDto _, $Res Function(PiSessionMetadataDto) __);
}



/// @nodoc
@JsonSerializable(createToJson: false)

class PiSessionHeaderDto implements PiSessionMetadataDto {
  const PiSessionHeaderDto({@JsonKey(fromJson: _intOrNull) required this.version, @JsonKey(fromJson: _stringOrNull) required this.id, @JsonKey(fromJson: _timestampOrNull) required this.timestamp, @JsonKey(fromJson: _stringOrNull) required this.cwd, @JsonKey(fromJson: _stringOrNull) required this.parentSession,  String? $type}): $type = $type ?? 'session';
  factory PiSessionHeaderDto.fromJson(Map<String, dynamic> json) => _$PiSessionHeaderDtoFromJson(json);

@JsonKey(fromJson: _intOrNull) final  int? version;
@JsonKey(fromJson: _stringOrNull) final  String? id;
@JsonKey(fromJson: _timestampOrNull) final  DateTime? timestamp;
@JsonKey(fromJson: _stringOrNull) final  String? cwd;
@JsonKey(fromJson: _stringOrNull) final  String? parentSession;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of PiSessionMetadataDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiSessionHeaderDtoCopyWith<PiSessionHeaderDto> get copyWith => _$PiSessionHeaderDtoCopyWithImpl<PiSessionHeaderDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiSessionHeaderDto&&(identical(other.version, version) || other.version == version)&&(identical(other.id, id) || other.id == id)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.cwd, cwd) || other.cwd == cwd)&&(identical(other.parentSession, parentSession) || other.parentSession == parentSession));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,version,id,timestamp,cwd,parentSession);



}

/// @nodoc
abstract mixin class $PiSessionHeaderDtoCopyWith<$Res> implements $PiSessionMetadataDtoCopyWith<$Res> {
  factory $PiSessionHeaderDtoCopyWith(PiSessionHeaderDto value, $Res Function(PiSessionHeaderDto) _then) = _$PiSessionHeaderDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _intOrNull) int? version,@JsonKey(fromJson: _stringOrNull) String? id,@JsonKey(fromJson: _timestampOrNull) DateTime? timestamp,@JsonKey(fromJson: _stringOrNull) String? cwd,@JsonKey(fromJson: _stringOrNull) String? parentSession
});




}
/// @nodoc
class _$PiSessionHeaderDtoCopyWithImpl<$Res>
    implements $PiSessionHeaderDtoCopyWith<$Res> {
  _$PiSessionHeaderDtoCopyWithImpl(this._self, this._then);

  final PiSessionHeaderDto _self;
  final $Res Function(PiSessionHeaderDto) _then;

/// Create a copy of PiSessionMetadataDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? version = freezed,Object? id = freezed,Object? timestamp = freezed,Object? cwd = freezed,Object? parentSession = freezed,}) {
  return _then(PiSessionHeaderDto(
version: freezed == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int?,id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,timestamp: freezed == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime?,cwd: freezed == cwd ? _self.cwd : cwd // ignore: cast_nullable_to_non_nullable
as String?,parentSession: freezed == parentSession ? _self.parentSession : parentSession // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class PiSessionInfoDto implements PiSessionMetadataDto {
  const PiSessionInfoDto({@JsonKey(fromJson: _strictNullableString) required this.name,  String? $type}): $type = $type ?? 'session_info';
  factory PiSessionInfoDto.fromJson(Map<String, dynamic> json) => _$PiSessionInfoDtoFromJson(json);

@JsonKey(fromJson: _strictNullableString) final  String? name;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of PiSessionMetadataDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiSessionInfoDtoCopyWith<PiSessionInfoDto> get copyWith => _$PiSessionInfoDtoCopyWithImpl<PiSessionInfoDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiSessionInfoDto&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name);



}

/// @nodoc
abstract mixin class $PiSessionInfoDtoCopyWith<$Res> implements $PiSessionMetadataDtoCopyWith<$Res> {
  factory $PiSessionInfoDtoCopyWith(PiSessionInfoDto value, $Res Function(PiSessionInfoDto) _then) = _$PiSessionInfoDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _strictNullableString) String? name
});




}
/// @nodoc
class _$PiSessionInfoDtoCopyWithImpl<$Res>
    implements $PiSessionInfoDtoCopyWith<$Res> {
  _$PiSessionInfoDtoCopyWithImpl(this._self, this._then);

  final PiSessionInfoDto _self;
  final $Res Function(PiSessionInfoDto) _then;

/// Create a copy of PiSessionMetadataDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? name = freezed,}) {
  return _then(PiSessionInfoDto(
name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$PiSettingsDto {

@JsonKey(fromJson: _stringOrNull) String? get sessionDir;
/// Create a copy of PiSettingsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiSettingsDtoCopyWith<PiSettingsDto> get copyWith => _$PiSettingsDtoCopyWithImpl<PiSettingsDto>(this as PiSettingsDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiSettingsDto&&(identical(other.sessionDir, sessionDir) || other.sessionDir == sessionDir));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionDir);



}

/// @nodoc
abstract mixin class $PiSettingsDtoCopyWith<$Res>  {
  factory $PiSettingsDtoCopyWith(PiSettingsDto value, $Res Function(PiSettingsDto) _then) = _$PiSettingsDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _stringOrNull) String? sessionDir
});




}
/// @nodoc
class _$PiSettingsDtoCopyWithImpl<$Res>
    implements $PiSettingsDtoCopyWith<$Res> {
  _$PiSettingsDtoCopyWithImpl(this._self, this._then);

  final PiSettingsDto _self;
  final $Res Function(PiSettingsDto) _then;

/// Create a copy of PiSettingsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionDir = freezed,}) {
  return _then(PiSettingsDto(
sessionDir: freezed == sessionDir ? _self.sessionDir : sessionDir // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _PiSettingsDto implements PiSettingsDto {
  const _PiSettingsDto({@JsonKey(fromJson: _stringOrNull) required this.sessionDir});
  factory _PiSettingsDto.fromJson(Map<String, dynamic> json) => _$PiSettingsDtoFromJson(json);

@override@JsonKey(fromJson: _stringOrNull) final  String? sessionDir;

/// Create a copy of PiSettingsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PiSettingsDtoCopyWith<_PiSettingsDto> get copyWith => __$PiSettingsDtoCopyWithImpl<_PiSettingsDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PiSettingsDto&&(identical(other.sessionDir, sessionDir) || other.sessionDir == sessionDir));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionDir);



}

/// @nodoc
abstract mixin class _$PiSettingsDtoCopyWith<$Res> implements $PiSettingsDtoCopyWith<$Res> {
  factory _$PiSettingsDtoCopyWith(_PiSettingsDto value, $Res Function(_PiSettingsDto) _then) = __$PiSettingsDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _stringOrNull) String? sessionDir
});




}
/// @nodoc
class __$PiSettingsDtoCopyWithImpl<$Res>
    implements _$PiSettingsDtoCopyWith<$Res> {
  __$PiSettingsDtoCopyWithImpl(this._self, this._then);

  final _PiSettingsDto _self;
  final $Res Function(_PiSettingsDto) _then;

/// Create a copy of PiSettingsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionDir = freezed,}) {
  return _then(_PiSettingsDto(
sessionDir: freezed == sessionDir ? _self.sessionDir : sessionDir // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
