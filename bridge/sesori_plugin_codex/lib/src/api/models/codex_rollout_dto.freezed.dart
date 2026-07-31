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
 final  CodexRolloutResponseItemDto payload;

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
 String? timestamp, CodexRolloutResponseItemDto payload
});


$CodexRolloutResponseItemDtoCopyWith<$Res> get payload;

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
as CodexRolloutResponseItemDto,
  ));
}

/// Create a copy of CodexRolloutLineDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexRolloutResponseItemDtoCopyWith<$Res> get payload {
  
  return $CodexRolloutResponseItemDtoCopyWith<$Res>(_self.payload, (value) {
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

CodexRolloutResponseItemDto _$CodexRolloutResponseItemDtoFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'message':
          return CodexRolloutMessageDto.fromJson(
            json
          );
                case 'reasoning':
          return CodexRolloutReasoningDto.fromJson(
            json
          );
                case 'function_call':
          return CodexRolloutFunctionCallDto.fromJson(
            json
          );
                case 'function_call_output':
          return CodexRolloutFunctionCallOutputDto.fromJson(
            json
          );
                case 'custom_tool_call':
          return CodexRolloutCustomToolCallDto.fromJson(
            json
          );
                case 'custom_tool_call_output':
          return CodexRolloutCustomToolCallOutputDto.fromJson(
            json
          );
                case 'web_search_call':
          return CodexRolloutWebSearchCallDto.fromJson(
            json
          );
        
          default:
            return CodexRolloutUnknownResponseItemDto.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$CodexRolloutResponseItemDto {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexRolloutResponseItemDto);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'CodexRolloutResponseItemDto()';
}


}

/// @nodoc
class $CodexRolloutResponseItemDtoCopyWith<$Res>  {
$CodexRolloutResponseItemDtoCopyWith(CodexRolloutResponseItemDto _, $Res Function(CodexRolloutResponseItemDto) __);
}



/// @nodoc
@JsonSerializable(createToJson: false)

class CodexRolloutMessageDto implements CodexRolloutResponseItemDto {
  const CodexRolloutMessageDto({required this.id, @JsonKey(unknownEnumValue: CodexRolloutRole.unknown) required this.role, @CodexRolloutContentListConverter() required final  List<CodexRolloutContentDto> content, final  String? $type}): _content = content,$type = $type ?? 'message';
  factory CodexRolloutMessageDto.fromJson(Map<String, dynamic> json) => _$CodexRolloutMessageDtoFromJson(json);

 final  String? id;
@JsonKey(unknownEnumValue: CodexRolloutRole.unknown) final  CodexRolloutRole role;
 final  List<CodexRolloutContentDto> _content;
@CodexRolloutContentListConverter() List<CodexRolloutContentDto> get content {
  if (_content is EqualUnmodifiableListView) return _content;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_content);
}


@JsonKey(name: 'type')
final String $type;


/// Create a copy of CodexRolloutResponseItemDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexRolloutMessageDtoCopyWith<CodexRolloutMessageDto> get copyWith => _$CodexRolloutMessageDtoCopyWithImpl<CodexRolloutMessageDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexRolloutMessageDto&&(identical(other.id, id) || other.id == id)&&(identical(other.role, role) || other.role == role)&&const DeepCollectionEquality().equals(other._content, _content));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,role,const DeepCollectionEquality().hash(_content));

@override
String toString() {
  return 'CodexRolloutResponseItemDto.message(id: $id, role: $role, content: $content)';
}


}

