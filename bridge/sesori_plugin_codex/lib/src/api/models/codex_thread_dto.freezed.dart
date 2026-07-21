// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'codex_thread_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CodexThreadEnvelopeDto {

 CodexThreadDto? get thread; String? get model; String? get modelProvider; String? get cwd;
/// Create a copy of CodexThreadEnvelopeDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexThreadEnvelopeDtoCopyWith<CodexThreadEnvelopeDto> get copyWith => _$CodexThreadEnvelopeDtoCopyWithImpl<CodexThreadEnvelopeDto>(this as CodexThreadEnvelopeDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexThreadEnvelopeDto&&(identical(other.thread, thread) || other.thread == thread)&&(identical(other.model, model) || other.model == model)&&(identical(other.modelProvider, modelProvider) || other.modelProvider == modelProvider)&&(identical(other.cwd, cwd) || other.cwd == cwd));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,thread,model,modelProvider,cwd);

@override
String toString() {
  return 'CodexThreadEnvelopeDto(thread: $thread, model: $model, modelProvider: $modelProvider, cwd: $cwd)';
}


}

/// @nodoc
abstract mixin class $CodexThreadEnvelopeDtoCopyWith<$Res>  {
  factory $CodexThreadEnvelopeDtoCopyWith(CodexThreadEnvelopeDto value, $Res Function(CodexThreadEnvelopeDto) _then) = _$CodexThreadEnvelopeDtoCopyWithImpl;
@useResult
$Res call({
 CodexThreadDto? thread, String? model, String? modelProvider, String? cwd
});


$CodexThreadDtoCopyWith<$Res>? get thread;

}
/// @nodoc
class _$CodexThreadEnvelopeDtoCopyWithImpl<$Res>
    implements $CodexThreadEnvelopeDtoCopyWith<$Res> {
  _$CodexThreadEnvelopeDtoCopyWithImpl(this._self, this._then);

  final CodexThreadEnvelopeDto _self;
  final $Res Function(CodexThreadEnvelopeDto) _then;

/// Create a copy of CodexThreadEnvelopeDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? thread = freezed,Object? model = freezed,Object? modelProvider = freezed,Object? cwd = freezed,}) {
  return _then(_self.copyWith(
thread: freezed == thread ? _self.thread : thread // ignore: cast_nullable_to_non_nullable
as CodexThreadDto?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,modelProvider: freezed == modelProvider ? _self.modelProvider : modelProvider // ignore: cast_nullable_to_non_nullable
as String?,cwd: freezed == cwd ? _self.cwd : cwd // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of CodexThreadEnvelopeDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexThreadDtoCopyWith<$Res>? get thread {
    if (_self.thread == null) {
    return null;
  }

  return $CodexThreadDtoCopyWith<$Res>(_self.thread!, (value) {
    return _then(_self.copyWith(thread: value));
  });
}
}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CodexThreadEnvelopeDto implements CodexThreadEnvelopeDto {
  const _CodexThreadEnvelopeDto({required this.thread, required this.model, required this.modelProvider, required this.cwd});
  factory _CodexThreadEnvelopeDto.fromJson(Map<String, dynamic> json) => _$CodexThreadEnvelopeDtoFromJson(json);

@override final  CodexThreadDto? thread;
@override final  String? model;
@override final  String? modelProvider;
@override final  String? cwd;

/// Create a copy of CodexThreadEnvelopeDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexThreadEnvelopeDtoCopyWith<_CodexThreadEnvelopeDto> get copyWith => __$CodexThreadEnvelopeDtoCopyWithImpl<_CodexThreadEnvelopeDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexThreadEnvelopeDto&&(identical(other.thread, thread) || other.thread == thread)&&(identical(other.model, model) || other.model == model)&&(identical(other.modelProvider, modelProvider) || other.modelProvider == modelProvider)&&(identical(other.cwd, cwd) || other.cwd == cwd));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,thread,model,modelProvider,cwd);

@override
String toString() {
  return 'CodexThreadEnvelopeDto(thread: $thread, model: $model, modelProvider: $modelProvider, cwd: $cwd)';
}


}

/// @nodoc
abstract mixin class _$CodexThreadEnvelopeDtoCopyWith<$Res> implements $CodexThreadEnvelopeDtoCopyWith<$Res> {
  factory _$CodexThreadEnvelopeDtoCopyWith(_CodexThreadEnvelopeDto value, $Res Function(_CodexThreadEnvelopeDto) _then) = __$CodexThreadEnvelopeDtoCopyWithImpl;
@override @useResult
$Res call({
 CodexThreadDto? thread, String? model, String? modelProvider, String? cwd
});


@override $CodexThreadDtoCopyWith<$Res>? get thread;

}
/// @nodoc
class __$CodexThreadEnvelopeDtoCopyWithImpl<$Res>
    implements _$CodexThreadEnvelopeDtoCopyWith<$Res> {
  __$CodexThreadEnvelopeDtoCopyWithImpl(this._self, this._then);

  final _CodexThreadEnvelopeDto _self;
  final $Res Function(_CodexThreadEnvelopeDto) _then;

/// Create a copy of CodexThreadEnvelopeDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? thread = freezed,Object? model = freezed,Object? modelProvider = freezed,Object? cwd = freezed,}) {
  return _then(_CodexThreadEnvelopeDto(
thread: freezed == thread ? _self.thread : thread // ignore: cast_nullable_to_non_nullable
as CodexThreadDto?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,modelProvider: freezed == modelProvider ? _self.modelProvider : modelProvider // ignore: cast_nullable_to_non_nullable
as String?,cwd: freezed == cwd ? _self.cwd : cwd // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of CodexThreadEnvelopeDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexThreadDtoCopyWith<$Res>? get thread {
    if (_self.thread == null) {
    return null;
  }

  return $CodexThreadDtoCopyWith<$Res>(_self.thread!, (value) {
    return _then(_self.copyWith(thread: value));
  });
}
}


/// @nodoc
mixin _$CodexThreadDto {

 String? get id; String? get name; String? get cwd; num? get createdAt; num? get updatedAt; String? get modelProvider; CodexThreadGitInfoDto? get gitInfo;
/// Create a copy of CodexThreadDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexThreadDtoCopyWith<CodexThreadDto> get copyWith => _$CodexThreadDtoCopyWithImpl<CodexThreadDto>(this as CodexThreadDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexThreadDto&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.cwd, cwd) || other.cwd == cwd)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.modelProvider, modelProvider) || other.modelProvider == modelProvider)&&(identical(other.gitInfo, gitInfo) || other.gitInfo == gitInfo));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,cwd,createdAt,updatedAt,modelProvider,gitInfo);

@override
String toString() {
  return 'CodexThreadDto(id: $id, name: $name, cwd: $cwd, createdAt: $createdAt, updatedAt: $updatedAt, modelProvider: $modelProvider, gitInfo: $gitInfo)';
}


}

/// @nodoc
abstract mixin class $CodexThreadDtoCopyWith<$Res>  {
  factory $CodexThreadDtoCopyWith(CodexThreadDto value, $Res Function(CodexThreadDto) _then) = _$CodexThreadDtoCopyWithImpl;
@useResult
$Res call({
 String? id, String? name, String? cwd, num? createdAt, num? updatedAt, String? modelProvider, CodexThreadGitInfoDto? gitInfo
});


$CodexThreadGitInfoDtoCopyWith<$Res>? get gitInfo;

}
/// @nodoc
class _$CodexThreadDtoCopyWithImpl<$Res>
    implements $CodexThreadDtoCopyWith<$Res> {
  _$CodexThreadDtoCopyWithImpl(this._self, this._then);

  final CodexThreadDto _self;
  final $Res Function(CodexThreadDto) _then;

/// Create a copy of CodexThreadDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? name = freezed,Object? cwd = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,Object? modelProvider = freezed,Object? gitInfo = freezed,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,cwd: freezed == cwd ? _self.cwd : cwd // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as num?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as num?,modelProvider: freezed == modelProvider ? _self.modelProvider : modelProvider // ignore: cast_nullable_to_non_nullable
as String?,gitInfo: freezed == gitInfo ? _self.gitInfo : gitInfo // ignore: cast_nullable_to_non_nullable
as CodexThreadGitInfoDto?,
  ));
}
/// Create a copy of CodexThreadDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexThreadGitInfoDtoCopyWith<$Res>? get gitInfo {
    if (_self.gitInfo == null) {
    return null;
  }

  return $CodexThreadGitInfoDtoCopyWith<$Res>(_self.gitInfo!, (value) {
    return _then(_self.copyWith(gitInfo: value));
  });
}
}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CodexThreadDto implements CodexThreadDto {
  const _CodexThreadDto({required this.id, required this.name, required this.cwd, required this.createdAt, required this.updatedAt, required this.modelProvider, required this.gitInfo});
  factory _CodexThreadDto.fromJson(Map<String, dynamic> json) => _$CodexThreadDtoFromJson(json);

@override final  String? id;
@override final  String? name;
@override final  String? cwd;
@override final  num? createdAt;
@override final  num? updatedAt;
@override final  String? modelProvider;
@override final  CodexThreadGitInfoDto? gitInfo;

/// Create a copy of CodexThreadDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexThreadDtoCopyWith<_CodexThreadDto> get copyWith => __$CodexThreadDtoCopyWithImpl<_CodexThreadDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexThreadDto&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.cwd, cwd) || other.cwd == cwd)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.modelProvider, modelProvider) || other.modelProvider == modelProvider)&&(identical(other.gitInfo, gitInfo) || other.gitInfo == gitInfo));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,cwd,createdAt,updatedAt,modelProvider,gitInfo);

@override
String toString() {
  return 'CodexThreadDto(id: $id, name: $name, cwd: $cwd, createdAt: $createdAt, updatedAt: $updatedAt, modelProvider: $modelProvider, gitInfo: $gitInfo)';
}


}

