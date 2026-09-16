// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'claude_permission_input_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ClaudePermissionInputDto {

 String? get command;@JsonKey(name: "file_path") String? get filePath;@JsonKey(name: "notebook_path") String? get notebookPath; String? get url;
/// Create a copy of ClaudePermissionInputDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClaudePermissionInputDtoCopyWith<ClaudePermissionInputDto> get copyWith => _$ClaudePermissionInputDtoCopyWithImpl<ClaudePermissionInputDto>(this as ClaudePermissionInputDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ClaudePermissionInputDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClaudePermissionInputDto&&(identical(other.command, _this.command) || other.command == _this.command)&&(identical(other.filePath, _this.filePath) || other.filePath == _this.filePath)&&(identical(other.notebookPath, _this.notebookPath) || other.notebookPath == _this.notebookPath)&&(identical(other.url, _this.url) || other.url == _this.url));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ClaudePermissionInputDto;
  return Object.hash(runtimeType,_this.command,_this.filePath,_this.notebookPath,_this.url);
}

@override
String toString() {
  final _this = this as ClaudePermissionInputDto;
  return 'ClaudePermissionInputDto(command: ${_this.command}, filePath: ${_this.filePath}, notebookPath: ${_this.notebookPath}, url: ${_this.url})';
}


}

/// @nodoc
abstract mixin class $ClaudePermissionInputDtoCopyWith<$Res>  {
  factory $ClaudePermissionInputDtoCopyWith(ClaudePermissionInputDto value, $Res Function(ClaudePermissionInputDto) _then) = _$ClaudePermissionInputDtoCopyWithImpl;
@useResult
$Res call({
 String? command,@JsonKey(name: "file_path") String? filePath,@JsonKey(name: "notebook_path") String? notebookPath, String? url
});




}
/// @nodoc
class _$ClaudePermissionInputDtoCopyWithImpl<$Res>
    implements $ClaudePermissionInputDtoCopyWith<$Res> {
  _$ClaudePermissionInputDtoCopyWithImpl(this._self, this._then);

  final ClaudePermissionInputDto _self;
  final $Res Function(ClaudePermissionInputDto) _then;

/// Create a copy of ClaudePermissionInputDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? command = freezed,Object? filePath = freezed,Object? notebookPath = freezed,Object? url = freezed,}) {
  return _then(ClaudePermissionInputDto(
command: freezed == command ? _self.command : command // ignore: cast_nullable_to_non_nullable
as String?,filePath: freezed == filePath ? _self.filePath : filePath // ignore: cast_nullable_to_non_nullable
as String?,notebookPath: freezed == notebookPath ? _self.notebookPath : notebookPath // ignore: cast_nullable_to_non_nullable
as String?,url: freezed == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _ClaudePermissionInputDto implements ClaudePermissionInputDto {
  const _ClaudePermissionInputDto({required this.command, @JsonKey(name: "file_path") required this.filePath, @JsonKey(name: "notebook_path") required this.notebookPath, required this.url});
  factory _ClaudePermissionInputDto.fromJson(Map<String, dynamic> json) => _$ClaudePermissionInputDtoFromJson(json);

@override final  String? command;
@override@JsonKey(name: "file_path") final  String? filePath;
@override@JsonKey(name: "notebook_path") final  String? notebookPath;
@override final  String? url;

/// Create a copy of ClaudePermissionInputDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClaudePermissionInputDtoCopyWith<_ClaudePermissionInputDto> get copyWith => __$ClaudePermissionInputDtoCopyWithImpl<_ClaudePermissionInputDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClaudePermissionInputDto&&(identical(other.command, command) || other.command == command)&&(identical(other.filePath, filePath) || other.filePath == filePath)&&(identical(other.notebookPath, notebookPath) || other.notebookPath == notebookPath)&&(identical(other.url, url) || other.url == url));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,command,filePath,notebookPath,url);
}

@override
String toString() {
    return 'ClaudePermissionInputDto(command: $command, filePath: $filePath, notebookPath: $notebookPath, url: $url)';
}


}

/// @nodoc
abstract mixin class _$ClaudePermissionInputDtoCopyWith<$Res> implements $ClaudePermissionInputDtoCopyWith<$Res> {
  factory _$ClaudePermissionInputDtoCopyWith(_ClaudePermissionInputDto value, $Res Function(_ClaudePermissionInputDto) _then) = __$ClaudePermissionInputDtoCopyWithImpl;
@override @useResult
$Res call({
 String? command,@JsonKey(name: "file_path") String? filePath,@JsonKey(name: "notebook_path") String? notebookPath, String? url
});




}
/// @nodoc
class __$ClaudePermissionInputDtoCopyWithImpl<$Res>
    implements _$ClaudePermissionInputDtoCopyWith<$Res> {
  __$ClaudePermissionInputDtoCopyWithImpl(this._self, this._then);

  final _ClaudePermissionInputDto _self;
  final $Res Function(_ClaudePermissionInputDto) _then;

/// Create a copy of ClaudePermissionInputDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? command = freezed,Object? filePath = freezed,Object? notebookPath = freezed,Object? url = freezed,}) {
  return _then(_ClaudePermissionInputDto(
command: freezed == command ? _self.command : command // ignore: cast_nullable_to_non_nullable
as String?,filePath: freezed == filePath ? _self.filePath : filePath // ignore: cast_nullable_to_non_nullable
as String?,notebookPath: freezed == notebookPath ? _self.notebookPath : notebookPath // ignore: cast_nullable_to_non_nullable
as String?,url: freezed == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
