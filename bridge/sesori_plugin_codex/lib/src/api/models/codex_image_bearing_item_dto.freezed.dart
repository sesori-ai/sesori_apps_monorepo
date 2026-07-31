// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'codex_image_bearing_item_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
CodexImageBearingItemDto _$CodexImageBearingItemDtoFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'imageGeneration':
          return CodexImageGenerationItemDto.fromJson(
            json
          );
                case 'mcpToolCall':
          return CodexMcpToolCallItemDto.fromJson(
            json
          );
                case 'dynamicToolCall':
          return CodexDynamicToolCallItemDto.fromJson(
            json
          );
        
          default:
            return CodexUnknownImageBearingItemDto.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$CodexImageBearingItemDto {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexImageBearingItemDto);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'CodexImageBearingItemDto()';
}


}

/// @nodoc
class $CodexImageBearingItemDtoCopyWith<$Res>  {
$CodexImageBearingItemDtoCopyWith(CodexImageBearingItemDto _, $Res Function(CodexImageBearingItemDto) __);
}



/// @nodoc
@JsonSerializable(createToJson: false)

class CodexImageGenerationItemDto implements CodexImageBearingItemDto {
  const CodexImageGenerationItemDto({required this.id, @JsonKey(unknownEnumValue: CodexImageGenerationStatus.unknown, defaultValue: CodexImageGenerationStatus.unknown) required this.status, required this.revisedPrompt, required this.result, required this.savedPath, final  String? $type}): $type = $type ?? 'imageGeneration';
  factory CodexImageGenerationItemDto.fromJson(Map<String, dynamic> json) => _$CodexImageGenerationItemDtoFromJson(json);

 final  String id;
@JsonKey(unknownEnumValue: CodexImageGenerationStatus.unknown, defaultValue: CodexImageGenerationStatus.unknown) final  CodexImageGenerationStatus status;
 final  String? revisedPrompt;
 final  String result;
 final  String? savedPath;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of CodexImageBearingItemDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexImageGenerationItemDtoCopyWith<CodexImageGenerationItemDto> get copyWith => _$CodexImageGenerationItemDtoCopyWithImpl<CodexImageGenerationItemDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexImageGenerationItemDto&&(identical(other.id, id) || other.id == id)&&(identical(other.status, status) || other.status == status)&&(identical(other.revisedPrompt, revisedPrompt) || other.revisedPrompt == revisedPrompt)&&(identical(other.result, result) || other.result == result)&&(identical(other.savedPath, savedPath) || other.savedPath == savedPath));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,status,revisedPrompt,result,savedPath);

@override
String toString() {
  return 'CodexImageBearingItemDto.imageGeneration(id: $id, status: $status, revisedPrompt: $revisedPrompt, result: $result, savedPath: $savedPath)';
}


}

/// @nodoc
abstract mixin class $CodexImageGenerationItemDtoCopyWith<$Res> implements $CodexImageBearingItemDtoCopyWith<$Res> {
  factory $CodexImageGenerationItemDtoCopyWith(CodexImageGenerationItemDto value, $Res Function(CodexImageGenerationItemDto) _then) = _$CodexImageGenerationItemDtoCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(unknownEnumValue: CodexImageGenerationStatus.unknown, defaultValue: CodexImageGenerationStatus.unknown) CodexImageGenerationStatus status, String? revisedPrompt, String result, String? savedPath
});




}
/// @nodoc
class _$CodexImageGenerationItemDtoCopyWithImpl<$Res>
    implements $CodexImageGenerationItemDtoCopyWith<$Res> {
  _$CodexImageGenerationItemDtoCopyWithImpl(this._self, this._then);

  final CodexImageGenerationItemDto _self;
  final $Res Function(CodexImageGenerationItemDto) _then;

/// Create a copy of CodexImageBearingItemDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? id = null,Object? status = null,Object? revisedPrompt = freezed,Object? result = null,Object? savedPath = freezed,}) {
  return _then(CodexImageGenerationItemDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as CodexImageGenerationStatus,revisedPrompt: freezed == revisedPrompt ? _self.revisedPrompt : revisedPrompt // ignore: cast_nullable_to_non_nullable
as String?,result: null == result ? _self.result : result // ignore: cast_nullable_to_non_nullable
as String,savedPath: freezed == savedPath ? _self.savedPath : savedPath // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class CodexMcpToolCallItemDto implements CodexImageBearingItemDto {
  const CodexMcpToolCallItemDto({required this.id, required this.server, required this.tool, @JsonKey(unknownEnumValue: CodexToolCallStatus.unknown, defaultValue: CodexToolCallStatus.unknown) required this.status, @JsonKey(name: "result")@CodexMcpResultContentConverter() required final  List<CodexImageBearingContentDto> content, @CodexToolErrorConverter() required this.error, final  String? $type}): _content = content,$type = $type ?? 'mcpToolCall';
  factory CodexMcpToolCallItemDto.fromJson(Map<String, dynamic> json) => _$CodexMcpToolCallItemDtoFromJson(json);

 final  String id;
 final  String? server;
 final  String? tool;
@JsonKey(unknownEnumValue: CodexToolCallStatus.unknown, defaultValue: CodexToolCallStatus.unknown) final  CodexToolCallStatus status;
 final  List<CodexImageBearingContentDto> _content;
@JsonKey(name: "result")@CodexMcpResultContentConverter() List<CodexImageBearingContentDto> get content {
  if (_content is EqualUnmodifiableListView) return _content;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_content);
}

@CodexToolErrorConverter() final  String? error;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of CodexImageBearingItemDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexMcpToolCallItemDtoCopyWith<CodexMcpToolCallItemDto> get copyWith => _$CodexMcpToolCallItemDtoCopyWithImpl<CodexMcpToolCallItemDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexMcpToolCallItemDto&&(identical(other.id, id) || other.id == id)&&(identical(other.server, server) || other.server == server)&&(identical(other.tool, tool) || other.tool == tool)&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other._content, _content)&&(identical(other.error, error) || other.error == error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,server,tool,status,const DeepCollectionEquality().hash(_content),error);