/// @nodoc
abstract mixin class _$CodexThreadDtoCopyWith<$Res> implements $CodexThreadDtoCopyWith<$Res> {
  factory _$CodexThreadDtoCopyWith(_CodexThreadDto value, $Res Function(_CodexThreadDto) _then) = __$CodexThreadDtoCopyWithImpl;
@override @useResult
$Res call({
 String? id, String? name, String? cwd, num? createdAt, num? updatedAt, String? modelProvider, CodexThreadGitInfoDto? gitInfo
});


@override $CodexThreadGitInfoDtoCopyWith<$Res>? get gitInfo;

}
/// @nodoc
class __$CodexThreadDtoCopyWithImpl<$Res>
    implements _$CodexThreadDtoCopyWith<$Res> {
  __$CodexThreadDtoCopyWithImpl(this._self, this._then);

  final _CodexThreadDto _self;
  final $Res Function(_CodexThreadDto) _then;

/// Create a copy of CodexThreadDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? name = freezed,Object? cwd = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,Object? modelProvider = freezed,Object? gitInfo = freezed,}) {
  return _then(_CodexThreadDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,cwd: freezed == cwd ? _self.cwd : cwd // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as num?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as num?,modelProvider: freezed == modelProvider ? _self.modelProvider : modelProvider // ignore: cast_nullable_to_non_nullable
as String?,gitInfo: freezed == gitInfo ? _self.gitInfo : gitInfo // ignore: cast_nullable_to_non_nullable
as CodexThreadGitInfoDto?,
  ));
}

