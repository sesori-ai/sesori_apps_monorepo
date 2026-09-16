// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pi_rpc_state_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PiRpcStateDto {

 PiRpcStateModelDto? get model; String? get thinkingLevel; bool get isStreaming; int get pendingMessageCount;
/// Create a copy of PiRpcStateDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiRpcStateDtoCopyWith<PiRpcStateDto> get copyWith => _$PiRpcStateDtoCopyWithImpl<PiRpcStateDto>(this as PiRpcStateDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as PiRpcStateDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiRpcStateDto&&(identical(other.model, _this.model) || other.model == _this.model)&&(identical(other.thinkingLevel, _this.thinkingLevel) || other.thinkingLevel == _this.thinkingLevel)&&(identical(other.isStreaming, _this.isStreaming) || other.isStreaming == _this.isStreaming)&&(identical(other.pendingMessageCount, _this.pendingMessageCount) || other.pendingMessageCount == _this.pendingMessageCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PiRpcStateDto;
  return Object.hash(runtimeType,_this.model,_this.thinkingLevel,_this.isStreaming,_this.pendingMessageCount);
}



}

/// @nodoc
abstract mixin class $PiRpcStateDtoCopyWith<$Res>  {
  factory $PiRpcStateDtoCopyWith(PiRpcStateDto value, $Res Function(PiRpcStateDto) _then) = _$PiRpcStateDtoCopyWithImpl;
@useResult
$Res call({
 PiRpcStateModelDto? model, String? thinkingLevel, bool isStreaming, int pendingMessageCount
});


$PiRpcStateModelDtoCopyWith<$Res>? get model;

}
/// @nodoc
class _$PiRpcStateDtoCopyWithImpl<$Res>
    implements $PiRpcStateDtoCopyWith<$Res> {
  _$PiRpcStateDtoCopyWithImpl(this._self, this._then);

  final PiRpcStateDto _self;
  final $Res Function(PiRpcStateDto) _then;

/// Create a copy of PiRpcStateDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? model = freezed,Object? thinkingLevel = freezed,Object? isStreaming = null,Object? pendingMessageCount = null,}) {
  return _then(PiRpcStateDto(
model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as PiRpcStateModelDto?,thinkingLevel: freezed == thinkingLevel ? _self.thinkingLevel : thinkingLevel // ignore: cast_nullable_to_non_nullable
as String?,isStreaming: null == isStreaming ? _self.isStreaming : isStreaming // ignore: cast_nullable_to_non_nullable
as bool,pendingMessageCount: null == pendingMessageCount ? _self.pendingMessageCount : pendingMessageCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of PiRpcStateDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PiRpcStateModelDtoCopyWith<$Res>? get model {
    if (_self.model == null) {
    return null;
  }

  return $PiRpcStateModelDtoCopyWith<$Res>(_self.model!, (value) {
    return _then(_self.copyWith(model: value));
  });
}
}



/// @nodoc
@JsonSerializable(createToJson: false)

class _PiRpcStateDto implements PiRpcStateDto {
  const _PiRpcStateDto({required this.model, required this.thinkingLevel, this.isStreaming = false, this.pendingMessageCount = 0});
  factory _PiRpcStateDto.fromJson(Map<String, dynamic> json) => _$PiRpcStateDtoFromJson(json);

@override final  PiRpcStateModelDto? model;
@override final  String? thinkingLevel;
@override@JsonKey() final  bool isStreaming;
@override@JsonKey() final  int pendingMessageCount;

/// Create a copy of PiRpcStateDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PiRpcStateDtoCopyWith<_PiRpcStateDto> get copyWith => __$PiRpcStateDtoCopyWithImpl<_PiRpcStateDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PiRpcStateDto&&(identical(other.model, model) || other.model == model)&&(identical(other.thinkingLevel, thinkingLevel) || other.thinkingLevel == thinkingLevel)&&(identical(other.isStreaming, isStreaming) || other.isStreaming == isStreaming)&&(identical(other.pendingMessageCount, pendingMessageCount) || other.pendingMessageCount == pendingMessageCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,model,thinkingLevel,isStreaming,pendingMessageCount);
}



}

/// @nodoc
abstract mixin class _$PiRpcStateDtoCopyWith<$Res> implements $PiRpcStateDtoCopyWith<$Res> {
  factory _$PiRpcStateDtoCopyWith(_PiRpcStateDto value, $Res Function(_PiRpcStateDto) _then) = __$PiRpcStateDtoCopyWithImpl;
@override @useResult
$Res call({
 PiRpcStateModelDto? model, String? thinkingLevel, bool isStreaming, int pendingMessageCount
});


@override $PiRpcStateModelDtoCopyWith<$Res>? get model;

}
/// @nodoc
class __$PiRpcStateDtoCopyWithImpl<$Res>
    implements _$PiRpcStateDtoCopyWith<$Res> {
  __$PiRpcStateDtoCopyWithImpl(this._self, this._then);

  final _PiRpcStateDto _self;
  final $Res Function(_PiRpcStateDto) _then;

/// Create a copy of PiRpcStateDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? model = freezed,Object? thinkingLevel = freezed,Object? isStreaming = null,Object? pendingMessageCount = null,}) {
  return _then(_PiRpcStateDto(
model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as PiRpcStateModelDto?,thinkingLevel: freezed == thinkingLevel ? _self.thinkingLevel : thinkingLevel // ignore: cast_nullable_to_non_nullable
as String?,isStreaming: null == isStreaming ? _self.isStreaming : isStreaming // ignore: cast_nullable_to_non_nullable
as bool,pendingMessageCount: null == pendingMessageCount ? _self.pendingMessageCount : pendingMessageCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of PiRpcStateDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PiRpcStateModelDtoCopyWith<$Res>? get model {
    if (_self.model == null) {
    return null;
  }

  return $PiRpcStateModelDtoCopyWith<$Res>(_self.model!, (value) {
    return _then(_self.copyWith(model: value));
  });
}
}


/// @nodoc
mixin _$PiRpcStateModelDto {

 String get provider; String get id;
/// Create a copy of PiRpcStateModelDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiRpcStateModelDtoCopyWith<PiRpcStateModelDto> get copyWith => _$PiRpcStateModelDtoCopyWithImpl<PiRpcStateModelDto>(this as PiRpcStateModelDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as PiRpcStateModelDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiRpcStateModelDto&&(identical(other.provider, _this.provider) || other.provider == _this.provider)&&(identical(other.id, _this.id) || other.id == _this.id));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PiRpcStateModelDto;
  return Object.hash(runtimeType,_this.provider,_this.id);
}



}

/// @nodoc
abstract mixin class $PiRpcStateModelDtoCopyWith<$Res>  {
  factory $PiRpcStateModelDtoCopyWith(PiRpcStateModelDto value, $Res Function(PiRpcStateModelDto) _then) = _$PiRpcStateModelDtoCopyWithImpl;
@useResult
$Res call({
 String provider, String id
});




}
/// @nodoc
class _$PiRpcStateModelDtoCopyWithImpl<$Res>
    implements $PiRpcStateModelDtoCopyWith<$Res> {
  _$PiRpcStateModelDtoCopyWithImpl(this._self, this._then);

  final PiRpcStateModelDto _self;
  final $Res Function(PiRpcStateModelDto) _then;

/// Create a copy of PiRpcStateModelDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? provider = null,Object? id = null,}) {
  return _then(PiRpcStateModelDto(
provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _PiRpcStateModelDto implements PiRpcStateModelDto {
  const _PiRpcStateModelDto({required this.provider, required this.id});
  factory _PiRpcStateModelDto.fromJson(Map<String, dynamic> json) => _$PiRpcStateModelDtoFromJson(json);

@override final  String provider;
@override final  String id;

/// Create a copy of PiRpcStateModelDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PiRpcStateModelDtoCopyWith<_PiRpcStateModelDto> get copyWith => __$PiRpcStateModelDtoCopyWithImpl<_PiRpcStateModelDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PiRpcStateModelDto&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.id, id) || other.id == id));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,provider,id);
}



}

/// @nodoc
abstract mixin class _$PiRpcStateModelDtoCopyWith<$Res> implements $PiRpcStateModelDtoCopyWith<$Res> {
  factory _$PiRpcStateModelDtoCopyWith(_PiRpcStateModelDto value, $Res Function(_PiRpcStateModelDto) _then) = __$PiRpcStateModelDtoCopyWithImpl;
@override @useResult
$Res call({
 String provider, String id
});




}
/// @nodoc
class __$PiRpcStateModelDtoCopyWithImpl<$Res>
    implements _$PiRpcStateModelDtoCopyWith<$Res> {
  __$PiRpcStateModelDtoCopyWithImpl(this._self, this._then);

  final _PiRpcStateModelDto _self;
  final $Res Function(_PiRpcStateModelDto) _then;

/// Create a copy of PiRpcStateModelDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? provider = null,Object? id = null,}) {
  return _then(_PiRpcStateModelDto(
provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