@override
String toString() {
  return 'CodexImageBearingItemDto.mcpToolCall(id: $id, server: $server, tool: $tool, status: $status, content: $content, error: $error)';
}


}

/// @nodoc
abstract mixin class $CodexMcpToolCallItemDtoCopyWith<$Res> implements $CodexImageBearingItemDtoCopyWith<$Res> {
  factory $CodexMcpToolCallItemDtoCopyWith(CodexMcpToolCallItemDto value, $Res Function(CodexMcpToolCallItemDto) _then) = _$CodexMcpToolCallItemDtoCopyWithImpl;
@useResult
$Res call({
 String id, String? server, String? tool,@JsonKey(unknownEnumValue: CodexToolCallStatus.unknown, defaultValue: CodexToolCallStatus.unknown) CodexToolCallStatus status,@JsonKey(name: "result")@CodexMcpResultContentConverter() List<CodexImageBearingContentDto> content,@CodexToolErrorConverter() String? error
});




}
/// @nodoc
class _$CodexMcpToolCallItemDtoCopyWithImpl<$Res>
    implements $CodexMcpToolCallItemDtoCopyWith<$Res> {
  _$CodexMcpToolCallItemDtoCopyWithImpl(this._self, this._then);

  final CodexMcpToolCallItemDto _self;
  final $Res Function(CodexMcpToolCallItemDto) _then;

/// Create a copy of CodexImageBearingItemDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? id = null,Object? server = freezed,Object? tool = freezed,Object? status = null,Object? content = null,Object? error = freezed,}) {
  return _then(CodexMcpToolCallItemDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,server: freezed == server ? _self.server : server // ignore: cast_nullable_to_non_nullable
as String?,tool: freezed == tool ? _self.tool : tool // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as CodexToolCallStatus,content: null == content ? _self._content : content // ignore: cast_nullable_to_non_nullable
as List<CodexImageBearingContentDto>,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class CodexDynamicToolCallItemDto implements CodexImageBearingItemDto {
  const CodexDynamicToolCallItemDto({required this.id, @CodexToolNameConverter() required this.tool, required this.arguments, @JsonKey(unknownEnumValue: CodexToolCallStatus.unknown, defaultValue: CodexToolCallStatus.unknown) required this.status, @JsonKey(name: "contentItems")@CodexImageBearingContentListConverter() required final  List<CodexImageBearingContentDto> content, final  String? $type}): _content = content,$type = $type ?? 'dynamicToolCall';
  factory CodexDynamicToolCallItemDto.fromJson(Map<String, dynamic> json) => _$CodexDynamicToolCallItemDtoFromJson(json);

 final  String id;
@CodexToolNameConverter() final  String tool;
 final  Object? arguments;
@JsonKey(unknownEnumValue: CodexToolCallStatus.unknown, defaultValue: CodexToolCallStatus.unknown) final  CodexToolCallStatus status;
 final  List<CodexImageBearingContentDto> _content;
@JsonKey(name: "contentItems")@CodexImageBearingContentListConverter() List<CodexImageBearingContentDto> get content {
  if (_content is EqualUnmodifiableListView) return _content;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_content);
}


@JsonKey(name: 'type')
final String $type;


/// Create a copy of CodexImageBearingItemDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexDynamicToolCallItemDtoCopyWith<CodexDynamicToolCallItemDto> get copyWith => _$CodexDynamicToolCallItemDtoCopyWithImpl<CodexDynamicToolCallItemDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexDynamicToolCallItemDto&&(identical(other.id, id) || other.id == id)&&(identical(other.tool, tool) || other.tool == tool)&&const DeepCollectionEquality().equals(other.arguments, arguments)&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other._content, _content));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,tool,const DeepCollectionEquality().hash(arguments),status,const DeepCollectionEquality().hash(_content));

@override
String toString() {
  return 'CodexImageBearingItemDto.dynamicToolCall(id: $id, tool: $tool, arguments: $arguments, status: $status, content: $content)';
}


}

/// @nodoc
abstract mixin class $CodexDynamicToolCallItemDtoCopyWith<$Res> implements $CodexImageBearingItemDtoCopyWith<$Res> {
  factory $CodexDynamicToolCallItemDtoCopyWith(CodexDynamicToolCallItemDto value, $Res Function(CodexDynamicToolCallItemDto) _then) = _$CodexDynamicToolCallItemDtoCopyWithImpl;
@useResult
$Res call({
 String id,@CodexToolNameConverter() String tool, Object? arguments,@JsonKey(unknownEnumValue: CodexToolCallStatus.unknown, defaultValue: CodexToolCallStatus.unknown) CodexToolCallStatus status,@JsonKey(name: "contentItems")@CodexImageBearingContentListConverter() List<CodexImageBearingContentDto> content
});




}
/// @nodoc
class _$CodexDynamicToolCallItemDtoCopyWithImpl<$Res>
    implements $CodexDynamicToolCallItemDtoCopyWith<$Res> {
  _$CodexDynamicToolCallItemDtoCopyWithImpl(this._self, this._then);

  final CodexDynamicToolCallItemDto _self;
  final $Res Function(CodexDynamicToolCallItemDto) _then;

/// Create a copy of CodexImageBearingItemDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? id = null,Object? tool = null,Object? arguments = freezed,Object? status = null,Object? content = null,}) {
  return _then(CodexDynamicToolCallItemDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,tool: null == tool ? _self.tool : tool // ignore: cast_nullable_to_non_nullable
as String,arguments: freezed == arguments ? _self.arguments : arguments ,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as CodexToolCallStatus,content: null == content ? _self._content : content // ignore: cast_nullable_to_non_nullable
as List<CodexImageBearingContentDto>,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class CodexUnknownImageBearingItemDto implements CodexImageBearingItemDto {
  const CodexUnknownImageBearingItemDto({final  String? $type}): $type = $type ?? 'unknown';
  factory CodexUnknownImageBearingItemDto.fromJson(Map<String, dynamic> json) => _$CodexUnknownImageBearingItemDtoFromJson(json);



@JsonKey(name: 'type')
final String $type;





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexUnknownImageBearingItemDto);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'CodexImageBearingItemDto.unknown()';
}


}




CodexImageBearingContentDto _$CodexImageBearingContentDtoFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'text':
          return CodexMcpTextContentDto.fromJson(
            json
          );
                case 'image':
          return CodexMcpImageContentDto.fromJson(
            json
          );
                case 'inputText':
          return CodexDynamicTextContentDto.fromJson(
            json
          );
                case 'inputImage':
          return CodexDynamicImageContentDto.fromJson(
            json
          );
                case 'inputAudio':
          return CodexDynamicAudioContentDto.fromJson(
            json
          );
        
          default:
            return CodexUnknownImageBearingContentDto.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$CodexImageBearingContentDto {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexImageBearingContentDto);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'CodexImageBearingContentDto()';
}


}

