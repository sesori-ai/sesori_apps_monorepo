// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'acp_permission_details_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AcpPermissionDetailsDto {

@JsonKey(unknownEnumValue: AcpPermissionToolKind.unknown) AcpPermissionToolKind? get kind; List<AcpPermissionLocationDto> get locations; List<AcpPermissionContentDto> get content;
/// Create a copy of AcpPermissionDetailsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AcpPermissionDetailsDtoCopyWith<AcpPermissionDetailsDto> get copyWith => _$AcpPermissionDetailsDtoCopyWithImpl<AcpPermissionDetailsDto>(this as AcpPermissionDetailsDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as AcpPermissionDetailsDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AcpPermissionDetailsDto&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&const DeepCollectionEquality().equals(other.locations, _this.locations)&&const DeepCollectionEquality().equals(other.content, _this.content));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AcpPermissionDetailsDto;
  return Object.hash(runtimeType,_this.kind,const DeepCollectionEquality().hash(_this.locations),const DeepCollectionEquality().hash(_this.content));
}

@override
String toString() {
  final _this = this as AcpPermissionDetailsDto;
  return 'AcpPermissionDetailsDto(kind: ${_this.kind}, locations: ${_this.locations}, content: ${_this.content})';
}


}

/// @nodoc
abstract mixin class $AcpPermissionDetailsDtoCopyWith<$Res>  {
  factory $AcpPermissionDetailsDtoCopyWith(AcpPermissionDetailsDto value, $Res Function(AcpPermissionDetailsDto) _then) = _$AcpPermissionDetailsDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(unknownEnumValue: AcpPermissionToolKind.unknown) AcpPermissionToolKind? kind, List<AcpPermissionLocationDto> locations, List<AcpPermissionContentDto> content
});




}
/// @nodoc
class _$AcpPermissionDetailsDtoCopyWithImpl<$Res>
    implements $AcpPermissionDetailsDtoCopyWith<$Res> {
  _$AcpPermissionDetailsDtoCopyWithImpl(this._self, this._then);

  final AcpPermissionDetailsDto _self;
  final $Res Function(AcpPermissionDetailsDto) _then;

/// Create a copy of AcpPermissionDetailsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = freezed,Object? locations = null,Object? content = null,}) {
  return _then(AcpPermissionDetailsDto(
kind: freezed == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as AcpPermissionToolKind?,locations: null == locations ? _self.locations : locations // ignore: cast_nullable_to_non_nullable
as List<AcpPermissionLocationDto>,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as List<AcpPermissionContentDto>,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _AcpPermissionDetailsDto implements AcpPermissionDetailsDto {
  const _AcpPermissionDetailsDto({@JsonKey(unknownEnumValue: AcpPermissionToolKind.unknown) required this.kind,  List<AcpPermissionLocationDto> locations = const [],  List<AcpPermissionContentDto> content = const []}): _locations = locations,_content = content;
  factory _AcpPermissionDetailsDto.fromJson(Map<String, dynamic> json) => _$AcpPermissionDetailsDtoFromJson(json);

@override@JsonKey(unknownEnumValue: AcpPermissionToolKind.unknown) final  AcpPermissionToolKind? kind;
 final  List<AcpPermissionLocationDto> _locations;
@override@JsonKey() List<AcpPermissionLocationDto> get locations {
  if (_locations is EqualUnmodifiableListView) return _locations;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_locations);
}

 final  List<AcpPermissionContentDto> _content;
@override@JsonKey() List<AcpPermissionContentDto> get content {
  if (_content is EqualUnmodifiableListView) return _content;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_content);
}


/// Create a copy of AcpPermissionDetailsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AcpPermissionDetailsDtoCopyWith<_AcpPermissionDetailsDto> get copyWith => __$AcpPermissionDetailsDtoCopyWithImpl<_AcpPermissionDetailsDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AcpPermissionDetailsDto&&(identical(other.kind, kind) || other.kind == kind)&&const DeepCollectionEquality().equals(other.locations, _locations)&&const DeepCollectionEquality().equals(other.content, _content));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,kind,const DeepCollectionEquality().hash(_locations),const DeepCollectionEquality().hash(_content));
}

@override
String toString() {
    return 'AcpPermissionDetailsDto(kind: $kind, locations: $locations, content: $content)';
}


}

