// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'codex_rollout_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CodexRolloutLineDto {

 String? get type; CodexRolloutPayloadDto? get payload;
/// Create a copy of CodexRolloutLineDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexRolloutLineDtoCopyWith<CodexRolloutLineDto> get copyWith => _$CodexRolloutLineDtoCopyWithImpl<CodexRolloutLineDto>(this as CodexRolloutLineDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexRolloutLineDto&&(identical(other.type, type) || other.type == type)&&(identical(other.payload, payload) || other.payload == payload));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,payload);

@override
String toString() {
  return 'CodexRolloutLineDto(type: $type, payload: $payload)';
}


}

/// @nodoc
abstract mixin class $CodexRolloutLineDtoCopyWith<$Res>  {
  factory $CodexRolloutLineDtoCopyWith(CodexRolloutLineDto value, $Res Function(CodexRolloutLineDto) _then) = _$CodexRolloutLineDtoCopyWithImpl;
@useResult
$Res call({
 String? type, CodexRolloutPayloadDto? payload
});


$CodexRolloutPayloadDtoCopyWith<$Res>? get payload;

}
/// @nodoc
class _$CodexRolloutLineDtoCopyWithImpl<$Res>
    implements $CodexRolloutLineDtoCopyWith<$Res> {
  _$CodexRolloutLineDtoCopyWithImpl(this._self, this._then);

  final CodexRolloutLineDto _self;
  final $Res Function(CodexRolloutLineDto) _then;

/// Create a copy of CodexRolloutLineDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = freezed,Object? payload = freezed,}) {
  return _then(_self.copyWith(
type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String?,payload: freezed == payload ? _self.payload : payload // ignore: cast_nullable_to_non_nullable
as CodexRolloutPayloadDto?,
  ));
}
/// Create a copy of CodexRolloutLineDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexRolloutPayloadDtoCopyWith<$Res>? get payload {
    if (_self.payload == null) {
    return null;
  }

  return $CodexRolloutPayloadDtoCopyWith<$Res>(_self.payload!, (value) {
    return _then(_self.copyWith(payload: value));
  });
}
}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CodexRolloutLineDto implements CodexRolloutLineDto {
  const _CodexRolloutLineDto({required this.type, required this.payload});
  factory _CodexRolloutLineDto.fromJson(Map<String, dynamic> json) => _$CodexRolloutLineDtoFromJson(json);

@override final  String? type;
@override final  CodexRolloutPayloadDto? payload;

/// Create a copy of CodexRolloutLineDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexRolloutLineDtoCopyWith<_CodexRolloutLineDto> get copyWith => __$CodexRolloutLineDtoCopyWithImpl<_CodexRolloutLineDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexRolloutLineDto&&(identical(other.type, type) || other.type == type)&&(identical(other.payload, payload) || other.payload == payload));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,payload);

@override
String toString() {
  return 'CodexRolloutLineDto(type: $type, payload: $payload)';
}


}

/// @nodoc
abstract mixin class _$CodexRolloutLineDtoCopyWith<$Res> implements $CodexRolloutLineDtoCopyWith<$Res> {
  factory _$CodexRolloutLineDtoCopyWith(_CodexRolloutLineDto value, $Res Function(_CodexRolloutLineDto) _then) = __$CodexRolloutLineDtoCopyWithImpl;
@override @useResult
$Res call({
 String? type, CodexRolloutPayloadDto? payload
});


@override $CodexRolloutPayloadDtoCopyWith<$Res>? get payload;

}
/// @nodoc
class __$CodexRolloutLineDtoCopyWithImpl<$Res>
    implements _$CodexRolloutLineDtoCopyWith<$Res> {
  __$CodexRolloutLineDtoCopyWithImpl(this._self, this._then);

  final _CodexRolloutLineDto _self;
  final $Res Function(_CodexRolloutLineDto) _then;

/// Create a copy of CodexRolloutLineDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = freezed,Object? payload = freezed,}) {
  return _then(_CodexRolloutLineDto(
type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String?,payload: freezed == payload ? _self.payload : payload // ignore: cast_nullable_to_non_nullable
as CodexRolloutPayloadDto?,
  ));
}

/// Create a copy of CodexRolloutLineDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexRolloutPayloadDtoCopyWith<$Res>? get payload {
    if (_self.payload == null) {
    return null;
  }

  return $CodexRolloutPayloadDtoCopyWith<$Res>(_self.payload!, (value) {
    return _then(_self.copyWith(payload: value));
  });
}
}


