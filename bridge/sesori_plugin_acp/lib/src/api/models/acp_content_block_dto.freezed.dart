// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'acp_content_block_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
AcpContentBlockDto _$AcpContentBlockDtoFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'text':
          return AcpTextContentBlockDto.fromJson(
            json
          );
                case 'image':
          return AcpImageContentBlockDto.fromJson(
            json
          );
                case 'audio':
          return AcpUnsupportedAudioContentBlockDto.fromJson(
            json
          );
                case 'resource':
          return AcpUnsupportedResourceContentBlockDto.fromJson(
            json
          );
                case 'resource_link':
          return AcpUnsupportedResourceLinkContentBlockDto.fromJson(
            json
          );
        
          default:
            return AcpUnknownContentBlockDto.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$AcpContentBlockDto {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AcpContentBlockDto);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AcpContentBlockDto()';
}


}

/// @nodoc
class $AcpContentBlockDtoCopyWith<$Res>  {
$AcpContentBlockDtoCopyWith(AcpContentBlockDto _, $Res Function(AcpContentBlockDto) __);
}



/// @nodoc
@JsonSerializable(createToJson: false)

class AcpTextContentBlockDto implements AcpContentBlockDto {
  const AcpTextContentBlockDto({required this.text,  String? $type}): $type = $type ?? 'text';
  factory AcpTextContentBlockDto.fromJson(Map<String, dynamic> json) => _$AcpTextContentBlockDtoFromJson(json);

 final  String text;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of AcpContentBlockDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AcpTextContentBlockDtoCopyWith<AcpTextContentBlockDto> get copyWith => _$AcpTextContentBlockDtoCopyWithImpl<AcpTextContentBlockDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AcpTextContentBlockDto&&(identical(other.text, text) || other.text == text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,text);

@override
String toString() {
  return 'AcpContentBlockDto.text(text: $text)';
}


}

/// @nodoc
abstract mixin class $AcpTextContentBlockDtoCopyWith<$Res> implements $AcpContentBlockDtoCopyWith<$Res> {
  factory $AcpTextContentBlockDtoCopyWith(AcpTextContentBlockDto value, $Res Function(AcpTextContentBlockDto) _then) = _$AcpTextContentBlockDtoCopyWithImpl;
@useResult
$Res call({
 String text
});




}
/// @nodoc
class _$AcpTextContentBlockDtoCopyWithImpl<$Res>
    implements $AcpTextContentBlockDtoCopyWith<$Res> {
  _$AcpTextContentBlockDtoCopyWithImpl(this._self, this._then);

  final AcpTextContentBlockDto _self;
  final $Res Function(AcpTextContentBlockDto) _then;

/// Create a copy of AcpContentBlockDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? text = null,}) {
  return _then(AcpTextContentBlockDto(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class AcpImageContentBlockDto implements AcpContentBlockDto {
  const AcpImageContentBlockDto({required this.data, required this.mimeType, required this.uri,  String? $type}): $type = $type ?? 'image';
  factory AcpImageContentBlockDto.fromJson(Map<String, dynamic> json) => _$AcpImageContentBlockDtoFromJson(json);

 final  String data;
 final  String mimeType;
 final  String? uri;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of AcpContentBlockDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AcpImageContentBlockDtoCopyWith<AcpImageContentBlockDto> get copyWith => _$AcpImageContentBlockDtoCopyWithImpl<AcpImageContentBlockDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AcpImageContentBlockDto&&(identical(other.data, data) || other.data == data)&&(identical(other.mimeType, mimeType) || other.mimeType == mimeType)&&(identical(other.uri, uri) || other.uri == uri));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data,mimeType,uri);

@override
String toString() {
  return 'AcpContentBlockDto.image(data: $data, mimeType: $mimeType, uri: $uri)';
}


}

/// @nodoc
abstract mixin class $AcpImageContentBlockDtoCopyWith<$Res> implements $AcpContentBlockDtoCopyWith<$Res> {
  factory $AcpImageContentBlockDtoCopyWith(AcpImageContentBlockDto value, $Res Function(AcpImageContentBlockDto) _then) = _$AcpImageContentBlockDtoCopyWithImpl;
@useResult
$Res call({
 String data, String mimeType, String? uri
});




}
/// @nodoc
class _$AcpImageContentBlockDtoCopyWithImpl<$Res>
    implements $AcpImageContentBlockDtoCopyWith<$Res> {
  _$AcpImageContentBlockDtoCopyWithImpl(this._self, this._then);

  final AcpImageContentBlockDto _self;
  final $Res Function(AcpImageContentBlockDto) _then;

/// Create a copy of AcpContentBlockDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? data = null,Object? mimeType = null,Object? uri = freezed,}) {
  return _then(AcpImageContentBlockDto(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as String,mimeType: null == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String,uri: freezed == uri ? _self.uri : uri // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class AcpUnsupportedAudioContentBlockDto implements AcpContentBlockDto {
  const AcpUnsupportedAudioContentBlockDto({ String? $type}): $type = $type ?? 'audio';
  factory AcpUnsupportedAudioContentBlockDto.fromJson(Map<String, dynamic> json) => _$AcpUnsupportedAudioContentBlockDtoFromJson(json);



@JsonKey(name: 'type')
final String $type;





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AcpUnsupportedAudioContentBlockDto);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AcpContentBlockDto.unsupportedAudio()';
}


}




/// @nodoc
@JsonSerializable(createToJson: false)

class AcpUnsupportedResourceContentBlockDto implements AcpContentBlockDto {
  const AcpUnsupportedResourceContentBlockDto({ String? $type}): $type = $type ?? 'resource';
  factory AcpUnsupportedResourceContentBlockDto.fromJson(Map<String, dynamic> json) => _$AcpUnsupportedResourceContentBlockDtoFromJson(json);



@JsonKey(name: 'type')
final String $type;





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AcpUnsupportedResourceContentBlockDto);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AcpContentBlockDto.unsupportedResource()';
}


}




/// @nodoc
@JsonSerializable(createToJson: false)

class AcpUnsupportedResourceLinkContentBlockDto implements AcpContentBlockDto {
  const AcpUnsupportedResourceLinkContentBlockDto({ String? $type}): $type = $type ?? 'resource_link';
  factory AcpUnsupportedResourceLinkContentBlockDto.fromJson(Map<String, dynamic> json) => _$AcpUnsupportedResourceLinkContentBlockDtoFromJson(json);



@JsonKey(name: 'type')
final String $type;





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AcpUnsupportedResourceLinkContentBlockDto);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AcpContentBlockDto.unsupportedResourceLink()';
}


}




/// @nodoc
@JsonSerializable(createToJson: false)

class AcpUnknownContentBlockDto implements AcpContentBlockDto {
  const AcpUnknownContentBlockDto({ String? $type}): $type = $type ?? 'unknown';
  factory AcpUnknownContentBlockDto.fromJson(Map<String, dynamic> json) => _$AcpUnknownContentBlockDtoFromJson(json);



@JsonKey(name: 'type')
final String $type;





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AcpUnknownContentBlockDto);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AcpContentBlockDto.unknown()';
}


}




// dart format on
