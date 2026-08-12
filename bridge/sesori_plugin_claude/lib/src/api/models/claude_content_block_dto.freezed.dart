// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'claude_content_block_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
ClaudeContentBlockDto _$ClaudeContentBlockDtoFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'text':
          return ClaudeTextContentBlockDto.fromJson(
            json
          );
                case 'thinking':
          return ClaudeThinkingContentBlockDto.fromJson(
            json
          );
                case 'redacted_thinking':
          return ClaudeRedactedThinkingContentBlockDto.fromJson(
            json
          );
                case 'tool_use':
          return ClaudeToolUseContentBlockDto.fromJson(
            json
          );
                case 'tool_result':
          return ClaudeToolResultContentBlockDto.fromJson(
            json
          );
                case 'image':
          return ClaudeImageContentBlockDto.fromJson(
            json
          );
        
          default:
            return ClaudeUnknownContentBlockDto.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$ClaudeContentBlockDto {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClaudeContentBlockDto);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;



}

/// @nodoc
class $ClaudeContentBlockDtoCopyWith<$Res>  {
$ClaudeContentBlockDtoCopyWith(ClaudeContentBlockDto _, $Res Function(ClaudeContentBlockDto) __);
}



/// @nodoc
@JsonSerializable(createToJson: false)

class ClaudeTextContentBlockDto implements ClaudeContentBlockDto {
  const ClaudeTextContentBlockDto({@JsonKey(fromJson: _stringOrNull) required this.text,  String? $type}): $type = $type ?? 'text';
  factory ClaudeTextContentBlockDto.fromJson(Map<String, dynamic> json) => _$ClaudeTextContentBlockDtoFromJson(json);

@JsonKey(fromJson: _stringOrNull) final  String? text;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of ClaudeContentBlockDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClaudeTextContentBlockDtoCopyWith<ClaudeTextContentBlockDto> get copyWith => _$ClaudeTextContentBlockDtoCopyWithImpl<ClaudeTextContentBlockDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClaudeTextContentBlockDto&&(identical(other.text, text) || other.text == text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,text);



}