/// @nodoc
mixin _$CodexRolloutPayloadDto {

 String? get id; String? get cwd; String? get timestamp;@JsonKey(name: "model_provider") String? get modelProvider;@JsonKey(name: "cli_version") String? get cliVersion; String? get model; CodexRolloutGitDto? get git;
/// Create a copy of CodexRolloutPayloadDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexRolloutPayloadDtoCopyWith<CodexRolloutPayloadDto> get copyWith => _$CodexRolloutPayloadDtoCopyWithImpl<CodexRolloutPayloadDto>(this as CodexRolloutPayloadDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexRolloutPayloadDto&&(identical(other.id, id) || other.id == id)&&(identical(other.cwd, cwd) || other.cwd == cwd)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.modelProvider, modelProvider) || other.modelProvider == modelProvider)&&(identical(other.cliVersion, cliVersion) || other.cliVersion == cliVersion)&&(identical(other.model, model) || other.model == model)&&(identical(other.git, git) || other.git == git));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,cwd,timestamp,modelProvider,cliVersion,model,git);

@override
String toString() {
  return 'CodexRolloutPayloadDto(id: $id, cwd: $cwd, timestamp: $timestamp, modelProvider: $modelProvider, cliVersion: $cliVersion, model: $model, git: $git)';
}


}

/// @nodoc
abstract mixin class $CodexRolloutPayloadDtoCopyWith<$Res>  {
  factory $CodexRolloutPayloadDtoCopyWith(CodexRolloutPayloadDto value, $Res Function(CodexRolloutPayloadDto) _then) = _$CodexRolloutPayloadDtoCopyWithImpl;
@useResult
$Res call({
 String? id, String? cwd, String? timestamp,@JsonKey(name: "model_provider") String? modelProvider,@JsonKey(name: "cli_version") String? cliVersion, String? model, CodexRolloutGitDto? git
});


$CodexRolloutGitDtoCopyWith<$Res>? get git;

}
/// @nodoc
class _$CodexRolloutPayloadDtoCopyWithImpl<$Res>
    implements $CodexRolloutPayloadDtoCopyWith<$Res> {
  _$CodexRolloutPayloadDtoCopyWithImpl(this._self, this._then);

  final CodexRolloutPayloadDto _self;
  final $Res Function(CodexRolloutPayloadDto) _then;

/// Create a copy of CodexRolloutPayloadDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? cwd = freezed,Object? timestamp = freezed,Object? modelProvider = freezed,Object? cliVersion = freezed,Object? model = freezed,Object? git = freezed,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,cwd: freezed == cwd ? _self.cwd : cwd // ignore: cast_nullable_to_non_nullable
as String?,timestamp: freezed == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as String?,modelProvider: freezed == modelProvider ? _self.modelProvider : modelProvider // ignore: cast_nullable_to_non_nullable
as String?,cliVersion: freezed == cliVersion ? _self.cliVersion : cliVersion // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,git: freezed == git ? _self.git : git // ignore: cast_nullable_to_non_nullable
as CodexRolloutGitDto?,
  ));
}
/// Create a copy of CodexRolloutPayloadDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexRolloutGitDtoCopyWith<$Res>? get git {
    if (_self.git == null) {
    return null;
  }

  return $CodexRolloutGitDtoCopyWith<$Res>(_self.git!, (value) {
    return _then(_self.copyWith(git: value));
  });
}
}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CodexRolloutPayloadDto implements CodexRolloutPayloadDto {
  const _CodexRolloutPayloadDto({required this.id, required this.cwd, required this.timestamp, @JsonKey(name: "model_provider") required this.modelProvider, @JsonKey(name: "cli_version") required this.cliVersion, required this.model, required this.git});
  factory _CodexRolloutPayloadDto.fromJson(Map<String, dynamic> json) => _$CodexRolloutPayloadDtoFromJson(json);

@override final  String? id;
@override final  String? cwd;
@override final  String? timestamp;
@override@JsonKey(name: "model_provider") final  String? modelProvider;
@override@JsonKey(name: "cli_version") final  String? cliVersion;
@override final  String? model;
@override final  CodexRolloutGitDto? git;

/// Create a copy of CodexRolloutPayloadDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexRolloutPayloadDtoCopyWith<_CodexRolloutPayloadDto> get copyWith => __$CodexRolloutPayloadDtoCopyWithImpl<_CodexRolloutPayloadDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexRolloutPayloadDto&&(identical(other.id, id) || other.id == id)&&(identical(other.cwd, cwd) || other.cwd == cwd)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.modelProvider, modelProvider) || other.modelProvider == modelProvider)&&(identical(other.cliVersion, cliVersion) || other.cliVersion == cliVersion)&&(identical(other.model, model) || other.model == model)&&(identical(other.git, git) || other.git == git));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,cwd,timestamp,modelProvider,cliVersion,model,git);

@override
String toString() {
  return 'CodexRolloutPayloadDto(id: $id, cwd: $cwd, timestamp: $timestamp, modelProvider: $modelProvider, cliVersion: $cliVersion, model: $model, git: $git)';
}


}

