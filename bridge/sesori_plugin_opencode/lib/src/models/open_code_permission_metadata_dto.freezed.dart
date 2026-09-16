// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'open_code_permission_metadata_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$OpenCodePermissionMetadataDto {

 String? get command; String? get filepath; String? get url; List<OpenCodePermissionFileDto> get files;
/// Create a copy of OpenCodePermissionMetadataDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OpenCodePermissionMetadataDtoCopyWith<OpenCodePermissionMetadataDto> get copyWith => _$OpenCodePermissionMetadataDtoCopyWithImpl<OpenCodePermissionMetadataDto>(this as OpenCodePermissionMetadataDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as OpenCodePermissionMetadataDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OpenCodePermissionMetadataDto&&(identical(other.command, _this.command) || other.command == _this.command)&&(identical(other.filepath, _this.filepath) || other.filepath == _this.filepath)&&(identical(other.url, _this.url) || other.url == _this.url)&&const DeepCollectionEquality().equals(other.files, _this.files));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as OpenCodePermissionMetadataDto;
  return Object.hash(runtimeType,_this.command,_this.filepath,_this.url,const DeepCollectionEquality().hash(_this.files));
}

@override
String toString() {
  final _this = this as OpenCodePermissionMetadataDto;
  return 'OpenCodePermissionMetadataDto(command: ${_this.command}, filepath: ${_this.filepath}, url: ${_this.url}, files: ${_this.files})';
}


}

/// @nodoc
abstract mixin class $OpenCodePermissionMetadataDtoCopyWith<$Res>  {
  factory $OpenCodePermissionMetadataDtoCopyWith(OpenCodePermissionMetadataDto value, $Res Function(OpenCodePermissionMetadataDto) _then) = _$OpenCodePermissionMetadataDtoCopyWithImpl;
@useResult
$Res call({
 String? command, String? filepath, String? url, List<OpenCodePermissionFileDto> files
});




}
/// @nodoc
class _$OpenCodePermissionMetadataDtoCopyWithImpl<$Res>
    implements $OpenCodePermissionMetadataDtoCopyWith<$Res> {
  _$OpenCodePermissionMetadataDtoCopyWithImpl(this._self, this._then);

  final OpenCodePermissionMetadataDto _self;
  final $Res Function(OpenCodePermissionMetadataDto) _then;

/// Create a copy of OpenCodePermissionMetadataDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? command = freezed,Object? filepath = freezed,Object? url = freezed,Object? files = null,}) {
  return _then(OpenCodePermissionMetadataDto(
command: freezed == command ? _self.command : command // ignore: cast_nullable_to_non_nullable
as String?,filepath: freezed == filepath ? _self.filepath : filepath // ignore: cast_nullable_to_non_nullable
as String?,url: freezed == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String?,files: null == files ? _self.files : files // ignore: cast_nullable_to_non_nullable
as List<OpenCodePermissionFileDto>,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _OpenCodePermissionMetadataDto implements OpenCodePermissionMetadataDto {
  const _OpenCodePermissionMetadataDto({required this.command, required this.filepath, required this.url,  List<OpenCodePermissionFileDto> files = const []}): _files = files;
  factory _OpenCodePermissionMetadataDto.fromJson(Map<String, dynamic> json) => _$OpenCodePermissionMetadataDtoFromJson(json);

@override final  String? command;
@override final  String? filepath;
@override final  String? url;
 final  List<OpenCodePermissionFileDto> _files;
@override@JsonKey() List<OpenCodePermissionFileDto> get files {
  if (_files is EqualUnmodifiableListView) return _files;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_files);
}


/// Create a copy of OpenCodePermissionMetadataDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OpenCodePermissionMetadataDtoCopyWith<_OpenCodePermissionMetadataDto> get copyWith => __$OpenCodePermissionMetadataDtoCopyWithImpl<_OpenCodePermissionMetadataDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _OpenCodePermissionMetadataDto&&(identical(other.command, command) || other.command == command)&&(identical(other.filepath, filepath) || other.filepath == filepath)&&(identical(other.url, url) || other.url == url)&&const DeepCollectionEquality().equals(other.files, _files));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,command,filepath,url,const DeepCollectionEquality().hash(_files));
}

@override
String toString() {
    return 'OpenCodePermissionMetadataDto(command: $command, filepath: $filepath, url: $url, files: $files)';
}


}

/// @nodoc
abstract mixin class _$OpenCodePermissionMetadataDtoCopyWith<$Res> implements $OpenCodePermissionMetadataDtoCopyWith<$Res> {
  factory _$OpenCodePermissionMetadataDtoCopyWith(_OpenCodePermissionMetadataDto value, $Res Function(_OpenCodePermissionMetadataDto) _then) = __$OpenCodePermissionMetadataDtoCopyWithImpl;
@override @useResult
$Res call({
 String? command, String? filepath, String? url, List<OpenCodePermissionFileDto> files
});




}
/// @nodoc
class __$OpenCodePermissionMetadataDtoCopyWithImpl<$Res>
    implements _$OpenCodePermissionMetadataDtoCopyWith<$Res> {
  __$OpenCodePermissionMetadataDtoCopyWithImpl(this._self, this._then);

  final _OpenCodePermissionMetadataDto _self;
  final $Res Function(_OpenCodePermissionMetadataDto) _then;

/// Create a copy of OpenCodePermissionMetadataDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? command = freezed,Object? filepath = freezed,Object? url = freezed,Object? files = null,}) {
  return _then(_OpenCodePermissionMetadataDto(
command: freezed == command ? _self.command : command // ignore: cast_nullable_to_non_nullable
as String?,filepath: freezed == filepath ? _self.filepath : filepath // ignore: cast_nullable_to_non_nullable
as String?,url: freezed == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String?,files: null == files ? _self._files : files // ignore: cast_nullable_to_non_nullable
as List<OpenCodePermissionFileDto>,
  ));
}


}


