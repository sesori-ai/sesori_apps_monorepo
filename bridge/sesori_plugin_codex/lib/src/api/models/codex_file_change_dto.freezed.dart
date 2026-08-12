// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'codex_file_change_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CodexFileChangeParamsDto {

 String? get threadId; String? get turnId; CodexFileChangeItemDto get item;
/// Create a copy of CodexFileChangeParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexFileChangeParamsDtoCopyWith<CodexFileChangeParamsDto> get copyWith => _$CodexFileChangeParamsDtoCopyWithImpl<CodexFileChangeParamsDto>(this as CodexFileChangeParamsDto, _$identity);

  /// Serializes this CodexFileChangeParamsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexFileChangeParamsDto&&(identical(other.threadId, threadId) || other.threadId == threadId)&&(identical(other.turnId, turnId) || other.turnId == turnId)&&(identical(other.item, item) || other.item == item));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,threadId,turnId,item);

@override
String toString() {
  return 'CodexFileChangeParamsDto(threadId: $threadId, turnId: $turnId, item: $item)';
}


}

/// @nodoc
abstract mixin class $CodexFileChangeParamsDtoCopyWith<$Res>  {
  factory $CodexFileChangeParamsDtoCopyWith(CodexFileChangeParamsDto value, $Res Function(CodexFileChangeParamsDto) _then) = _$CodexFileChangeParamsDtoCopyWithImpl;
@useResult
$Res call({
 String? threadId, String? turnId, CodexFileChangeItemDto item
});


$CodexFileChangeItemDtoCopyWith<$Res> get item;

}
/// @nodoc
class _$CodexFileChangeParamsDtoCopyWithImpl<$Res>
    implements $CodexFileChangeParamsDtoCopyWith<$Res> {
  _$CodexFileChangeParamsDtoCopyWithImpl(this._self, this._then);

  final CodexFileChangeParamsDto _self;
  final $Res Function(CodexFileChangeParamsDto) _then;

/// Create a copy of CodexFileChangeParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? threadId = freezed,Object? turnId = freezed,Object? item = null,}) {
  return _then(CodexFileChangeParamsDto(
threadId: freezed == threadId ? _self.threadId : threadId // ignore: cast_nullable_to_non_nullable
as String?,turnId: freezed == turnId ? _self.turnId : turnId // ignore: cast_nullable_to_non_nullable
as String?,item: null == item ? _self.item : item // ignore: cast_nullable_to_non_nullable
as CodexFileChangeItemDto,
  ));
}
/// Create a copy of CodexFileChangeParamsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexFileChangeItemDtoCopyWith<$Res> get item {
  
  return $CodexFileChangeItemDtoCopyWith<$Res>(_self.item, (value) {
    return _then(_self.copyWith(item: value));
  });
}
}



/// @nodoc
@JsonSerializable()

class _CodexFileChangeParamsDto implements CodexFileChangeParamsDto {
  const _CodexFileChangeParamsDto({required this.threadId, required this.turnId, required this.item});
  factory _CodexFileChangeParamsDto.fromJson(Map<String, dynamic> json) => _$CodexFileChangeParamsDtoFromJson(json);

@override final  String? threadId;
@override final  String? turnId;
@override final  CodexFileChangeItemDto item;

/// Create a copy of CodexFileChangeParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexFileChangeParamsDtoCopyWith<_CodexFileChangeParamsDto> get copyWith => __$CodexFileChangeParamsDtoCopyWithImpl<_CodexFileChangeParamsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CodexFileChangeParamsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexFileChangeParamsDto&&(identical(other.threadId, threadId) || other.threadId == threadId)&&(identical(other.turnId, turnId) || other.turnId == turnId)&&(identical(other.item, item) || other.item == item));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,threadId,turnId,item);

@override
String toString() {
  return 'CodexFileChangeParamsDto(threadId: $threadId, turnId: $turnId, item: $item)';
}


}

/// @nodoc
abstract mixin class _$CodexFileChangeParamsDtoCopyWith<$Res> implements $CodexFileChangeParamsDtoCopyWith<$Res> {
  factory _$CodexFileChangeParamsDtoCopyWith(_CodexFileChangeParamsDto value, $Res Function(_CodexFileChangeParamsDto) _then) = __$CodexFileChangeParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String? threadId, String? turnId, CodexFileChangeItemDto item
});


@override $CodexFileChangeItemDtoCopyWith<$Res> get item;

}
/// @nodoc
class __$CodexFileChangeParamsDtoCopyWithImpl<$Res>
    implements _$CodexFileChangeParamsDtoCopyWith<$Res> {
  __$CodexFileChangeParamsDtoCopyWithImpl(this._self, this._then);

  final _CodexFileChangeParamsDto _self;
  final $Res Function(_CodexFileChangeParamsDto) _then;

/// Create a copy of CodexFileChangeParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? threadId = freezed,Object? turnId = freezed,Object? item = null,}) {
  return _then(_CodexFileChangeParamsDto(
threadId: freezed == threadId ? _self.threadId : threadId // ignore: cast_nullable_to_non_nullable
as String?,turnId: freezed == turnId ? _self.turnId : turnId // ignore: cast_nullable_to_non_nullable
as String?,item: null == item ? _self.item : item // ignore: cast_nullable_to_non_nullable
as CodexFileChangeItemDto,
  ));
}

