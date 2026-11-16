// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'hermes_replay_update_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$HermesReplayUpdateDto {

 String? get sessionUpdate;@JsonKey(name: "_meta") HermesUpdateMetaDto? get meta; HermesTextContentDto? get content;
/// Create a copy of HermesReplayUpdateDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HermesReplayUpdateDtoCopyWith<HermesReplayUpdateDto> get copyWith => _$HermesReplayUpdateDtoCopyWithImpl<HermesReplayUpdateDto>(this as HermesReplayUpdateDto, _$identity);

  /// Serializes this HermesReplayUpdateDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as HermesReplayUpdateDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HermesReplayUpdateDto&&(identical(other.sessionUpdate, _this.sessionUpdate) || other.sessionUpdate == _this.sessionUpdate)&&(identical(other.meta, _this.meta) || other.meta == _this.meta)&&(identical(other.content, _this.content) || other.content == _this.content));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as HermesReplayUpdateDto;
  return Object.hash(runtimeType,_this.sessionUpdate,_this.meta,_this.content);
}

@override
String toString() {
  final _this = this as HermesReplayUpdateDto;
  return 'HermesReplayUpdateDto(sessionUpdate: ${_this.sessionUpdate}, meta: ${_this.meta}, content: ${_this.content})';
}


}

/// @nodoc
abstract mixin class $HermesReplayUpdateDtoCopyWith<$Res>  {
  factory $HermesReplayUpdateDtoCopyWith(HermesReplayUpdateDto value, $Res Function(HermesReplayUpdateDto) _then) = _$HermesReplayUpdateDtoCopyWithImpl;
@useResult
$Res call({
 String? sessionUpdate,@JsonKey(name: "_meta") HermesUpdateMetaDto? meta, HermesTextContentDto? content
});


$HermesUpdateMetaDtoCopyWith<$Res>? get meta;$HermesTextContentDtoCopyWith<$Res>? get content;

}
/// @nodoc
class _$HermesReplayUpdateDtoCopyWithImpl<$Res>
    implements $HermesReplayUpdateDtoCopyWith<$Res> {
  _$HermesReplayUpdateDtoCopyWithImpl(this._self, this._then);

  final HermesReplayUpdateDto _self;
  final $Res Function(HermesReplayUpdateDto) _then;

/// Create a copy of HermesReplayUpdateDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionUpdate = freezed,Object? meta = freezed,Object? content = freezed,}) {
  return _then(HermesReplayUpdateDto(
sessionUpdate: freezed == sessionUpdate ? _self.sessionUpdate : sessionUpdate // ignore: cast_nullable_to_non_nullable
as String?,meta: freezed == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as HermesUpdateMetaDto?,content: freezed == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as HermesTextContentDto?,
  ));
}
/// Create a copy of HermesReplayUpdateDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$HermesUpdateMetaDtoCopyWith<$Res>? get meta {
    if (_self.meta == null) {
    return null;
  }

  return $HermesUpdateMetaDtoCopyWith<$Res>(_self.meta!, (value) {
    return _then(_self.copyWith(meta: value));
  });
}/// Create a copy of HermesReplayUpdateDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$HermesTextContentDtoCopyWith<$Res>? get content {
    if (_self.content == null) {
    return null;
  }

  return $HermesTextContentDtoCopyWith<$Res>(_self.content!, (value) {
    return _then(_self.copyWith(content: value));
  });
}
}



/// @nodoc
@JsonSerializable()

class _HermesReplayUpdateDto implements HermesReplayUpdateDto {
  const _HermesReplayUpdateDto({required this.sessionUpdate, @JsonKey(name: "_meta") required this.meta, required this.content});
  factory _HermesReplayUpdateDto.fromJson(Map<String, dynamic> json) => _$HermesReplayUpdateDtoFromJson(json);

@override final  String? sessionUpdate;
@override@JsonKey(name: "_meta") final  HermesUpdateMetaDto? meta;
@override final  HermesTextContentDto? content;

/// Create a copy of HermesReplayUpdateDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HermesReplayUpdateDtoCopyWith<_HermesReplayUpdateDto> get copyWith => __$HermesReplayUpdateDtoCopyWithImpl<_HermesReplayUpdateDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$HermesReplayUpdateDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _HermesReplayUpdateDto&&(identical(other.sessionUpdate, sessionUpdate) || other.sessionUpdate == sessionUpdate)&&(identical(other.meta, meta) || other.meta == meta)&&(identical(other.content, content) || other.content == content));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,sessionUpdate,meta,content);
}

