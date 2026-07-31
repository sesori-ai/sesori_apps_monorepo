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

CodexRolloutLineDto _$CodexRolloutLineDtoFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'session_meta':
          return CodexRolloutSessionMetadataLineDto.fromJson(
            json
          );
                case 'turn_context':
          return CodexRolloutTurnContextLineDto.fromJson(
            json
          );
                case 'response_item':
          return CodexRolloutResponseItemLineDto.fromJson(
            json
          );
                case 'compacted':
          return CodexRolloutCompactedLineDto.fromJson(
            json
          );
        
          default:
            return CodexRolloutUnknownLineDto.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$CodexRolloutLineDto {

 String? get timestamp;
/// Create a copy of CodexRolloutLineDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexRolloutLineDtoCopyWith<CodexRolloutLineDto> get copyWith => _$CodexRolloutLineDtoCopyWithImpl<CodexRolloutLineDto>(this as CodexRolloutLineDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexRolloutLineDto&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,timestamp);

@override
String toString() {
  return 'CodexRolloutLineDto(timestamp: $timestamp)';
}


}

/// @nodoc
abstract mixin class $CodexRolloutLineDtoCopyWith<$Res>  {
  factory $CodexRolloutLineDtoCopyWith(CodexRolloutLineDto value, $Res Function(CodexRolloutLineDto) _then) = _$CodexRolloutLineDtoCopyWithImpl;
@useResult
$Res call({
 String? timestamp
});




}
/// @nodoc
class _$CodexRolloutLineDtoCopyWithImpl<$Res>
    implements $CodexRolloutLineDtoCopyWith<$Res> {
  _$CodexRolloutLineDtoCopyWithImpl(this._self, this._then);

  final CodexRolloutLineDto _self;
  final $Res Function(CodexRolloutLineDto) _then;

/// Create a copy of CodexRolloutLineDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? timestamp = freezed,}) {
  return _then(_self.copyWith(
timestamp: freezed == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class CodexRolloutSessionMetadataLineDto implements CodexRolloutLineDto {
  const CodexRolloutSessionMetadataLineDto({required this.timestamp, required this.payload, final  String? $type}): $type = $type ?? 'session_meta';
  factory CodexRolloutSessionMetadataLineDto.fromJson(Map<String, dynamic> json) => _$CodexRolloutSessionMetadataLineDtoFromJson(json);

@override final  String? timestamp;
 final  CodexRolloutSessionMetadataPayloadDto payload;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of CodexRolloutLineDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexRolloutSessionMetadataLineDtoCopyWith<CodexRolloutSessionMetadataLineDto> get copyWith => _$CodexRolloutSessionMetadataLineDtoCopyWithImpl<CodexRolloutSessionMetadataLineDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexRolloutSessionMetadataLineDto&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.payload, payload) || other.payload == payload));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,timestamp,payload);

@override
String toString() {
  return 'CodexRolloutLineDto.sessionMetadata(timestamp: $timestamp, payload: $payload)';
}


}

/// @nodoc
abstract mixin class $CodexRolloutSessionMetadataLineDtoCopyWith<$Res> implements $CodexRolloutLineDtoCopyWith<$Res> {
  factory $CodexRolloutSessionMetadataLineDtoCopyWith(CodexRolloutSessionMetadataLineDto value, $Res Function(CodexRolloutSessionMetadataLineDto) _then) = _$CodexRolloutSessionMetadataLineDtoCopyWithImpl;
@override @useResult
$Res call({
 String? timestamp, CodexRolloutSessionMetadataPayloadDto payload
});


$CodexRolloutSessionMetadataPayloadDtoCopyWith<$Res> get payload;

}
/// @nodoc
class _$CodexRolloutSessionMetadataLineDtoCopyWithImpl<$Res>
    implements $CodexRolloutSessionMetadataLineDtoCopyWith<$Res> {
  _$CodexRolloutSessionMetadataLineDtoCopyWithImpl(this._self, this._then);

  final CodexRolloutSessionMetadataLineDto _self;
  final $Res Function(CodexRolloutSessionMetadataLineDto) _then;

/// Create a copy of CodexRolloutLineDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? timestamp = freezed,Object? payload = null,}) {
  return _then(CodexRolloutSessionMetadataLineDto(
timestamp: freezed == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as String?,payload: null == payload ? _self.payload : payload // ignore: cast_nullable_to_non_nullable
as CodexRolloutSessionMetadataPayloadDto,
  ));
}

/// Create a copy of CodexRolloutLineDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexRolloutSessionMetadataPayloadDtoCopyWith<$Res> get payload {
  
  return $CodexRolloutSessionMetadataPayloadDtoCopyWith<$Res>(_self.payload, (value) {
    return _then(_self.copyWith(payload: value));
  });
}
}

/// @nodoc
@JsonSerializable(createToJson: false)

class CodexRolloutTurnContextLineDto implements CodexRolloutLineDto {
  const CodexRolloutTurnContextLineDto({required this.timestamp, required this.payload, final  String? $type}): $type = $type ?? 'turn_context';
  factory CodexRolloutTurnContextLineDto.fromJson(Map<String, dynamic> json) => _$CodexRolloutTurnContextLineDtoFromJson(json);

@override final  String? timestamp;
 final  CodexRolloutTurnContextPayloadDto payload;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of CodexRolloutLineDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexRolloutTurnContextLineDtoCopyWith<CodexRolloutTurnContextLineDto> get copyWith => _$CodexRolloutTurnContextLineDtoCopyWithImpl<CodexRolloutTurnContextLineDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexRolloutTurnContextLineDto&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.payload, payload) || other.payload == payload));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,timestamp,payload);

@override
String toString() {
  return 'CodexRolloutLineDto.turnContext(timestamp: $timestamp, payload: $payload)';
}


}