/// @nodoc
abstract mixin class $ClaudeTextContentBlockDtoCopyWith<$Res> implements $ClaudeContentBlockDtoCopyWith<$Res> {
  factory $ClaudeTextContentBlockDtoCopyWith(ClaudeTextContentBlockDto value, $Res Function(ClaudeTextContentBlockDto) _then) = _$ClaudeTextContentBlockDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _stringOrNull) String? text
});




}
/// @nodoc
class _$ClaudeTextContentBlockDtoCopyWithImpl<$Res>
    implements $ClaudeTextContentBlockDtoCopyWith<$Res> {
  _$ClaudeTextContentBlockDtoCopyWithImpl(this._self, this._then);

  final ClaudeTextContentBlockDto _self;
  final $Res Function(ClaudeTextContentBlockDto) _then;

/// Create a copy of ClaudeContentBlockDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? text = freezed,}) {
  return _then(ClaudeTextContentBlockDto(
text: freezed == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class ClaudeThinkingContentBlockDto implements ClaudeContentBlockDto {
  const ClaudeThinkingContentBlockDto({@JsonKey(fromJson: _stringOrNull) required this.thinking, @JsonKey(fromJson: _stringOrNull) required this.signature,  String? $type}): $type = $type ?? 'thinking';
  factory ClaudeThinkingContentBlockDto.fromJson(Map<String, dynamic> json) => _$ClaudeThinkingContentBlockDtoFromJson(json);

@JsonKey(fromJson: _stringOrNull) final  String? thinking;
@JsonKey(fromJson: _stringOrNull) final  String? signature;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of ClaudeContentBlockDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClaudeThinkingContentBlockDtoCopyWith<ClaudeThinkingContentBlockDto> get copyWith => _$ClaudeThinkingContentBlockDtoCopyWithImpl<ClaudeThinkingContentBlockDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClaudeThinkingContentBlockDto&&(identical(other.thinking, thinking) || other.thinking == thinking)&&(identical(other.signature, signature) || other.signature == signature));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,thinking,signature);



}

/// @nodoc
abstract mixin class $ClaudeThinkingContentBlockDtoCopyWith<$Res> implements $ClaudeContentBlockDtoCopyWith<$Res> {
  factory $ClaudeThinkingContentBlockDtoCopyWith(ClaudeThinkingContentBlockDto value, $Res Function(ClaudeThinkingContentBlockDto) _then) = _$ClaudeThinkingContentBlockDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _stringOrNull) String? thinking,@JsonKey(fromJson: _stringOrNull) String? signature
});




}
/// @nodoc
class _$ClaudeThinkingContentBlockDtoCopyWithImpl<$Res>
    implements $ClaudeThinkingContentBlockDtoCopyWith<$Res> {
  _$ClaudeThinkingContentBlockDtoCopyWithImpl(this._self, this._then);

  final ClaudeThinkingContentBlockDto _self;
  final $Res Function(ClaudeThinkingContentBlockDto) _then;

/// Create a copy of ClaudeContentBlockDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? thinking = freezed,Object? signature = freezed,}) {
  return _then(ClaudeThinkingContentBlockDto(
thinking: freezed == thinking ? _self.thinking : thinking // ignore: cast_nullable_to_non_nullable
as String?,signature: freezed == signature ? _self.signature : signature // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class ClaudeRedactedThinkingContentBlockDto implements ClaudeContentBlockDto {
  const ClaudeRedactedThinkingContentBlockDto({ String? $type}): $type = $type ?? 'redacted_thinking';
  factory ClaudeRedactedThinkingContentBlockDto.fromJson(Map<String, dynamic> json) => _$ClaudeRedactedThinkingContentBlockDtoFromJson(json);



@JsonKey(name: 'type')
final String $type;





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClaudeRedactedThinkingContentBlockDto);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;



}




/// @nodoc
@JsonSerializable(createToJson: false)

class ClaudeToolUseContentBlockDto implements ClaudeContentBlockDto {
  const ClaudeToolUseContentBlockDto({@JsonKey(fromJson: _stringOrNull) required this.id, @JsonKey(fromJson: _stringOrNull) required this.name, required this.input,  String? $type}): $type = $type ?? 'tool_use';
  factory ClaudeToolUseContentBlockDto.fromJson(Map<String, dynamic> json) => _$ClaudeToolUseContentBlockDtoFromJson(json);

@JsonKey(fromJson: _stringOrNull) final  String? id;
@JsonKey(fromJson: _stringOrNull) final  String? name;
 final  Object? input;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of ClaudeContentBlockDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClaudeToolUseContentBlockDtoCopyWith<ClaudeToolUseContentBlockDto> get copyWith => _$ClaudeToolUseContentBlockDtoCopyWithImpl<ClaudeToolUseContentBlockDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClaudeToolUseContentBlockDto&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other.input, input));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,const DeepCollectionEquality().hash(input));



}

/// @nodoc
abstract mixin class $ClaudeToolUseContentBlockDtoCopyWith<$Res> implements $ClaudeContentBlockDtoCopyWith<$Res> {
  factory $ClaudeToolUseContentBlockDtoCopyWith(ClaudeToolUseContentBlockDto value, $Res Function(ClaudeToolUseContentBlockDto) _then) = _$ClaudeToolUseContentBlockDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _stringOrNull) String? id,@JsonKey(fromJson: _stringOrNull) String? name, Object? input
});




}
/// @nodoc
class _$ClaudeToolUseContentBlockDtoCopyWithImpl<$Res>
    implements $ClaudeToolUseContentBlockDtoCopyWith<$Res> {
  _$ClaudeToolUseContentBlockDtoCopyWithImpl(this._self, this._then);

  final ClaudeToolUseContentBlockDto _self;
  final $Res Function(ClaudeToolUseContentBlockDto) _then;

/// Create a copy of ClaudeContentBlockDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? name = freezed,Object? input = freezed,}) {
  return _then(ClaudeToolUseContentBlockDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,input: freezed == input ? _self.input : input ,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class ClaudeToolResultContentBlockDto implements ClaudeContentBlockDto {
  const ClaudeToolResultContentBlockDto({@JsonKey(name: "tool_use_id", fromJson: _stringOrNull) required this.toolUseId, required this.content, @JsonKey(name: "is_error", fromJson: _boolOrNull) required this.isError,  String? $type}): $type = $type ?? 'tool_result';
  factory ClaudeToolResultContentBlockDto.fromJson(Map<String, dynamic> json) => _$ClaudeToolResultContentBlockDtoFromJson(json);

@JsonKey(name: "tool_use_id", fromJson: _stringOrNull) final  String? toolUseId;
 final  Object? content;
@JsonKey(name: "is_error", fromJson: _boolOrNull) final  bool? isError;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of ClaudeContentBlockDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClaudeToolResultContentBlockDtoCopyWith<ClaudeToolResultContentBlockDto> get copyWith => _$ClaudeToolResultContentBlockDtoCopyWithImpl<ClaudeToolResultContentBlockDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClaudeToolResultContentBlockDto&&(identical(other.toolUseId, toolUseId) || other.toolUseId == toolUseId)&&const DeepCollectionEquality().equals(other.content, content)&&(identical(other.isError, isError) || other.isError == isError));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,toolUseId,const DeepCollectionEquality().hash(content),isError);



}