@override
String toString() {
    return 'HermesReplayUpdateDto(sessionUpdate: $sessionUpdate, meta: $meta, content: $content)';
}


}

/// @nodoc
abstract mixin class _$HermesReplayUpdateDtoCopyWith<$Res> implements $HermesReplayUpdateDtoCopyWith<$Res> {
  factory _$HermesReplayUpdateDtoCopyWith(_HermesReplayUpdateDto value, $Res Function(_HermesReplayUpdateDto) _then) = __$HermesReplayUpdateDtoCopyWithImpl;
@override @useResult
$Res call({
 String? sessionUpdate,@JsonKey(name: "_meta") HermesUpdateMetaDto? meta, HermesTextContentDto? content
});


@override $HermesUpdateMetaDtoCopyWith<$Res>? get meta;@override $HermesTextContentDtoCopyWith<$Res>? get content;

}
/// @nodoc
class __$HermesReplayUpdateDtoCopyWithImpl<$Res>
    implements _$HermesReplayUpdateDtoCopyWith<$Res> {
  __$HermesReplayUpdateDtoCopyWithImpl(this._self, this._then);

  final _HermesReplayUpdateDto _self;
  final $Res Function(_HermesReplayUpdateDto) _then;

/// Create a copy of HermesReplayUpdateDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionUpdate = freezed,Object? meta = freezed,Object? content = freezed,}) {
  return _then(_HermesReplayUpdateDto(
sessionUpdate: freezed == sessionUpdate ? _self.sessionUpdate : sessionUpdate // ignore: cast_nullable_to_non_nullable
as String?,meta: freezed == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as HermesUpdateMetaDto?,content: freezed == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as HermesTextContentDto?,
  ));
}

/// Create a copy of HermesReplayUpdateDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$HermesUpdateMetaDtoCopyWith<$Res>? get meta {
    if (_self.meta == null) {
    return null;
  }

  return $HermesUpdateMetaDtoCopyWith<$Res>(_self.meta!, (value) {
    return _then(_self.copyWith(meta: value));
  });
}/// Create a copy of HermesReplayUpdateDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$HermesTextContentDtoCopyWith<$Res>? get content {
    if (_self.content == null) {
    return null;
  }

  return $HermesTextContentDtoCopyWith<$Res>(_self.content!, (value) {
    return _then(_self.copyWith(content: value));
  });
}
}


/// @nodoc
mixin _$HermesUpdateMetaDto {

 HermesMetaDto? get hermes;
/// Create a copy of HermesUpdateMetaDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HermesUpdateMetaDtoCopyWith<HermesUpdateMetaDto> get copyWith => _$HermesUpdateMetaDtoCopyWithImpl<HermesUpdateMetaDto>(this as HermesUpdateMetaDto, _$identity);

  /// Serializes this HermesUpdateMetaDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as HermesUpdateMetaDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HermesUpdateMetaDto&&(identical(other.hermes, _this.hermes) || other.hermes == _this.hermes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as HermesUpdateMetaDto;
  return Object.hash(runtimeType,_this.hermes);
}

@override
String toString() {
  final _this = this as HermesUpdateMetaDto;
  return 'HermesUpdateMetaDto(hermes: ${_this.hermes})';
}


}

/// @nodoc
abstract mixin class $HermesUpdateMetaDtoCopyWith<$Res>  {
  factory $HermesUpdateMetaDtoCopyWith(HermesUpdateMetaDto value, $Res Function(HermesUpdateMetaDto) _then) = _$HermesUpdateMetaDtoCopyWithImpl;
@useResult
$Res call({
 HermesMetaDto? hermes
});


$HermesMetaDtoCopyWith<$Res>? get hermes;

}
/// @nodoc
class _$HermesUpdateMetaDtoCopyWithImpl<$Res>
    implements $HermesUpdateMetaDtoCopyWith<$Res> {
  _$HermesUpdateMetaDtoCopyWithImpl(this._self, this._then);

  final HermesUpdateMetaDto _self;
  final $Res Function(HermesUpdateMetaDto) _then;

/// Create a copy of HermesUpdateMetaDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? hermes = freezed,}) {
  return _then(HermesUpdateMetaDto(
hermes: freezed == hermes ? _self.hermes : hermes // ignore: cast_nullable_to_non_nullable
as HermesMetaDto?,
  ));
}
/// Create a copy of HermesUpdateMetaDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$HermesMetaDtoCopyWith<$Res>? get hermes {
    if (_self.hermes == null) {
    return null;
  }

  return $HermesMetaDtoCopyWith<$Res>(_self.hermes!, (value) {
    return _then(_self.copyWith(hermes: value));
  });
}
}