/// @nodoc
abstract mixin class _$AcpPermissionDetailsDtoCopyWith<$Res> implements $AcpPermissionDetailsDtoCopyWith<$Res> {
  factory _$AcpPermissionDetailsDtoCopyWith(_AcpPermissionDetailsDto value, $Res Function(_AcpPermissionDetailsDto) _then) = __$AcpPermissionDetailsDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(unknownEnumValue: AcpPermissionToolKind.unknown) AcpPermissionToolKind? kind, List<AcpPermissionLocationDto> locations, List<AcpPermissionContentDto> content
});




}
/// @nodoc
class __$AcpPermissionDetailsDtoCopyWithImpl<$Res>
    implements _$AcpPermissionDetailsDtoCopyWith<$Res> {
  __$AcpPermissionDetailsDtoCopyWithImpl(this._self, this._then);

  final _AcpPermissionDetailsDto _self;
  final $Res Function(_AcpPermissionDetailsDto) _then;

/// Create a copy of AcpPermissionDetailsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = freezed,Object? locations = null,Object? content = null,}) {
  return _then(_AcpPermissionDetailsDto(
kind: freezed == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as AcpPermissionToolKind?,locations: null == locations ? _self._locations : locations // ignore: cast_nullable_to_non_nullable
as List<AcpPermissionLocationDto>,content: null == content ? _self._content : content // ignore: cast_nullable_to_non_nullable
as List<AcpPermissionContentDto>,
  ));
}


}


/// @nodoc
mixin _$AcpPermissionLocationDto {

 String get path;
/// Create a copy of AcpPermissionLocationDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AcpPermissionLocationDtoCopyWith<AcpPermissionLocationDto> get copyWith => _$AcpPermissionLocationDtoCopyWithImpl<AcpPermissionLocationDto>(this as AcpPermissionLocationDto, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as AcpPermissionLocationDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AcpPermissionLocationDto&&(identical(other.path, _this.path) || other.path == _this.path));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AcpPermissionLocationDto;
  return Object.hash(runtimeType,_this.path);
}

@override
String toString() {
  final _this = this as AcpPermissionLocationDto;
  return 'AcpPermissionLocationDto(path: ${_this.path})';
}


}

/// @nodoc
abstract mixin class $AcpPermissionLocationDtoCopyWith<$Res>  {
  factory $AcpPermissionLocationDtoCopyWith(AcpPermissionLocationDto value, $Res Function(AcpPermissionLocationDto) _then) = _$AcpPermissionLocationDtoCopyWithImpl;
@useResult
$Res call({
 String path
});




}
/// @nodoc
class _$AcpPermissionLocationDtoCopyWithImpl<$Res>
    implements $AcpPermissionLocationDtoCopyWith<$Res> {
  _$AcpPermissionLocationDtoCopyWithImpl(this._self, this._then);

  final AcpPermissionLocationDto _self;
  final $Res Function(AcpPermissionLocationDto) _then;

/// Create a copy of AcpPermissionLocationDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? path = null,}) {
  return _then(AcpPermissionLocationDto(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _AcpPermissionLocationDto implements AcpPermissionLocationDto {
  const _AcpPermissionLocationDto({required this.path});
  factory _AcpPermissionLocationDto.fromJson(Map<String, dynamic> json) => _$AcpPermissionLocationDtoFromJson(json);

@override final  String path;

/// Create a copy of AcpPermissionLocationDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AcpPermissionLocationDtoCopyWith<_AcpPermissionLocationDto> get copyWith => __$AcpPermissionLocationDtoCopyWithImpl<_AcpPermissionLocationDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AcpPermissionLocationDto&&(identical(other.path, path) || other.path == path));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,path);
}

@override
String toString() {
    return 'AcpPermissionLocationDto(path: $path)';
}


}

/// @nodoc
abstract mixin class _$AcpPermissionLocationDtoCopyWith<$Res> implements $AcpPermissionLocationDtoCopyWith<$Res> {
  factory _$AcpPermissionLocationDtoCopyWith(_AcpPermissionLocationDto value, $Res Function(_AcpPermissionLocationDto) _then) = __$AcpPermissionLocationDtoCopyWithImpl;
@override @useResult
$Res call({
 String path
});




}
/// @nodoc
class __$AcpPermissionLocationDtoCopyWithImpl<$Res>
    implements _$AcpPermissionLocationDtoCopyWith<$Res> {
  __$AcpPermissionLocationDtoCopyWithImpl(this._self, this._then);

  final _AcpPermissionLocationDto _self;
  final $Res Function(_AcpPermissionLocationDto) _then;

/// Create a copy of AcpPermissionLocationDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? path = null,}) {
  return _then(_AcpPermissionLocationDto(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

AcpPermissionContentDto _$AcpPermissionContentDtoFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'diff':
          return AcpPermissionDiffDto.fromJson(
            json
          );
                case 'content':
          return AcpPermissionStandardContentDto.fromJson(
            json
          );
        
          default:
            return AcpPermissionUnknownContentDto.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$AcpPermissionContentDto {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AcpPermissionContentDto);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'AcpPermissionContentDto()';
}


}

/// @nodoc
class $AcpPermissionContentDtoCopyWith<$Res>  {
$AcpPermissionContentDtoCopyWith(AcpPermissionContentDto _, $Res Function(AcpPermissionContentDto) __);
}



/// @nodoc
@JsonSerializable(createToJson: false)

class AcpPermissionDiffDto implements AcpPermissionContentDto {
  const AcpPermissionDiffDto({required this.path, required this.oldText,  String? $type}): $type = $type ?? 'diff';
  factory AcpPermissionDiffDto.fromJson(Map<String, dynamic> json) => _$AcpPermissionDiffDtoFromJson(json);

 final  String path;
 final  String? oldText;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of AcpPermissionContentDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AcpPermissionDiffDtoCopyWith<AcpPermissionDiffDto> get copyWith => _$AcpPermissionDiffDtoCopyWithImpl<AcpPermissionDiffDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AcpPermissionDiffDto&&(identical(other.path, path) || other.path == path)&&(identical(other.oldText, oldText) || other.oldText == oldText));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,path,oldText);
}

@override
String toString() {
    return 'AcpPermissionContentDto.diff(path: $path, oldText: $oldText)';
}


}