/// @nodoc
abstract mixin class $ClaudeToolResultContentBlockDtoCopyWith<$Res> implements $ClaudeContentBlockDtoCopyWith<$Res> {
  factory $ClaudeToolResultContentBlockDtoCopyWith(ClaudeToolResultContentBlockDto value, $Res Function(ClaudeToolResultContentBlockDto) _then) = _$ClaudeToolResultContentBlockDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: "tool_use_id", fromJson: _stringOrNull) String? toolUseId, Object? content,@JsonKey(name: "is_error", fromJson: _boolOrNull) bool? isError
});




}
/// @nodoc
class _$ClaudeToolResultContentBlockDtoCopyWithImpl<$Res>
    implements $ClaudeToolResultContentBlockDtoCopyWith<$Res> {
  _$ClaudeToolResultContentBlockDtoCopyWithImpl(this._self, this._then);

  final ClaudeToolResultContentBlockDto _self;
  final $Res Function(ClaudeToolResultContentBlockDto) _then;

/// Create a copy of ClaudeContentBlockDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? toolUseId = freezed,Object? content = freezed,Object? isError = freezed,}) {
  return _then(ClaudeToolResultContentBlockDto(
toolUseId: freezed == toolUseId ? _self.toolUseId : toolUseId // ignore: cast_nullable_to_non_nullable
as String?,content: freezed == content ? _self.content : content ,isError: freezed == isError ? _self.isError : isError // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class ClaudeImageContentBlockDto implements ClaudeContentBlockDto {
  const ClaudeImageContentBlockDto({@JsonKey(fromJson: _imageSourceOrNull) required this.source,  String? $type}): $type = $type ?? 'image';
  factory ClaudeImageContentBlockDto.fromJson(Map<String, dynamic> json) => _$ClaudeImageContentBlockDtoFromJson(json);

@JsonKey(fromJson: _imageSourceOrNull) final  ClaudeImageSourceDto? source;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of ClaudeContentBlockDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClaudeImageContentBlockDtoCopyWith<ClaudeImageContentBlockDto> get copyWith => _$ClaudeImageContentBlockDtoCopyWithImpl<ClaudeImageContentBlockDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClaudeImageContentBlockDto&&(identical(other.source, source) || other.source == source));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,source);



}

/// @nodoc
abstract mixin class $ClaudeImageContentBlockDtoCopyWith<$Res> implements $ClaudeContentBlockDtoCopyWith<$Res> {
  factory $ClaudeImageContentBlockDtoCopyWith(ClaudeImageContentBlockDto value, $Res Function(ClaudeImageContentBlockDto) _then) = _$ClaudeImageContentBlockDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _imageSourceOrNull) ClaudeImageSourceDto? source
});


$ClaudeImageSourceDtoCopyWith<$Res>? get source;

}
/// @nodoc
class _$ClaudeImageContentBlockDtoCopyWithImpl<$Res>
    implements $ClaudeImageContentBlockDtoCopyWith<$Res> {
  _$ClaudeImageContentBlockDtoCopyWithImpl(this._self, this._then);

  final ClaudeImageContentBlockDto _self;
  final $Res Function(ClaudeImageContentBlockDto) _then;

/// Create a copy of ClaudeContentBlockDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? source = freezed,}) {
  return _then(ClaudeImageContentBlockDto(
source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as ClaudeImageSourceDto?,
  ));
}

/// Create a copy of ClaudeContentBlockDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ClaudeImageSourceDtoCopyWith<$Res>? get source {
    if (_self.source == null) {
    return null;
  }

  return $ClaudeImageSourceDtoCopyWith<$Res>(_self.source!, (value) {
    return _then(_self.copyWith(source: value));
  });
}
}

/// @nodoc
@JsonSerializable(createToJson: false)

class ClaudeUnknownContentBlockDto implements ClaudeContentBlockDto {
  const ClaudeUnknownContentBlockDto({ String? $type}): $type = $type ?? 'unknown';
  factory ClaudeUnknownContentBlockDto.fromJson(Map<String, dynamic> json) => _$ClaudeUnknownContentBlockDtoFromJson(json);



@JsonKey(name: 'type')
final String $type;





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClaudeUnknownContentBlockDto);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;



}