/// @nodoc
@JsonSerializable()

class _HermesUpdateMetaDto implements HermesUpdateMetaDto {
  const _HermesUpdateMetaDto({required this.hermes});
  factory _HermesUpdateMetaDto.fromJson(Map<String, dynamic> json) => _$HermesUpdateMetaDtoFromJson(json);

@override final  HermesMetaDto? hermes;

/// Create a copy of HermesUpdateMetaDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HermesUpdateMetaDtoCopyWith<_HermesUpdateMetaDto> get copyWith => __$HermesUpdateMetaDtoCopyWithImpl<_HermesUpdateMetaDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$HermesUpdateMetaDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _HermesUpdateMetaDto&&(identical(other.hermes, hermes) || other.hermes == hermes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,hermes);
}

@override
String toString() {
    return 'HermesUpdateMetaDto(hermes: $hermes)';
}


}

/// @nodoc
abstract mixin class _$HermesUpdateMetaDtoCopyWith<$Res> implements $HermesUpdateMetaDtoCopyWith<$Res> {
  factory _$HermesUpdateMetaDtoCopyWith(_HermesUpdateMetaDto value, $Res Function(_HermesUpdateMetaDto) _then) = __$HermesUpdateMetaDtoCopyWithImpl;
@override @useResult
$Res call({
 HermesMetaDto? hermes
});


@override $HermesMetaDtoCopyWith<$Res>? get hermes;

}
/// @nodoc
class __$HermesUpdateMetaDtoCopyWithImpl<$Res>
    implements _$HermesUpdateMetaDtoCopyWith<$Res> {
  __$HermesUpdateMetaDtoCopyWithImpl(this._self, this._then);

  final _HermesUpdateMetaDto _self;
  final $Res Function(_HermesUpdateMetaDto) _then;

/// Create a copy of HermesUpdateMetaDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? hermes = freezed,}) {
  return _then(_HermesUpdateMetaDto(
hermes: freezed == hermes ? _self.hermes : hermes // ignore: cast_nullable_to_non_nullable
as HermesMetaDto?,
  ));
}

/// Create a copy of HermesUpdateMetaDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$HermesMetaDtoCopyWith<$Res>? get hermes {
    if (_self.hermes == null) {
    return null;
  }

  return $HermesMetaDtoCopyWith<$Res>(_self.hermes!, (value) {
    return _then(_self.copyWith(hermes: value));
  });
}
}


/// @nodoc
mixin _$HermesMetaDto {

 bool? get compactionSummary;
/// Create a copy of HermesMetaDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HermesMetaDtoCopyWith<HermesMetaDto> get copyWith => _$HermesMetaDtoCopyWithImpl<HermesMetaDto>(this as HermesMetaDto, _$identity);

  /// Serializes this HermesMetaDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as HermesMetaDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HermesMetaDto&&(identical(other.compactionSummary, _this.compactionSummary) || other.compactionSummary == _this.compactionSummary));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as HermesMetaDto;
  return Object.hash(runtimeType,_this.compactionSummary);
}

@override
String toString() {
  final _this = this as HermesMetaDto;
  return 'HermesMetaDto(compactionSummary: ${_this.compactionSummary})';
}


}

