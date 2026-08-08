// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'acp_tool_content_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
AcpToolContentDto _$AcpToolContentDtoFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'content':
          return AcpStandardToolContentDto.fromJson(
            json
          );
                case 'diff':
          return AcpDiffToolContentDto.fromJson(
            json
          );
                case 'terminal':
          return AcpTerminalToolContentDto.fromJson(
            json
          );
        
          default:
            return AcpUnknownToolContentDto.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$AcpToolContentDto {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AcpToolContentDto);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AcpToolContentDto()';
}


}

/// @nodoc
class $AcpToolContentDtoCopyWith<$Res>  {
$AcpToolContentDtoCopyWith(AcpToolContentDto _, $Res Function(AcpToolContentDto) __);
}



/// @nodoc
@JsonSerializable(createToJson: false)

class AcpStandardToolContentDto implements AcpToolContentDto {
  const AcpStandardToolContentDto({required this.content, final  String? $type}): $type = $type ?? 'content';
  factory AcpStandardToolContentDto.fromJson(Map<String, dynamic> json) => _$AcpStandardToolContentDtoFromJson(json);

 final  AcpContentBlockDto content;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of AcpToolContentDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AcpStandardToolContentDtoCopyWith<AcpStandardToolContentDto> get copyWith => _$AcpStandardToolContentDtoCopyWithImpl<AcpStandardToolContentDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AcpStandardToolContentDto&&(identical(other.content, content) || other.content == content));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,content);

@override
String toString() {
  return 'AcpToolContentDto.content(content: $content)';
}


}

/// @nodoc
abstract mixin class $AcpStandardToolContentDtoCopyWith<$Res> implements $AcpToolContentDtoCopyWith<$Res> {
  factory $AcpStandardToolContentDtoCopyWith(AcpStandardToolContentDto value, $Res Function(AcpStandardToolContentDto) _then) = _$AcpStandardToolContentDtoCopyWithImpl;
@useResult
$Res call({
 AcpContentBlockDto content
});


$AcpContentBlockDtoCopyWith<$Res> get content;

}
/// @nodoc
class _$AcpStandardToolContentDtoCopyWithImpl<$Res>
    implements $AcpStandardToolContentDtoCopyWith<$Res> {
  _$AcpStandardToolContentDtoCopyWithImpl(this._self, this._then);

  final AcpStandardToolContentDto _self;
  final $Res Function(AcpStandardToolContentDto) _then;

/// Create a copy of AcpToolContentDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? content = null,}) {
  return _then(AcpStandardToolContentDto(
content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as AcpContentBlockDto,
  ));
}

/// Create a copy of AcpToolContentDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AcpContentBlockDtoCopyWith<$Res> get content {
  
  return $AcpContentBlockDtoCopyWith<$Res>(_self.content, (value) {
    return _then(_self.copyWith(content: value));
  });
}
}

/// @nodoc
@JsonSerializable(createToJson: false)

class AcpDiffToolContentDto implements AcpToolContentDto {
  const AcpDiffToolContentDto({required this.path, required this.oldText, required this.newText, final  String? $type}): $type = $type ?? 'diff';
  factory AcpDiffToolContentDto.fromJson(Map<String, dynamic> json) => _$AcpDiffToolContentDtoFromJson(json);

 final  String path;
 final  String? oldText;
 final  String newText;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of AcpToolContentDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AcpDiffToolContentDtoCopyWith<AcpDiffToolContentDto> get copyWith => _$AcpDiffToolContentDtoCopyWithImpl<AcpDiffToolContentDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AcpDiffToolContentDto&&(identical(other.path, path) || other.path == path)&&(identical(other.oldText, oldText) || other.oldText == oldText)&&(identical(other.newText, newText) || other.newText == newText));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,path,oldText,newText);

@override
String toString() {
  return 'AcpToolContentDto.diff(path: $path, oldText: $oldText, newText: $newText)';
}


}

/// @nodoc
abstract mixin class $AcpDiffToolContentDtoCopyWith<$Res> implements $AcpToolContentDtoCopyWith<$Res> {
  factory $AcpDiffToolContentDtoCopyWith(AcpDiffToolContentDto value, $Res Function(AcpDiffToolContentDto) _then) = _$AcpDiffToolContentDtoCopyWithImpl;
@useResult
$Res call({
 String path, String? oldText, String newText
});




}
/// @nodoc
class _$AcpDiffToolContentDtoCopyWithImpl<$Res>
    implements $AcpDiffToolContentDtoCopyWith<$Res> {
  _$AcpDiffToolContentDtoCopyWithImpl(this._self, this._then);

  final AcpDiffToolContentDto _self;
  final $Res Function(AcpDiffToolContentDto) _then;

/// Create a copy of AcpToolContentDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? path = null,Object? oldText = freezed,Object? newText = null,}) {
  return _then(AcpDiffToolContentDto(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,oldText: freezed == oldText ? _self.oldText : oldText // ignore: cast_nullable_to_non_nullable
as String?,newText: null == newText ? _self.newText : newText // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class AcpTerminalToolContentDto implements AcpToolContentDto {
  const AcpTerminalToolContentDto({required this.terminalId, final  String? $type}): $type = $type ?? 'terminal';
  factory AcpTerminalToolContentDto.fromJson(Map<String, dynamic> json) => _$AcpTerminalToolContentDtoFromJson(json);

 final  String terminalId;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of AcpToolContentDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AcpTerminalToolContentDtoCopyWith<AcpTerminalToolContentDto> get copyWith => _$AcpTerminalToolContentDtoCopyWithImpl<AcpTerminalToolContentDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AcpTerminalToolContentDto&&(identical(other.terminalId, terminalId) || other.terminalId == terminalId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,terminalId);

@override
String toString() {
  return 'AcpToolContentDto.terminal(terminalId: $terminalId)';
}


}

/// @nodoc
abstract mixin class $AcpTerminalToolContentDtoCopyWith<$Res> implements $AcpToolContentDtoCopyWith<$Res> {
  factory $AcpTerminalToolContentDtoCopyWith(AcpTerminalToolContentDto value, $Res Function(AcpTerminalToolContentDto) _then) = _$AcpTerminalToolContentDtoCopyWithImpl;
@useResult
$Res call({
 String terminalId
});




}
/// @nodoc
class _$AcpTerminalToolContentDtoCopyWithImpl<$Res>
    implements $AcpTerminalToolContentDtoCopyWith<$Res> {
  _$AcpTerminalToolContentDtoCopyWithImpl(this._self, this._then);

  final AcpTerminalToolContentDto _self;
  final $Res Function(AcpTerminalToolContentDto) _then;

/// Create a copy of AcpToolContentDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? terminalId = null,}) {
  return _then(AcpTerminalToolContentDto(
terminalId: null == terminalId ? _self.terminalId : terminalId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class AcpUnknownToolContentDto implements AcpToolContentDto {
  const AcpUnknownToolContentDto({final  String? $type}): $type = $type ?? 'unknown';
  factory AcpUnknownToolContentDto.fromJson(Map<String, dynamic> json) => _$AcpUnknownToolContentDtoFromJson(json);



@JsonKey(name: 'type')
final String $type;





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AcpUnknownToolContentDto);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AcpToolContentDto.unknown()';
}


}




// dart format on
