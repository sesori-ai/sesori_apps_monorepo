// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'codex_user_input_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CodexUserInputParamsDto {

 List<CodexUserInputQuestionDto> get questions;
/// Create a copy of CodexUserInputParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexUserInputParamsDtoCopyWith<CodexUserInputParamsDto> get copyWith => _$CodexUserInputParamsDtoCopyWithImpl<CodexUserInputParamsDto>(this as CodexUserInputParamsDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexUserInputParamsDto&&const DeepCollectionEquality().equals(other.questions, questions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(questions));

@override
String toString() {
  return 'CodexUserInputParamsDto(questions: $questions)';
}


}

/// @nodoc
abstract mixin class $CodexUserInputParamsDtoCopyWith<$Res>  {
  factory $CodexUserInputParamsDtoCopyWith(CodexUserInputParamsDto value, $Res Function(CodexUserInputParamsDto) _then) = _$CodexUserInputParamsDtoCopyWithImpl;
@useResult
$Res call({
 List<CodexUserInputQuestionDto> questions
});




}
/// @nodoc
class _$CodexUserInputParamsDtoCopyWithImpl<$Res>
    implements $CodexUserInputParamsDtoCopyWith<$Res> {
  _$CodexUserInputParamsDtoCopyWithImpl(this._self, this._then);

  final CodexUserInputParamsDto _self;
  final $Res Function(CodexUserInputParamsDto) _then;

/// Create a copy of CodexUserInputParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? questions = null,}) {
  return _then(CodexUserInputParamsDto(
questions: null == questions ? _self.questions : questions // ignore: cast_nullable_to_non_nullable
as List<CodexUserInputQuestionDto>,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CodexUserInputParamsDto implements CodexUserInputParamsDto {
  const _CodexUserInputParamsDto({required  List<CodexUserInputQuestionDto> questions}): _questions = questions;
  factory _CodexUserInputParamsDto.fromJson(Map<String, dynamic> json) => _$CodexUserInputParamsDtoFromJson(json);

 final  List<CodexUserInputQuestionDto> _questions;
@override List<CodexUserInputQuestionDto> get questions {
  if (_questions is EqualUnmodifiableListView) return _questions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_questions);
}


/// Create a copy of CodexUserInputParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexUserInputParamsDtoCopyWith<_CodexUserInputParamsDto> get copyWith => __$CodexUserInputParamsDtoCopyWithImpl<_CodexUserInputParamsDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexUserInputParamsDto&&const DeepCollectionEquality().equals(other._questions, _questions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_questions));

@override
String toString() {
  return 'CodexUserInputParamsDto(questions: $questions)';
}


}

/// @nodoc
abstract mixin class _$CodexUserInputParamsDtoCopyWith<$Res> implements $CodexUserInputParamsDtoCopyWith<$Res> {
  factory _$CodexUserInputParamsDtoCopyWith(_CodexUserInputParamsDto value, $Res Function(_CodexUserInputParamsDto) _then) = __$CodexUserInputParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 List<CodexUserInputQuestionDto> questions
});




}
/// @nodoc
class __$CodexUserInputParamsDtoCopyWithImpl<$Res>
    implements _$CodexUserInputParamsDtoCopyWith<$Res> {
  __$CodexUserInputParamsDtoCopyWithImpl(this._self, this._then);

  final _CodexUserInputParamsDto _self;
  final $Res Function(_CodexUserInputParamsDto) _then;

/// Create a copy of CodexUserInputParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? questions = null,}) {
  return _then(_CodexUserInputParamsDto(
questions: null == questions ? _self._questions : questions // ignore: cast_nullable_to_non_nullable
as List<CodexUserInputQuestionDto>,
  ));
}


}


/// @nodoc
mixin _$CodexUserInputQuestionDto {

 String get id; String get header; String get question; List<CodexUserInputOptionDto>? get options; bool get isOther;
/// Create a copy of CodexUserInputQuestionDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexUserInputQuestionDtoCopyWith<CodexUserInputQuestionDto> get copyWith => _$CodexUserInputQuestionDtoCopyWithImpl<CodexUserInputQuestionDto>(this as CodexUserInputQuestionDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexUserInputQuestionDto&&(identical(other.id, id) || other.id == id)&&(identical(other.header, header) || other.header == header)&&(identical(other.question, question) || other.question == question)&&const DeepCollectionEquality().equals(other.options, options)&&(identical(other.isOther, isOther) || other.isOther == isOther));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,header,question,const DeepCollectionEquality().hash(options),isOther);

@override
String toString() {
  return 'CodexUserInputQuestionDto(id: $id, header: $header, question: $question, options: $options, isOther: $isOther)';
}


}

