// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'file_preview.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FilePreviewRequest {

 String get path;
/// Create a copy of FilePreviewRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FilePreviewRequestCopyWith<FilePreviewRequest> get copyWith => _$FilePreviewRequestCopyWithImpl<FilePreviewRequest>(this as FilePreviewRequest, _$identity);

  /// Serializes this FilePreviewRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as FilePreviewRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FilePreviewRequest&&(identical(other.path, _this.path) || other.path == _this.path));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as FilePreviewRequest;
  return Object.hash(runtimeType,_this.path);
}

@override
String toString() {
  final _this = this as FilePreviewRequest;
  return 'FilePreviewRequest(path: ${_this.path})';
}


}

/// @nodoc
abstract mixin class $FilePreviewRequestCopyWith<$Res>  {
  factory $FilePreviewRequestCopyWith(FilePreviewRequest value, $Res Function(FilePreviewRequest) _then) = _$FilePreviewRequestCopyWithImpl;
@useResult
$Res call({
 String path
});




}
/// @nodoc
class _$FilePreviewRequestCopyWithImpl<$Res>
    implements $FilePreviewRequestCopyWith<$Res> {
  _$FilePreviewRequestCopyWithImpl(this._self, this._then);

  final FilePreviewRequest _self;
  final $Res Function(FilePreviewRequest) _then;

/// Create a copy of FilePreviewRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? path = null,}) {
  return _then(FilePreviewRequest(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _FilePreviewRequest implements FilePreviewRequest {
  const _FilePreviewRequest({required this.path});
  factory _FilePreviewRequest.fromJson(Map<String, dynamic> json) => _$FilePreviewRequestFromJson(json);

@override final  String path;

/// Create a copy of FilePreviewRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FilePreviewRequestCopyWith<_FilePreviewRequest> get copyWith => __$FilePreviewRequestCopyWithImpl<_FilePreviewRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FilePreviewRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _FilePreviewRequest&&(identical(other.path, path) || other.path == path));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,path);
}

@override
String toString() {
    return 'FilePreviewRequest(path: $path)';
}


}

/// @nodoc
abstract mixin class _$FilePreviewRequestCopyWith<$Res> implements $FilePreviewRequestCopyWith<$Res> {
  factory _$FilePreviewRequestCopyWith(_FilePreviewRequest value, $Res Function(_FilePreviewRequest) _then) = __$FilePreviewRequestCopyWithImpl;
@override @useResult
$Res call({
 String path
});




}
/// @nodoc
class __$FilePreviewRequestCopyWithImpl<$Res>
    implements _$FilePreviewRequestCopyWith<$Res> {
  __$FilePreviewRequestCopyWithImpl(this._self, this._then);

  final _FilePreviewRequest _self;
  final $Res Function(_FilePreviewRequest) _then;

/// Create a copy of FilePreviewRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? path = null,}) {
  return _then(_FilePreviewRequest(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

FilePreviewResponse _$FilePreviewResponseFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'text':
          return FilePreviewText.fromJson(
            json
          );
                case 'image':
          return FilePreviewImage.fromJson(
            json
          );
                case 'missing':
          return FilePreviewMissing.fromJson(
            json
          );
                case 'too_large':
          return FilePreviewTooLarge.fromJson(
            json
          );
                case 'unsupported':
          return FilePreviewUnsupported.fromJson(
            json
          );
                case 'denied':
          return FilePreviewDenied.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'type',
  'FilePreviewResponse',
  'Invalid union type "${json['type']}"!'
);
        }
      
}

/// @nodoc
mixin _$FilePreviewResponse {



  /// Serializes this FilePreviewResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FilePreviewResponse);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'FilePreviewResponse()';
}


}

/// @nodoc
class $FilePreviewResponseCopyWith<$Res>  {
$FilePreviewResponseCopyWith(FilePreviewResponse _, $Res Function(FilePreviewResponse) __);
}



/// @nodoc
@JsonSerializable()

class FilePreviewText implements FilePreviewResponse {
  const FilePreviewText({required this.content,  String? $type}): $type = $type ?? 'text';
  factory FilePreviewText.fromJson(Map<String, dynamic> json) => _$FilePreviewTextFromJson(json);

 final  String content;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of FilePreviewResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FilePreviewTextCopyWith<FilePreviewText> get copyWith => _$FilePreviewTextCopyWithImpl<FilePreviewText>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FilePreviewTextToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FilePreviewText&&(identical(other.content, content) || other.content == content));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,content);
}

@override
String toString() {
    return 'FilePreviewResponse.text(content: $content)';
}


}