/// @nodoc
abstract mixin class $HermesMetaDtoCopyWith<$Res>  {
  factory $HermesMetaDtoCopyWith(HermesMetaDto value, $Res Function(HermesMetaDto) _then) = _$HermesMetaDtoCopyWithImpl;
@useResult
$Res call({
 bool? compactionSummary
});




}
/// @nodoc
class _$HermesMetaDtoCopyWithImpl<$Res>
    implements $HermesMetaDtoCopyWith<$Res> {
  _$HermesMetaDtoCopyWithImpl(this._self, this._then);

  final HermesMetaDto _self;
  final $Res Function(HermesMetaDto) _then;

/// Create a copy of HermesMetaDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? compactionSummary = freezed,}) {
  return _then(HermesMetaDto(
compactionSummary: freezed == compactionSummary ? _self.compactionSummary : compactionSummary // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _HermesMetaDto implements HermesMetaDto {
  const _HermesMetaDto({required this.compactionSummary});
  factory _HermesMetaDto.fromJson(Map<String, dynamic> json) => _$HermesMetaDtoFromJson(json);

@override final  bool? compactionSummary;

/// Create a copy of HermesMetaDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HermesMetaDtoCopyWith<_HermesMetaDto> get copyWith => __$HermesMetaDtoCopyWithImpl<_HermesMetaDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$HermesMetaDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _HermesMetaDto&&(identical(other.compactionSummary, compactionSummary) || other.compactionSummary == compactionSummary));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,compactionSummary);
}

@override
String toString() {
    return 'HermesMetaDto(compactionSummary: $compactionSummary)';
}


}

/// @nodoc
abstract mixin class _$HermesMetaDtoCopyWith<$Res> implements $HermesMetaDtoCopyWith<$Res> {
  factory _$HermesMetaDtoCopyWith(_HermesMetaDto value, $Res Function(_HermesMetaDto) _then) = __$HermesMetaDtoCopyWithImpl;
@override @useResult
$Res call({
 bool? compactionSummary
});




}
/// @nodoc
class __$HermesMetaDtoCopyWithImpl<$Res>
    implements _$HermesMetaDtoCopyWith<$Res> {
  __$HermesMetaDtoCopyWithImpl(this._self, this._then);

  final _HermesMetaDto _self;
  final $Res Function(_HermesMetaDto) _then;

/// Create a copy of HermesMetaDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? compactionSummary = freezed,}) {
  return _then(_HermesMetaDto(
compactionSummary: freezed == compactionSummary ? _self.compactionSummary : compactionSummary // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}


}


/// @nodoc
mixin _$HermesTextContentDto {

 String? get type; String? get text;
/// Create a copy of HermesTextContentDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HermesTextContentDtoCopyWith<HermesTextContentDto> get copyWith => _$HermesTextContentDtoCopyWithImpl<HermesTextContentDto>(this as HermesTextContentDto, _$identity);

  /// Serializes this HermesTextContentDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as HermesTextContentDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HermesTextContentDto&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.text, _this.text) || other.text == _this.text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as HermesTextContentDto;
  return Object.hash(runtimeType,_this.type,_this.text);
}

@override
String toString() {
  final _this = this as HermesTextContentDto;
  return 'HermesTextContentDto(type: ${_this.type}, text: ${_this.text})';
}


}

/// @nodoc
abstract mixin class $HermesTextContentDtoCopyWith<$Res>  {
  factory $HermesTextContentDtoCopyWith(HermesTextContentDto value, $Res Function(HermesTextContentDto) _then) = _$HermesTextContentDtoCopyWithImpl;
@useResult
$Res call({
 String? type, String? text
});




}
/// @nodoc
class _$HermesTextContentDtoCopyWithImpl<$Res>
    implements $HermesTextContentDtoCopyWith<$Res> {
  _$HermesTextContentDtoCopyWithImpl(this._self, this._then);

  final HermesTextContentDto _self;
  final $Res Function(HermesTextContentDto) _then;

/// Create a copy of HermesTextContentDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = freezed,Object? text = freezed,}) {
  return _then(HermesTextContentDto(
type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String?,text: freezed == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _HermesTextContentDto implements HermesTextContentDto {
  const _HermesTextContentDto({required this.type, required this.text});
  factory _HermesTextContentDto.fromJson(Map<String, dynamic> json) => _$HermesTextContentDtoFromJson(json);

@override final  String? type;
@override final  String? text;

/// Create a copy of HermesTextContentDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HermesTextContentDtoCopyWith<_HermesTextContentDto> get copyWith => __$HermesTextContentDtoCopyWithImpl<_HermesTextContentDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$HermesTextContentDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _HermesTextContentDto&&(identical(other.type, type) || other.type == type)&&(identical(other.text, text) || other.text == text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,type,text);
}

@override
String toString() {
    return 'HermesTextContentDto(type: $type, text: $text)';
}


}

/// @nodoc
abstract mixin class _$HermesTextContentDtoCopyWith<$Res> implements $HermesTextContentDtoCopyWith<$Res> {
  factory _$HermesTextContentDtoCopyWith(_HermesTextContentDto value, $Res Function(_HermesTextContentDto) _then) = __$HermesTextContentDtoCopyWithImpl;
@override @useResult
$Res call({
 String? type, String? text
});




}
/// @nodoc
class __$HermesTextContentDtoCopyWithImpl<$Res>
    implements _$HermesTextContentDtoCopyWith<$Res> {
  __$HermesTextContentDtoCopyWithImpl(this._self, this._then);

  final _HermesTextContentDto _self;
  final $Res Function(_HermesTextContentDto) _then;

/// Create a copy of HermesTextContentDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = freezed,Object? text = freezed,}) {
  return _then(_HermesTextContentDto(
type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String?,text: freezed == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