/// @nodoc
abstract mixin class $CodexRolloutMessageDtoCopyWith<$Res> implements $CodexRolloutResponseItemDtoCopyWith<$Res> {
  factory $CodexRolloutMessageDtoCopyWith(CodexRolloutMessageDto value, $Res Function(CodexRolloutMessageDto) _then) = _$CodexRolloutMessageDtoCopyWithImpl;
@useResult
$Res call({
 String? id,@JsonKey(unknownEnumValue: CodexRolloutRole.unknown) CodexRolloutRole role,@CodexRolloutContentListConverter() List<CodexRolloutContentDto> content
});




}
/// @nodoc
class _$CodexRolloutMessageDtoCopyWithImpl<$Res>
    implements $CodexRolloutMessageDtoCopyWith<$Res> {
  _$CodexRolloutMessageDtoCopyWithImpl(this._self, this._then);

  final CodexRolloutMessageDto _self;
  final $Res Function(CodexRolloutMessageDto) _then;

/// Create a copy of CodexRolloutResponseItemDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? role = null,Object? content = null,}) {
  return _then(CodexRolloutMessageDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as CodexRolloutRole,content: null == content ? _self._content : content // ignore: cast_nullable_to_non_nullable
as List<CodexRolloutContentDto>,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class CodexRolloutReasoningDto implements CodexRolloutResponseItemDto {
  const CodexRolloutReasoningDto({required this.id, @CodexRolloutContentListConverter() required final  List<CodexRolloutContentDto> summary, final  String? $type}): _summary = summary,$type = $type ?? 'reasoning';
  factory CodexRolloutReasoningDto.fromJson(Map<String, dynamic> json) => _$CodexRolloutReasoningDtoFromJson(json);

 final  String? id;
 final  List<CodexRolloutContentDto> _summary;
@CodexRolloutContentListConverter() List<CodexRolloutContentDto> get summary {
  if (_summary is EqualUnmodifiableListView) return _summary;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_summary);
}


@JsonKey(name: 'type')
final String $type;


/// Create a copy of CodexRolloutResponseItemDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexRolloutReasoningDtoCopyWith<CodexRolloutReasoningDto> get copyWith => _$CodexRolloutReasoningDtoCopyWithImpl<CodexRolloutReasoningDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexRolloutReasoningDto&&(identical(other.id, id) || other.id == id)&&const DeepCollectionEquality().equals(other._summary, _summary));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,const DeepCollectionEquality().hash(_summary));

@override
String toString() {
  return 'CodexRolloutResponseItemDto.reasoning(id: $id, summary: $summary)';
}


}

/// @nodoc
abstract mixin class $CodexRolloutReasoningDtoCopyWith<$Res> implements $CodexRolloutResponseItemDtoCopyWith<$Res> {
  factory $CodexRolloutReasoningDtoCopyWith(CodexRolloutReasoningDto value, $Res Function(CodexRolloutReasoningDto) _then) = _$CodexRolloutReasoningDtoCopyWithImpl;
@useResult
$Res call({
 String? id,@CodexRolloutContentListConverter() List<CodexRolloutContentDto> summary
});




}
/// @nodoc
class _$CodexRolloutReasoningDtoCopyWithImpl<$Res>
    implements $CodexRolloutReasoningDtoCopyWith<$Res> {
  _$CodexRolloutReasoningDtoCopyWithImpl(this._self, this._then);

  final CodexRolloutReasoningDto _self;
  final $Res Function(CodexRolloutReasoningDto) _then;

/// Create a copy of CodexRolloutResponseItemDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? summary = null,}) {
  return _then(CodexRolloutReasoningDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,summary: null == summary ? _self._summary : summary // ignore: cast_nullable_to_non_nullable
as List<CodexRolloutContentDto>,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class CodexRolloutFunctionCallDto implements CodexRolloutResponseItemDto {
  const CodexRolloutFunctionCallDto({required this.id, @JsonKey(name: "call_id") required this.callId, required this.name, required this.arguments, final  String? $type}): $type = $type ?? 'function_call';
  factory CodexRolloutFunctionCallDto.fromJson(Map<String, dynamic> json) => _$CodexRolloutFunctionCallDtoFromJson(json);

 final  String? id;
@JsonKey(name: "call_id") final  String callId;
 final  String name;
 final  String arguments;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of CodexRolloutResponseItemDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexRolloutFunctionCallDtoCopyWith<CodexRolloutFunctionCallDto> get copyWith => _$CodexRolloutFunctionCallDtoCopyWithImpl<CodexRolloutFunctionCallDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexRolloutFunctionCallDto&&(identical(other.id, id) || other.id == id)&&(identical(other.callId, callId) || other.callId == callId)&&(identical(other.name, name) || other.name == name)&&(identical(other.arguments, arguments) || other.arguments == arguments));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,callId,name,arguments);

@override
String toString() {
  return 'CodexRolloutResponseItemDto.functionCall(id: $id, callId: $callId, name: $name, arguments: $arguments)';
}


}

/// @nodoc
abstract mixin class $CodexRolloutFunctionCallDtoCopyWith<$Res> implements $CodexRolloutResponseItemDtoCopyWith<$Res> {
  factory $CodexRolloutFunctionCallDtoCopyWith(CodexRolloutFunctionCallDto value, $Res Function(CodexRolloutFunctionCallDto) _then) = _$CodexRolloutFunctionCallDtoCopyWithImpl;
@useResult
$Res call({
 String? id,@JsonKey(name: "call_id") String callId, String name, String arguments
});




}
/// @nodoc
class _$CodexRolloutFunctionCallDtoCopyWithImpl<$Res>
    implements $CodexRolloutFunctionCallDtoCopyWith<$Res> {
  _$CodexRolloutFunctionCallDtoCopyWithImpl(this._self, this._then);

  final CodexRolloutFunctionCallDto _self;
  final $Res Function(CodexRolloutFunctionCallDto) _then;

/// Create a copy of CodexRolloutResponseItemDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? callId = null,Object? name = null,Object? arguments = null,}) {
  return _then(CodexRolloutFunctionCallDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,callId: null == callId ? _self.callId : callId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,arguments: null == arguments ? _self.arguments : arguments // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class CodexRolloutFunctionCallOutputDto implements CodexRolloutResponseItemDto {
  const CodexRolloutFunctionCallOutputDto({@JsonKey(name: "call_id") required this.callId, @CodexRolloutOutputConverter() required final  List<CodexRolloutContentDto> output, final  String? $type}): _output = output,$type = $type ?? 'function_call_output';
  factory CodexRolloutFunctionCallOutputDto.fromJson(Map<String, dynamic> json) => _$CodexRolloutFunctionCallOutputDtoFromJson(json);

@JsonKey(name: "call_id") final  String callId;
 final  List<CodexRolloutContentDto> _output;
@CodexRolloutOutputConverter() List<CodexRolloutContentDto> get output {
  if (_output is EqualUnmodifiableListView) return _output;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_output);
}


@JsonKey(name: 'type')
final String $type;


/// Create a copy of CodexRolloutResponseItemDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexRolloutFunctionCallOutputDtoCopyWith<CodexRolloutFunctionCallOutputDto> get copyWith => _$CodexRolloutFunctionCallOutputDtoCopyWithImpl<CodexRolloutFunctionCallOutputDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexRolloutFunctionCallOutputDto&&(identical(other.callId, callId) || other.callId == callId)&&const DeepCollectionEquality().equals(other._output, _output));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,callId,const DeepCollectionEquality().hash(_output));

@override
String toString() {
  return 'CodexRolloutResponseItemDto.functionCallOutput(callId: $callId, output: $output)';
}


}

/// @nodoc
abstract mixin class $CodexRolloutFunctionCallOutputDtoCopyWith<$Res> implements $CodexRolloutResponseItemDtoCopyWith<$Res> {
  factory $CodexRolloutFunctionCallOutputDtoCopyWith(CodexRolloutFunctionCallOutputDto value, $Res Function(CodexRolloutFunctionCallOutputDto) _then) = _$CodexRolloutFunctionCallOutputDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: "call_id") String callId,@CodexRolloutOutputConverter() List<CodexRolloutContentDto> output
});




}
/// @nodoc
class _$CodexRolloutFunctionCallOutputDtoCopyWithImpl<$Res>
    implements $CodexRolloutFunctionCallOutputDtoCopyWith<$Res> {
  _$CodexRolloutFunctionCallOutputDtoCopyWithImpl(this._self, this._then);

  final CodexRolloutFunctionCallOutputDto _self;
  final $Res Function(CodexRolloutFunctionCallOutputDto) _then;

/// Create a copy of CodexRolloutResponseItemDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? callId = null,Object? output = null,}) {
  return _then(CodexRolloutFunctionCallOutputDto(
callId: null == callId ? _self.callId : callId // ignore: cast_nullable_to_non_nullable
as String,output: null == output ? _self._output : output // ignore: cast_nullable_to_non_nullable
as List<CodexRolloutContentDto>,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class CodexRolloutCustomToolCallDto implements CodexRolloutResponseItemDto {
  const CodexRolloutCustomToolCallDto({required this.id, @JsonKey(name: "call_id") required this.callId, required this.name, required this.input, final  String? $type}): $type = $type ?? 'custom_tool_call';
  factory CodexRolloutCustomToolCallDto.fromJson(Map<String, dynamic> json) => _$CodexRolloutCustomToolCallDtoFromJson(json);

 final  String? id;
@JsonKey(name: "call_id") final  String callId;
 final  String name;
 final  String input;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of CodexRolloutResponseItemDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexRolloutCustomToolCallDtoCopyWith<CodexRolloutCustomToolCallDto> get copyWith => _$CodexRolloutCustomToolCallDtoCopyWithImpl<CodexRolloutCustomToolCallDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexRolloutCustomToolCallDto&&(identical(other.id, id) || other.id == id)&&(identical(other.callId, callId) || other.callId == callId)&&(identical(other.name, name) || other.name == name)&&(identical(other.input, input) || other.input == input));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,callId,name,input);

@override
String toString() {
  return 'CodexRolloutResponseItemDto.customToolCall(id: $id, callId: $callId, name: $name, input: $input)';
}


}

/// @nodoc
abstract mixin class $CodexRolloutCustomToolCallDtoCopyWith<$Res> implements $CodexRolloutResponseItemDtoCopyWith<$Res> {
  factory $CodexRolloutCustomToolCallDtoCopyWith(CodexRolloutCustomToolCallDto value, $Res Function(CodexRolloutCustomToolCallDto) _then) = _$CodexRolloutCustomToolCallDtoCopyWithImpl;
@useResult
$Res call({
 String? id,@JsonKey(name: "call_id") String callId, String name, String input
});




}
/// @nodoc
class _$CodexRolloutCustomToolCallDtoCopyWithImpl<$Res>
    implements $CodexRolloutCustomToolCallDtoCopyWith<$Res> {
  _$CodexRolloutCustomToolCallDtoCopyWithImpl(this._self, this._then);

  final CodexRolloutCustomToolCallDto _self;
  final $Res Function(CodexRolloutCustomToolCallDto) _then;

/// Create a copy of CodexRolloutResponseItemDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? callId = null,Object? name = null,Object? input = null,}) {
  return _then(CodexRolloutCustomToolCallDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,callId: null == callId ? _self.callId : callId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,input: null == input ? _self.input : input // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class CodexRolloutCustomToolCallOutputDto implements CodexRolloutResponseItemDto {
  const CodexRolloutCustomToolCallOutputDto({@JsonKey(name: "call_id") required this.callId, @CodexRolloutOutputConverter() required final  List<CodexRolloutContentDto> output, final  String? $type}): _output = output,$type = $type ?? 'custom_tool_call_output';
  factory CodexRolloutCustomToolCallOutputDto.fromJson(Map<String, dynamic> json) => _$CodexRolloutCustomToolCallOutputDtoFromJson(json);

@JsonKey(name: "call_id") final  String callId;
 final  List<CodexRolloutContentDto> _output;
@CodexRolloutOutputConverter() List<CodexRolloutContentDto> get output {
  if (_output is EqualUnmodifiableListView) return _output;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_output);
}


@JsonKey(name: 'type')
final String $type;


/// Create a copy of CodexRolloutResponseItemDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexRolloutCustomToolCallOutputDtoCopyWith<CodexRolloutCustomToolCallOutputDto> get copyWith => _$CodexRolloutCustomToolCallOutputDtoCopyWithImpl<CodexRolloutCustomToolCallOutputDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexRolloutCustomToolCallOutputDto&&(identical(other.callId, callId) || other.callId == callId)&&const DeepCollectionEquality().equals(other._output, _output));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,callId,const DeepCollectionEquality().hash(_output));

@override
String toString() {
  return 'CodexRolloutResponseItemDto.customToolCallOutput(callId: $callId, output: $output)';
}


}

/// @nodoc
abstract mixin class $CodexRolloutCustomToolCallOutputDtoCopyWith<$Res> implements $CodexRolloutResponseItemDtoCopyWith<$Res> {
  factory $CodexRolloutCustomToolCallOutputDtoCopyWith(CodexRolloutCustomToolCallOutputDto value, $Res Function(CodexRolloutCustomToolCallOutputDto) _then) = _$CodexRolloutCustomToolCallOutputDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: "call_id") String callId,@CodexRolloutOutputConverter() List<CodexRolloutContentDto> output
});




}
/// @nodoc
class _$CodexRolloutCustomToolCallOutputDtoCopyWithImpl<$Res>
    implements $CodexRolloutCustomToolCallOutputDtoCopyWith<$Res> {
  _$CodexRolloutCustomToolCallOutputDtoCopyWithImpl(this._self, this._then);

  final CodexRolloutCustomToolCallOutputDto _self;
  final $Res Function(CodexRolloutCustomToolCallOutputDto) _then;

/// Create a copy of CodexRolloutResponseItemDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? callId = null,Object? output = null,}) {
  return _then(CodexRolloutCustomToolCallOutputDto(
callId: null == callId ? _self.callId : callId // ignore: cast_nullable_to_non_nullable
as String,output: null == output ? _self._output : output // ignore: cast_nullable_to_non_nullable
as List<CodexRolloutContentDto>,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class CodexRolloutWebSearchCallDto implements CodexRolloutResponseItemDto {
  const CodexRolloutWebSearchCallDto({required this.id, required this.action, final  String? $type}): $type = $type ?? 'web_search_call';
  factory CodexRolloutWebSearchCallDto.fromJson(Map<String, dynamic> json) => _$CodexRolloutWebSearchCallDtoFromJson(json);

 final  String? id;
 final  CodexRolloutActionDto? action;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of CodexRolloutResponseItemDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexRolloutWebSearchCallDtoCopyWith<CodexRolloutWebSearchCallDto> get copyWith => _$CodexRolloutWebSearchCallDtoCopyWithImpl<CodexRolloutWebSearchCallDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexRolloutWebSearchCallDto&&(identical(other.id, id) || other.id == id)&&(identical(other.action, action) || other.action == action));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,action);

@override
String toString() {
  return 'CodexRolloutResponseItemDto.webSearchCall(id: $id, action: $action)';
}


}

/// @nodoc
abstract mixin class $CodexRolloutWebSearchCallDtoCopyWith<$Res> implements $CodexRolloutResponseItemDtoCopyWith<$Res> {
  factory $CodexRolloutWebSearchCallDtoCopyWith(CodexRolloutWebSearchCallDto value, $Res Function(CodexRolloutWebSearchCallDto) _then) = _$CodexRolloutWebSearchCallDtoCopyWithImpl;
@useResult
$Res call({
 String? id, CodexRolloutActionDto? action
});


$CodexRolloutActionDtoCopyWith<$Res>? get action;

}
/// @nodoc
class _$CodexRolloutWebSearchCallDtoCopyWithImpl<$Res>
    implements $CodexRolloutWebSearchCallDtoCopyWith<$Res> {
  _$CodexRolloutWebSearchCallDtoCopyWithImpl(this._self, this._then);

  final CodexRolloutWebSearchCallDto _self;
  final $Res Function(CodexRolloutWebSearchCallDto) _then;

/// Create a copy of CodexRolloutResponseItemDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? action = freezed,}) {
  return _then(CodexRolloutWebSearchCallDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,action: freezed == action ? _self.action : action // ignore: cast_nullable_to_non_nullable
as CodexRolloutActionDto?,
  ));
}

/// Create a copy of CodexRolloutResponseItemDto
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

class CodexRolloutUnknownResponseItemDto implements CodexRolloutResponseItemDto {
  const CodexRolloutUnknownResponseItemDto({final  String? $type}): $type = $type ?? 'unknown';
  factory CodexRolloutUnknownResponseItemDto.fromJson(Map<String, dynamic> json) => _$CodexRolloutUnknownResponseItemDtoFromJson(json);



@JsonKey(name: 'type')
final String $type;





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexRolloutUnknownResponseItemDto);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'CodexRolloutResponseItemDto.unknown()';
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