/// @nodoc
mixin _$ClaudeImageSourceDto {

@JsonKey(fromJson: _stringOrNull) String? get type;@JsonKey(name: "media_type", fromJson: _stringOrNull) String? get mediaType;@JsonKey(fromJson: _stringOrNull) String? get data;
/// Create a copy of ClaudeImageSourceDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClaudeImageSourceDtoCopyWith<ClaudeImageSourceDto> get copyWith => _$ClaudeImageSourceDtoCopyWithImpl<ClaudeImageSourceDto>(this as ClaudeImageSourceDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClaudeImageSourceDto&&(identical(other.type, type) || other.type == type)&&(identical(other.mediaType, mediaType) || other.mediaType == mediaType)&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,mediaType,data);



}

/// @nodoc
abstract mixin class $ClaudeImageSourceDtoCopyWith<$Res>  {
  factory $ClaudeImageSourceDtoCopyWith(ClaudeImageSourceDto value, $Res Function(ClaudeImageSourceDto) _then) = _$ClaudeImageSourceDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _stringOrNull) String? type,@JsonKey(name: "media_type", fromJson: _stringOrNull) String? mediaType,@JsonKey(fromJson: _stringOrNull) String? data
});




}
/// @nodoc
class _$ClaudeImageSourceDtoCopyWithImpl<$Res>
    implements $ClaudeImageSourceDtoCopyWith<$Res> {
  _$ClaudeImageSourceDtoCopyWithImpl(this._self, this._then);

  final ClaudeImageSourceDto _self;
  final $Res Function(ClaudeImageSourceDto) _then;

/// Create a copy of ClaudeImageSourceDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = freezed,Object? mediaType = freezed,Object? data = freezed,}) {
  return _then(ClaudeImageSourceDto(
type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String?,mediaType: freezed == mediaType ? _self.mediaType : mediaType // ignore: cast_nullable_to_non_nullable
as String?,data: freezed == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _ClaudeImageSourceDto implements ClaudeImageSourceDto {
  const _ClaudeImageSourceDto({@JsonKey(fromJson: _stringOrNull) required this.type, @JsonKey(name: "media_type", fromJson: _stringOrNull) required this.mediaType, @JsonKey(fromJson: _stringOrNull) required this.data});
  factory _ClaudeImageSourceDto.fromJson(Map<String, dynamic> json) => _$ClaudeImageSourceDtoFromJson(json);

@override@JsonKey(fromJson: _stringOrNull) final  String? type;
@override@JsonKey(name: "media_type", fromJson: _stringOrNull) final  String? mediaType;
@override@JsonKey(fromJson: _stringOrNull) final  String? data;

/// Create a copy of ClaudeImageSourceDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClaudeImageSourceDtoCopyWith<_ClaudeImageSourceDto> get copyWith => __$ClaudeImageSourceDtoCopyWithImpl<_ClaudeImageSourceDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClaudeImageSourceDto&&(identical(other.type, type) || other.type == type)&&(identical(other.mediaType, mediaType) || other.mediaType == mediaType)&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,mediaType,data);



}

/// @nodoc
abstract mixin class _$ClaudeImageSourceDtoCopyWith<$Res> implements $ClaudeImageSourceDtoCopyWith<$Res> {
  factory _$ClaudeImageSourceDtoCopyWith(_ClaudeImageSourceDto value, $Res Function(_ClaudeImageSourceDto) _then) = __$ClaudeImageSourceDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _stringOrNull) String? type,@JsonKey(name: "media_type", fromJson: _stringOrNull) String? mediaType,@JsonKey(fromJson: _stringOrNull) String? data
});




}
/// @nodoc
class __$ClaudeImageSourceDtoCopyWithImpl<$Res>
    implements _$ClaudeImageSourceDtoCopyWith<$Res> {
  __$ClaudeImageSourceDtoCopyWithImpl(this._self, this._then);

  final _ClaudeImageSourceDto _self;
  final $Res Function(_ClaudeImageSourceDto) _then;

/// Create a copy of ClaudeImageSourceDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = freezed,Object? mediaType = freezed,Object? data = freezed,}) {
  return _then(_ClaudeImageSourceDto(
type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String?,mediaType: freezed == mediaType ? _self.mediaType : mediaType // ignore: cast_nullable_to_non_nullable
as String?,data: freezed == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