/// @nodoc
abstract mixin class $CodexRolloutTurnContextLineDtoCopyWith<$Res> implements $CodexRolloutLineDtoCopyWith<$Res> {
  factory $CodexRolloutTurnContextLineDtoCopyWith(CodexRolloutTurnContextLineDto value, $Res Function(CodexRolloutTurnContextLineDto) _then) = _$CodexRolloutTurnContextLineDtoCopyWithImpl;
@override @useResult
$Res call({
 String? timestamp, CodexRolloutTurnContextPayloadDto payload
});


$CodexRolloutTurnContextPayloadDtoCopyWith<$Res> get payload;

}
/// @nodoc
class _$CodexRolloutTurnContextLineDtoCopyWithImpl<$Res>
    implements $CodexRolloutTurnContextLineDtoCopyWith<$Res> {
  _$CodexRolloutTurnContextLineDtoCopyWithImpl(this._self, this._then);

  final CodexRolloutTurnContextLineDto _self;
  final $Res Function(CodexRolloutTurnContextLineDto) _then;

/// Create a copy of CodexRolloutLineDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? timestamp = freezed,Object? payload = null,}) {
  return _then(CodexRolloutTurnContextLineDto(
timestamp: freezed == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as String?,payload: null == payload ? _self.payload : payload // ignore: cast_nullable_to_non_nullable
as CodexRolloutTurnContextPayloadDto,
  ));
}

/// Create a copy of CodexRolloutLineDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexRolloutTurnContextPayloadDtoCopyWith<$Res> get payload {
  
  return $CodexRolloutTurnContextPayloadDtoCopyWith<$Res>(_self.payload, (value) {
    return _then(_self.copyWith(payload: value));
  });
}
}

/// @nodoc
@JsonSerializable(createToJson: false)

class CodexRolloutResponseItemLineDto implements CodexRolloutLineDto {
  const CodexRolloutResponseItemLineDto({required this.timestamp, required this.payload, final  String? $type}): $type = $type ?? 'response_item';
  factory CodexRolloutResponseItemLineDto.fromJson(Map<String, dynamic> json) => _$CodexRolloutResponseItemLineDtoFromJson(json);

@override final  String? timestamp;
 final  CodexRolloutPayloadDto payload;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of CodexRolloutLineDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexRolloutResponseItemLineDtoCopyWith<CodexRolloutResponseItemLineDto> get copyWith => _$CodexRolloutResponseItemLineDtoCopyWithImpl<CodexRolloutResponseItemLineDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexRolloutResponseItemLineDto&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.payload, payload) || other.payload == payload));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,timestamp,payload);

@override
String toString() {
  return 'CodexRolloutLineDto.responseItem(timestamp: $timestamp, payload: $payload)';
}


}

/// @nodoc
abstract mixin class $CodexRolloutResponseItemLineDtoCopyWith<$Res> implements $CodexRolloutLineDtoCopyWith<$Res> {
  factory $CodexRolloutResponseItemLineDtoCopyWith(CodexRolloutResponseItemLineDto value, $Res Function(CodexRolloutResponseItemLineDto) _then) = _$CodexRolloutResponseItemLineDtoCopyWithImpl;
@override @useResult
$Res call({
 String? timestamp, CodexRolloutPayloadDto payload
});


$CodexRolloutPayloadDtoCopyWith<$Res> get payload;

}
/// @nodoc
class _$CodexRolloutResponseItemLineDtoCopyWithImpl<$Res>
    implements $CodexRolloutResponseItemLineDtoCopyWith<$Res> {
  _$CodexRolloutResponseItemLineDtoCopyWithImpl(this._self, this._then);

  final CodexRolloutResponseItemLineDto _self;
  final $Res Function(CodexRolloutResponseItemLineDto) _then;

/// Create a copy of CodexRolloutLineDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? timestamp = freezed,Object? payload = null,}) {
  return _then(CodexRolloutResponseItemLineDto(
timestamp: freezed == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as String?,payload: null == payload ? _self.payload : payload // ignore: cast_nullable_to_non_nullable
as CodexRolloutPayloadDto,
  ));
}

/// Create a copy of CodexRolloutLineDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexRolloutPayloadDtoCopyWith<$Res> get payload {
  
  return $CodexRolloutPayloadDtoCopyWith<$Res>(_self.payload, (value) {
    return _then(_self.copyWith(payload: value));
  });
}
}

/// @nodoc
@JsonSerializable(createToJson: false)

class CodexRolloutCompactedLineDto implements CodexRolloutLineDto {
  const CodexRolloutCompactedLineDto({required this.timestamp, final  String? $type}): $type = $type ?? 'compacted';
  factory CodexRolloutCompactedLineDto.fromJson(Map<String, dynamic> json) => _$CodexRolloutCompactedLineDtoFromJson(json);

@override final  String? timestamp;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of CodexRolloutLineDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexRolloutCompactedLineDtoCopyWith<CodexRolloutCompactedLineDto> get copyWith => _$CodexRolloutCompactedLineDtoCopyWithImpl<CodexRolloutCompactedLineDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexRolloutCompactedLineDto&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,timestamp);

@override
String toString() {
  return 'CodexRolloutLineDto.compacted(timestamp: $timestamp)';
}


}

