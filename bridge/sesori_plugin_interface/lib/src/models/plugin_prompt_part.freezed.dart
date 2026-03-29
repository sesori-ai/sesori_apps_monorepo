// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plugin_prompt_part.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PluginPromptPart {



  /// Serializes this PluginPromptPart to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginPromptPart);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PluginPromptPart()';
}


}

/// @nodoc
class $PluginPromptPartCopyWith<$Res>  {
$PluginPromptPartCopyWith(PluginPromptPart _, $Res Function(PluginPromptPart) __);
}



/// @nodoc
@JsonSerializable(createFactory: false)

class PluginPromptPartText implements PluginPromptPart {
  const PluginPromptPartText({required this.text, final  String? $type}): $type = $type ?? 'text';
  

 final  String text;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of PluginPromptPart
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginPromptPartTextCopyWith<PluginPromptPartText> get copyWith => _$PluginPromptPartTextCopyWithImpl<PluginPromptPartText>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginPromptPartTextToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginPromptPartText&&(identical(other.text, text) || other.text == text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,text);

@override
String toString() {
  return 'PluginPromptPart.text(text: $text)';
}


}

/// @nodoc
abstract mixin class $PluginPromptPartTextCopyWith<$Res> implements $PluginPromptPartCopyWith<$Res> {
  factory $PluginPromptPartTextCopyWith(PluginPromptPartText value, $Res Function(PluginPromptPartText) _then) = _$PluginPromptPartTextCopyWithImpl;
@useResult
$Res call({
 String text
});




}
/// @nodoc
class _$PluginPromptPartTextCopyWithImpl<$Res>
    implements $PluginPromptPartTextCopyWith<$Res> {
  _$PluginPromptPartTextCopyWithImpl(this._self, this._then);

  final PluginPromptPartText _self;
  final $Res Function(PluginPromptPartText) _then;

/// Create a copy of PluginPromptPart
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? text = null,}) {
  return _then(PluginPromptPartText(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable(createFactory: false)

class PluginPromptPartFilePath implements PluginPromptPart {
  const PluginPromptPartFilePath({required this.mime, required this.path, required this.filename, final  String? $type}): $type = $type ?? 'filePath';
  

 final  String mime;
 final  String path;
 final  String? filename;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of PluginPromptPart
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginPromptPartFilePathCopyWith<PluginPromptPartFilePath> get copyWith => _$PluginPromptPartFilePathCopyWithImpl<PluginPromptPartFilePath>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginPromptPartFilePathToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginPromptPartFilePath&&(identical(other.mime, mime) || other.mime == mime)&&(identical(other.path, path) || other.path == path)&&(identical(other.filename, filename) || other.filename == filename));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,mime,path,filename);

@override
String toString() {
  return 'PluginPromptPart.filePath(mime: $mime, path: $path, filename: $filename)';
}


}

/// @nodoc
abstract mixin class $PluginPromptPartFilePathCopyWith<$Res> implements $PluginPromptPartCopyWith<$Res> {
  factory $PluginPromptPartFilePathCopyWith(PluginPromptPartFilePath value, $Res Function(PluginPromptPartFilePath) _then) = _$PluginPromptPartFilePathCopyWithImpl;
@useResult
$Res call({
 String mime, String path, String? filename
});




}
/// @nodoc
class _$PluginPromptPartFilePathCopyWithImpl<$Res>
    implements $PluginPromptPartFilePathCopyWith<$Res> {
  _$PluginPromptPartFilePathCopyWithImpl(this._self, this._then);

  final PluginPromptPartFilePath _self;
  final $Res Function(PluginPromptPartFilePath) _then;

/// Create a copy of PluginPromptPart
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? mime = null,Object? path = null,Object? filename = freezed,}) {
  return _then(PluginPromptPartFilePath(
mime: null == mime ? _self.mime : mime // ignore: cast_nullable_to_non_nullable
as String,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,filename: freezed == filename ? _self.filename : filename // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable(createFactory: false)

class PluginPromptPartFileUrl implements PluginPromptPart {
  const PluginPromptPartFileUrl({required this.mime, required this.url, required this.filename, final  String? $type}): $type = $type ?? 'fileUrl';
  

 final  String mime;
 final  String url;
 final  String? filename;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of PluginPromptPart
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginPromptPartFileUrlCopyWith<PluginPromptPartFileUrl> get copyWith => _$PluginPromptPartFileUrlCopyWithImpl<PluginPromptPartFileUrl>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginPromptPartFileUrlToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginPromptPartFileUrl&&(identical(other.mime, mime) || other.mime == mime)&&(identical(other.url, url) || other.url == url)&&(identical(other.filename, filename) || other.filename == filename));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,mime,url,filename);

@override
String toString() {
  return 'PluginPromptPart.fileUrl(mime: $mime, url: $url, filename: $filename)';
}


}

/// @nodoc
abstract mixin class $PluginPromptPartFileUrlCopyWith<$Res> implements $PluginPromptPartCopyWith<$Res> {
  factory $PluginPromptPartFileUrlCopyWith(PluginPromptPartFileUrl value, $Res Function(PluginPromptPartFileUrl) _then) = _$PluginPromptPartFileUrlCopyWithImpl;
@useResult
$Res call({
 String mime, String url, String? filename
});




}
/// @nodoc
class _$PluginPromptPartFileUrlCopyWithImpl<$Res>
    implements $PluginPromptPartFileUrlCopyWith<$Res> {
  _$PluginPromptPartFileUrlCopyWithImpl(this._self, this._then);

  final PluginPromptPartFileUrl _self;
  final $Res Function(PluginPromptPartFileUrl) _then;

/// Create a copy of PluginPromptPart
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? mime = null,Object? url = null,Object? filename = freezed,}) {
  return _then(PluginPromptPartFileUrl(
mime: null == mime ? _self.mime : mime // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,filename: freezed == filename ? _self.filename : filename // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable(createFactory: false)

class PluginPromptPartFileData implements PluginPromptPart {
  const PluginPromptPartFileData({required this.mime, required this.base64, required this.filename, final  String? $type}): $type = $type ?? 'fileData';
  

 final  String mime;
 final  String base64;
 final  String? filename;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of PluginPromptPart
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginPromptPartFileDataCopyWith<PluginPromptPartFileData> get copyWith => _$PluginPromptPartFileDataCopyWithImpl<PluginPromptPartFileData>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginPromptPartFileDataToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginPromptPartFileData&&(identical(other.mime, mime) || other.mime == mime)&&(identical(other.base64, base64) || other.base64 == base64)&&(identical(other.filename, filename) || other.filename == filename));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,mime,base64,filename);

@override
String toString() {
  return 'PluginPromptPart.fileData(mime: $mime, base64: $base64, filename: $filename)';
}


}

/// @nodoc
abstract mixin class $PluginPromptPartFileDataCopyWith<$Res> implements $PluginPromptPartCopyWith<$Res> {
  factory $PluginPromptPartFileDataCopyWith(PluginPromptPartFileData value, $Res Function(PluginPromptPartFileData) _then) = _$PluginPromptPartFileDataCopyWithImpl;
@useResult
$Res call({
 String mime, String base64, String? filename
});




}
/// @nodoc
class _$PluginPromptPartFileDataCopyWithImpl<$Res>
    implements $PluginPromptPartFileDataCopyWith<$Res> {
  _$PluginPromptPartFileDataCopyWithImpl(this._self, this._then);

  final PluginPromptPartFileData _self;
  final $Res Function(PluginPromptPartFileData) _then;

/// Create a copy of PluginPromptPart
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? mime = null,Object? base64 = null,Object? filename = freezed,}) {
  return _then(PluginPromptPartFileData(
mime: null == mime ? _self.mime : mime // ignore: cast_nullable_to_non_nullable
as String,base64: null == base64 ? _self.base64 : base64 // ignore: cast_nullable_to_non_nullable
as String,filename: freezed == filename ? _self.filename : filename // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