/// @nodoc
mixin _$OpenCodePermissionFileDto {

 String get filePath;@JsonKey(unknownEnumValue: OpenCodePermissionFileType.unknown) OpenCodePermissionFileType get type; String? get movePath;
/// Create a copy of OpenCodePermissionFileDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OpenCodePermissionFileDtoCopyWith<OpenCodePermissionFileDto> get copyWith => _$OpenCodePermissionFileDtoCopyWithImpl<OpenCodePermissionFileDto>(this as OpenCodePermissionFileDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as OpenCodePermissionFileDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OpenCodePermissionFileDto&&(identical(other.filePath, _this.filePath) || other.filePath == _this.filePath)&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.movePath, _this.movePath) || other.movePath == _this.movePath));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as OpenCodePermissionFileDto;
  return Object.hash(runtimeType,_this.filePath,_this.type,_this.movePath);
}

@override
String toString() {
  final _this = this as OpenCodePermissionFileDto;
  return 'OpenCodePermissionFileDto(filePath: ${_this.filePath}, type: ${_this.type}, movePath: ${_this.movePath})';
}


}

/// @nodoc
abstract mixin class $OpenCodePermissionFileDtoCopyWith<$Res>  {
  factory $OpenCodePermissionFileDtoCopyWith(OpenCodePermissionFileDto value, $Res Function(OpenCodePermissionFileDto) _then) = _$OpenCodePermissionFileDtoCopyWithImpl;
@useResult
$Res call({
 String filePath,@JsonKey(unknownEnumValue: OpenCodePermissionFileType.unknown) OpenCodePermissionFileType type, String? movePath
});




}
/// @nodoc
class _$OpenCodePermissionFileDtoCopyWithImpl<$Res>
    implements $OpenCodePermissionFileDtoCopyWith<$Res> {
  _$OpenCodePermissionFileDtoCopyWithImpl(this._self, this._then);

  final OpenCodePermissionFileDto _self;
  final $Res Function(OpenCodePermissionFileDto) _then;

/// Create a copy of OpenCodePermissionFileDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? filePath = null,Object? type = null,Object? movePath = freezed,}) {
  return _then(OpenCodePermissionFileDto(
filePath: null == filePath ? _self.filePath : filePath // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as OpenCodePermissionFileType,movePath: freezed == movePath ? _self.movePath : movePath // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _OpenCodePermissionFileDto implements OpenCodePermissionFileDto {
  const _OpenCodePermissionFileDto({required this.filePath, @JsonKey(unknownEnumValue: OpenCodePermissionFileType.unknown) required this.type, required this.movePath});
  factory _OpenCodePermissionFileDto.fromJson(Map<String, dynamic> json) => _$OpenCodePermissionFileDtoFromJson(json);

@override final  String filePath;
@override@JsonKey(unknownEnumValue: OpenCodePermissionFileType.unknown) final  OpenCodePermissionFileType type;
@override final  String? movePath;

/// Create a copy of OpenCodePermissionFileDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OpenCodePermissionFileDtoCopyWith<_OpenCodePermissionFileDto> get copyWith => __$OpenCodePermissionFileDtoCopyWithImpl<_OpenCodePermissionFileDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _OpenCodePermissionFileDto&&(identical(other.filePath, filePath) || other.filePath == filePath)&&(identical(other.type, type) || other.type == type)&&(identical(other.movePath, movePath) || other.movePath == movePath));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,filePath,type,movePath);
}

@override
String toString() {
    return 'OpenCodePermissionFileDto(filePath: $filePath, type: $type, movePath: $movePath)';
}


}

/// @nodoc
abstract mixin class _$OpenCodePermissionFileDtoCopyWith<$Res> implements $OpenCodePermissionFileDtoCopyWith<$Res> {
  factory _$OpenCodePermissionFileDtoCopyWith(_OpenCodePermissionFileDto value, $Res Function(_OpenCodePermissionFileDto) _then) = __$OpenCodePermissionFileDtoCopyWithImpl;
@override @useResult
$Res call({
 String filePath,@JsonKey(unknownEnumValue: OpenCodePermissionFileType.unknown) OpenCodePermissionFileType type, String? movePath
});




}
/// @nodoc
class __$OpenCodePermissionFileDtoCopyWithImpl<$Res>
    implements _$OpenCodePermissionFileDtoCopyWith<$Res> {
  __$OpenCodePermissionFileDtoCopyWithImpl(this._self, this._then);

  final _OpenCodePermissionFileDto _self;
  final $Res Function(_OpenCodePermissionFileDto) _then;

/// Create a copy of OpenCodePermissionFileDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? filePath = null,Object? type = null,Object? movePath = freezed,}) {
  return _then(_OpenCodePermissionFileDto(
filePath: null == filePath ? _self.filePath : filePath // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as OpenCodePermissionFileType,movePath: freezed == movePath ? _self.movePath : movePath // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
