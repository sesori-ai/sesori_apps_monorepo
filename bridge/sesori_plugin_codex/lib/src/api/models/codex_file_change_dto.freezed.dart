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
  final _this = this as CodexFileChangeParamsDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexFileChangeParamsDto&&(identical(other.threadId, _this.threadId) || other.threadId == _this.threadId)&&(identical(other.turnId, _this.turnId) || other.turnId == _this.turnId)&&(identical(other.item, _this.item) || other.item == _this.item));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CodexFileChangeParamsDto;
  return Object.hash(runtimeType,_this.threadId,_this.turnId,_this.item);
}

@override
String toString() {
  final _this = this as CodexFileChangeParamsDto;
  return 'CodexFileChangeParamsDto(threadId: ${_this.threadId}, turnId: ${_this.turnId}, item: ${_this.item})';
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
int get hashCode {
    return Object.hash(runtimeType,threadId,turnId,item);
}

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

@JsonKey(unknownEnumValue: CodexFileChangeItemType.unknown, defaultValue: CodexFileChangeItemType.unknown) CodexFileChangeItemType get type; String? get id;@JsonKey(fromJson: _fileChangeStatusFromJson) CodexFileChangeStatus get status; List<CodexFileUpdateDto> get changes;
/// Create a copy of CodexFileChangeItemDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexFileChangeItemDtoCopyWith<CodexFileChangeItemDto> get copyWith => _$CodexFileChangeItemDtoCopyWithImpl<CodexFileChangeItemDto>(this as CodexFileChangeItemDto, _$identity);

  /// Serializes this CodexFileChangeItemDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as CodexFileChangeItemDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexFileChangeItemDto&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.status, _this.status) || other.status == _this.status)&&const DeepCollectionEquality().equals(other.changes, _this.changes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CodexFileChangeItemDto;
  return Object.hash(runtimeType,_this.type,_this.id,_this.status,const DeepCollectionEquality().hash(_this.changes));
}

@override
String toString() {
  final _this = this as CodexFileChangeItemDto;
  return 'CodexFileChangeItemDto(type: ${_this.type}, id: ${_this.id}, status: ${_this.status}, changes: ${_this.changes})';
}


}

/// @nodoc
abstract mixin class $CodexFileChangeItemDtoCopyWith<$Res>  {
  factory $CodexFileChangeItemDtoCopyWith(CodexFileChangeItemDto value, $Res Function(CodexFileChangeItemDto) _then) = _$CodexFileChangeItemDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(unknownEnumValue: CodexFileChangeItemType.unknown, defaultValue: CodexFileChangeItemType.unknown) CodexFileChangeItemType type, String? id,@JsonKey(fromJson: _fileChangeStatusFromJson) CodexFileChangeStatus status, List<CodexFileUpdateDto> changes
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
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? id = freezed,Object? status = null,Object? changes = null,}) {
  return _then(CodexFileChangeItemDto(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as CodexFileChangeItemType,id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as CodexFileChangeStatus,changes: null == changes ? _self.changes : changes // ignore: cast_nullable_to_non_nullable
as List<CodexFileUpdateDto>,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _CodexFileChangeItemDto implements CodexFileChangeItemDto {
  const _CodexFileChangeItemDto({@JsonKey(unknownEnumValue: CodexFileChangeItemType.unknown, defaultValue: CodexFileChangeItemType.unknown) required this.type, required this.id, @JsonKey(fromJson: _fileChangeStatusFromJson) required this.status,  List<CodexFileUpdateDto> changes = const []}): _changes = changes;
  factory _CodexFileChangeItemDto.fromJson(Map<String, dynamic> json) => _$CodexFileChangeItemDtoFromJson(json);

@override@JsonKey(unknownEnumValue: CodexFileChangeItemType.unknown, defaultValue: CodexFileChangeItemType.unknown) final  CodexFileChangeItemType type;
@override final  String? id;
@override@JsonKey(fromJson: _fileChangeStatusFromJson) final  CodexFileChangeStatus status;
 final  List<CodexFileUpdateDto> _changes;
@override@JsonKey() List<CodexFileUpdateDto> get changes {
  if (_changes is EqualUnmodifiableListView) return _changes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_changes);
}


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
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexFileChangeItemDto&&(identical(other.type, type) || other.type == type)&&(identical(other.id, id) || other.id == id)&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.changes, _changes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,type,id,status,const DeepCollectionEquality().hash(_changes));
}

@override
String toString() {
    return 'CodexFileChangeItemDto(type: $type, id: $id, status: $status, changes: $changes)';
}


}