/// @nodoc
class $CodexImageBearingContentDtoCopyWith<$Res>  {
$CodexImageBearingContentDtoCopyWith(CodexImageBearingContentDto _, $Res Function(CodexImageBearingContentDto) __);
}



/// @nodoc
@JsonSerializable(createToJson: false)

class CodexMcpTextContentDto implements CodexImageBearingContentDto {
  const CodexMcpTextContentDto({required this.text, final  String? $type}): $type = $type ?? 'text';
  factory CodexMcpTextContentDto.fromJson(Map<String, dynamic> json) => _$CodexMcpTextContentDtoFromJson(json);

 final  String text;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of CodexImageBearingContentDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexMcpTextContentDtoCopyWith<CodexMcpTextContentDto> get copyWith => _$CodexMcpTextContentDtoCopyWithImpl<CodexMcpTextContentDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexMcpTextContentDto&&(identical(other.text, text) || other.text == text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,text);

@override
String toString() {
  return 'CodexImageBearingContentDto.mcpText(text: $text)';
}


}

/// @nodoc
abstract mixin class $CodexMcpTextContentDtoCopyWith<$Res> implements $CodexImageBearingContentDtoCopyWith<$Res> {
  factory $CodexMcpTextContentDtoCopyWith(CodexMcpTextContentDto value, $Res Function(CodexMcpTextContentDto) _then) = _$CodexMcpTextContentDtoCopyWithImpl;
@useResult
$Res call({
 String text
});




}
/// @nodoc
class _$CodexMcpTextContentDtoCopyWithImpl<$Res>
    implements $CodexMcpTextContentDtoCopyWith<$Res> {
  _$CodexMcpTextContentDtoCopyWithImpl(this._self, this._then);

  final CodexMcpTextContentDto _self;
  final $Res Function(CodexMcpTextContentDto) _then;

/// Create a copy of CodexImageBearingContentDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? text = null,}) {
  return _then(CodexMcpTextContentDto(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class CodexMcpImageContentDto implements CodexImageBearingContentDto {
  const CodexMcpImageContentDto({required this.data, required this.mimeType, final  String? $type}): $type = $type ?? 'image';
  factory CodexMcpImageContentDto.fromJson(Map<String, dynamic> json) => _$CodexMcpImageContentDtoFromJson(json);

 final  String data;
 final  String mimeType;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of CodexImageBearingContentDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexMcpImageContentDtoCopyWith<CodexMcpImageContentDto> get copyWith => _$CodexMcpImageContentDtoCopyWithImpl<CodexMcpImageContentDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexMcpImageContentDto&&(identical(other.data, data) || other.data == data)&&(identical(other.mimeType, mimeType) || other.mimeType == mimeType));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data,mimeType);

@override
String toString() {
  return 'CodexImageBearingContentDto.mcpImage(data: $data, mimeType: $mimeType)';
}


}

/// @nodoc
abstract mixin class $CodexMcpImageContentDtoCopyWith<$Res> implements $CodexImageBearingContentDtoCopyWith<$Res> {
  factory $CodexMcpImageContentDtoCopyWith(CodexMcpImageContentDto value, $Res Function(CodexMcpImageContentDto) _then) = _$CodexMcpImageContentDtoCopyWithImpl;
@useResult
$Res call({
 String data, String mimeType
});




}
/// @nodoc
class _$CodexMcpImageContentDtoCopyWithImpl<$Res>
    implements $CodexMcpImageContentDtoCopyWith<$Res> {
  _$CodexMcpImageContentDtoCopyWithImpl(this._self, this._then);

  final CodexMcpImageContentDto _self;
  final $Res Function(CodexMcpImageContentDto) _then;

/// Create a copy of CodexImageBearingContentDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? data = null,Object? mimeType = null,}) {
  return _then(CodexMcpImageContentDto(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as String,mimeType: null == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class CodexDynamicTextContentDto implements CodexImageBearingContentDto {
  const CodexDynamicTextContentDto({required this.text, final  String? $type}): $type = $type ?? 'inputText';
  factory CodexDynamicTextContentDto.fromJson(Map<String, dynamic> json) => _$CodexDynamicTextContentDtoFromJson(json);

 final  String text;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of CodexImageBearingContentDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexDynamicTextContentDtoCopyWith<CodexDynamicTextContentDto> get copyWith => _$CodexDynamicTextContentDtoCopyWithImpl<CodexDynamicTextContentDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexDynamicTextContentDto&&(identical(other.text, text) || other.text == text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,text);

@override
String toString() {
  return 'CodexImageBearingContentDto.dynamicText(text: $text)';
}


}

/// @nodoc
abstract mixin class $CodexDynamicTextContentDtoCopyWith<$Res> implements $CodexImageBearingContentDtoCopyWith<$Res> {
  factory $CodexDynamicTextContentDtoCopyWith(CodexDynamicTextContentDto value, $Res Function(CodexDynamicTextContentDto) _then) = _$CodexDynamicTextContentDtoCopyWithImpl;
@useResult
$Res call({
 String text
});




}
/// @nodoc
class _$CodexDynamicTextContentDtoCopyWithImpl<$Res>
    implements $CodexDynamicTextContentDtoCopyWith<$Res> {
  _$CodexDynamicTextContentDtoCopyWithImpl(this._self, this._then);

  final CodexDynamicTextContentDto _self;
  final $Res Function(CodexDynamicTextContentDto) _then;

/// Create a copy of CodexImageBearingContentDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? text = null,}) {
  return _then(CodexDynamicTextContentDto(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class CodexDynamicImageContentDto implements CodexImageBearingContentDto {
  const CodexDynamicImageContentDto({required this.imageUrl, final  String? $type}): $type = $type ?? 'inputImage';
  factory CodexDynamicImageContentDto.fromJson(Map<String, dynamic> json) => _$CodexDynamicImageContentDtoFromJson(json);

 final  String imageUrl;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of CodexImageBearingContentDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexDynamicImageContentDtoCopyWith<CodexDynamicImageContentDto> get copyWith => _$CodexDynamicImageContentDtoCopyWithImpl<CodexDynamicImageContentDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexDynamicImageContentDto&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,imageUrl);

@override
String toString() {
  return 'CodexImageBearingContentDto.dynamicImage(imageUrl: $imageUrl)';
}


}

/// @nodoc
abstract mixin class $CodexDynamicImageContentDtoCopyWith<$Res> implements $CodexImageBearingContentDtoCopyWith<$Res> {
  factory $CodexDynamicImageContentDtoCopyWith(CodexDynamicImageContentDto value, $Res Function(CodexDynamicImageContentDto) _then) = _$CodexDynamicImageContentDtoCopyWithImpl;
@useResult
$Res call({
 String imageUrl
});




}
/// @nodoc
class _$CodexDynamicImageContentDtoCopyWithImpl<$Res>
    implements $CodexDynamicImageContentDtoCopyWith<$Res> {
  _$CodexDynamicImageContentDtoCopyWithImpl(this._self, this._then);

  final CodexDynamicImageContentDto _self;
  final $Res Function(CodexDynamicImageContentDto) _then;

/// Create a copy of CodexImageBearingContentDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? imageUrl = null,}) {
  return _then(CodexDynamicImageContentDto(
imageUrl: null == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class CodexDynamicAudioContentDto implements CodexImageBearingContentDto {
  const CodexDynamicAudioContentDto({required this.audioUrl, final  String? $type}): $type = $type ?? 'inputAudio';
  factory CodexDynamicAudioContentDto.fromJson(Map<String, dynamic> json) => _$CodexDynamicAudioContentDtoFromJson(json);

 final  String audioUrl;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of CodexImageBearingContentDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexDynamicAudioContentDtoCopyWith<CodexDynamicAudioContentDto> get copyWith => _$CodexDynamicAudioContentDtoCopyWithImpl<CodexDynamicAudioContentDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexDynamicAudioContentDto&&(identical(other.audioUrl, audioUrl) || other.audioUrl == audioUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,audioUrl);

@override
String toString() {
  return 'CodexImageBearingContentDto.dynamicAudio(audioUrl: $audioUrl)';
}


}

/// @nodoc
abstract mixin class $CodexDynamicAudioContentDtoCopyWith<$Res> implements $CodexImageBearingContentDtoCopyWith<$Res> {
  factory $CodexDynamicAudioContentDtoCopyWith(CodexDynamicAudioContentDto value, $Res Function(CodexDynamicAudioContentDto) _then) = _$CodexDynamicAudioContentDtoCopyWithImpl;
@useResult
$Res call({
 String audioUrl
});




}
/// @nodoc
class _$CodexDynamicAudioContentDtoCopyWithImpl<$Res>
    implements $CodexDynamicAudioContentDtoCopyWith<$Res> {
  _$CodexDynamicAudioContentDtoCopyWithImpl(this._self, this._then);

  final CodexDynamicAudioContentDto _self;
  final $Res Function(CodexDynamicAudioContentDto) _then;

/// Create a copy of CodexImageBearingContentDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? audioUrl = null,}) {
  return _then(CodexDynamicAudioContentDto(
audioUrl: null == audioUrl ? _self.audioUrl : audioUrl // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class CodexUnknownImageBearingContentDto implements CodexImageBearingContentDto {
  const CodexUnknownImageBearingContentDto({final  String? $type}): $type = $type ?? 'unknown';
  factory CodexUnknownImageBearingContentDto.fromJson(Map<String, dynamic> json) => _$CodexUnknownImageBearingContentDtoFromJson(json);



@JsonKey(name: 'type')
final String $type;





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexUnknownImageBearingContentDto);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'CodexImageBearingContentDto.unknown()';
}


}




// dart format on