/// @nodoc
abstract mixin class $AcpPermissionDiffDtoCopyWith<$Res> implements $AcpPermissionContentDtoCopyWith<$Res> {
  factory $AcpPermissionDiffDtoCopyWith(AcpPermissionDiffDto value, $Res Function(AcpPermissionDiffDto) _then) = _$AcpPermissionDiffDtoCopyWithImpl;
@useResult
$Res call({
 String path, String? oldText
});




}
/// @nodoc
class _$AcpPermissionDiffDtoCopyWithImpl<$Res>
    implements $AcpPermissionDiffDtoCopyWith<$Res> {
  _$AcpPermissionDiffDtoCopyWithImpl(this._self, this._then);

  final AcpPermissionDiffDto _self;
  final $Res Function(AcpPermissionDiffDto) _then;

/// Create a copy of AcpPermissionContentDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? path = null,Object? oldText = freezed,}) {
  return _then(AcpPermissionDiffDto(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,oldText: freezed == oldText ? _self.oldText : oldText // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class AcpPermissionStandardContentDto implements AcpPermissionContentDto {
  const AcpPermissionStandardContentDto({required this.content,  String? $type}): $type = $type ?? 'content';
  factory AcpPermissionStandardContentDto.fromJson(Map<String, dynamic> json) => _$AcpPermissionStandardContentDtoFromJson(json);

 final  AcpPermissionResourceDto content;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of AcpPermissionContentDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AcpPermissionStandardContentDtoCopyWith<AcpPermissionStandardContentDto> get copyWith => _$AcpPermissionStandardContentDtoCopyWithImpl<AcpPermissionStandardContentDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AcpPermissionStandardContentDto&&(identical(other.content, content) || other.content == content));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,content);
}

@override
String toString() {
    return 'AcpPermissionContentDto.content(content: $content)';
}


}

/// @nodoc
abstract mixin class $AcpPermissionStandardContentDtoCopyWith<$Res> implements $AcpPermissionContentDtoCopyWith<$Res> {
  factory $AcpPermissionStandardContentDtoCopyWith(AcpPermissionStandardContentDto value, $Res Function(AcpPermissionStandardContentDto) _then) = _$AcpPermissionStandardContentDtoCopyWithImpl;
@useResult
$Res call({
 AcpPermissionResourceDto content
});


$AcpPermissionResourceDtoCopyWith<$Res> get content;

}
/// @nodoc
class _$AcpPermissionStandardContentDtoCopyWithImpl<$Res>
    implements $AcpPermissionStandardContentDtoCopyWith<$Res> {
  _$AcpPermissionStandardContentDtoCopyWithImpl(this._self, this._then);

  final AcpPermissionStandardContentDto _self;
  final $Res Function(AcpPermissionStandardContentDto) _then;

/// Create a copy of AcpPermissionContentDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? content = null,}) {
  return _then(AcpPermissionStandardContentDto(
content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as AcpPermissionResourceDto,
  ));
}

