// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'permission_details.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
PermissionDetails _$PermissionDetailsFromJson(
  Map<String, dynamic> json
) {
        switch (json['kind']) {
                  case 'command':
          return CommandPermissionDetails.fromJson(
            json
          );
                case 'fileChanges':
          return FileChangesPermissionDetails.fromJson(
            json
          );
                case 'network':
          return NetworkPermissionDetails.fromJson(
            json
          );
        
          default:
            return GenericPermissionDetails.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$PermissionDetails {



  /// Serializes this PermissionDetails to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PermissionDetails);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'PermissionDetails()';
}


}

/// @nodoc
class $PermissionDetailsCopyWith<$Res>  {
$PermissionDetailsCopyWith(PermissionDetails _, $Res Function(PermissionDetails) __);
}



/// @nodoc
@JsonSerializable()

class GenericPermissionDetails implements PermissionDetails {
  const GenericPermissionDetails({ String? $type}): $type = $type ?? 'generic';
  factory GenericPermissionDetails.fromJson(Map<String, dynamic> json) => _$GenericPermissionDetailsFromJson(json);



@JsonKey(name: 'kind')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$GenericPermissionDetailsToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is GenericPermissionDetails);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'PermissionDetails.generic()';
}


}




/// @nodoc
@JsonSerializable()

class CommandPermissionDetails implements PermissionDetails {
  const CommandPermissionDetails({required this.command,  String? $type}): $type = $type ?? 'command';
  factory CommandPermissionDetails.fromJson(Map<String, dynamic> json) => _$CommandPermissionDetailsFromJson(json);

 final  String command;

@JsonKey(name: 'kind')
final String $type;


/// Create a copy of PermissionDetails
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CommandPermissionDetailsCopyWith<CommandPermissionDetails> get copyWith => _$CommandPermissionDetailsCopyWithImpl<CommandPermissionDetails>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CommandPermissionDetailsToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CommandPermissionDetails&&(identical(other.command, command) || other.command == command));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,command);
}

@override
String toString() {
    return 'PermissionDetails.command(command: $command)';
}


}

/// @nodoc
abstract mixin class $CommandPermissionDetailsCopyWith<$Res> implements $PermissionDetailsCopyWith<$Res> {
  factory $CommandPermissionDetailsCopyWith(CommandPermissionDetails value, $Res Function(CommandPermissionDetails) _then) = _$CommandPermissionDetailsCopyWithImpl;
@useResult
$Res call({
 String command
});




}
/// @nodoc
class _$CommandPermissionDetailsCopyWithImpl<$Res>
    implements $CommandPermissionDetailsCopyWith<$Res> {
  _$CommandPermissionDetailsCopyWithImpl(this._self, this._then);

  final CommandPermissionDetails _self;
  final $Res Function(CommandPermissionDetails) _then;

/// Create a copy of PermissionDetails
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? command = null,}) {
  return _then(CommandPermissionDetails(
command: null == command ? _self.command : command // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class FileChangesPermissionDetails implements PermissionDetails {
  const FileChangesPermissionDetails({required  List<PermissionFile> files,  String? $type}): _files = files,$type = $type ?? 'fileChanges';
  factory FileChangesPermissionDetails.fromJson(Map<String, dynamic> json) => _$FileChangesPermissionDetailsFromJson(json);

 final  List<PermissionFile> _files;
 List<PermissionFile> get files {
  if (_files is EqualUnmodifiableListView) return _files;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_files);
}


@JsonKey(name: 'kind')
final String $type;


/// Create a copy of PermissionDetails
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FileChangesPermissionDetailsCopyWith<FileChangesPermissionDetails> get copyWith => _$FileChangesPermissionDetailsCopyWithImpl<FileChangesPermissionDetails>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FileChangesPermissionDetailsToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FileChangesPermissionDetails&&const DeepCollectionEquality().equals(other.files, _files));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_files));
}

@override
String toString() {
    return 'PermissionDetails.fileChanges(files: $files)';
}


}

/// @nodoc
abstract mixin class $FileChangesPermissionDetailsCopyWith<$Res> implements $PermissionDetailsCopyWith<$Res> {
  factory $FileChangesPermissionDetailsCopyWith(FileChangesPermissionDetails value, $Res Function(FileChangesPermissionDetails) _then) = _$FileChangesPermissionDetailsCopyWithImpl;
@useResult
$Res call({
 List<PermissionFile> files
});




}
/// @nodoc
class _$FileChangesPermissionDetailsCopyWithImpl<$Res>
    implements $FileChangesPermissionDetailsCopyWith<$Res> {
  _$FileChangesPermissionDetailsCopyWithImpl(this._self, this._then);

  final FileChangesPermissionDetails _self;
  final $Res Function(FileChangesPermissionDetails) _then;

/// Create a copy of PermissionDetails
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? files = null,}) {
  return _then(FileChangesPermissionDetails(
files: null == files ? _self._files : files // ignore: cast_nullable_to_non_nullable
as List<PermissionFile>,
  ));
}


}

/// @nodoc
@JsonSerializable()

class NetworkPermissionDetails implements PermissionDetails {
  const NetworkPermissionDetails({required  List<String> targets, required this.command,  String? $type}): _targets = targets,$type = $type ?? 'network';
  factory NetworkPermissionDetails.fromJson(Map<String, dynamic> json) => _$NetworkPermissionDetailsFromJson(json);