/// Create a copy of CodexThreadDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexThreadGitInfoDtoCopyWith<$Res>? get gitInfo {
    if (_self.gitInfo == null) {
    return null;
  }

  return $CodexThreadGitInfoDtoCopyWith<$Res>(_self.gitInfo!, (value) {
    return _then(_self.copyWith(gitInfo: value));
  });
}
}


/// @nodoc
mixin _$CodexThreadGitInfoDto {

 String? get branch;
/// Create a copy of CodexThreadGitInfoDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexThreadGitInfoDtoCopyWith<CodexThreadGitInfoDto> get copyWith => _$CodexThreadGitInfoDtoCopyWithImpl<CodexThreadGitInfoDto>(this as CodexThreadGitInfoDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexThreadGitInfoDto&&(identical(other.branch, branch) || other.branch == branch));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,branch);

@override
String toString() {
  return 'CodexThreadGitInfoDto(branch: $branch)';
}


}

/// @nodoc
abstract mixin class $CodexThreadGitInfoDtoCopyWith<$Res>  {
  factory $CodexThreadGitInfoDtoCopyWith(CodexThreadGitInfoDto value, $Res Function(CodexThreadGitInfoDto) _then) = _$CodexThreadGitInfoDtoCopyWithImpl;
@useResult
$Res call({
 String? branch
});




}
/// @nodoc
class _$CodexThreadGitInfoDtoCopyWithImpl<$Res>
    implements $CodexThreadGitInfoDtoCopyWith<$Res> {
  _$CodexThreadGitInfoDtoCopyWithImpl(this._self, this._then);

  final CodexThreadGitInfoDto _self;
  final $Res Function(CodexThreadGitInfoDto) _then;

/// Create a copy of CodexThreadGitInfoDto
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

class _CodexThreadGitInfoDto implements CodexThreadGitInfoDto {
  const _CodexThreadGitInfoDto({required this.branch});
  factory _CodexThreadGitInfoDto.fromJson(Map<String, dynamic> json) => _$CodexThreadGitInfoDtoFromJson(json);

@override final  String? branch;

/// Create a copy of CodexThreadGitInfoDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexThreadGitInfoDtoCopyWith<_CodexThreadGitInfoDto> get copyWith => __$CodexThreadGitInfoDtoCopyWithImpl<_CodexThreadGitInfoDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexThreadGitInfoDto&&(identical(other.branch, branch) || other.branch == branch));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,branch);

@override
String toString() {
  return 'CodexThreadGitInfoDto(branch: $branch)';
}


}

/// @nodoc
abstract mixin class _$CodexThreadGitInfoDtoCopyWith<$Res> implements $CodexThreadGitInfoDtoCopyWith<$Res> {
  factory _$CodexThreadGitInfoDtoCopyWith(_CodexThreadGitInfoDto value, $Res Function(_CodexThreadGitInfoDto) _then) = __$CodexThreadGitInfoDtoCopyWithImpl;
@override @useResult
$Res call({
 String? branch
});




}
/// @nodoc
class __$CodexThreadGitInfoDtoCopyWithImpl<$Res>
    implements _$CodexThreadGitInfoDtoCopyWith<$Res> {
  __$CodexThreadGitInfoDtoCopyWithImpl(this._self, this._then);

  final _CodexThreadGitInfoDto _self;
  final $Res Function(_CodexThreadGitInfoDto) _then;

/// Create a copy of CodexThreadGitInfoDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? branch = freezed,}) {
  return _then(_CodexThreadGitInfoDto(
branch: freezed == branch ? _self.branch : branch // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