/// @nodoc
abstract mixin class $CodexUserInputQuestionDtoCopyWith<$Res>  {
  factory $CodexUserInputQuestionDtoCopyWith(CodexUserInputQuestionDto value, $Res Function(CodexUserInputQuestionDto) _then) = _$CodexUserInputQuestionDtoCopyWithImpl;
@useResult
$Res call({
 String id, String header, String question, List<CodexUserInputOptionDto>? options, bool isOther
});




}
/// @nodoc
class _$CodexUserInputQuestionDtoCopyWithImpl<$Res>
    implements $CodexUserInputQuestionDtoCopyWith<$Res> {
  _$CodexUserInputQuestionDtoCopyWithImpl(this._self, this._then);

  final CodexUserInputQuestionDto _self;
  final $Res Function(CodexUserInputQuestionDto) _then;

/// Create a copy of CodexUserInputQuestionDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? header = null,Object? question = null,Object? options = freezed,Object? isOther = null,}) {
  return _then(CodexUserInputQuestionDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,header: null == header ? _self.header : header // ignore: cast_nullable_to_non_nullable
as String,question: null == question ? _self.question : question // ignore: cast_nullable_to_non_nullable
as String,options: freezed == options ? _self.options : options // ignore: cast_nullable_to_non_nullable
as List<CodexUserInputOptionDto>?,isOther: null == isOther ? _self.isOther : isOther // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CodexUserInputQuestionDto implements CodexUserInputQuestionDto {
  const _CodexUserInputQuestionDto({required this.id, required this.header, required this.question, required  List<CodexUserInputOptionDto>? options, this.isOther = false}): _options = options;
  factory _CodexUserInputQuestionDto.fromJson(Map<String, dynamic> json) => _$CodexUserInputQuestionDtoFromJson(json);

@override final  String id;
@override final  String header;
@override final  String question;
 final  List<CodexUserInputOptionDto>? _options;
@override List<CodexUserInputOptionDto>? get options {
  final value = _options;
  if (value == null) return null;
  if (_options is EqualUnmodifiableListView) return _options;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override@JsonKey() final  bool isOther;

/// Create a copy of CodexUserInputQuestionDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexUserInputQuestionDtoCopyWith<_CodexUserInputQuestionDto> get copyWith => __$CodexUserInputQuestionDtoCopyWithImpl<_CodexUserInputQuestionDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexUserInputQuestionDto&&(identical(other.id, id) || other.id == id)&&(identical(other.header, header) || other.header == header)&&(identical(other.question, question) || other.question == question)&&const DeepCollectionEquality().equals(other._options, _options)&&(identical(other.isOther, isOther) || other.isOther == isOther));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,header,question,const DeepCollectionEquality().hash(_options),isOther);

@override
String toString() {
  return 'CodexUserInputQuestionDto(id: $id, header: $header, question: $question, options: $options, isOther: $isOther)';
}


}

/// @nodoc
abstract mixin class _$CodexUserInputQuestionDtoCopyWith<$Res> implements $CodexUserInputQuestionDtoCopyWith<$Res> {
  factory _$CodexUserInputQuestionDtoCopyWith(_CodexUserInputQuestionDto value, $Res Function(_CodexUserInputQuestionDto) _then) = __$CodexUserInputQuestionDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String header, String question, List<CodexUserInputOptionDto>? options, bool isOther
});




}
/// @nodoc
class __$CodexUserInputQuestionDtoCopyWithImpl<$Res>
    implements _$CodexUserInputQuestionDtoCopyWith<$Res> {
  __$CodexUserInputQuestionDtoCopyWithImpl(this._self, this._then);

  final _CodexUserInputQuestionDto _self;
  final $Res Function(_CodexUserInputQuestionDto) _then;

/// Create a copy of CodexUserInputQuestionDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? header = null,Object? question = null,Object? options = freezed,Object? isOther = null,}) {
  return _then(_CodexUserInputQuestionDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,header: null == header ? _self.header : header // ignore: cast_nullable_to_non_nullable
as String,question: null == question ? _self.question : question // ignore: cast_nullable_to_non_nullable
as String,options: freezed == options ? _self._options : options // ignore: cast_nullable_to_non_nullable
as List<CodexUserInputOptionDto>?,isOther: null == isOther ? _self.isOther : isOther // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$CodexUserInputOptionDto {

 String get label; String get description;
/// Create a copy of CodexUserInputOptionDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexUserInputOptionDtoCopyWith<CodexUserInputOptionDto> get copyWith => _$CodexUserInputOptionDtoCopyWithImpl<CodexUserInputOptionDto>(this as CodexUserInputOptionDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexUserInputOptionDto&&(identical(other.label, label) || other.label == label)&&(identical(other.description, description) || other.description == description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,label,description);

@override
String toString() {
  return 'CodexUserInputOptionDto(label: $label, description: $description)';
}


}

/// @nodoc
abstract mixin class $CodexUserInputOptionDtoCopyWith<$Res>  {
  factory $CodexUserInputOptionDtoCopyWith(CodexUserInputOptionDto value, $Res Function(CodexUserInputOptionDto) _then) = _$CodexUserInputOptionDtoCopyWithImpl;
@useResult
$Res call({
 String label, String description
});




}
/// @nodoc
class _$CodexUserInputOptionDtoCopyWithImpl<$Res>
    implements $CodexUserInputOptionDtoCopyWith<$Res> {
  _$CodexUserInputOptionDtoCopyWithImpl(this._self, this._then);

  final CodexUserInputOptionDto _self;
  final $Res Function(CodexUserInputOptionDto) _then;

/// Create a copy of CodexUserInputOptionDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? label = null,Object? description = null,}) {
  return _then(CodexUserInputOptionDto(
label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CodexUserInputOptionDto implements CodexUserInputOptionDto {
  const _CodexUserInputOptionDto({required this.label, required this.description});
  factory _CodexUserInputOptionDto.fromJson(Map<String, dynamic> json) => _$CodexUserInputOptionDtoFromJson(json);

@override final  String label;
@override final  String description;

/// Create a copy of CodexUserInputOptionDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexUserInputOptionDtoCopyWith<_CodexUserInputOptionDto> get copyWith => __$CodexUserInputOptionDtoCopyWithImpl<_CodexUserInputOptionDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexUserInputOptionDto&&(identical(other.label, label) || other.label == label)&&(identical(other.description, description) || other.description == description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,label,description);

@override
String toString() {
  return 'CodexUserInputOptionDto(label: $label, description: $description)';
}


}

/// @nodoc
abstract mixin class _$CodexUserInputOptionDtoCopyWith<$Res> implements $CodexUserInputOptionDtoCopyWith<$Res> {
  factory _$CodexUserInputOptionDtoCopyWith(_CodexUserInputOptionDto value, $Res Function(_CodexUserInputOptionDto) _then) = __$CodexUserInputOptionDtoCopyWithImpl;
@override @useResult
$Res call({
 String label, String description
});




}
/// @nodoc
class __$CodexUserInputOptionDtoCopyWithImpl<$Res>
    implements _$CodexUserInputOptionDtoCopyWith<$Res> {
  __$CodexUserInputOptionDtoCopyWithImpl(this._self, this._then);

  final _CodexUserInputOptionDto _self;
  final $Res Function(_CodexUserInputOptionDto) _then;

/// Create a copy of CodexUserInputOptionDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? label = null,Object? description = null,}) {
  return _then(_CodexUserInputOptionDto(
label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$CodexQuestionItemParamsDto {

 String get threadId; CodexQuestionItemDto get item;
/// Create a copy of CodexQuestionItemParamsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexQuestionItemParamsDtoCopyWith<CodexQuestionItemParamsDto> get copyWith => _$CodexQuestionItemParamsDtoCopyWithImpl<CodexQuestionItemParamsDto>(this as CodexQuestionItemParamsDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexQuestionItemParamsDto&&(identical(other.threadId, threadId) || other.threadId == threadId)&&(identical(other.item, item) || other.item == item));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,threadId,item);

@override
String toString() {
  return 'CodexQuestionItemParamsDto(threadId: $threadId, item: $item)';
}


}

/// @nodoc
abstract mixin class $CodexQuestionItemParamsDtoCopyWith<$Res>  {
  factory $CodexQuestionItemParamsDtoCopyWith(CodexQuestionItemParamsDto value, $Res Function(CodexQuestionItemParamsDto) _then) = _$CodexQuestionItemParamsDtoCopyWithImpl;
@useResult
$Res call({
 String threadId, CodexQuestionItemDto item
});


$CodexQuestionItemDtoCopyWith<$Res> get item;

}
/// @nodoc
class _$CodexQuestionItemParamsDtoCopyWithImpl<$Res>
    implements $CodexQuestionItemParamsDtoCopyWith<$Res> {
  _$CodexQuestionItemParamsDtoCopyWithImpl(this._self, this._then);

  final CodexQuestionItemParamsDto _self;
  final $Res Function(CodexQuestionItemParamsDto) _then;

/// Create a copy of CodexQuestionItemParamsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? threadId = null,Object? item = null,}) {
  return _then(CodexQuestionItemParamsDto(
threadId: null == threadId ? _self.threadId : threadId // ignore: cast_nullable_to_non_nullable
as String,item: null == item ? _self.item : item // ignore: cast_nullable_to_non_nullable
as CodexQuestionItemDto,
  ));
}
/// Create a copy of CodexQuestionItemParamsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexQuestionItemDtoCopyWith<$Res> get item {
  
  return $CodexQuestionItemDtoCopyWith<$Res>(_self.item, (value) {
    return _then(_self.copyWith(item: value));
  });
}
}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CodexQuestionItemParamsDto implements CodexQuestionItemParamsDto {
  const _CodexQuestionItemParamsDto({required this.threadId, required this.item});
  factory _CodexQuestionItemParamsDto.fromJson(Map<String, dynamic> json) => _$CodexQuestionItemParamsDtoFromJson(json);

@override final  String threadId;
@override final  CodexQuestionItemDto item;

/// Create a copy of CodexQuestionItemParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexQuestionItemParamsDtoCopyWith<_CodexQuestionItemParamsDto> get copyWith => __$CodexQuestionItemParamsDtoCopyWithImpl<_CodexQuestionItemParamsDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexQuestionItemParamsDto&&(identical(other.threadId, threadId) || other.threadId == threadId)&&(identical(other.item, item) || other.item == item));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,threadId,item);

@override
String toString() {
  return 'CodexQuestionItemParamsDto(threadId: $threadId, item: $item)';
}


}

/// @nodoc
abstract mixin class _$CodexQuestionItemParamsDtoCopyWith<$Res> implements $CodexQuestionItemParamsDtoCopyWith<$Res> {
  factory _$CodexQuestionItemParamsDtoCopyWith(_CodexQuestionItemParamsDto value, $Res Function(_CodexQuestionItemParamsDto) _then) = __$CodexQuestionItemParamsDtoCopyWithImpl;
@override @useResult
$Res call({
 String threadId, CodexQuestionItemDto item
});


@override $CodexQuestionItemDtoCopyWith<$Res> get item;

}
/// @nodoc
class __$CodexQuestionItemParamsDtoCopyWithImpl<$Res>
    implements _$CodexQuestionItemParamsDtoCopyWith<$Res> {
  __$CodexQuestionItemParamsDtoCopyWithImpl(this._self, this._then);

  final _CodexQuestionItemParamsDto _self;
  final $Res Function(_CodexQuestionItemParamsDto) _then;

/// Create a copy of CodexQuestionItemParamsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? threadId = null,Object? item = null,}) {
  return _then(_CodexQuestionItemParamsDto(
threadId: null == threadId ? _self.threadId : threadId // ignore: cast_nullable_to_non_nullable
as String,item: null == item ? _self.item : item // ignore: cast_nullable_to_non_nullable
as CodexQuestionItemDto,
  ));
}

/// Create a copy of CodexQuestionItemParamsDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexQuestionItemDtoCopyWith<$Res> get item {
  
  return $CodexQuestionItemDtoCopyWith<$Res>(_self.item, (value) {
    return _then(_self.copyWith(item: value));
  });
}
}

CodexQuestionItemDto _$CodexQuestionItemDtoFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'agentMessage':
          return CodexAgentQuestionItemDto.fromJson(
            json
          );
        
          default:
            return CodexUnknownQuestionItemDto.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$CodexQuestionItemDto {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexQuestionItemDto);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'CodexQuestionItemDto()';
}


}

/// @nodoc
class $CodexQuestionItemDtoCopyWith<$Res>  {
$CodexQuestionItemDtoCopyWith(CodexQuestionItemDto _, $Res Function(CodexQuestionItemDto) __);
}



/// @nodoc
@JsonSerializable(createToJson: false)

class CodexAgentQuestionItemDto implements CodexQuestionItemDto {
  const CodexAgentQuestionItemDto({required this.id, @JsonKey(unknownEnumValue: CodexAgentMessageDelivery.unknown) required this.delivery, required  List<CodexAsyncUserInputQuestionDto>? questions,  String? $type}): _questions = questions,$type = $type ?? 'agentMessage';
  factory CodexAgentQuestionItemDto.fromJson(Map<String, dynamic> json) => _$CodexAgentQuestionItemDtoFromJson(json);

 final  String id;
@JsonKey(unknownEnumValue: CodexAgentMessageDelivery.unknown) final  CodexAgentMessageDelivery? delivery;
 final  List<CodexAsyncUserInputQuestionDto>? _questions;
 List<CodexAsyncUserInputQuestionDto>? get questions {
  final value = _questions;
  if (value == null) return null;
  if (_questions is EqualUnmodifiableListView) return _questions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}


@JsonKey(name: 'type')
final String $type;


/// Create a copy of CodexQuestionItemDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexAgentQuestionItemDtoCopyWith<CodexAgentQuestionItemDto> get copyWith => _$CodexAgentQuestionItemDtoCopyWithImpl<CodexAgentQuestionItemDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexAgentQuestionItemDto&&(identical(other.id, id) || other.id == id)&&(identical(other.delivery, delivery) || other.delivery == delivery)&&const DeepCollectionEquality().equals(other._questions, _questions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,delivery,const DeepCollectionEquality().hash(_questions));

@override
String toString() {
  return 'CodexQuestionItemDto.agentMessage(id: $id, delivery: $delivery, questions: $questions)';
}


}

/// @nodoc
abstract mixin class $CodexAgentQuestionItemDtoCopyWith<$Res> implements $CodexQuestionItemDtoCopyWith<$Res> {
  factory $CodexAgentQuestionItemDtoCopyWith(CodexAgentQuestionItemDto value, $Res Function(CodexAgentQuestionItemDto) _then) = _$CodexAgentQuestionItemDtoCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(unknownEnumValue: CodexAgentMessageDelivery.unknown) CodexAgentMessageDelivery? delivery, List<CodexAsyncUserInputQuestionDto>? questions
});




}
/// @nodoc
class _$CodexAgentQuestionItemDtoCopyWithImpl<$Res>
    implements $CodexAgentQuestionItemDtoCopyWith<$Res> {
  _$CodexAgentQuestionItemDtoCopyWithImpl(this._self, this._then);

  final CodexAgentQuestionItemDto _self;
  final $Res Function(CodexAgentQuestionItemDto) _then;

/// Create a copy of CodexQuestionItemDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? id = null,Object? delivery = freezed,Object? questions = freezed,}) {
  return _then(CodexAgentQuestionItemDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,delivery: freezed == delivery ? _self.delivery : delivery // ignore: cast_nullable_to_non_nullable
as CodexAgentMessageDelivery?,questions: freezed == questions ? _self._questions : questions // ignore: cast_nullable_to_non_nullable
as List<CodexAsyncUserInputQuestionDto>?,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class CodexUnknownQuestionItemDto implements CodexQuestionItemDto {
  const CodexUnknownQuestionItemDto({ String? $type}): $type = $type ?? 'unknown';
  factory CodexUnknownQuestionItemDto.fromJson(Map<String, dynamic> json) => _$CodexUnknownQuestionItemDtoFromJson(json);



@JsonKey(name: 'type')
final String $type;





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexUnknownQuestionItemDto);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'CodexQuestionItemDto.unknown()';
}


}





