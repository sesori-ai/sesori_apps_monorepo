// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plugin_permission_details.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PluginPermissionDetails {



  /// Serializes this PluginPermissionDetails to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginPermissionDetails);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'PluginPermissionDetails()';
}


}

/// @nodoc
class $PluginPermissionDetailsCopyWith<$Res>  {
$PluginPermissionDetailsCopyWith(PluginPermissionDetails _, $Res Function(PluginPermissionDetails) __);
}



/// @nodoc
@JsonSerializable(createFactory: false)

class PluginGenericPermissionDetails implements PluginPermissionDetails {
  const PluginGenericPermissionDetails({ String? $type}): $type = $type ?? 'generic';
  



@JsonKey(name: 'runtimeType')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$PluginGenericPermissionDetailsToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginGenericPermissionDetails);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'PluginPermissionDetails.generic()';
}


}




/// @nodoc
@JsonSerializable(createFactory: false)

class PluginCommandPermissionDetails implements PluginPermissionDetails {
  const PluginCommandPermissionDetails({required this.command,  String? $type}): $type = $type ?? 'command';
  

 final  String command;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of PluginPermissionDetails
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginCommandPermissionDetailsCopyWith<PluginCommandPermissionDetails> get copyWith => _$PluginCommandPermissionDetailsCopyWithImpl<PluginCommandPermissionDetails>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginCommandPermissionDetailsToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginCommandPermissionDetails&&(identical(other.command, command) || other.command == command));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,command);
}

@override
String toString() {
    return 'PluginPermissionDetails.command(command: $command)';
}


}

/// @nodoc
abstract mixin class $PluginCommandPermissionDetailsCopyWith<$Res> implements $PluginPermissionDetailsCopyWith<$Res> {
  factory $PluginCommandPermissionDetailsCopyWith(PluginCommandPermissionDetails value, $Res Function(PluginCommandPermissionDetails) _then) = _$PluginCommandPermissionDetailsCopyWithImpl;
@useResult
$Res call({
 String command
});




}
/// @nodoc
class _$PluginCommandPermissionDetailsCopyWithImpl<$Res>
    implements $PluginCommandPermissionDetailsCopyWith<$Res> {
  _$PluginCommandPermissionDetailsCopyWithImpl(this._self, this._then);

  final PluginCommandPermissionDetails _self;
  final $Res Function(PluginCommandPermissionDetails) _then;

/// Create a copy of PluginPermissionDetails
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? command = null,}) {
  return _then(PluginCommandPermissionDetails(
command: null == command ? _self.command : command // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable(createFactory: false)

class PluginFileChangesPermissionDetails implements PluginPermissionDetails {
  const PluginFileChangesPermissionDetails({required  List<PluginPermissionFile> files,  String? $type}): _files = files,$type = $type ?? 'fileChanges';
  

 final  List<PluginPermissionFile> _files;
 List<PluginPermissionFile> get files {
  if (_files is EqualUnmodifiableListView) return _files;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_files);
}


@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of PluginPermissionDetails
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginFileChangesPermissionDetailsCopyWith<PluginFileChangesPermissionDetails> get copyWith => _$PluginFileChangesPermissionDetailsCopyWithImpl<PluginFileChangesPermissionDetails>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginFileChangesPermissionDetailsToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginFileChangesPermissionDetails&&const DeepCollectionEquality().equals(other.files, _files));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_files));
}

@override
String toString() {
    return 'PluginPermissionDetails.fileChanges(files: $files)';
}


}

/// @nodoc
abstract mixin class $PluginFileChangesPermissionDetailsCopyWith<$Res> implements $PluginPermissionDetailsCopyWith<$Res> {
  factory $PluginFileChangesPermissionDetailsCopyWith(PluginFileChangesPermissionDetails value, $Res Function(PluginFileChangesPermissionDetails) _then) = _$PluginFileChangesPermissionDetailsCopyWithImpl;
@useResult
$Res call({
 List<PluginPermissionFile> files
});




}
/// @nodoc
class _$PluginFileChangesPermissionDetailsCopyWithImpl<$Res>
    implements $PluginFileChangesPermissionDetailsCopyWith<$Res> {
  _$PluginFileChangesPermissionDetailsCopyWithImpl(this._self, this._then);

  final PluginFileChangesPermissionDetails _self;
  final $Res Function(PluginFileChangesPermissionDetails) _then;

/// Create a copy of PluginPermissionDetails
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? files = null,}) {
  return _then(PluginFileChangesPermissionDetails(
files: null == files ? _self._files : files // ignore: cast_nullable_to_non_nullable
as List<PluginPermissionFile>,
  ));
}


}

/// @nodoc
@JsonSerializable(createFactory: false)

class PluginNetworkPermissionDetails implements PluginPermissionDetails {
  const PluginNetworkPermissionDetails({required  List<String> targets, required this.command,  String? $type}): _targets = targets,$type = $type ?? 'network';
  