/// Create a copy of AcpPermissionContentDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AcpPermissionResourceDtoCopyWith<$Res> get content {
  
  return $AcpPermissionResourceDtoCopyWith<$Res>(_self.content, (value) {
    return _then(_self.copyWith(content: value));
  });
}
}

/// @nodoc
@JsonSerializable(createToJson: false)

class AcpPermissionUnknownContentDto implements AcpPermissionContentDto {
  const AcpPermissionUnknownContentDto({ String? $type}): $type = $type ?? 'unknown';
  factory AcpPermissionUnknownContentDto.fromJson(Map<String, dynamic> json) => _$AcpPermissionUnknownContentDtoFromJson(json);



@JsonKey(name: 'type')
final String $type;





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AcpPermissionUnknownContentDto);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'AcpPermissionContentDto.unknown()';
}


}




AcpPermissionResourceDto _$AcpPermissionResourceDtoFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'resource_link':
          return AcpPermissionResourceLinkDto.fromJson(
            json
          );
        
          default:
            return AcpPermissionUnknownResourceDto.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$AcpPermissionResourceDto {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AcpPermissionResourceDto);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'AcpPermissionResourceDto()';
}


}

/// @nodoc
class $AcpPermissionResourceDtoCopyWith<$Res>  {
$AcpPermissionResourceDtoCopyWith(AcpPermissionResourceDto _, $Res Function(AcpPermissionResourceDto) __);
}



/// @nodoc
@JsonSerializable(createToJson: false)

class AcpPermissionResourceLinkDto implements AcpPermissionResourceDto {
  const AcpPermissionResourceLinkDto({required this.uri,  String? $type}): $type = $type ?? 'resource_link';
  factory AcpPermissionResourceLinkDto.fromJson(Map<String, dynamic> json) => _$AcpPermissionResourceLinkDtoFromJson(json);

 final  String uri;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of AcpPermissionResourceDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AcpPermissionResourceLinkDtoCopyWith<AcpPermissionResourceLinkDto> get copyWith => _$AcpPermissionResourceLinkDtoCopyWithImpl<AcpPermissionResourceLinkDto>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AcpPermissionResourceLinkDto&&(identical(other.uri, uri) || other.uri == uri));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,uri);
}

@override
String toString() {
    return 'AcpPermissionResourceDto.link(uri: $uri)';
}


}

/// @nodoc
abstract mixin class $AcpPermissionResourceLinkDtoCopyWith<$Res> implements $AcpPermissionResourceDtoCopyWith<$Res> {
  factory $AcpPermissionResourceLinkDtoCopyWith(AcpPermissionResourceLinkDto value, $Res Function(AcpPermissionResourceLinkDto) _then) = _$AcpPermissionResourceLinkDtoCopyWithImpl;
@useResult
$Res call({
 String uri
});




}
/// @nodoc
class _$AcpPermissionResourceLinkDtoCopyWithImpl<$Res>
    implements $AcpPermissionResourceLinkDtoCopyWith<$Res> {
  _$AcpPermissionResourceLinkDtoCopyWithImpl(this._self, this._then);

  final AcpPermissionResourceLinkDto _self;
  final $Res Function(AcpPermissionResourceLinkDto) _then;

/// Create a copy of AcpPermissionResourceDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? uri = null,}) {
  return _then(AcpPermissionResourceLinkDto(
uri: null == uri ? _self.uri : uri // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class AcpPermissionUnknownResourceDto implements AcpPermissionResourceDto {
  const AcpPermissionUnknownResourceDto({ String? $type}): $type = $type ?? 'unknown';
  factory AcpPermissionUnknownResourceDto.fromJson(Map<String, dynamic> json) => _$AcpPermissionUnknownResourceDtoFromJson(json);



@JsonKey(name: 'type')
final String $type;





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AcpPermissionUnknownResourceDto);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'AcpPermissionResourceDto.unknown()';
}


}




// dart format on
