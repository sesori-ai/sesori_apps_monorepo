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
mixin _$CodexSessionIndexEntryDto {

 String? get id;@JsonKey(name: "thread_name") String? get threadName;@JsonKey(name: "updated_at") String? get updatedAt;
/// Create a copy of CodexSessionIndexEntryDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexSessionIndexEntryDtoCopyWith<CodexSessionIndexEntryDto> get copyWith => _$CodexSessionIndexEntryDtoCopyWithImpl<CodexSessionIndexEntryDto>(this as CodexSessionIndexEntryDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexSessionIndexEntryDto&&(identical(other.id, id) || other.id == id)&&(identical(other.threadName, threadName) || other.threadName == threadName)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,threadName,updatedAt);

@override
String toString() {
  return 'CodexSessionIndexEntryDto(id: $id, threadName: $threadName, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $CodexSessionIndexEntryDtoCopyWith<$Res>  {
  factory $CodexSessionIndexEntryDtoCopyWith(CodexSessionIndexEntryDto value, $Res Function(CodexSessionIndexEntryDto) _then) = _$CodexSessionIndexEntryDtoCopyWithImpl;
@useResult
$Res call({
 String? id,@JsonKey(name: "thread_name") String? threadName,@JsonKey(name: "updated_at") String? updatedAt
});




}
/// @nodoc
class _$CodexSessionIndexEntryDtoCopyWithImpl<$Res>
    implements $CodexSessionIndexEntryDtoCopyWith<$Res> {
  _$CodexSessionIndexEntryDtoCopyWithImpl(this._self, this._then);

  final CodexSessionIndexEntryDto _self;
  final $Res Function(CodexSessionIndexEntryDto) _then;

/// Create a copy of CodexSessionIndexEntryDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? threadName = freezed,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,threadName: freezed == threadName ? _self.threadName : threadName // ignore: cast_nullable_to_non_nullable
as String?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CodexSessionIndexEntryDto implements CodexSessionIndexEntryDto {
  const _CodexSessionIndexEntryDto({required this.id, @JsonKey(name: "thread_name") required this.threadName, @JsonKey(name: "updated_at") required this.updatedAt});
  factory _CodexSessionIndexEntryDto.fromJson(Map<String, dynamic> json) => _$CodexSessionIndexEntryDtoFromJson(json);

@override final  String? id;
@override@JsonKey(name: "thread_name") final  String? threadName;
@override@JsonKey(name: "updated_at") final  String? updatedAt;

/// Create a copy of CodexSessionIndexEntryDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexSessionIndexEntryDtoCopyWith<_CodexSessionIndexEntryDto> get copyWith => __$CodexSessionIndexEntryDtoCopyWithImpl<_CodexSessionIndexEntryDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexSessionIndexEntryDto&&(identical(other.id, id) || other.id == id)&&(identical(other.threadName, threadName) || other.threadName == threadName)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,threadName,updatedAt);

@override
String toString() {
  return 'CodexSessionIndexEntryDto(id: $id, threadName: $threadName, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$CodexSessionIndexEntryDtoCopyWith<$Res> implements $CodexSessionIndexEntryDtoCopyWith<$Res> {
  factory _$CodexSessionIndexEntryDtoCopyWith(_CodexSessionIndexEntryDto value, $Res Function(_CodexSessionIndexEntryDto) _then) = __$CodexSessionIndexEntryDtoCopyWithImpl;
@override @useResult
$Res call({
 String? id,@JsonKey(name: "thread_name") String? threadName,@JsonKey(name: "updated_at") String? updatedAt
});




}
/// @nodoc
class __$CodexSessionIndexEntryDtoCopyWithImpl<$Res>
    implements _$CodexSessionIndexEntryDtoCopyWith<$Res> {
  __$CodexSessionIndexEntryDtoCopyWithImpl(this._self, this._then);

  final _CodexSessionIndexEntryDto _self;
  final $Res Function(_CodexSessionIndexEntryDto) _then;

/// Create a copy of CodexSessionIndexEntryDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? threadName = freezed,Object? updatedAt = freezed,}) {
  return _then(_CodexSessionIndexEntryDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,threadName: freezed == threadName ? _self.threadName : threadName // ignore: cast_nullable_to_non_nullable
as String?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$CodexRolloutLineDto {

 String? get timestamp;@JsonKey(unknownEnumValue: CodexRolloutLineType.unknown) CodexRolloutLineType? get type; CodexRolloutPayloadDto? get payload;
/// Create a copy of CodexRolloutLineDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexRolloutLineDtoCopyWith<CodexRolloutLineDto> get copyWith => _$CodexRolloutLineDtoCopyWithImpl<CodexRolloutLineDto>(this as CodexRolloutLineDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexRolloutLineDto&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.type, type) || other.type == type)&&(identical(other.payload, payload) || other.payload == payload));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,timestamp,type,payload);

@override
String toString() {
  return 'CodexRolloutLineDto(timestamp: $timestamp, type: $type, payload: $payload)';
}


}

/// @nodoc
abstract mixin class $CodexRolloutLineDtoCopyWith<$Res>  {
  factory $CodexRolloutLineDtoCopyWith(CodexRolloutLineDto value, $Res Function(CodexRolloutLineDto) _then) = _$CodexRolloutLineDtoCopyWithImpl;
@useResult
$Res call({
 String? timestamp,@JsonKey(unknownEnumValue: CodexRolloutLineType.unknown) CodexRolloutLineType? type, CodexRolloutPayloadDto? payload
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
@pragma('vm:prefer-inline') @override $Res call({Object? timestamp = freezed,Object? type = freezed,Object? payload = freezed,}) {
  return _then(_self.copyWith(
timestamp: freezed == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as String?,type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as CodexRolloutLineType?,payload: freezed == payload ? _self.payload : payload // ignore: cast_nullable_to_non_nullable
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
  const _CodexRolloutLineDto({required this.timestamp, @JsonKey(unknownEnumValue: CodexRolloutLineType.unknown) required this.type, required this.payload});
  factory _CodexRolloutLineDto.fromJson(Map<String, dynamic> json) => _$CodexRolloutLineDtoFromJson(json);

@override final  String? timestamp;
@override@JsonKey(unknownEnumValue: CodexRolloutLineType.unknown) final  CodexRolloutLineType? type;
@override final  CodexRolloutPayloadDto? payload;

/// Create a copy of CodexRolloutLineDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexRolloutLineDtoCopyWith<_CodexRolloutLineDto> get copyWith => __$CodexRolloutLineDtoCopyWithImpl<_CodexRolloutLineDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexRolloutLineDto&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.type, type) || other.type == type)&&(identical(other.payload, payload) || other.payload == payload));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,timestamp,type,payload);

@override
String toString() {
  return 'CodexRolloutLineDto(timestamp: $timestamp, type: $type, payload: $payload)';
}


}

/// @nodoc
abstract mixin class _$CodexRolloutLineDtoCopyWith<$Res> implements $CodexRolloutLineDtoCopyWith<$Res> {
  factory _$CodexRolloutLineDtoCopyWith(_CodexRolloutLineDto value, $Res Function(_CodexRolloutLineDto) _then) = __$CodexRolloutLineDtoCopyWithImpl;
@override @useResult
$Res call({
 String? timestamp,@JsonKey(unknownEnumValue: CodexRolloutLineType.unknown) CodexRolloutLineType? type, CodexRolloutPayloadDto? payload
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
@override @pragma('vm:prefer-inline') $Res call({Object? timestamp = freezed,Object? type = freezed,Object? payload = freezed,}) {
  return _then(_CodexRolloutLineDto(
timestamp: freezed == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as String?,type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as CodexRolloutLineType?,payload: freezed == payload ? _self.payload : payload // ignore: cast_nullable_to_non_nullable
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

 String? get id; String? get cwd; String? get timestamp;@JsonKey(name: "model_provider") String? get modelProvider;@JsonKey(name: "cli_version") String? get cliVersion; String? get model; CodexRolloutGitDto? get git;@JsonKey(unknownEnumValue: CodexRolloutPayloadType.unknown) CodexRolloutPayloadType? get type;@JsonKey(unknownEnumValue: CodexRolloutRole.unknown) CodexRolloutRole? get role; List<CodexRolloutContentDto>? get content;@JsonKey(name: "call_id") String? get callId; String? get name; String? get arguments; String? get output; CodexRolloutActionDto? get action;
/// Create a copy of CodexRolloutPayloadDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexRolloutPayloadDtoCopyWith<CodexRolloutPayloadDto> get copyWith => _$CodexRolloutPayloadDtoCopyWithImpl<CodexRolloutPayloadDto>(this as CodexRolloutPayloadDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexRolloutPayloadDto&&(identical(other.id, id) || other.id == id)&&(identical(other.cwd, cwd) || other.cwd == cwd)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.modelProvider, modelProvider) || other.modelProvider == modelProvider)&&(identical(other.cliVersion, cliVersion) || other.cliVersion == cliVersion)&&(identical(other.model, model) || other.model == model)&&(identical(other.git, git) || other.git == git)&&(identical(other.type, type) || other.type == type)&&(identical(other.role, role) || other.role == role)&&const DeepCollectionEquality().equals(other.content, content)&&(identical(other.callId, callId) || other.callId == callId)&&(identical(other.name, name) || other.name == name)&&(identical(other.arguments, arguments) || other.arguments == arguments)&&(identical(other.output, output) || other.output == output)&&(identical(other.action, action) || other.action == action));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,cwd,timestamp,modelProvider,cliVersion,model,git,type,role,const DeepCollectionEquality().hash(content),callId,name,arguments,output,action);

@override
String toString() {
  return 'CodexRolloutPayloadDto(id: $id, cwd: $cwd, timestamp: $timestamp, modelProvider: $modelProvider, cliVersion: $cliVersion, model: $model, git: $git, type: $type, role: $role, content: $content, callId: $callId, name: $name, arguments: $arguments, output: $output, action: $action)';
}


}

/// @nodoc
abstract mixin class $CodexRolloutPayloadDtoCopyWith<$Res>  {
  factory $CodexRolloutPayloadDtoCopyWith(CodexRolloutPayloadDto value, $Res Function(CodexRolloutPayloadDto) _then) = _$CodexRolloutPayloadDtoCopyWithImpl;
@useResult
$Res call({
 String? id, String? cwd, String? timestamp,@JsonKey(name: "model_provider") String? modelProvider,@JsonKey(name: "cli_version") String? cliVersion, String? model, CodexRolloutGitDto? git,@JsonKey(unknownEnumValue: CodexRolloutPayloadType.unknown) CodexRolloutPayloadType? type,@JsonKey(unknownEnumValue: CodexRolloutRole.unknown) CodexRolloutRole? role, List<CodexRolloutContentDto>? content,@JsonKey(name: "call_id") String? callId, String? name, String? arguments, String? output, CodexRolloutActionDto? action
});


$CodexRolloutGitDtoCopyWith<$Res>? get git;$CodexRolloutActionDtoCopyWith<$Res>? get action;

}
/// @nodoc
class _$CodexRolloutPayloadDtoCopyWithImpl<$Res>
    implements $CodexRolloutPayloadDtoCopyWith<$Res> {
  _$CodexRolloutPayloadDtoCopyWithImpl(this._self, this._then);

  final CodexRolloutPayloadDto _self;
  final $Res Function(CodexRolloutPayloadDto) _then;

/// Create a copy of CodexRolloutPayloadDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? cwd = freezed,Object? timestamp = freezed,Object? modelProvider = freezed,Object? cliVersion = freezed,Object? model = freezed,Object? git = freezed,Object? type = freezed,Object? role = freezed,Object? content = freezed,Object? callId = freezed,Object? name = freezed,Object? arguments = freezed,Object? output = freezed,Object? action = freezed,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,cwd: freezed == cwd ? _self.cwd : cwd // ignore: cast_nullable_to_non_nullable
as String?,timestamp: freezed == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as String?,modelProvider: freezed == modelProvider ? _self.modelProvider : modelProvider // ignore: cast_nullable_to_non_nullable
as String?,cliVersion: freezed == cliVersion ? _self.cliVersion : cliVersion // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,git: freezed == git ? _self.git : git // ignore: cast_nullable_to_non_nullable
as CodexRolloutGitDto?,type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as CodexRolloutPayloadType?,role: freezed == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as CodexRolloutRole?,content: freezed == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as List<CodexRolloutContentDto>?,callId: freezed == callId ? _self.callId : callId // ignore: cast_nullable_to_non_nullable
as String?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,arguments: freezed == arguments ? _self.arguments : arguments // ignore: cast_nullable_to_non_nullable
as String?,output: freezed == output ? _self.output : output // ignore: cast_nullable_to_non_nullable
as String?,action: freezed == action ? _self.action : action // ignore: cast_nullable_to_non_nullable
as CodexRolloutActionDto?,
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
}/// Create a copy of CodexRolloutPayloadDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexRolloutActionDtoCopyWith<$Res>? get action {
    if (_self.action == null) {
    return null;
  }

  return $CodexRolloutActionDtoCopyWith<$Res>(_self.action!, (value) {
    return _then(_self.copyWith(action: value));
  });
}
}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CodexRolloutPayloadDto implements CodexRolloutPayloadDto {
  const _CodexRolloutPayloadDto({required this.id, required this.cwd, required this.timestamp, @JsonKey(name: "model_provider") required this.modelProvider, @JsonKey(name: "cli_version") required this.cliVersion, required this.model, required this.git, @JsonKey(unknownEnumValue: CodexRolloutPayloadType.unknown) required this.type, @JsonKey(unknownEnumValue: CodexRolloutRole.unknown) required this.role, required final  List<CodexRolloutContentDto>? content, @JsonKey(name: "call_id") required this.callId, required this.name, required this.arguments, required this.output, required this.action}): _content = content;
  factory _CodexRolloutPayloadDto.fromJson(Map<String, dynamic> json) => _$CodexRolloutPayloadDtoFromJson(json);

@override final  String? id;
@override final  String? cwd;
@override final  String? timestamp;
@override@JsonKey(name: "model_provider") final  String? modelProvider;
@override@JsonKey(name: "cli_version") final  String? cliVersion;
@override final  String? model;
@override final  CodexRolloutGitDto? git;
@override@JsonKey(unknownEnumValue: CodexRolloutPayloadType.unknown) final  CodexRolloutPayloadType? type;
@override@JsonKey(unknownEnumValue: CodexRolloutRole.unknown) final  CodexRolloutRole? role;
 final  List<CodexRolloutContentDto>? _content;
@override List<CodexRolloutContentDto>? get content {
  final value = _content;
  if (value == null) return null;
  if (_content is EqualUnmodifiableListView) return _content;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override@JsonKey(name: "call_id") final  String? callId;
@override final  String? name;
@override final  String? arguments;
@override final  String? output;
@override final  CodexRolloutActionDto? action;

/// Create a copy of CodexRolloutPayloadDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexRolloutPayloadDtoCopyWith<_CodexRolloutPayloadDto> get copyWith => __$CodexRolloutPayloadDtoCopyWithImpl<_CodexRolloutPayloadDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexRolloutPayloadDto&&(identical(other.id, id) || other.id == id)&&(identical(other.cwd, cwd) || other.cwd == cwd)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.modelProvider, modelProvider) || other.modelProvider == modelProvider)&&(identical(other.cliVersion, cliVersion) || other.cliVersion == cliVersion)&&(identical(other.model, model) || other.model == model)&&(identical(other.git, git) || other.git == git)&&(identical(other.type, type) || other.type == type)&&(identical(other.role, role) || other.role == role)&&const DeepCollectionEquality().equals(other._content, _content)&&(identical(other.callId, callId) || other.callId == callId)&&(identical(other.name, name) || other.name == name)&&(identical(other.arguments, arguments) || other.arguments == arguments)&&(identical(other.output, output) || other.output == output)&&(identical(other.action, action) || other.action == action));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,cwd,timestamp,modelProvider,cliVersion,model,git,type,role,const DeepCollectionEquality().hash(_content),callId,name,arguments,output,action);

@override
String toString() {
  return 'CodexRolloutPayloadDto(id: $id, cwd: $cwd, timestamp: $timestamp, modelProvider: $modelProvider, cliVersion: $cliVersion, model: $model, git: $git, type: $type, role: $role, content: $content, callId: $callId, name: $name, arguments: $arguments, output: $output, action: $action)';
}


}

/// @nodoc
abstract mixin class _$CodexRolloutPayloadDtoCopyWith<$Res> implements $CodexRolloutPayloadDtoCopyWith<$Res> {
  factory _$CodexRolloutPayloadDtoCopyWith(_CodexRolloutPayloadDto value, $Res Function(_CodexRolloutPayloadDto) _then) = __$CodexRolloutPayloadDtoCopyWithImpl;
@override @useResult
$Res call({
 String? id, String? cwd, String? timestamp,@JsonKey(name: "model_provider") String? modelProvider,@JsonKey(name: "cli_version") String? cliVersion, String? model, CodexRolloutGitDto? git,@JsonKey(unknownEnumValue: CodexRolloutPayloadType.unknown) CodexRolloutPayloadType? type,@JsonKey(unknownEnumValue: CodexRolloutRole.unknown) CodexRolloutRole? role, List<CodexRolloutContentDto>? content,@JsonKey(name: "call_id") String? callId, String? name, String? arguments, String? output, CodexRolloutActionDto? action
});


@override $CodexRolloutGitDtoCopyWith<$Res>? get git;@override $CodexRolloutActionDtoCopyWith<$Res>? get action;

}
/// @nodoc
class __$CodexRolloutPayloadDtoCopyWithImpl<$Res>
    implements _$CodexRolloutPayloadDtoCopyWith<$Res> {
  __$CodexRolloutPayloadDtoCopyWithImpl(this._self, this._then);

  final _CodexRolloutPayloadDto _self;
  final $Res Function(_CodexRolloutPayloadDto) _then;

/// Create a copy of CodexRolloutPayloadDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? cwd = freezed,Object? timestamp = freezed,Object? modelProvider = freezed,Object? cliVersion = freezed,Object? model = freezed,Object? git = freezed,Object? type = freezed,Object? role = freezed,Object? content = freezed,Object? callId = freezed,Object? name = freezed,Object? arguments = freezed,Object? output = freezed,Object? action = freezed,}) {
  return _then(_CodexRolloutPayloadDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,cwd: freezed == cwd ? _self.cwd : cwd // ignore: cast_nullable_to_non_nullable
as String?,timestamp: freezed == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as String?,modelProvider: freezed == modelProvider ? _self.modelProvider : modelProvider // ignore: cast_nullable_to_non_nullable
as String?,cliVersion: freezed == cliVersion ? _self.cliVersion : cliVersion // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,git: freezed == git ? _self.git : git // ignore: cast_nullable_to_non_nullable
as CodexRolloutGitDto?,type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as CodexRolloutPayloadType?,role: freezed == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as CodexRolloutRole?,content: freezed == content ? _self._content : content // ignore: cast_nullable_to_non_nullable
as List<CodexRolloutContentDto>?,callId: freezed == callId ? _self.callId : callId // ignore: cast_nullable_to_non_nullable
as String?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,arguments: freezed == arguments ? _self.arguments : arguments // ignore: cast_nullable_to_non_nullable
as String?,output: freezed == output ? _self.output : output // ignore: cast_nullable_to_non_nullable
as String?,action: freezed == action ? _self.action : action // ignore: cast_nullable_to_non_nullable
as CodexRolloutActionDto?,
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
}/// Create a copy of CodexRolloutPayloadDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexRolloutActionDtoCopyWith<$Res>? get action {
    if (_self.action == null) {
    return null;
  }

  return $CodexRolloutActionDtoCopyWith<$Res>(_self.action!, (value) {
    return _then(_self.copyWith(action: value));
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


/// @nodoc
mixin _$CodexRolloutContentDto {

@JsonKey(unknownEnumValue: CodexRolloutContentType.unknown) CodexRolloutContentType? get type; String? get text;
/// Create a copy of CodexRolloutContentDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexRolloutContentDtoCopyWith<CodexRolloutContentDto> get copyWith => _$CodexRolloutContentDtoCopyWithImpl<CodexRolloutContentDto>(this as CodexRolloutContentDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexRolloutContentDto&&(identical(other.type, type) || other.type == type)&&(identical(other.text, text) || other.text == text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,text);

@override
String toString() {
  return 'CodexRolloutContentDto(type: $type, text: $text)';
}


}

/// @nodoc
abstract mixin class $CodexRolloutContentDtoCopyWith<$Res>  {
  factory $CodexRolloutContentDtoCopyWith(CodexRolloutContentDto value, $Res Function(CodexRolloutContentDto) _then) = _$CodexRolloutContentDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(unknownEnumValue: CodexRolloutContentType.unknown) CodexRolloutContentType? type, String? text
});




}
/// @nodoc
class _$CodexRolloutContentDtoCopyWithImpl<$Res>
    implements $CodexRolloutContentDtoCopyWith<$Res> {
  _$CodexRolloutContentDtoCopyWithImpl(this._self, this._then);

  final CodexRolloutContentDto _self;
  final $Res Function(CodexRolloutContentDto) _then;

/// Create a copy of CodexRolloutContentDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = freezed,Object? text = freezed,}) {
  return _then(_self.copyWith(
type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as CodexRolloutContentType?,text: freezed == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CodexRolloutContentDto implements CodexRolloutContentDto {
  const _CodexRolloutContentDto({@JsonKey(unknownEnumValue: CodexRolloutContentType.unknown) required this.type, required this.text});
  factory _CodexRolloutContentDto.fromJson(Map<String, dynamic> json) => _$CodexRolloutContentDtoFromJson(json);

@override@JsonKey(unknownEnumValue: CodexRolloutContentType.unknown) final  CodexRolloutContentType? type;
@override final  String? text;

/// Create a copy of CodexRolloutContentDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexRolloutContentDtoCopyWith<_CodexRolloutContentDto> get copyWith => __$CodexRolloutContentDtoCopyWithImpl<_CodexRolloutContentDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexRolloutContentDto&&(identical(other.type, type) || other.type == type)&&(identical(other.text, text) || other.text == text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,text);

@override
String toString() {
  return 'CodexRolloutContentDto(type: $type, text: $text)';
}


}

/// @nodoc
abstract mixin class _$CodexRolloutContentDtoCopyWith<$Res> implements $CodexRolloutContentDtoCopyWith<$Res> {
  factory _$CodexRolloutContentDtoCopyWith(_CodexRolloutContentDto value, $Res Function(_CodexRolloutContentDto) _then) = __$CodexRolloutContentDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(unknownEnumValue: CodexRolloutContentType.unknown) CodexRolloutContentType? type, String? text
});




}
/// @nodoc
class __$CodexRolloutContentDtoCopyWithImpl<$Res>
    implements _$CodexRolloutContentDtoCopyWith<$Res> {
  __$CodexRolloutContentDtoCopyWithImpl(this._self, this._then);

  final _CodexRolloutContentDto _self;
  final $Res Function(_CodexRolloutContentDto) _then;

/// Create a copy of CodexRolloutContentDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = freezed,Object? text = freezed,}) {
  return _then(_CodexRolloutContentDto(
type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as CodexRolloutContentType?,text: freezed == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$CodexRolloutActionDto {

 String? get query;
/// Create a copy of CodexRolloutActionDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexRolloutActionDtoCopyWith<CodexRolloutActionDto> get copyWith => _$CodexRolloutActionDtoCopyWithImpl<CodexRolloutActionDto>(this as CodexRolloutActionDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexRolloutActionDto&&(identical(other.query, query) || other.query == query));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,query);

@override
String toString() {
  return 'CodexRolloutActionDto(query: $query)';
}


}

/// @nodoc
abstract mixin class $CodexRolloutActionDtoCopyWith<$Res>  {
  factory $CodexRolloutActionDtoCopyWith(CodexRolloutActionDto value, $Res Function(CodexRolloutActionDto) _then) = _$CodexRolloutActionDtoCopyWithImpl;
@useResult
$Res call({
 String? query
});




}
/// @nodoc
class _$CodexRolloutActionDtoCopyWithImpl<$Res>
    implements $CodexRolloutActionDtoCopyWith<$Res> {
  _$CodexRolloutActionDtoCopyWithImpl(this._self, this._then);

  final CodexRolloutActionDto _self;
  final $Res Function(CodexRolloutActionDto) _then;

/// Create a copy of CodexRolloutActionDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? query = freezed,}) {
  return _then(_self.copyWith(
query: freezed == query ? _self.query : query // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CodexRolloutActionDto implements CodexRolloutActionDto {
  const _CodexRolloutActionDto({required this.query});
  factory _CodexRolloutActionDto.fromJson(Map<String, dynamic> json) => _$CodexRolloutActionDtoFromJson(json);

@override final  String? query;

/// Create a copy of CodexRolloutActionDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexRolloutActionDtoCopyWith<_CodexRolloutActionDto> get copyWith => __$CodexRolloutActionDtoCopyWithImpl<_CodexRolloutActionDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexRolloutActionDto&&(identical(other.query, query) || other.query == query));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,query);

@override
String toString() {
  return 'CodexRolloutActionDto(query: $query)';
}


}

/// @nodoc
abstract mixin class _$CodexRolloutActionDtoCopyWith<$Res> implements $CodexRolloutActionDtoCopyWith<$Res> {
  factory _$CodexRolloutActionDtoCopyWith(_CodexRolloutActionDto value, $Res Function(_CodexRolloutActionDto) _then) = __$CodexRolloutActionDtoCopyWithImpl;
@override @useResult
$Res call({
 String? query
});




}
/// @nodoc
class __$CodexRolloutActionDtoCopyWithImpl<$Res>
    implements _$CodexRolloutActionDtoCopyWith<$Res> {
  __$CodexRolloutActionDtoCopyWithImpl(this._self, this._then);

  final _CodexRolloutActionDto _self;
  final $Res Function(_CodexRolloutActionDto) _then;

/// Create a copy of CodexRolloutActionDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? query = freezed,}) {
  return _then(_CodexRolloutActionDto(
query: freezed == query ? _self.query : query // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$CodexToolArgumentsDto {

 Object? get cmd; Object? get command; Object? get path;@JsonKey(name: "file_path") Object? get filePath; Object? get query;
/// Create a copy of CodexToolArgumentsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexToolArgumentsDtoCopyWith<CodexToolArgumentsDto> get copyWith => _$CodexToolArgumentsDtoCopyWithImpl<CodexToolArgumentsDto>(this as CodexToolArgumentsDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexToolArgumentsDto&&const DeepCollectionEquality().equals(other.cmd, cmd)&&const DeepCollectionEquality().equals(other.command, command)&&const DeepCollectionEquality().equals(other.path, path)&&const DeepCollectionEquality().equals(other.filePath, filePath)&&const DeepCollectionEquality().equals(other.query, query));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(cmd),const DeepCollectionEquality().hash(command),const DeepCollectionEquality().hash(path),const DeepCollectionEquality().hash(filePath),const DeepCollectionEquality().hash(query));

@override
String toString() {
  return 'CodexToolArgumentsDto(cmd: $cmd, command: $command, path: $path, filePath: $filePath, query: $query)';
}


}

/// @nodoc
abstract mixin class $CodexToolArgumentsDtoCopyWith<$Res>  {
  factory $CodexToolArgumentsDtoCopyWith(CodexToolArgumentsDto value, $Res Function(CodexToolArgumentsDto) _then) = _$CodexToolArgumentsDtoCopyWithImpl;
@useResult
$Res call({
 Object? cmd, Object? command, Object? path,@JsonKey(name: "file_path") Object? filePath, Object? query
});




}
/// @nodoc
class _$CodexToolArgumentsDtoCopyWithImpl<$Res>
    implements $CodexToolArgumentsDtoCopyWith<$Res> {
  _$CodexToolArgumentsDtoCopyWithImpl(this._self, this._then);

  final CodexToolArgumentsDto _self;
  final $Res Function(CodexToolArgumentsDto) _then;

/// Create a copy of CodexToolArgumentsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? cmd = freezed,Object? command = freezed,Object? path = freezed,Object? filePath = freezed,Object? query = freezed,}) {
  return _then(_self.copyWith(
cmd: freezed == cmd ? _self.cmd : cmd ,command: freezed == command ? _self.command : command ,path: freezed == path ? _self.path : path ,filePath: freezed == filePath ? _self.filePath : filePath ,query: freezed == query ? _self.query : query ,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CodexToolArgumentsDto implements CodexToolArgumentsDto {
  const _CodexToolArgumentsDto({required this.cmd, required this.command, required this.path, @JsonKey(name: "file_path") required this.filePath, required this.query});
  factory _CodexToolArgumentsDto.fromJson(Map<String, dynamic> json) => _$CodexToolArgumentsDtoFromJson(json);

@override final  Object? cmd;
@override final  Object? command;
@override final  Object? path;
@override@JsonKey(name: "file_path") final  Object? filePath;
@override final  Object? query;

/// Create a copy of CodexToolArgumentsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexToolArgumentsDtoCopyWith<_CodexToolArgumentsDto> get copyWith => __$CodexToolArgumentsDtoCopyWithImpl<_CodexToolArgumentsDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexToolArgumentsDto&&const DeepCollectionEquality().equals(other.cmd, cmd)&&const DeepCollectionEquality().equals(other.command, command)&&const DeepCollectionEquality().equals(other.path, path)&&const DeepCollectionEquality().equals(other.filePath, filePath)&&const DeepCollectionEquality().equals(other.query, query));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(cmd),const DeepCollectionEquality().hash(command),const DeepCollectionEquality().hash(path),const DeepCollectionEquality().hash(filePath),const DeepCollectionEquality().hash(query));

@override
String toString() {
  return 'CodexToolArgumentsDto(cmd: $cmd, command: $command, path: $path, filePath: $filePath, query: $query)';
}


}

/// @nodoc
abstract mixin class _$CodexToolArgumentsDtoCopyWith<$Res> implements $CodexToolArgumentsDtoCopyWith<$Res> {
  factory _$CodexToolArgumentsDtoCopyWith(_CodexToolArgumentsDto value, $Res Function(_CodexToolArgumentsDto) _then) = __$CodexToolArgumentsDtoCopyWithImpl;
@override @useResult
$Res call({
 Object? cmd, Object? command, Object? path,@JsonKey(name: "file_path") Object? filePath, Object? query
});




}
/// @nodoc
class __$CodexToolArgumentsDtoCopyWithImpl<$Res>
    implements _$CodexToolArgumentsDtoCopyWith<$Res> {
  __$CodexToolArgumentsDtoCopyWithImpl(this._self, this._then);

  final _CodexToolArgumentsDto _self;
  final $Res Function(_CodexToolArgumentsDto) _then;

/// Create a copy of CodexToolArgumentsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? cmd = freezed,Object? command = freezed,Object? path = freezed,Object? filePath = freezed,Object? query = freezed,}) {
  return _then(_CodexToolArgumentsDto(
cmd: freezed == cmd ? _self.cmd : cmd ,command: freezed == command ? _self.command : command ,path: freezed == path ? _self.path : path ,filePath: freezed == filePath ? _self.filePath : filePath ,query: freezed == query ? _self.query : query ,
  ));
}


}

// dart format on