/// @nodoc
abstract mixin class _$CodexRolloutPayloadDtoCopyWith<$Res> implements $CodexRolloutPayloadDtoCopyWith<$Res> {
  factory _$CodexRolloutPayloadDtoCopyWith(_CodexRolloutPayloadDto value, $Res Function(_CodexRolloutPayloadDto) _then) = __$CodexRolloutPayloadDtoCopyWithImpl;
@override @useResult
$Res call({
 String? id, String? cwd, String? timestamp,@JsonKey(name: "model_provider") String? modelProvider,@JsonKey(name: "cli_version") String? cliVersion, String? model, CodexRolloutGitDto? git
});


@override $CodexRolloutGitDtoCopyWith<$Res>? get git;

}
/// @nodoc
class __$CodexRolloutPayloadDtoCopyWithImpl<$Res>
    implements _$CodexRolloutPayloadDtoCopyWith<$Res> {
  __$CodexRolloutPayloadDtoCopyWithImpl(this._self, this._then);

  final _CodexRolloutPayloadDto _self;
  final $Res Function(_CodexRolloutPayloadDto) _then;

/// Create a copy of CodexRolloutPayloadDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? cwd = freezed,Object? timestamp = freezed,Object? modelProvider = freezed,Object? cliVersion = freezed,Object? model = freezed,Object? git = freezed,}) {
  return _then(_CodexRolloutPayloadDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,cwd: freezed == cwd ? _self.cwd : cwd // ignore: cast_nullable_to_non_nullable
as String?,timestamp: freezed == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as String?,modelProvider: freezed == modelProvider ? _self.modelProvider : modelProvider // ignore: cast_nullable_to_non_nullable
as String?,cliVersion: freezed == cliVersion ? _self.cliVersion : cliVersion // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,git: freezed == git ? _self.git : git // ignore: cast_nullable_to_non_nullable
as CodexRolloutGitDto?,
  ));
}

/// Create a copy of CodexRolloutPayloadDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexRolloutGitDtoCopyWith<$Res>? get git {
    if (_self.git == null) {
    return null;
  }

  return $CodexRolloutGitDtoCopyWith<$Res>(_self.git!, (value) {
    return _then(_self.copyWith(git: value));
  });
}
}


/// @nodoc
mixin _$CodexRolloutGitDto {

 String? get branch;
/// Create a copy of CodexRolloutGitDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexRolloutGitDtoCopyWith<CodexRolloutGitDto> get copyWith => _$CodexRolloutGitDtoCopyWithImpl<CodexRolloutGitDto>(this as CodexRolloutGitDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexRolloutGitDto&&(identical(other.branch, branch) || other.branch == branch));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,branch);

@override
String toString() {
  return 'CodexRolloutGitDto(branch: $branch)';
}


}

/// @nodoc
abstract mixin class $CodexRolloutGitDtoCopyWith<$Res>  {
  factory $CodexRolloutGitDtoCopyWith(CodexRolloutGitDto value, $Res Function(CodexRolloutGitDto) _then) = _$CodexRolloutGitDtoCopyWithImpl;
@useResult
$Res call({
 String? branch
});




}
/// @nodoc
class _$CodexRolloutGitDtoCopyWithImpl<$Res>
    implements $CodexRolloutGitDtoCopyWith<$Res> {
  _$CodexRolloutGitDtoCopyWithImpl(this._self, this._then);

  final CodexRolloutGitDto _self;
  final $Res Function(CodexRolloutGitDto) _then;

/// Create a copy of CodexRolloutGitDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? branch = freezed,}) {
  return _then(_self.copyWith(
branch: freezed == branch ? _self.branch : branch // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CodexRolloutGitDto implements CodexRolloutGitDto {
  const _CodexRolloutGitDto({required this.branch});
  factory _CodexRolloutGitDto.fromJson(Map<String, dynamic> json) => _$CodexRolloutGitDtoFromJson(json);

@override final  String? branch;

/// Create a copy of CodexRolloutGitDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexRolloutGitDtoCopyWith<_CodexRolloutGitDto> get copyWith => __$CodexRolloutGitDtoCopyWithImpl<_CodexRolloutGitDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexRolloutGitDto&&(identical(other.branch, branch) || other.branch == branch));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,branch);

@override
String toString() {
  return 'CodexRolloutGitDto(branch: $branch)';
}


}

/// @nodoc
abstract mixin class _$CodexRolloutGitDtoCopyWith<$Res> implements $CodexRolloutGitDtoCopyWith<$Res> {
  factory _$CodexRolloutGitDtoCopyWith(_CodexRolloutGitDto value, $Res Function(_CodexRolloutGitDto) _then) = __$CodexRolloutGitDtoCopyWithImpl;
@override @useResult
$Res call({
 String? branch
});




}
/// @nodoc
class __$CodexRolloutGitDtoCopyWithImpl<$Res>
    implements _$CodexRolloutGitDtoCopyWith<$Res> {
  __$CodexRolloutGitDtoCopyWithImpl(this._self, this._then);

  final _CodexRolloutGitDto _self;
  final $Res Function(_CodexRolloutGitDto) _then;

/// Create a copy of CodexRolloutGitDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? branch = freezed,}) {
  return _then(_CodexRolloutGitDto(
branch: freezed == branch ? _self.branch : branch // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