/// @nodoc
abstract mixin class _$CodexFileChangeItemDtoCopyWith<$Res> implements $CodexFileChangeItemDtoCopyWith<$Res> {
  factory _$CodexFileChangeItemDtoCopyWith(_CodexFileChangeItemDto value, $Res Function(_CodexFileChangeItemDto) _then) = __$CodexFileChangeItemDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(unknownEnumValue: CodexFileChangeItemType.unknown, defaultValue: CodexFileChangeItemType.unknown) CodexFileChangeItemType type, String? id,@JsonKey(fromJson: _fileChangeStatusFromJson) CodexFileChangeStatus status, List<CodexFileUpdateDto> changes
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
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? id = freezed,Object? status = null,Object? changes = null,}) {
  return _then(_CodexFileChangeItemDto(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as CodexFileChangeItemType,id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as CodexFileChangeStatus,changes: null == changes ? _self._changes : changes // ignore: cast_nullable_to_non_nullable
as List<CodexFileUpdateDto>,
  ));
}


}


/// @nodoc
mixin _$CodexFileUpdateDto {

 String get path; CodexFileUpdateKindDto get kind;
/// Create a copy of CodexFileUpdateDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexFileUpdateDtoCopyWith<CodexFileUpdateDto> get copyWith => _$CodexFileUpdateDtoCopyWithImpl<CodexFileUpdateDto>(this as CodexFileUpdateDto, _$identity);

  /// Serializes this CodexFileUpdateDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as CodexFileUpdateDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexFileUpdateDto&&(identical(other.path, _this.path) || other.path == _this.path)&&(identical(other.kind, _this.kind) || other.kind == _this.kind));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CodexFileUpdateDto;
  return Object.hash(runtimeType,_this.path,_this.kind);
}

@override
String toString() {
  final _this = this as CodexFileUpdateDto;
  return 'CodexFileUpdateDto(path: ${_this.path}, kind: ${_this.kind})';
}


}

/// @nodoc
abstract mixin class $CodexFileUpdateDtoCopyWith<$Res>  {
  factory $CodexFileUpdateDtoCopyWith(CodexFileUpdateDto value, $Res Function(CodexFileUpdateDto) _then) = _$CodexFileUpdateDtoCopyWithImpl;
@useResult
$Res call({
 String path, CodexFileUpdateKindDto kind
});


$CodexFileUpdateKindDtoCopyWith<$Res> get kind;

}
/// @nodoc
class _$CodexFileUpdateDtoCopyWithImpl<$Res>
    implements $CodexFileUpdateDtoCopyWith<$Res> {
  _$CodexFileUpdateDtoCopyWithImpl(this._self, this._then);

  final CodexFileUpdateDto _self;
  final $Res Function(CodexFileUpdateDto) _then;

/// Create a copy of CodexFileUpdateDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? path = null,Object? kind = null,}) {
  return _then(CodexFileUpdateDto(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as CodexFileUpdateKindDto,
  ));
}
/// Create a copy of CodexFileUpdateDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexFileUpdateKindDtoCopyWith<$Res> get kind {
  
  return $CodexFileUpdateKindDtoCopyWith<$Res>(_self.kind, (value) {
    return _then(_self.copyWith(kind: value));
  });
}
}



/// @nodoc
@JsonSerializable()

class _CodexFileUpdateDto implements CodexFileUpdateDto {
  const _CodexFileUpdateDto({required this.path, required this.kind});
  factory _CodexFileUpdateDto.fromJson(Map<String, dynamic> json) => _$CodexFileUpdateDtoFromJson(json);

@override final  String path;
@override final  CodexFileUpdateKindDto kind;

/// Create a copy of CodexFileUpdateDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexFileUpdateDtoCopyWith<_CodexFileUpdateDto> get copyWith => __$CodexFileUpdateDtoCopyWithImpl<_CodexFileUpdateDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CodexFileUpdateDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexFileUpdateDto&&(identical(other.path, path) || other.path == path)&&(identical(other.kind, kind) || other.kind == kind));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,path,kind);
}

@override
String toString() {
    return 'CodexFileUpdateDto(path: $path, kind: $kind)';
}


}

/// @nodoc
abstract mixin class _$CodexFileUpdateDtoCopyWith<$Res> implements $CodexFileUpdateDtoCopyWith<$Res> {
  factory _$CodexFileUpdateDtoCopyWith(_CodexFileUpdateDto value, $Res Function(_CodexFileUpdateDto) _then) = __$CodexFileUpdateDtoCopyWithImpl;
@override @useResult
$Res call({
 String path, CodexFileUpdateKindDto kind
});


@override $CodexFileUpdateKindDtoCopyWith<$Res> get kind;

}
/// @nodoc
class __$CodexFileUpdateDtoCopyWithImpl<$Res>
    implements _$CodexFileUpdateDtoCopyWith<$Res> {
  __$CodexFileUpdateDtoCopyWithImpl(this._self, this._then);

  final _CodexFileUpdateDto _self;
  final $Res Function(_CodexFileUpdateDto) _then;

/// Create a copy of CodexFileUpdateDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? path = null,Object? kind = null,}) {
  return _then(_CodexFileUpdateDto(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as CodexFileUpdateKindDto,
  ));
}