 final  List<String> _targets;
 List<String> get targets {
  if (_targets is EqualUnmodifiableListView) return _targets;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_targets);
}

 final  String? command;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of PluginPermissionDetails
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginNetworkPermissionDetailsCopyWith<PluginNetworkPermissionDetails> get copyWith => _$PluginNetworkPermissionDetailsCopyWithImpl<PluginNetworkPermissionDetails>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginNetworkPermissionDetailsToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginNetworkPermissionDetails&&const DeepCollectionEquality().equals(other.targets, _targets)&&(identical(other.command, command) || other.command == command));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_targets),command);
}

@override
String toString() {
    return 'PluginPermissionDetails.network(targets: $targets, command: $command)';
}


}

/// @nodoc
abstract mixin class $PluginNetworkPermissionDetailsCopyWith<$Res> implements $PluginPermissionDetailsCopyWith<$Res> {
  factory $PluginNetworkPermissionDetailsCopyWith(PluginNetworkPermissionDetails value, $Res Function(PluginNetworkPermissionDetails) _then) = _$PluginNetworkPermissionDetailsCopyWithImpl;
@useResult
$Res call({
 List<String> targets, String? command
});




}
/// @nodoc
class _$PluginNetworkPermissionDetailsCopyWithImpl<$Res>
    implements $PluginNetworkPermissionDetailsCopyWith<$Res> {
  _$PluginNetworkPermissionDetailsCopyWithImpl(this._self, this._then);

  final PluginNetworkPermissionDetails _self;
  final $Res Function(PluginNetworkPermissionDetails) _then;

/// Create a copy of PluginPermissionDetails
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? targets = null,Object? command = freezed,}) {
  return _then(PluginNetworkPermissionDetails(
targets: null == targets ? _self._targets : targets // ignore: cast_nullable_to_non_nullable
as List<String>,command: freezed == command ? _self.command : command // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$PluginPermissionFile {

 String get path; PluginPermissionFileOperation? get operation;
/// Create a copy of PluginPermissionFile
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginPermissionFileCopyWith<PluginPermissionFile> get copyWith => _$PluginPermissionFileCopyWithImpl<PluginPermissionFile>(this as PluginPermissionFile, _$identity);

  /// Serializes this PluginPermissionFile to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PluginPermissionFile;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginPermissionFile&&(identical(other.path, _this.path) || other.path == _this.path)&&(identical(other.operation, _this.operation) || other.operation == _this.operation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PluginPermissionFile;
  return Object.hash(runtimeType,_this.path,_this.operation);
}

@override
String toString() {
  final _this = this as PluginPermissionFile;
  return 'PluginPermissionFile(path: ${_this.path}, operation: ${_this.operation})';
}


}

/// @nodoc
abstract mixin class $PluginPermissionFileCopyWith<$Res>  {
  factory $PluginPermissionFileCopyWith(PluginPermissionFile value, $Res Function(PluginPermissionFile) _then) = _$PluginPermissionFileCopyWithImpl;
@useResult
$Res call({
 String path, PluginPermissionFileOperation? operation
});




}
/// @nodoc
class _$PluginPermissionFileCopyWithImpl<$Res>
    implements $PluginPermissionFileCopyWith<$Res> {
  _$PluginPermissionFileCopyWithImpl(this._self, this._then);

  final PluginPermissionFile _self;
  final $Res Function(PluginPermissionFile) _then;

/// Create a copy of PluginPermissionFile
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? path = null,Object? operation = freezed,}) {
  return _then(PluginPermissionFile(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,operation: freezed == operation ? _self.operation : operation // ignore: cast_nullable_to_non_nullable
as PluginPermissionFileOperation?,
  ));
}

}



/// @nodoc
@JsonSerializable(createFactory: false)

class _PluginPermissionFile implements PluginPermissionFile {
  const _PluginPermissionFile({required this.path, required this.operation});
  

@override final  String path;
@override final  PluginPermissionFileOperation? operation;

/// Create a copy of PluginPermissionFile
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginPermissionFileCopyWith<_PluginPermissionFile> get copyWith => __$PluginPermissionFileCopyWithImpl<_PluginPermissionFile>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginPermissionFileToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginPermissionFile&&(identical(other.path, path) || other.path == path)&&(identical(other.operation, operation) || other.operation == operation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,path,operation);
}

@override
String toString() {
    return 'PluginPermissionFile(path: $path, operation: $operation)';
}


}

/// @nodoc
abstract mixin class _$PluginPermissionFileCopyWith<$Res> implements $PluginPermissionFileCopyWith<$Res> {
  factory _$PluginPermissionFileCopyWith(_PluginPermissionFile value, $Res Function(_PluginPermissionFile) _then) = __$PluginPermissionFileCopyWithImpl;
@override @useResult
$Res call({
 String path, PluginPermissionFileOperation? operation
});




}
/// @nodoc
class __$PluginPermissionFileCopyWithImpl<$Res>
    implements _$PluginPermissionFileCopyWith<$Res> {
  __$PluginPermissionFileCopyWithImpl(this._self, this._then);

  final _PluginPermissionFile _self;
  final $Res Function(_PluginPermissionFile) _then;

/// Create a copy of PluginPermissionFile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? path = null,Object? operation = freezed,}) {
  return _then(_PluginPermissionFile(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,operation: freezed == operation ? _self.operation : operation // ignore: cast_nullable_to_non_nullable
as PluginPermissionFileOperation?,
  ));
}


}

// dart format on