/// @nodoc
abstract mixin class $CodexRolloutCompactedLineDtoCopyWith<$Res> implements $CodexRolloutLineDtoCopyWith<$Res> {
  factory $CodexRolloutCompactedLineDtoCopyWith(CodexRolloutCompactedLineDto value, $Res Function(CodexRolloutCompactedLineDto) _then) = _$CodexRolloutCompactedLineDtoCopyWithImpl;
@override @useResult
$Res call({
 String? timestamp
});




}
/// @nodoc
class _$CodexRolloutCompactedLineDtoCopyWithImpl<$Res>
    implements $CodexRolloutCompactedLineDtoCopyWith<$Res> {
  _$CodexRolloutCompactedLineDtoCopyWithImpl(this._self, this._then);

  final CodexRolloutCompactedLineDto _self;
  final $Res Function(CodexRolloutCompactedLineDto) _then;

/// Create a copy of CodexRolloutLineDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? timestamp = freezed,}) {
  return _then(CodexRolloutCompactedLineDto(
timestamp: freezed == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class CodexRolloutUnknownLineDto implements CodexRolloutLineDto {
  const CodexRolloutUnknownLineDto({required this.timestamp, final  String? $type}): $type = $type ?? 'unknown';
  factory CodexRolloutUnknownLineDto.fromJson(Map<String, dynamic> json) => _$CodexRolloutUnknownLineDtoFromJson(json);

@override final  String? timestamp;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of CodexRolloutLineDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexRolloutUnknownLineDtoCopyWith<CodexRolloutUnknownLineDto> get copyWith => _$CodexRolloutUnknownLineDtoCopyWithImpl<CodexRolloutUnknownLineDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexRolloutUnknownLineDto&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,timestamp);

@override
String toString() {
  return 'CodexRolloutLineDto.unknown(timestamp: $timestamp)';
}


}

/// @nodoc
abstract mixin class $CodexRolloutUnknownLineDtoCopyWith<$Res> implements $CodexRolloutLineDtoCopyWith<$Res> {
  factory $CodexRolloutUnknownLineDtoCopyWith(CodexRolloutUnknownLineDto value, $Res Function(CodexRolloutUnknownLineDto) _then) = _$CodexRolloutUnknownLineDtoCopyWithImpl;
@override @useResult
$Res call({
 String? timestamp
});




}
/// @nodoc
class _$CodexRolloutUnknownLineDtoCopyWithImpl<$Res>
    implements $CodexRolloutUnknownLineDtoCopyWith<$Res> {
  _$CodexRolloutUnknownLineDtoCopyWithImpl(this._self, this._then);

  final CodexRolloutUnknownLineDto _self;
  final $Res Function(CodexRolloutUnknownLineDto) _then;

/// Create a copy of CodexRolloutLineDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? timestamp = freezed,}) {
  return _then(CodexRolloutUnknownLineDto(
timestamp: freezed == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$CodexRolloutSessionMetadataPayloadDto {

 String? get id; String? get cwd; String? get timestamp;@JsonKey(name: "model_provider") String? get modelProvider;@JsonKey(name: "cli_version") String? get cliVersion;
/// Create a copy of CodexRolloutSessionMetadataPayloadDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexRolloutSessionMetadataPayloadDtoCopyWith<CodexRolloutSessionMetadataPayloadDto> get copyWith => _$CodexRolloutSessionMetadataPayloadDtoCopyWithImpl<CodexRolloutSessionMetadataPayloadDto>(this as CodexRolloutSessionMetadataPayloadDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexRolloutSessionMetadataPayloadDto&&(identical(other.id, id) || other.id == id)&&(identical(other.cwd, cwd) || other.cwd == cwd)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.modelProvider, modelProvider) || other.modelProvider == modelProvider)&&(identical(other.cliVersion, cliVersion) || other.cliVersion == cliVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,cwd,timestamp,modelProvider,cliVersion);

@override
String toString() {
  return 'CodexRolloutSessionMetadataPayloadDto(id: $id, cwd: $cwd, timestamp: $timestamp, modelProvider: $modelProvider, cliVersion: $cliVersion)';
}


}

/// @nodoc
abstract mixin class $CodexRolloutSessionMetadataPayloadDtoCopyWith<$Res>  {
  factory $CodexRolloutSessionMetadataPayloadDtoCopyWith(CodexRolloutSessionMetadataPayloadDto value, $Res Function(CodexRolloutSessionMetadataPayloadDto) _then) = _$CodexRolloutSessionMetadataPayloadDtoCopyWithImpl;
@useResult
$Res call({
 String? id, String? cwd, String? timestamp,@JsonKey(name: "model_provider") String? modelProvider,@JsonKey(name: "cli_version") String? cliVersion
});




}
/// @nodoc
class _$CodexRolloutSessionMetadataPayloadDtoCopyWithImpl<$Res>
    implements $CodexRolloutSessionMetadataPayloadDtoCopyWith<$Res> {
  _$CodexRolloutSessionMetadataPayloadDtoCopyWithImpl(this._self, this._then);

  final CodexRolloutSessionMetadataPayloadDto _self;
  final $Res Function(CodexRolloutSessionMetadataPayloadDto) _then;

/// Create a copy of CodexRolloutSessionMetadataPayloadDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? cwd = freezed,Object? timestamp = freezed,Object? modelProvider = freezed,Object? cliVersion = freezed,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,cwd: freezed == cwd ? _self.cwd : cwd // ignore: cast_nullable_to_non_nullable
as String?,timestamp: freezed == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as String?,modelProvider: freezed == modelProvider ? _self.modelProvider : modelProvider // ignore: cast_nullable_to_non_nullable
as String?,cliVersion: freezed == cliVersion ? _self.cliVersion : cliVersion // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CodexRolloutSessionMetadataPayloadDto implements CodexRolloutSessionMetadataPayloadDto {
  const _CodexRolloutSessionMetadataPayloadDto({required this.id, required this.cwd, required this.timestamp, @JsonKey(name: "model_provider") required this.modelProvider, @JsonKey(name: "cli_version") required this.cliVersion});
  factory _CodexRolloutSessionMetadataPayloadDto.fromJson(Map<String, dynamic> json) => _$CodexRolloutSessionMetadataPayloadDtoFromJson(json);

@override final  String? id;
@override final  String? cwd;
@override final  String? timestamp;
@override@JsonKey(name: "model_provider") final  String? modelProvider;
@override@JsonKey(name: "cli_version") final  String? cliVersion;

/// Create a copy of CodexRolloutSessionMetadataPayloadDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexRolloutSessionMetadataPayloadDtoCopyWith<_CodexRolloutSessionMetadataPayloadDto> get copyWith => __$CodexRolloutSessionMetadataPayloadDtoCopyWithImpl<_CodexRolloutSessionMetadataPayloadDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexRolloutSessionMetadataPayloadDto&&(identical(other.id, id) || other.id == id)&&(identical(other.cwd, cwd) || other.cwd == cwd)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.modelProvider, modelProvider) || other.modelProvider == modelProvider)&&(identical(other.cliVersion, cliVersion) || other.cliVersion == cliVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,cwd,timestamp,modelProvider,cliVersion);

@override
String toString() {
  return 'CodexRolloutSessionMetadataPayloadDto(id: $id, cwd: $cwd, timestamp: $timestamp, modelProvider: $modelProvider, cliVersion: $cliVersion)';
}


}

/// @nodoc
abstract mixin class _$CodexRolloutSessionMetadataPayloadDtoCopyWith<$Res> implements $CodexRolloutSessionMetadataPayloadDtoCopyWith<$Res> {
  factory _$CodexRolloutSessionMetadataPayloadDtoCopyWith(_CodexRolloutSessionMetadataPayloadDto value, $Res Function(_CodexRolloutSessionMetadataPayloadDto) _then) = __$CodexRolloutSessionMetadataPayloadDtoCopyWithImpl;
@override @useResult
$Res call({
 String? id, String? cwd, String? timestamp,@JsonKey(name: "model_provider") String? modelProvider,@JsonKey(name: "cli_version") String? cliVersion
});




}
/// @nodoc
class __$CodexRolloutSessionMetadataPayloadDtoCopyWithImpl<$Res>
    implements _$CodexRolloutSessionMetadataPayloadDtoCopyWith<$Res> {
  __$CodexRolloutSessionMetadataPayloadDtoCopyWithImpl(this._self, this._then);

  final _CodexRolloutSessionMetadataPayloadDto _self;
  final $Res Function(_CodexRolloutSessionMetadataPayloadDto) _then;

/// Create a copy of CodexRolloutSessionMetadataPayloadDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? cwd = freezed,Object? timestamp = freezed,Object? modelProvider = freezed,Object? cliVersion = freezed,}) {
  return _then(_CodexRolloutSessionMetadataPayloadDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,cwd: freezed == cwd ? _self.cwd : cwd // ignore: cast_nullable_to_non_nullable
as String?,timestamp: freezed == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as String?,modelProvider: freezed == modelProvider ? _self.modelProvider : modelProvider // ignore: cast_nullable_to_non_nullable
as String?,cliVersion: freezed == cliVersion ? _self.cliVersion : cliVersion // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$CodexRolloutTurnContextPayloadDto {

 String? get model;
/// Create a copy of CodexRolloutTurnContextPayloadDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexRolloutTurnContextPayloadDtoCopyWith<CodexRolloutTurnContextPayloadDto> get copyWith => _$CodexRolloutTurnContextPayloadDtoCopyWithImpl<CodexRolloutTurnContextPayloadDto>(this as CodexRolloutTurnContextPayloadDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexRolloutTurnContextPayloadDto&&(identical(other.model, model) || other.model == model));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,model);

@override
String toString() {
  return 'CodexRolloutTurnContextPayloadDto(model: $model)';
}


}

/// @nodoc
abstract mixin class $CodexRolloutTurnContextPayloadDtoCopyWith<$Res>  {
  factory $CodexRolloutTurnContextPayloadDtoCopyWith(CodexRolloutTurnContextPayloadDto value, $Res Function(CodexRolloutTurnContextPayloadDto) _then) = _$CodexRolloutTurnContextPayloadDtoCopyWithImpl;
@useResult
$Res call({
 String? model
});




}
/// @nodoc
class _$CodexRolloutTurnContextPayloadDtoCopyWithImpl<$Res>
    implements $CodexRolloutTurnContextPayloadDtoCopyWith<$Res> {
  _$CodexRolloutTurnContextPayloadDtoCopyWithImpl(this._self, this._then);

  final CodexRolloutTurnContextPayloadDto _self;
  final $Res Function(CodexRolloutTurnContextPayloadDto) _then;

/// Create a copy of CodexRolloutTurnContextPayloadDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? model = freezed,}) {
  return _then(_self.copyWith(
model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CodexRolloutTurnContextPayloadDto implements CodexRolloutTurnContextPayloadDto {
  const _CodexRolloutTurnContextPayloadDto({required this.model});
  factory _CodexRolloutTurnContextPayloadDto.fromJson(Map<String, dynamic> json) => _$CodexRolloutTurnContextPayloadDtoFromJson(json);

@override final  String? model;

/// Create a copy of CodexRolloutTurnContextPayloadDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexRolloutTurnContextPayloadDtoCopyWith<_CodexRolloutTurnContextPayloadDto> get copyWith => __$CodexRolloutTurnContextPayloadDtoCopyWithImpl<_CodexRolloutTurnContextPayloadDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexRolloutTurnContextPayloadDto&&(identical(other.model, model) || other.model == model));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,model);

@override
String toString() {
  return 'CodexRolloutTurnContextPayloadDto(model: $model)';
}


}

/// @nodoc
abstract mixin class _$CodexRolloutTurnContextPayloadDtoCopyWith<$Res> implements $CodexRolloutTurnContextPayloadDtoCopyWith<$Res> {
  factory _$CodexRolloutTurnContextPayloadDtoCopyWith(_CodexRolloutTurnContextPayloadDto value, $Res Function(_CodexRolloutTurnContextPayloadDto) _then) = __$CodexRolloutTurnContextPayloadDtoCopyWithImpl;
@override @useResult
$Res call({
 String? model
});




}
/// @nodoc
class __$CodexRolloutTurnContextPayloadDtoCopyWithImpl<$Res>
    implements _$CodexRolloutTurnContextPayloadDtoCopyWith<$Res> {
  __$CodexRolloutTurnContextPayloadDtoCopyWithImpl(this._self, this._then);

  final _CodexRolloutTurnContextPayloadDto _self;
  final $Res Function(_CodexRolloutTurnContextPayloadDto) _then;

/// Create a copy of CodexRolloutTurnContextPayloadDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? model = freezed,}) {
  return _then(_CodexRolloutTurnContextPayloadDto(
model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$CodexRolloutPayloadDto {

 String? get id; String? get cwd; String? get timestamp;@JsonKey(name: "model_provider") String? get modelProvider;@JsonKey(name: "cli_version") String? get cliVersion; String? get model;@JsonKey(unknownEnumValue: CodexRolloutPayloadType.unknown) CodexRolloutPayloadType? get type;@JsonKey(unknownEnumValue: CodexRolloutRole.unknown) CodexRolloutRole? get role;@CodexRolloutContentListConverter() List<CodexRolloutContentDto>? get content;@CodexRolloutContentListConverter() List<CodexRolloutContentDto>? get summary;@JsonKey(name: "call_id") String? get callId; String? get name; String? get arguments; String? get input;@CodexRolloutOutputConverter() List<CodexRolloutContentDto>? get output; CodexRolloutActionDto? get action;
/// Create a copy of CodexRolloutPayloadDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexRolloutPayloadDtoCopyWith<CodexRolloutPayloadDto> get copyWith => _$CodexRolloutPayloadDtoCopyWithImpl<CodexRolloutPayloadDto>(this as CodexRolloutPayloadDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexRolloutPayloadDto&&(identical(other.id, id) || other.id == id)&&(identical(other.cwd, cwd) || other.cwd == cwd)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.modelProvider, modelProvider) || other.modelProvider == modelProvider)&&(identical(other.cliVersion, cliVersion) || other.cliVersion == cliVersion)&&(identical(other.model, model) || other.model == model)&&(identical(other.type, type) || other.type == type)&&(identical(other.role, role) || other.role == role)&&const DeepCollectionEquality().equals(other.content, content)&&const DeepCollectionEquality().equals(other.summary, summary)&&(identical(other.callId, callId) || other.callId == callId)&&(identical(other.name, name) || other.name == name)&&(identical(other.arguments, arguments) || other.arguments == arguments)&&(identical(other.input, input) || other.input == input)&&const DeepCollectionEquality().equals(other.output, output)&&(identical(other.action, action) || other.action == action));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,cwd,timestamp,modelProvider,cliVersion,model,type,role,const DeepCollectionEquality().hash(content),const DeepCollectionEquality().hash(summary),callId,name,arguments,input,const DeepCollectionEquality().hash(output),action);

@override
String toString() {
  return 'CodexRolloutPayloadDto(id: $id, cwd: $cwd, timestamp: $timestamp, modelProvider: $modelProvider, cliVersion: $cliVersion, model: $model, type: $type, role: $role, content: $content, summary: $summary, callId: $callId, name: $name, arguments: $arguments, input: $input, output: $output, action: $action)';
}


}

/// @nodoc
abstract mixin class $CodexRolloutPayloadDtoCopyWith<$Res>  {
  factory $CodexRolloutPayloadDtoCopyWith(CodexRolloutPayloadDto value, $Res Function(CodexRolloutPayloadDto) _then) = _$CodexRolloutPayloadDtoCopyWithImpl;
@useResult
$Res call({
 String? id, String? cwd, String? timestamp,@JsonKey(name: "model_provider") String? modelProvider,@JsonKey(name: "cli_version") String? cliVersion, String? model,@JsonKey(unknownEnumValue: CodexRolloutPayloadType.unknown) CodexRolloutPayloadType? type,@JsonKey(unknownEnumValue: CodexRolloutRole.unknown) CodexRolloutRole? role,@CodexRolloutContentListConverter() List<CodexRolloutContentDto>? content,@CodexRolloutContentListConverter() List<CodexRolloutContentDto>? summary,@JsonKey(name: "call_id") String? callId, String? name, String? arguments, String? input,@CodexRolloutOutputConverter() List<CodexRolloutContentDto>? output, CodexRolloutActionDto? action
});


$CodexRolloutActionDtoCopyWith<$Res>? get action;

}
/// @nodoc
class _$CodexRolloutPayloadDtoCopyWithImpl<$Res>
    implements $CodexRolloutPayloadDtoCopyWith<$Res> {
  _$CodexRolloutPayloadDtoCopyWithImpl(this._self, this._then);

  final CodexRolloutPayloadDto _self;
  final $Res Function(CodexRolloutPayloadDto) _then;

/// Create a copy of CodexRolloutPayloadDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? cwd = freezed,Object? timestamp = freezed,Object? modelProvider = freezed,Object? cliVersion = freezed,Object? model = freezed,Object? type = freezed,Object? role = freezed,Object? content = freezed,Object? summary = freezed,Object? callId = freezed,Object? name = freezed,Object? arguments = freezed,Object? input = freezed,Object? output = freezed,Object? action = freezed,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,cwd: freezed == cwd ? _self.cwd : cwd // ignore: cast_nullable_to_non_nullable
as String?,timestamp: freezed == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as String?,modelProvider: freezed == modelProvider ? _self.modelProvider : modelProvider // ignore: cast_nullable_to_non_nullable
as String?,cliVersion: freezed == cliVersion ? _self.cliVersion : cliVersion // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as CodexRolloutPayloadType?,role: freezed == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as CodexRolloutRole?,content: freezed == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as List<CodexRolloutContentDto>?,summary: freezed == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as List<CodexRolloutContentDto>?,callId: freezed == callId ? _self.callId : callId // ignore: cast_nullable_to_non_nullable
as String?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,arguments: freezed == arguments ? _self.arguments : arguments // ignore: cast_nullable_to_non_nullable
as String?,input: freezed == input ? _self.input : input // ignore: cast_nullable_to_non_nullable
as String?,output: freezed == output ? _self.output : output // ignore: cast_nullable_to_non_nullable
as List<CodexRolloutContentDto>?,action: freezed == action ? _self.action : action // ignore: cast_nullable_to_non_nullable
as CodexRolloutActionDto?,
  ));
}
/// Create a copy of CodexRolloutPayloadDto
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
  const _CodexRolloutPayloadDto({required this.id, required this.cwd, required this.timestamp, @JsonKey(name: "model_provider") required this.modelProvider, @JsonKey(name: "cli_version") required this.cliVersion, required this.model, @JsonKey(unknownEnumValue: CodexRolloutPayloadType.unknown) required this.type, @JsonKey(unknownEnumValue: CodexRolloutRole.unknown) required this.role, @CodexRolloutContentListConverter() required final  List<CodexRolloutContentDto>? content, @CodexRolloutContentListConverter() required final  List<CodexRolloutContentDto>? summary, @JsonKey(name: "call_id") required this.callId, required this.name, required this.arguments, required this.input, @CodexRolloutOutputConverter() required final  List<CodexRolloutContentDto>? output, required this.action}): _content = content,_summary = summary,_output = output;
  factory _CodexRolloutPayloadDto.fromJson(Map<String, dynamic> json) => _$CodexRolloutPayloadDtoFromJson(json);

@override final  String? id;
@override final  String? cwd;
@override final  String? timestamp;
@override@JsonKey(name: "model_provider") final  String? modelProvider;
@override@JsonKey(name: "cli_version") final  String? cliVersion;
@override final  String? model;
@override@JsonKey(unknownEnumValue: CodexRolloutPayloadType.unknown) final  CodexRolloutPayloadType? type;
@override@JsonKey(unknownEnumValue: CodexRolloutRole.unknown) final  CodexRolloutRole? role;
 final  List<CodexRolloutContentDto>? _content;
@override@CodexRolloutContentListConverter() List<CodexRolloutContentDto>? get content {
  final value = _content;
  if (value == null) return null;
  if (_content is EqualUnmodifiableListView) return _content;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

 final  List<CodexRolloutContentDto>? _summary;
@override@CodexRolloutContentListConverter() List<CodexRolloutContentDto>? get summary {
  final value = _summary;
  if (value == null) return null;
  if (_summary is EqualUnmodifiableListView) return _summary;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override@JsonKey(name: "call_id") final  String? callId;
@override final  String? name;
@override final  String? arguments;
@override final  String? input;
 final  List<CodexRolloutContentDto>? _output;
@override@CodexRolloutOutputConverter() List<CodexRolloutContentDto>? get output {
  final value = _output;
  if (value == null) return null;
  if (_output is EqualUnmodifiableListView) return _output;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  CodexRolloutActionDto? action;

/// Create a copy of CodexRolloutPayloadDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexRolloutPayloadDtoCopyWith<_CodexRolloutPayloadDto> get copyWith => __$CodexRolloutPayloadDtoCopyWithImpl<_CodexRolloutPayloadDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexRolloutPayloadDto&&(identical(other.id, id) || other.id == id)&&(identical(other.cwd, cwd) || other.cwd == cwd)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.modelProvider, modelProvider) || other.modelProvider == modelProvider)&&(identical(other.cliVersion, cliVersion) || other.cliVersion == cliVersion)&&(identical(other.model, model) || other.model == model)&&(identical(other.type, type) || other.type == type)&&(identical(other.role, role) || other.role == role)&&const DeepCollectionEquality().equals(other._content, _content)&&const DeepCollectionEquality().equals(other._summary, _summary)&&(identical(other.callId, callId) || other.callId == callId)&&(identical(other.name, name) || other.name == name)&&(identical(other.arguments, arguments) || other.arguments == arguments)&&(identical(other.input, input) || other.input == input)&&const DeepCollectionEquality().equals(other._output, _output)&&(identical(other.action, action) || other.action == action));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,cwd,timestamp,modelProvider,cliVersion,model,type,role,const DeepCollectionEquality().hash(_content),const DeepCollectionEquality().hash(_summary),callId,name,arguments,input,const DeepCollectionEquality().hash(_output),action);

@override
String toString() {
  return 'CodexRolloutPayloadDto(id: $id, cwd: $cwd, timestamp: $timestamp, modelProvider: $modelProvider, cliVersion: $cliVersion, model: $model, type: $type, role: $role, content: $content, summary: $summary, callId: $callId, name: $name, arguments: $arguments, input: $input, output: $output, action: $action)';
}


}

/// @nodoc
abstract mixin class _$CodexRolloutPayloadDtoCopyWith<$Res> implements $CodexRolloutPayloadDtoCopyWith<$Res> {
  factory _$CodexRolloutPayloadDtoCopyWith(_CodexRolloutPayloadDto value, $Res Function(_CodexRolloutPayloadDto) _then) = __$CodexRolloutPayloadDtoCopyWithImpl;
@override @useResult
$Res call({
 String? id, String? cwd, String? timestamp,@JsonKey(name: "model_provider") String? modelProvider,@JsonKey(name: "cli_version") String? cliVersion, String? model,@JsonKey(unknownEnumValue: CodexRolloutPayloadType.unknown) CodexRolloutPayloadType? type,@JsonKey(unknownEnumValue: CodexRolloutRole.unknown) CodexRolloutRole? role,@CodexRolloutContentListConverter() List<CodexRolloutContentDto>? content,@CodexRolloutContentListConverter() List<CodexRolloutContentDto>? summary,@JsonKey(name: "call_id") String? callId, String? name, String? arguments, String? input,@CodexRolloutOutputConverter() List<CodexRolloutContentDto>? output, CodexRolloutActionDto? action
});


@override $CodexRolloutActionDtoCopyWith<$Res>? get action;

}
/// @nodoc
class __$CodexRolloutPayloadDtoCopyWithImpl<$Res>
    implements _$CodexRolloutPayloadDtoCopyWith<$Res> {
  __$CodexRolloutPayloadDtoCopyWithImpl(this._self, this._then);

  final _CodexRolloutPayloadDto _self;
  final $Res Function(_CodexRolloutPayloadDto) _then;

/// Create a copy of CodexRolloutPayloadDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? cwd = freezed,Object? timestamp = freezed,Object? modelProvider = freezed,Object? cliVersion = freezed,Object? model = freezed,Object? type = freezed,Object? role = freezed,Object? content = freezed,Object? summary = freezed,Object? callId = freezed,Object? name = freezed,Object? arguments = freezed,Object? input = freezed,Object? output = freezed,Object? action = freezed,}) {
  return _then(_CodexRolloutPayloadDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,cwd: freezed == cwd ? _self.cwd : cwd // ignore: cast_nullable_to_non_nullable
as String?,timestamp: freezed == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as String?,modelProvider: freezed == modelProvider ? _self.modelProvider : modelProvider // ignore: cast_nullable_to_non_nullable
as String?,cliVersion: freezed == cliVersion ? _self.cliVersion : cliVersion // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as CodexRolloutPayloadType?,role: freezed == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as CodexRolloutRole?,content: freezed == content ? _self._content : content // ignore: cast_nullable_to_non_nullable
as List<CodexRolloutContentDto>?,summary: freezed == summary ? _self._summary : summary // ignore: cast_nullable_to_non_nullable
as List<CodexRolloutContentDto>?,callId: freezed == callId ? _self.callId : callId // ignore: cast_nullable_to_non_nullable
as String?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,arguments: freezed == arguments ? _self.arguments : arguments // ignore: cast_nullable_to_non_nullable
as String?,input: freezed == input ? _self.input : input // ignore: cast_nullable_to_non_nullable
as String?,output: freezed == output ? _self._output : output // ignore: cast_nullable_to_non_nullable
as List<CodexRolloutContentDto>?,action: freezed == action ? _self.action : action // ignore: cast_nullable_to_non_nullable
as CodexRolloutActionDto?,
  ));
}

/// Create a copy of CodexRolloutPayloadDto
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

CodexRolloutContentDto _$CodexRolloutContentDtoFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'input_text':
          return CodexRolloutInputTextDto.fromJson(
            json
          );
                case 'output_text':
          return CodexRolloutOutputTextDto.fromJson(
            json
          );
                case 'summary_text':
          return CodexRolloutSummaryTextDto.fromJson(
            json
          );
                case 'input_image':
          return CodexRolloutInputImageDto.fromJson(
            json
          );
        
          default:
            return CodexRolloutUnknownContentDto.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$CodexRolloutContentDto {



  /// Serializes this CodexRolloutContentDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexRolloutContentDto);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'CodexRolloutContentDto()';
}


}

/// @nodoc
class $CodexRolloutContentDtoCopyWith<$Res>  {
$CodexRolloutContentDtoCopyWith(CodexRolloutContentDto _, $Res Function(CodexRolloutContentDto) __);
}



/// @nodoc
@JsonSerializable()

class CodexRolloutInputTextDto implements CodexRolloutContentDto {
  const CodexRolloutInputTextDto({required this.text, final  String? $type}): $type = $type ?? 'input_text';
  factory CodexRolloutInputTextDto.fromJson(Map<String, dynamic> json) => _$CodexRolloutInputTextDtoFromJson(json);

 final  String text;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of CodexRolloutContentDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexRolloutInputTextDtoCopyWith<CodexRolloutInputTextDto> get copyWith => _$CodexRolloutInputTextDtoCopyWithImpl<CodexRolloutInputTextDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CodexRolloutInputTextDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexRolloutInputTextDto&&(identical(other.text, text) || other.text == text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,text);

@override
String toString() {
  return 'CodexRolloutContentDto.inputText(text: $text)';
}


}

/// @nodoc
abstract mixin class $CodexRolloutInputTextDtoCopyWith<$Res> implements $CodexRolloutContentDtoCopyWith<$Res> {
  factory $CodexRolloutInputTextDtoCopyWith(CodexRolloutInputTextDto value, $Res Function(CodexRolloutInputTextDto) _then) = _$CodexRolloutInputTextDtoCopyWithImpl;
@useResult
$Res call({
 String text
});




}
/// @nodoc
class _$CodexRolloutInputTextDtoCopyWithImpl<$Res>
    implements $CodexRolloutInputTextDtoCopyWith<$Res> {
  _$CodexRolloutInputTextDtoCopyWithImpl(this._self, this._then);

  final CodexRolloutInputTextDto _self;
  final $Res Function(CodexRolloutInputTextDto) _then;

/// Create a copy of CodexRolloutContentDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? text = null,}) {
  return _then(CodexRolloutInputTextDto(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class CodexRolloutOutputTextDto implements CodexRolloutContentDto {
  const CodexRolloutOutputTextDto({required this.text, final  String? $type}): $type = $type ?? 'output_text';
  factory CodexRolloutOutputTextDto.fromJson(Map<String, dynamic> json) => _$CodexRolloutOutputTextDtoFromJson(json);

 final  String text;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of CodexRolloutContentDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexRolloutOutputTextDtoCopyWith<CodexRolloutOutputTextDto> get copyWith => _$CodexRolloutOutputTextDtoCopyWithImpl<CodexRolloutOutputTextDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CodexRolloutOutputTextDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexRolloutOutputTextDto&&(identical(other.text, text) || other.text == text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,text);

@override
String toString() {
  return 'CodexRolloutContentDto.outputText(text: $text)';
}


}

/// @nodoc
abstract mixin class $CodexRolloutOutputTextDtoCopyWith<$Res> implements $CodexRolloutContentDtoCopyWith<$Res> {
  factory $CodexRolloutOutputTextDtoCopyWith(CodexRolloutOutputTextDto value, $Res Function(CodexRolloutOutputTextDto) _then) = _$CodexRolloutOutputTextDtoCopyWithImpl;
@useResult
$Res call({
 String text
});




}
/// @nodoc
class _$CodexRolloutOutputTextDtoCopyWithImpl<$Res>
    implements $CodexRolloutOutputTextDtoCopyWith<$Res> {
  _$CodexRolloutOutputTextDtoCopyWithImpl(this._self, this._then);

  final CodexRolloutOutputTextDto _self;
  final $Res Function(CodexRolloutOutputTextDto) _then;

/// Create a copy of CodexRolloutContentDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? text = null,}) {
  return _then(CodexRolloutOutputTextDto(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class CodexRolloutSummaryTextDto implements CodexRolloutContentDto {
  const CodexRolloutSummaryTextDto({required this.text, final  String? $type}): $type = $type ?? 'summary_text';
  factory CodexRolloutSummaryTextDto.fromJson(Map<String, dynamic> json) => _$CodexRolloutSummaryTextDtoFromJson(json);

 final  String text;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of CodexRolloutContentDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexRolloutSummaryTextDtoCopyWith<CodexRolloutSummaryTextDto> get copyWith => _$CodexRolloutSummaryTextDtoCopyWithImpl<CodexRolloutSummaryTextDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CodexRolloutSummaryTextDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexRolloutSummaryTextDto&&(identical(other.text, text) || other.text == text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,text);

@override
String toString() {
  return 'CodexRolloutContentDto.summaryText(text: $text)';
}


}

/// @nodoc
abstract mixin class $CodexRolloutSummaryTextDtoCopyWith<$Res> implements $CodexRolloutContentDtoCopyWith<$Res> {
  factory $CodexRolloutSummaryTextDtoCopyWith(CodexRolloutSummaryTextDto value, $Res Function(CodexRolloutSummaryTextDto) _then) = _$CodexRolloutSummaryTextDtoCopyWithImpl;
@useResult
$Res call({
 String text
});




}
/// @nodoc
class _$CodexRolloutSummaryTextDtoCopyWithImpl<$Res>
    implements $CodexRolloutSummaryTextDtoCopyWith<$Res> {
  _$CodexRolloutSummaryTextDtoCopyWithImpl(this._self, this._then);

  final CodexRolloutSummaryTextDto _self;
  final $Res Function(CodexRolloutSummaryTextDto) _then;

/// Create a copy of CodexRolloutContentDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? text = null,}) {
  return _then(CodexRolloutSummaryTextDto(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class CodexRolloutInputImageDto implements CodexRolloutContentDto {
  const CodexRolloutInputImageDto({@JsonKey(name: "image_url") required this.imageUrl, final  String? $type}): $type = $type ?? 'input_image';
  factory CodexRolloutInputImageDto.fromJson(Map<String, dynamic> json) => _$CodexRolloutInputImageDtoFromJson(json);

@JsonKey(name: "image_url") final  String imageUrl;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of CodexRolloutContentDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexRolloutInputImageDtoCopyWith<CodexRolloutInputImageDto> get copyWith => _$CodexRolloutInputImageDtoCopyWithImpl<CodexRolloutInputImageDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CodexRolloutInputImageDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexRolloutInputImageDto&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,imageUrl);

@override
String toString() {
  return 'CodexRolloutContentDto.inputImage(imageUrl: $imageUrl)';
}


}

/// @nodoc
abstract mixin class $CodexRolloutInputImageDtoCopyWith<$Res> implements $CodexRolloutContentDtoCopyWith<$Res> {
  factory $CodexRolloutInputImageDtoCopyWith(CodexRolloutInputImageDto value, $Res Function(CodexRolloutInputImageDto) _then) = _$CodexRolloutInputImageDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: "image_url") String imageUrl
});




}
/// @nodoc
class _$CodexRolloutInputImageDtoCopyWithImpl<$Res>
    implements $CodexRolloutInputImageDtoCopyWith<$Res> {
  _$CodexRolloutInputImageDtoCopyWithImpl(this._self, this._then);

  final CodexRolloutInputImageDto _self;
  final $Res Function(CodexRolloutInputImageDto) _then;

/// Create a copy of CodexRolloutContentDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? imageUrl = null,}) {
  return _then(CodexRolloutInputImageDto(
imageUrl: null == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class CodexRolloutUnknownContentDto implements CodexRolloutContentDto {
  const CodexRolloutUnknownContentDto({final  String? $type}): $type = $type ?? 'unknown';
  factory CodexRolloutUnknownContentDto.fromJson(Map<String, dynamic> json) => _$CodexRolloutUnknownContentDtoFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$CodexRolloutUnknownContentDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexRolloutUnknownContentDto);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'CodexRolloutContentDto.unknown()';
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