 final  List<String> _targets;
 List<String> get targets {
  if (_targets is EqualUnmodifiableListView) return _targets;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_targets);
}

 final  String? command;

@JsonKey(name: 'kind')
final String $type;


/// Create a copy of PermissionDetails
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NetworkPermissionDetailsCopyWith<NetworkPermissionDetails> get copyWith => _$NetworkPermissionDetailsCopyWithImpl<NetworkPermissionDetails>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NetworkPermissionDetailsToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is NetworkPermissionDetails&&const DeepCollectionEquality().equals(other.targets, _targets)&&(identical(other.command, command) || other.command == command));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_targets),command);
}

@override
String toString() {
    return 'PermissionDetails.network(targets: $targets, command: $command)';
}


}

/// @nodoc
abstract mixin class $NetworkPermissionDetailsCopyWith<$Res> implements $PermissionDetailsCopyWith<$Res> {
  factory $NetworkPermissionDetailsCopyWith(NetworkPermissionDetails value, $Res Function(NetworkPermissionDetails) _then) = _$NetworkPermissionDetailsCopyWithImpl;
@useResult
$Res call({
 List<String> targets, String? command
});




}
/// @nodoc
class _$NetworkPermissionDetailsCopyWithImpl<$Res>
    implements $NetworkPermissionDetailsCopyWith<$Res> {
  _$NetworkPermissionDetailsCopyWithImpl(this._self, this._then);

  final NetworkPermissionDetails _self;
  final $Res Function(NetworkPermissionDetails) _then;

/// Create a copy of PermissionDetails
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? targets = null,Object? command = freezed,}) {
  return _then(NetworkPermissionDetails(
targets: null == targets ? _self._targets : targets // ignore: cast_nullable_to_non_nullable
as List<String>,command: freezed == command ? _self.command : command // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$PermissionFile {

 String get path;@JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) PermissionFileOperation? get operation;
/// Create a copy of PermissionFile
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PermissionFileCopyWith<PermissionFile> get copyWith => _$PermissionFileCopyWithImpl<PermissionFile>(this as PermissionFile, _$identity);

  /// Serializes this PermissionFile to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PermissionFile;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PermissionFile&&(identical(other.path, _this.path) || other.path == _this.path)&&(identical(other.operation, _this.operation) || other.operation == _this.operation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PermissionFile;
  return Object.hash(runtimeType,_this.path,_this.operation);
}

@override
String toString() {
  final _this = this as PermissionFile;
  return 'PermissionFile(path: ${_this.path}, operation: ${_this.operation})';
}


}

/// @nodoc
abstract mixin class $PermissionFileCopyWith<$Res>  {
  factory $PermissionFileCopyWith(PermissionFile value, $Res Function(PermissionFile) _then) = _$PermissionFileCopyWithImpl;
@useResult
$Res call({
 String path,@JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) PermissionFileOperation? operation
});




}
/// @nodoc
class _$PermissionFileCopyWithImpl<$Res>
    implements $PermissionFileCopyWith<$Res> {
  _$PermissionFileCopyWithImpl(this._self, this._then);

  final PermissionFile _self;
  final $Res Function(PermissionFile) _then;

/// Create a copy of PermissionFile
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? path = null,Object? operation = freezed,}) {
  return _then(PermissionFile(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,operation: freezed == operation ? _self.operation : operation // ignore: cast_nullable_to_non_nullable
as PermissionFileOperation?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _PermissionFile implements PermissionFile {
  const _PermissionFile({required this.path, @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) required this.operation});
  factory _PermissionFile.fromJson(Map<String, dynamic> json) => _$PermissionFileFromJson(json);

@override final  String path;
@override@JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) final  PermissionFileOperation? operation;

/// Create a copy of PermissionFile
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PermissionFileCopyWith<_PermissionFile> get copyWith => __$PermissionFileCopyWithImpl<_PermissionFile>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PermissionFileToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PermissionFile&&(identical(other.path, path) || other.path == path)&&(identical(other.operation, operation) || other.operation == operation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,path,operation);
}

@override
String toString() {
    return 'PermissionFile(path: $path, operation: $operation)';
}


}

/// @nodoc
abstract mixin class _$PermissionFileCopyWith<$Res> implements $PermissionFileCopyWith<$Res> {
  factory _$PermissionFileCopyWith(_PermissionFile value, $Res Function(_PermissionFile) _then) = __$PermissionFileCopyWithImpl;
@override @useResult
$Res call({
 String path,@JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) PermissionFileOperation? operation
});




}
/// @nodoc
class __$PermissionFileCopyWithImpl<$Res>
    implements _$PermissionFileCopyWith<$Res> {
  __$PermissionFileCopyWithImpl(this._self, this._then);

  final _PermissionFile _self;
  final $Res Function(_PermissionFile) _then;

/// Create a copy of PermissionFile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? path = null,Object? operation = freezed,}) {
  return _then(_PermissionFile(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,operation: freezed == operation ? _self.operation : operation // ignore: cast_nullable_to_non_nullable
as PermissionFileOperation?,
  ));
}


}

// dart format on
