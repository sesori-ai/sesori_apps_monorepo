// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'codex_turn_input_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CodexTurnInputDto {



  /// Serializes this CodexTurnInputDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexTurnInputDto);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'CodexTurnInputDto()';
}


}

/// @nodoc
class $CodexTurnInputDtoCopyWith<$Res>  {
$CodexTurnInputDtoCopyWith(CodexTurnInputDto _, $Res Function(CodexTurnInputDto) __);
}



/// @nodoc
@JsonSerializable(createFactory: false)

class CodexTurnTextInputDto implements CodexTurnInputDto {
  const CodexTurnTextInputDto({required this.text, @JsonKey(name: "text_elements") final  List<Object?> textElements = const <Object?>[], final  String? $type}): _textElements = textElements,$type = $type ?? 'text';
  

 final  String text;
 final  List<Object?> _textElements;
@JsonKey(name: "text_elements") List<Object?> get textElements {
  if (_textElements is EqualUnmodifiableListView) return _textElements;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_textElements);
}


@JsonKey(name: 'type')
final String $type;


/// Create a copy of CodexTurnInputDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexTurnTextInputDtoCopyWith<CodexTurnTextInputDto> get copyWith => _$CodexTurnTextInputDtoCopyWithImpl<CodexTurnTextInputDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CodexTurnTextInputDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexTurnTextInputDto&&(identical(other.text, text) || other.text == text)&&const DeepCollectionEquality().equals(other._textElements, _textElements));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,text,const DeepCollectionEquality().hash(_textElements));

@override
String toString() {
  return 'CodexTurnInputDto.text(text: $text, textElements: $textElements)';
}


}

/// @nodoc
abstract mixin class $CodexTurnTextInputDtoCopyWith<$Res> implements $CodexTurnInputDtoCopyWith<$Res> {
  factory $CodexTurnTextInputDtoCopyWith(CodexTurnTextInputDto value, $Res Function(CodexTurnTextInputDto) _then) = _$CodexTurnTextInputDtoCopyWithImpl;
@useResult
$Res call({
 String text,@JsonKey(name: "text_elements") List<Object?> textElements
});




}
/// @nodoc
class _$CodexTurnTextInputDtoCopyWithImpl<$Res>
    implements $CodexTurnTextInputDtoCopyWith<$Res> {
  _$CodexTurnTextInputDtoCopyWithImpl(this._self, this._then);

  final CodexTurnTextInputDto _self;
  final $Res Function(CodexTurnTextInputDto) _then;

/// Create a copy of CodexTurnInputDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? text = null,Object? textElements = null,}) {
  return _then(CodexTurnTextInputDto(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,textElements: null == textElements ? _self._textElements : textElements // ignore: cast_nullable_to_non_nullable
as List<Object?>,
  ));
}


}

/// @nodoc
@JsonSerializable(createFactory: false)

class CodexTurnLocalImageInputDto implements CodexTurnInputDto {
  const CodexTurnLocalImageInputDto({required this.path, final  String? $type}): $type = $type ?? 'localImage';
  

 final  String path;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of CodexTurnInputDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexTurnLocalImageInputDtoCopyWith<CodexTurnLocalImageInputDto> get copyWith => _$CodexTurnLocalImageInputDtoCopyWithImpl<CodexTurnLocalImageInputDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CodexTurnLocalImageInputDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexTurnLocalImageInputDto&&(identical(other.path, path) || other.path == path));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,path);

@override
String toString() {
  return 'CodexTurnInputDto.localImage(path: $path)';
}


}

/// @nodoc
abstract mixin class $CodexTurnLocalImageInputDtoCopyWith<$Res> implements $CodexTurnInputDtoCopyWith<$Res> {
  factory $CodexTurnLocalImageInputDtoCopyWith(CodexTurnLocalImageInputDto value, $Res Function(CodexTurnLocalImageInputDto) _then) = _$CodexTurnLocalImageInputDtoCopyWithImpl;
@useResult
$Res call({
 String path
});




}
/// @nodoc
class _$CodexTurnLocalImageInputDtoCopyWithImpl<$Res>
    implements $CodexTurnLocalImageInputDtoCopyWith<$Res> {
  _$CodexTurnLocalImageInputDtoCopyWithImpl(this._self, this._then);

  final CodexTurnLocalImageInputDto _self;
  final $Res Function(CodexTurnLocalImageInputDto) _then;

/// Create a copy of CodexTurnInputDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? path = null,}) {
  return _then(CodexTurnLocalImageInputDto(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable(createFactory: false)

class CodexTurnImageInputDto implements CodexTurnInputDto {
  const CodexTurnImageInputDto({required this.url, final  String? $type}): $type = $type ?? 'image';
  

 final  String url;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of CodexTurnInputDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexTurnImageInputDtoCopyWith<CodexTurnImageInputDto> get copyWith => _$CodexTurnImageInputDtoCopyWithImpl<CodexTurnImageInputDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CodexTurnImageInputDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexTurnImageInputDto&&(identical(other.url, url) || other.url == url));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,url);

@override
String toString() {
  return 'CodexTurnInputDto.image(url: $url)';
}


}

/// @nodoc
abstract mixin class $CodexTurnImageInputDtoCopyWith<$Res> implements $CodexTurnInputDtoCopyWith<$Res> {
  factory $CodexTurnImageInputDtoCopyWith(CodexTurnImageInputDto value, $Res Function(CodexTurnImageInputDto) _then) = _$CodexTurnImageInputDtoCopyWithImpl;
@useResult
$Res call({
 String url
});




}
/// @nodoc
class _$CodexTurnImageInputDtoCopyWithImpl<$Res>
    implements $CodexTurnImageInputDtoCopyWith<$Res> {
  _$CodexTurnImageInputDtoCopyWithImpl(this._self, this._then);

  final CodexTurnImageInputDto _self;
  final $Res Function(CodexTurnImageInputDto) _then;

/// Create a copy of CodexTurnInputDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? url = null,}) {
  return _then(CodexTurnImageInputDto(
url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