/// Create a copy of CodexFileUpdateDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexFileUpdateKindDtoCopyWith<$Res> get kind {
  
  return $CodexFileUpdateKindDtoCopyWith<$Res>(_self.kind, (value) {
    return _then(_self.copyWith(kind: value));
  });
}
}


/// @nodoc
mixin _$CodexFileUpdateKindDto {

@JsonKey(unknownEnumValue: CodexFileUpdateKind.unknown) CodexFileUpdateKind get type;@JsonKey(name: "move_path") String? get movePath;
/// Create a copy of CodexFileUpdateKindDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexFileUpdateKindDtoCopyWith<CodexFileUpdateKindDto> get copyWith => _$CodexFileUpdateKindDtoCopyWithImpl<CodexFileUpdateKindDto>(this as CodexFileUpdateKindDto, _$identity);

  /// Serializes this CodexFileUpdateKindDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as CodexFileUpdateKindDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexFileUpdateKindDto&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.movePath, _this.movePath) || other.movePath == _this.movePath));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CodexFileUpdateKindDto;
  return Object.hash(runtimeType,_this.type,_this.movePath);
}

@override
String toString() {
  final _this = this as CodexFileUpdateKindDto;
  return 'CodexFileUpdateKindDto(type: ${_this.type}, movePath: ${_this.movePath})';
}


}

/// @nodoc
abstract mixin class $CodexFileUpdateKindDtoCopyWith<$Res>  {
  factory $CodexFileUpdateKindDtoCopyWith(CodexFileUpdateKindDto value, $Res Function(CodexFileUpdateKindDto) _then) = _$CodexFileUpdateKindDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(unknownEnumValue: CodexFileUpdateKind.unknown) CodexFileUpdateKind type,@JsonKey(name: "move_path") String? movePath
});




}
/// @nodoc
class _$CodexFileUpdateKindDtoCopyWithImpl<$Res>
    implements $CodexFileUpdateKindDtoCopyWith<$Res> {
  _$CodexFileUpdateKindDtoCopyWithImpl(this._self, this._then);

  final CodexFileUpdateKindDto _self;
  final $Res Function(CodexFileUpdateKindDto) _then;

/// Create a copy of CodexFileUpdateKindDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? movePath = freezed,}) {
  return _then(CodexFileUpdateKindDto(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as CodexFileUpdateKind,movePath: freezed == movePath ? _self.movePath : movePath // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _CodexFileUpdateKindDto implements CodexFileUpdateKindDto {
  const _CodexFileUpdateKindDto({@JsonKey(unknownEnumValue: CodexFileUpdateKind.unknown) required this.type, @JsonKey(name: "move_path") required this.movePath});
  factory _CodexFileUpdateKindDto.fromJson(Map<String, dynamic> json) => _$CodexFileUpdateKindDtoFromJson(json);

@override@JsonKey(unknownEnumValue: CodexFileUpdateKind.unknown) final  CodexFileUpdateKind type;
@override@JsonKey(name: "move_path") final  String? movePath;

/// Create a copy of CodexFileUpdateKindDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexFileUpdateKindDtoCopyWith<_CodexFileUpdateKindDto> get copyWith => __$CodexFileUpdateKindDtoCopyWithImpl<_CodexFileUpdateKindDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CodexFileUpdateKindDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexFileUpdateKindDto&&(identical(other.type, type) || other.type == type)&&(identical(other.movePath, movePath) || other.movePath == movePath));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,type,movePath);
}

@override
String toString() {
    return 'CodexFileUpdateKindDto(type: $type, movePath: $movePath)';
}


}

/// @nodoc
abstract mixin class _$CodexFileUpdateKindDtoCopyWith<$Res> implements $CodexFileUpdateKindDtoCopyWith<$Res> {
  factory _$CodexFileUpdateKindDtoCopyWith(_CodexFileUpdateKindDto value, $Res Function(_CodexFileUpdateKindDto) _then) = __$CodexFileUpdateKindDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(unknownEnumValue: CodexFileUpdateKind.unknown) CodexFileUpdateKind type,@JsonKey(name: "move_path") String? movePath
});




}
/// @nodoc
class __$CodexFileUpdateKindDtoCopyWithImpl<$Res>
    implements _$CodexFileUpdateKindDtoCopyWith<$Res> {
  __$CodexFileUpdateKindDtoCopyWithImpl(this._self, this._then);

  final _CodexFileUpdateKindDto _self;
  final $Res Function(_CodexFileUpdateKindDto) _then;

/// Create a copy of CodexFileUpdateKindDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? movePath = freezed,}) {
  return _then(_CodexFileUpdateKindDto(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as CodexFileUpdateKind,movePath: freezed == movePath ? _self.movePath : movePath // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