/// @nodoc
mixin _$CodexAsyncUserInputQuestionDto {

 String get title; List<String>? get options;
/// Create a copy of CodexAsyncUserInputQuestionDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexAsyncUserInputQuestionDtoCopyWith<CodexAsyncUserInputQuestionDto> get copyWith => _$CodexAsyncUserInputQuestionDtoCopyWithImpl<CodexAsyncUserInputQuestionDto>(this as CodexAsyncUserInputQuestionDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexAsyncUserInputQuestionDto&&(identical(other.title, title) || other.title == title)&&const DeepCollectionEquality().equals(other.options, options));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title,const DeepCollectionEquality().hash(options));

@override
String toString() {
  return 'CodexAsyncUserInputQuestionDto(title: $title, options: $options)';
}


}

/// @nodoc
abstract mixin class $CodexAsyncUserInputQuestionDtoCopyWith<$Res>  {
  factory $CodexAsyncUserInputQuestionDtoCopyWith(CodexAsyncUserInputQuestionDto value, $Res Function(CodexAsyncUserInputQuestionDto) _then) = _$CodexAsyncUserInputQuestionDtoCopyWithImpl;
@useResult
$Res call({
 String title, List<String>? options
});




}
/// @nodoc
class _$CodexAsyncUserInputQuestionDtoCopyWithImpl<$Res>
    implements $CodexAsyncUserInputQuestionDtoCopyWith<$Res> {
  _$CodexAsyncUserInputQuestionDtoCopyWithImpl(this._self, this._then);

  final CodexAsyncUserInputQuestionDto _self;
  final $Res Function(CodexAsyncUserInputQuestionDto) _then;

/// Create a copy of CodexAsyncUserInputQuestionDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? title = null,Object? options = freezed,}) {
  return _then(CodexAsyncUserInputQuestionDto(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,options: freezed == options ? _self.options : options // ignore: cast_nullable_to_non_nullable
as List<String>?,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CodexAsyncUserInputQuestionDto implements CodexAsyncUserInputQuestionDto {
  const _CodexAsyncUserInputQuestionDto({required this.title, required  List<String>? options}): _options = options;
  factory _CodexAsyncUserInputQuestionDto.fromJson(Map<String, dynamic> json) => _$CodexAsyncUserInputQuestionDtoFromJson(json);

@override final  String title;
 final  List<String>? _options;
@override List<String>? get options {
  final value = _options;
  if (value == null) return null;
  if (_options is EqualUnmodifiableListView) return _options;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}


/// Create a copy of CodexAsyncUserInputQuestionDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexAsyncUserInputQuestionDtoCopyWith<_CodexAsyncUserInputQuestionDto> get copyWith => __$CodexAsyncUserInputQuestionDtoCopyWithImpl<_CodexAsyncUserInputQuestionDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexAsyncUserInputQuestionDto&&(identical(other.title, title) || other.title == title)&&const DeepCollectionEquality().equals(other._options, _options));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title,const DeepCollectionEquality().hash(_options));

@override
String toString() {
  return 'CodexAsyncUserInputQuestionDto(title: $title, options: $options)';
}


}

/// @nodoc
abstract mixin class _$CodexAsyncUserInputQuestionDtoCopyWith<$Res> implements $CodexAsyncUserInputQuestionDtoCopyWith<$Res> {
  factory _$CodexAsyncUserInputQuestionDtoCopyWith(_CodexAsyncUserInputQuestionDto value, $Res Function(_CodexAsyncUserInputQuestionDto) _then) = __$CodexAsyncUserInputQuestionDtoCopyWithImpl;
@override @useResult
$Res call({
 String title, List<String>? options
});




}
/// @nodoc
class __$CodexAsyncUserInputQuestionDtoCopyWithImpl<$Res>
    implements _$CodexAsyncUserInputQuestionDtoCopyWith<$Res> {
  __$CodexAsyncUserInputQuestionDtoCopyWithImpl(this._self, this._then);

  final _CodexAsyncUserInputQuestionDto _self;
  final $Res Function(_CodexAsyncUserInputQuestionDto) _then;

/// Create a copy of CodexAsyncUserInputQuestionDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? title = null,Object? options = freezed,}) {
  return _then(_CodexAsyncUserInputQuestionDto(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,options: freezed == options ? _self._options : options // ignore: cast_nullable_to_non_nullable
as List<String>?,
  ));
}


}

// dart format on