/// @nodoc
abstract mixin class $FilePreviewTextCopyWith<$Res> implements $FilePreviewResponseCopyWith<$Res> {
  factory $FilePreviewTextCopyWith(FilePreviewText value, $Res Function(FilePreviewText) _then) = _$FilePreviewTextCopyWithImpl;
@useResult
$Res call({
 String content
});




}
/// @nodoc
class _$FilePreviewTextCopyWithImpl<$Res>
    implements $FilePreviewTextCopyWith<$Res> {
  _$FilePreviewTextCopyWithImpl(this._self, this._then);

  final FilePreviewText _self;
  final $Res Function(FilePreviewText) _then;

/// Create a copy of FilePreviewResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? content = null,}) {
  return _then(FilePreviewText(
content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class FilePreviewImage implements FilePreviewResponse {
  const FilePreviewImage({required this.mime, required this.base64, required this.byteLength,  String? $type}): $type = $type ?? 'image';
  factory FilePreviewImage.fromJson(Map<String, dynamic> json) => _$FilePreviewImageFromJson(json);

 final  String mime;
 final  String base64;
 final  int byteLength;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of FilePreviewResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FilePreviewImageCopyWith<FilePreviewImage> get copyWith => _$FilePreviewImageCopyWithImpl<FilePreviewImage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FilePreviewImageToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FilePreviewImage&&(identical(other.mime, mime) || other.mime == mime)&&(identical(other.base64, base64) || other.base64 == base64)&&(identical(other.byteLength, byteLength) || other.byteLength == byteLength));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,mime,base64,byteLength);
}

@override
String toString() {
    return 'FilePreviewResponse.image(mime: $mime, base64: $base64, byteLength: $byteLength)';
}


}

/// @nodoc
abstract mixin class $FilePreviewImageCopyWith<$Res> implements $FilePreviewResponseCopyWith<$Res> {
  factory $FilePreviewImageCopyWith(FilePreviewImage value, $Res Function(FilePreviewImage) _then) = _$FilePreviewImageCopyWithImpl;
@useResult
$Res call({
 String mime, String base64, int byteLength
});




}
/// @nodoc
class _$FilePreviewImageCopyWithImpl<$Res>
    implements $FilePreviewImageCopyWith<$Res> {
  _$FilePreviewImageCopyWithImpl(this._self, this._then);

  final FilePreviewImage _self;
  final $Res Function(FilePreviewImage) _then;

/// Create a copy of FilePreviewResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? mime = null,Object? base64 = null,Object? byteLength = null,}) {
  return _then(FilePreviewImage(
mime: null == mime ? _self.mime : mime // ignore: cast_nullable_to_non_nullable
as String,base64: null == base64 ? _self.base64 : base64 // ignore: cast_nullable_to_non_nullable
as String,byteLength: null == byteLength ? _self.byteLength : byteLength // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
@JsonSerializable()

class FilePreviewMissing implements FilePreviewResponse {
  const FilePreviewMissing({ String? $type}): $type = $type ?? 'missing';
  factory FilePreviewMissing.fromJson(Map<String, dynamic> json) => _$FilePreviewMissingFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$FilePreviewMissingToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FilePreviewMissing);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'FilePreviewResponse.missing()';
}


}




/// @nodoc
@JsonSerializable()

class FilePreviewTooLarge implements FilePreviewResponse {
  const FilePreviewTooLarge({ String? $type}): $type = $type ?? 'too_large';
  factory FilePreviewTooLarge.fromJson(Map<String, dynamic> json) => _$FilePreviewTooLargeFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$FilePreviewTooLargeToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FilePreviewTooLarge);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'FilePreviewResponse.tooLarge()';
}


}




/// @nodoc
@JsonSerializable()

class FilePreviewUnsupported implements FilePreviewResponse {
  const FilePreviewUnsupported({ String? $type}): $type = $type ?? 'unsupported';
  factory FilePreviewUnsupported.fromJson(Map<String, dynamic> json) => _$FilePreviewUnsupportedFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$FilePreviewUnsupportedToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FilePreviewUnsupported);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'FilePreviewResponse.unsupported()';
}


}




/// @nodoc
@JsonSerializable()

class FilePreviewDenied implements FilePreviewResponse {
  const FilePreviewDenied({ String? $type}): $type = $type ?? 'denied';
  factory FilePreviewDenied.fromJson(Map<String, dynamic> json) => _$FilePreviewDeniedFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$FilePreviewDeniedToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is FilePreviewDenied);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'FilePreviewResponse.denied()';
}


}




// dart format on