/// Create a copy of CodexFileChangeParamsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexFileChangeItemDtoCopyWith<$Res> get item {
  
  return $CodexFileChangeItemDtoCopyWith<$Res>(_self.item, (value) {
    return _then(_self.copyWith(item: value));
  });
}
}


/// @nodoc
mixin _$CodexFileChangeItemDto {

@JsonKey(unknownEnumValue: CodexFileChangeItemType.unknown, defaultValue: CodexFileChangeItemType.unknown) CodexFileChangeItemType get type; String? get id;@JsonKey(fromJson: _fileChangeStatusFromJson) CodexFileChangeStatus get status;
/// Create a copy of CodexFileChangeItemDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexFileChangeItemDtoCopyWith<CodexFileChangeItemDto> get copyWith => _$CodexFileChangeItemDtoCopyWithImpl<CodexFileChangeItemDto>(this as CodexFileChangeItemDto, _$identity);

  /// Serializes this CodexFileChangeItemDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexFileChangeItemDto&&(identical(other.type, type) || other.type == type)&&(identical(other.id, id) || other.id == id)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,id,status);

@override
String toString() {
  return 'CodexFileChangeItemDto(type: $type, id: $id, status: $status)';
}


}

/// @nodoc
abstract mixin class $CodexFileChangeItemDtoCopyWith<$Res>  {
  factory $CodexFileChangeItemDtoCopyWith(CodexFileChangeItemDto value, $Res Function(CodexFileChangeItemDto) _then) = _$CodexFileChangeItemDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(unknownEnumValue: CodexFileChangeItemType.unknown, defaultValue: CodexFileChangeItemType.unknown) CodexFileChangeItemType type, String? id,@JsonKey(fromJson: _fileChangeStatusFromJson) CodexFileChangeStatus status
});




}
/// @nodoc
class _$CodexFileChangeItemDtoCopyWithImpl<$Res>
    implements $CodexFileChangeItemDtoCopyWith<$Res> {
  _$CodexFileChangeItemDtoCopyWithImpl(this._self, this._then);

  final CodexFileChangeItemDto _self;
  final $Res Function(CodexFileChangeItemDto) _then;

/// Create a copy of CodexFileChangeItemDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? id = freezed,Object? status = null,}) {
  return _then(CodexFileChangeItemDto(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as CodexFileChangeItemType,id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as CodexFileChangeStatus,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _CodexFileChangeItemDto implements CodexFileChangeItemDto {
  const _CodexFileChangeItemDto({@JsonKey(unknownEnumValue: CodexFileChangeItemType.unknown, defaultValue: CodexFileChangeItemType.unknown) required this.type, required this.id, @JsonKey(fromJson: _fileChangeStatusFromJson) required this.status});
  factory _CodexFileChangeItemDto.fromJson(Map<String, dynamic> json) => _$CodexFileChangeItemDtoFromJson(json);

@override@JsonKey(unknownEnumValue: CodexFileChangeItemType.unknown, defaultValue: CodexFileChangeItemType.unknown) final  CodexFileChangeItemType type;
@override final  String? id;
@override@JsonKey(fromJson: _fileChangeStatusFromJson) final  CodexFileChangeStatus status;

/// Create a copy of CodexFileChangeItemDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexFileChangeItemDtoCopyWith<_CodexFileChangeItemDto> get copyWith => __$CodexFileChangeItemDtoCopyWithImpl<_CodexFileChangeItemDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CodexFileChangeItemDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexFileChangeItemDto&&(identical(other.type, type) || other.type == type)&&(identical(other.id, id) || other.id == id)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,id,status);

@override
String toString() {
  return 'CodexFileChangeItemDto(type: $type, id: $id, status: $status)';
}


}

/// @nodoc
abstract mixin class _$CodexFileChangeItemDtoCopyWith<$Res> implements $CodexFileChangeItemDtoCopyWith<$Res> {
  factory _$CodexFileChangeItemDtoCopyWith(_CodexFileChangeItemDto value, $Res Function(_CodexFileChangeItemDto) _then) = __$CodexFileChangeItemDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(unknownEnumValue: CodexFileChangeItemType.unknown, defaultValue: CodexFileChangeItemType.unknown) CodexFileChangeItemType type, String? id,@JsonKey(fromJson: _fileChangeStatusFromJson) CodexFileChangeStatus status
});




}
/// @nodoc
class __$CodexFileChangeItemDtoCopyWithImpl<$Res>
    implements _$CodexFileChangeItemDtoCopyWith<$Res> {
  __$CodexFileChangeItemDtoCopyWithImpl(this._self, this._then);

  final _CodexFileChangeItemDto _self;
  final $Res Function(_CodexFileChangeItemDto) _then;

/// Create a copy of CodexFileChangeItemDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? id = freezed,Object? status = null,}) {
  return _then(_CodexFileChangeItemDto(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as CodexFileChangeItemType,id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as CodexFileChangeStatus,
  ));
}


}

// dart format on
