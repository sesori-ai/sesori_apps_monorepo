// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'codex_thread_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CodexThreadEnvelopeDto {

 CodexThreadDto? get thread; String? get model; String? get modelProvider; String? get cwd;
/// Create a copy of CodexThreadEnvelopeDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexThreadEnvelopeDtoCopyWith<CodexThreadEnvelopeDto> get copyWith => _$CodexThreadEnvelopeDtoCopyWithImpl<CodexThreadEnvelopeDto>(this as CodexThreadEnvelopeDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexThreadEnvelopeDto&&(identical(other.thread, thread) || other.thread == thread)&&(identical(other.model, model) || other.model == model)&&(identical(other.modelProvider, modelProvider) || other.modelProvider == modelProvider)&&(identical(other.cwd, cwd) || other.cwd == cwd));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,thread,model,modelProvider,cwd);

@override
String toString() {
  return 'CodexThreadEnvelopeDto(thread: $thread, model: $model, modelProvider: $modelProvider, cwd: $cwd)';
}


}

/// @nodoc
abstract mixin class $CodexThreadEnvelopeDtoCopyWith<$Res>  {
  factory $CodexThreadEnvelopeDtoCopyWith(CodexThreadEnvelopeDto value, $Res Function(CodexThreadEnvelopeDto) _then) = _$CodexThreadEnvelopeDtoCopyWithImpl;
@useResult
$Res call({
 CodexThreadDto? thread, String? model, String? modelProvider, String? cwd
});


$CodexThreadDtoCopyWith<$Res>? get thread;

}
/// @nodoc
class _$CodexThreadEnvelopeDtoCopyWithImpl<$Res>
    implements $CodexThreadEnvelopeDtoCopyWith<$Res> {
  _$CodexThreadEnvelopeDtoCopyWithImpl(this._self, this._then);

  final CodexThreadEnvelopeDto _self;
  final $Res Function(CodexThreadEnvelopeDto) _then;

/// Create a copy of CodexThreadEnvelopeDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? thread = freezed,Object? model = freezed,Object? modelProvider = freezed,Object? cwd = freezed,}) {
  return _then(CodexThreadEnvelopeDto(
thread: freezed == thread ? _self.thread : thread // ignore: cast_nullable_to_non_nullable
as CodexThreadDto?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,modelProvider: freezed == modelProvider ? _self.modelProvider : modelProvider // ignore: cast_nullable_to_non_nullable
as String?,cwd: freezed == cwd ? _self.cwd : cwd // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of CodexThreadEnvelopeDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexThreadDtoCopyWith<$Res>? get thread {
    if (_self.thread == null) {
    return null;
  }

  return $CodexThreadDtoCopyWith<$Res>(_self.thread!, (value) {
    return _then(_self.copyWith(thread: value));
  });
}
}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CodexThreadEnvelopeDto implements CodexThreadEnvelopeDto {
  const _CodexThreadEnvelopeDto({required this.thread, required this.model, required this.modelProvider, required this.cwd});
  factory _CodexThreadEnvelopeDto.fromJson(Map<String, dynamic> json) => _$CodexThreadEnvelopeDtoFromJson(json);

@override final  CodexThreadDto? thread;
@override final  String? model;
@override final  String? modelProvider;
@override final  String? cwd;

/// Create a copy of CodexThreadEnvelopeDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexThreadEnvelopeDtoCopyWith<_CodexThreadEnvelopeDto> get copyWith => __$CodexThreadEnvelopeDtoCopyWithImpl<_CodexThreadEnvelopeDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexThreadEnvelopeDto&&(identical(other.thread, thread) || other.thread == thread)&&(identical(other.model, model) || other.model == model)&&(identical(other.modelProvider, modelProvider) || other.modelProvider == modelProvider)&&(identical(other.cwd, cwd) || other.cwd == cwd));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,thread,model,modelProvider,cwd);

@override
String toString() {
  return 'CodexThreadEnvelopeDto(thread: $thread, model: $model, modelProvider: $modelProvider, cwd: $cwd)';
}


}

/// @nodoc
abstract mixin class _$CodexThreadEnvelopeDtoCopyWith<$Res> implements $CodexThreadEnvelopeDtoCopyWith<$Res> {
  factory _$CodexThreadEnvelopeDtoCopyWith(_CodexThreadEnvelopeDto value, $Res Function(_CodexThreadEnvelopeDto) _then) = __$CodexThreadEnvelopeDtoCopyWithImpl;
@override @useResult
$Res call({
 CodexThreadDto? thread, String? model, String? modelProvider, String? cwd
});


@override $CodexThreadDtoCopyWith<$Res>? get thread;

}
/// @nodoc
class __$CodexThreadEnvelopeDtoCopyWithImpl<$Res>
    implements _$CodexThreadEnvelopeDtoCopyWith<$Res> {
  __$CodexThreadEnvelopeDtoCopyWithImpl(this._self, this._then);

  final _CodexThreadEnvelopeDto _self;
  final $Res Function(_CodexThreadEnvelopeDto) _then;

/// Create a copy of CodexThreadEnvelopeDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? thread = freezed,Object? model = freezed,Object? modelProvider = freezed,Object? cwd = freezed,}) {
  return _then(_CodexThreadEnvelopeDto(
thread: freezed == thread ? _self.thread : thread // ignore: cast_nullable_to_non_nullable
as CodexThreadDto?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,modelProvider: freezed == modelProvider ? _self.modelProvider : modelProvider // ignore: cast_nullable_to_non_nullable
as String?,cwd: freezed == cwd ? _self.cwd : cwd // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of CodexThreadEnvelopeDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodexThreadDtoCopyWith<$Res>? get thread {
    if (_self.thread == null) {
    return null;
  }

  return $CodexThreadDtoCopyWith<$Res>(_self.thread!, (value) {
    return _then(_self.copyWith(thread: value));
  });
}
}


/// @nodoc
mixin _$CodexThreadTurnDto {

 String? get id;@JsonKey(defaultValue: <CodexThreadItemDto>[]) List<CodexThreadItemDto> get items;
/// Create a copy of CodexThreadTurnDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexThreadTurnDtoCopyWith<CodexThreadTurnDto> get copyWith => _$CodexThreadTurnDtoCopyWithImpl<CodexThreadTurnDto>(this as CodexThreadTurnDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexThreadTurnDto&&(identical(other.id, id) || other.id == id)&&const DeepCollectionEquality().equals(other.items, items));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,const DeepCollectionEquality().hash(items));

@override
String toString() {
  return 'CodexThreadTurnDto(id: $id, items: $items)';
}


}

/// @nodoc
abstract mixin class $CodexThreadTurnDtoCopyWith<$Res>  {
  factory $CodexThreadTurnDtoCopyWith(CodexThreadTurnDto value, $Res Function(CodexThreadTurnDto) _then) = _$CodexThreadTurnDtoCopyWithImpl;
@useResult
$Res call({
 String? id,@JsonKey(defaultValue: <CodexThreadItemDto>[]) List<CodexThreadItemDto> items
});




}
/// @nodoc
class _$CodexThreadTurnDtoCopyWithImpl<$Res>
    implements $CodexThreadTurnDtoCopyWith<$Res> {
  _$CodexThreadTurnDtoCopyWithImpl(this._self, this._then);

  final CodexThreadTurnDto _self;
  final $Res Function(CodexThreadTurnDto) _then;

/// Create a copy of CodexThreadTurnDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? items = null,}) {
  return _then(CodexThreadTurnDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<CodexThreadItemDto>,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CodexThreadTurnDto implements CodexThreadTurnDto {
  const _CodexThreadTurnDto({required this.id, @JsonKey(defaultValue: <CodexThreadItemDto>[]) required  List<CodexThreadItemDto> items}): _items = items;
  factory _CodexThreadTurnDto.fromJson(Map<String, dynamic> json) => _$CodexThreadTurnDtoFromJson(json);

@override final  String? id;
 final  List<CodexThreadItemDto> _items;
@override@JsonKey(defaultValue: <CodexThreadItemDto>[]) List<CodexThreadItemDto> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}


/// Create a copy of CodexThreadTurnDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexThreadTurnDtoCopyWith<_CodexThreadTurnDto> get copyWith => __$CodexThreadTurnDtoCopyWithImpl<_CodexThreadTurnDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexThreadTurnDto&&(identical(other.id, id) || other.id == id)&&const DeepCollectionEquality().equals(other._items, _items));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,const DeepCollectionEquality().hash(_items));

@override
String toString() {
  return 'CodexThreadTurnDto(id: $id, items: $items)';
}


}

/// @nodoc
abstract mixin class _$CodexThreadTurnDtoCopyWith<$Res> implements $CodexThreadTurnDtoCopyWith<$Res> {
  factory _$CodexThreadTurnDtoCopyWith(_CodexThreadTurnDto value, $Res Function(_CodexThreadTurnDto) _then) = __$CodexThreadTurnDtoCopyWithImpl;
@override @useResult
$Res call({
 String? id,@JsonKey(defaultValue: <CodexThreadItemDto>[]) List<CodexThreadItemDto> items
});




}
/// @nodoc
class __$CodexThreadTurnDtoCopyWithImpl<$Res>
    implements _$CodexThreadTurnDtoCopyWith<$Res> {
  __$CodexThreadTurnDtoCopyWithImpl(this._self, this._then);

  final _CodexThreadTurnDto _self;
  final $Res Function(_CodexThreadTurnDto) _then;

/// Create a copy of CodexThreadTurnDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? items = null,}) {
  return _then(_CodexThreadTurnDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<CodexThreadItemDto>,
  ));
}


}

CodexThreadItemDto _$CodexThreadItemDtoFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'userMessage':
          return CodexThreadUserMessageItemDto.fromJson(
            json
          );
        
          default:
            return CodexThreadUnknownItemDto.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$CodexThreadItemDto {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexThreadItemDto);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'CodexThreadItemDto()';
}


}

/// @nodoc
class $CodexThreadItemDtoCopyWith<$Res>  {
$CodexThreadItemDtoCopyWith(CodexThreadItemDto _, $Res Function(CodexThreadItemDto) __);
}



/// @nodoc
@JsonSerializable(createToJson: false)

class CodexThreadUserMessageItemDto implements CodexThreadItemDto {
  const CodexThreadUserMessageItemDto({@JsonKey(defaultValue: <CodexThreadContentDto>[]) required  List<CodexThreadContentDto> content,  String? $type}): _content = content,$type = $type ?? 'userMessage';
  factory CodexThreadUserMessageItemDto.fromJson(Map<String, dynamic> json) => _$CodexThreadUserMessageItemDtoFromJson(json);

 final  List<CodexThreadContentDto> _content;
@JsonKey(defaultValue: <CodexThreadContentDto>[]) List<CodexThreadContentDto> get content {
  if (_content is EqualUnmodifiableListView) return _content;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_content);
}


@JsonKey(name: 'type')
final String $type;


/// Create a copy of CodexThreadItemDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexThreadUserMessageItemDtoCopyWith<CodexThreadUserMessageItemDto> get copyWith => _$CodexThreadUserMessageItemDtoCopyWithImpl<CodexThreadUserMessageItemDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexThreadUserMessageItemDto&&const DeepCollectionEquality().equals(other._content, _content));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_content));

@override
String toString() {
  return 'CodexThreadItemDto.userMessage(content: $content)';
}


}

/// @nodoc
abstract mixin class $CodexThreadUserMessageItemDtoCopyWith<$Res> implements $CodexThreadItemDtoCopyWith<$Res> {
  factory $CodexThreadUserMessageItemDtoCopyWith(CodexThreadUserMessageItemDto value, $Res Function(CodexThreadUserMessageItemDto) _then) = _$CodexThreadUserMessageItemDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(defaultValue: <CodexThreadContentDto>[]) List<CodexThreadContentDto> content
});




}
/// @nodoc
class _$CodexThreadUserMessageItemDtoCopyWithImpl<$Res>
    implements $CodexThreadUserMessageItemDtoCopyWith<$Res> {
  _$CodexThreadUserMessageItemDtoCopyWithImpl(this._self, this._then);

  final CodexThreadUserMessageItemDto _self;
  final $Res Function(CodexThreadUserMessageItemDto) _then;

/// Create a copy of CodexThreadItemDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? content = null,}) {
  return _then(CodexThreadUserMessageItemDto(
content: null == content ? _self._content : content // ignore: cast_nullable_to_non_nullable
as List<CodexThreadContentDto>,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class CodexThreadUnknownItemDto implements CodexThreadItemDto {
  const CodexThreadUnknownItemDto({ String? $type}): $type = $type ?? 'unknown';
  factory CodexThreadUnknownItemDto.fromJson(Map<String, dynamic> json) => _$CodexThreadUnknownItemDtoFromJson(json);



@JsonKey(name: 'type')
final String $type;





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexThreadUnknownItemDto);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'CodexThreadItemDto.unknown()';
}


}




CodexThreadContentDto _$CodexThreadContentDtoFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'text':
          return CodexThreadTextContentDto.fromJson(
            json
          );
        
          default:
            return CodexThreadUnknownContentDto.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$CodexThreadContentDto {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexThreadContentDto);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'CodexThreadContentDto()';
}


}

/// @nodoc
class $CodexThreadContentDtoCopyWith<$Res>  {
$CodexThreadContentDtoCopyWith(CodexThreadContentDto _, $Res Function(CodexThreadContentDto) __);
}



/// @nodoc
@JsonSerializable(createToJson: false)

class CodexThreadTextContentDto implements CodexThreadContentDto {
  const CodexThreadTextContentDto({required this.text,  String? $type}): $type = $type ?? 'text';
  factory CodexThreadTextContentDto.fromJson(Map<String, dynamic> json) => _$CodexThreadTextContentDtoFromJson(json);

 final  String text;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of CodexThreadContentDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexThreadTextContentDtoCopyWith<CodexThreadTextContentDto> get copyWith => _$CodexThreadTextContentDtoCopyWithImpl<CodexThreadTextContentDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexThreadTextContentDto&&(identical(other.text, text) || other.text == text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,text);

@override
String toString() {
  return 'CodexThreadContentDto.text(text: $text)';
}


}

/// @nodoc
abstract mixin class $CodexThreadTextContentDtoCopyWith<$Res> implements $CodexThreadContentDtoCopyWith<$Res> {
  factory $CodexThreadTextContentDtoCopyWith(CodexThreadTextContentDto value, $Res Function(CodexThreadTextContentDto) _then) = _$CodexThreadTextContentDtoCopyWithImpl;
@useResult
$Res call({
 String text
});




}
/// @nodoc
class _$CodexThreadTextContentDtoCopyWithImpl<$Res>
    implements $CodexThreadTextContentDtoCopyWith<$Res> {
  _$CodexThreadTextContentDtoCopyWithImpl(this._self, this._then);

  final CodexThreadTextContentDto _self;
  final $Res Function(CodexThreadTextContentDto) _then;

/// Create a copy of CodexThreadContentDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? text = null,}) {
  return _then(CodexThreadTextContentDto(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class CodexThreadUnknownContentDto implements CodexThreadContentDto {
  const CodexThreadUnknownContentDto({ String? $type}): $type = $type ?? 'unknown';
  factory CodexThreadUnknownContentDto.fromJson(Map<String, dynamic> json) => _$CodexThreadUnknownContentDtoFromJson(json);



@JsonKey(name: 'type')
final String $type;





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexThreadUnknownContentDto);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'CodexThreadContentDto.unknown()';
}


}





/// @nodoc
mixin _$CodexThreadDto {

 String? get id; String? get name; String? get cwd; num? get createdAt; num? get updatedAt; String? get modelProvider; String? get parentThreadId; String? get agentNickname; String? get agentRole;@JsonKey(unknownEnumValue: CodexThreadSource.unknown) CodexThreadSource? get threadSource;@JsonKey(defaultValue: <CodexThreadTurnDto>[]) List<CodexThreadTurnDto> get turns;
/// Create a copy of CodexThreadDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexThreadDtoCopyWith<CodexThreadDto> get copyWith => _$CodexThreadDtoCopyWithImpl<CodexThreadDto>(this as CodexThreadDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexThreadDto&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.cwd, cwd) || other.cwd == cwd)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.modelProvider, modelProvider) || other.modelProvider == modelProvider)&&(identical(other.parentThreadId, parentThreadId) || other.parentThreadId == parentThreadId)&&(identical(other.agentNickname, agentNickname) || other.agentNickname == agentNickname)&&(identical(other.agentRole, agentRole) || other.agentRole == agentRole)&&(identical(other.threadSource, threadSource) || other.threadSource == threadSource)&&const DeepCollectionEquality().equals(other.turns, turns));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,cwd,createdAt,updatedAt,modelProvider,parentThreadId,agentNickname,agentRole,threadSource,const DeepCollectionEquality().hash(turns));

@override
String toString() {
  return 'CodexThreadDto(id: $id, name: $name, cwd: $cwd, createdAt: $createdAt, updatedAt: $updatedAt, modelProvider: $modelProvider, parentThreadId: $parentThreadId, agentNickname: $agentNickname, agentRole: $agentRole, threadSource: $threadSource, turns: $turns)';
}


}

/// @nodoc
abstract mixin class $CodexThreadDtoCopyWith<$Res>  {
  factory $CodexThreadDtoCopyWith(CodexThreadDto value, $Res Function(CodexThreadDto) _then) = _$CodexThreadDtoCopyWithImpl;
@useResult
$Res call({
 String? id, String? name, String? cwd, num? createdAt, num? updatedAt, String? modelProvider, String? parentThreadId, String? agentNickname, String? agentRole,@JsonKey(unknownEnumValue: CodexThreadSource.unknown) CodexThreadSource? threadSource,@JsonKey(defaultValue: <CodexThreadTurnDto>[]) List<CodexThreadTurnDto> turns
});




}
/// @nodoc
class _$CodexThreadDtoCopyWithImpl<$Res>
    implements $CodexThreadDtoCopyWith<$Res> {
  _$CodexThreadDtoCopyWithImpl(this._self, this._then);

  final CodexThreadDto _self;
  final $Res Function(CodexThreadDto) _then;

/// Create a copy of CodexThreadDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? name = freezed,Object? cwd = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,Object? modelProvider = freezed,Object? parentThreadId = freezed,Object? agentNickname = freezed,Object? agentRole = freezed,Object? threadSource = freezed,Object? turns = null,}) {
  return _then(CodexThreadDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,cwd: freezed == cwd ? _self.cwd : cwd // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as num?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as num?,modelProvider: freezed == modelProvider ? _self.modelProvider : modelProvider // ignore: cast_nullable_to_non_nullable
as String?,parentThreadId: freezed == parentThreadId ? _self.parentThreadId : parentThreadId // ignore: cast_nullable_to_non_nullable
as String?,agentNickname: freezed == agentNickname ? _self.agentNickname : agentNickname // ignore: cast_nullable_to_non_nullable
as String?,agentRole: freezed == agentRole ? _self.agentRole : agentRole // ignore: cast_nullable_to_non_nullable
as String?,threadSource: freezed == threadSource ? _self.threadSource : threadSource // ignore: cast_nullable_to_non_nullable
as CodexThreadSource?,turns: null == turns ? _self.turns : turns // ignore: cast_nullable_to_non_nullable
as List<CodexThreadTurnDto>,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CodexThreadDto implements CodexThreadDto {
  const _CodexThreadDto({required this.id, required this.name, required this.cwd, required this.createdAt, required this.updatedAt, required this.modelProvider, required this.parentThreadId, required this.agentNickname, required this.agentRole, @JsonKey(unknownEnumValue: CodexThreadSource.unknown) required this.threadSource, @JsonKey(defaultValue: <CodexThreadTurnDto>[]) required  List<CodexThreadTurnDto> turns}): _turns = turns;
  factory _CodexThreadDto.fromJson(Map<String, dynamic> json) => _$CodexThreadDtoFromJson(json);

@override final  String? id;
@override final  String? name;
@override final  String? cwd;
@override final  num? createdAt;
@override final  num? updatedAt;
@override final  String? modelProvider;
@override final  String? parentThreadId;
@override final  String? agentNickname;
@override final  String? agentRole;
@override@JsonKey(unknownEnumValue: CodexThreadSource.unknown) final  CodexThreadSource? threadSource;
 final  List<CodexThreadTurnDto> _turns;
@override@JsonKey(defaultValue: <CodexThreadTurnDto>[]) List<CodexThreadTurnDto> get turns {
  if (_turns is EqualUnmodifiableListView) return _turns;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_turns);
}


/// Create a copy of CodexThreadDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexThreadDtoCopyWith<_CodexThreadDto> get copyWith => __$CodexThreadDtoCopyWithImpl<_CodexThreadDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexThreadDto&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.cwd, cwd) || other.cwd == cwd)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.modelProvider, modelProvider) || other.modelProvider == modelProvider)&&(identical(other.parentThreadId, parentThreadId) || other.parentThreadId == parentThreadId)&&(identical(other.agentNickname, agentNickname) || other.agentNickname == agentNickname)&&(identical(other.agentRole, agentRole) || other.agentRole == agentRole)&&(identical(other.threadSource, threadSource) || other.threadSource == threadSource)&&const DeepCollectionEquality().equals(other._turns, _turns));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,cwd,createdAt,updatedAt,modelProvider,parentThreadId,agentNickname,agentRole,threadSource,const DeepCollectionEquality().hash(_turns));

@override
String toString() {
  return 'CodexThreadDto(id: $id, name: $name, cwd: $cwd, createdAt: $createdAt, updatedAt: $updatedAt, modelProvider: $modelProvider, parentThreadId: $parentThreadId, agentNickname: $agentNickname, agentRole: $agentRole, threadSource: $threadSource, turns: $turns)';
}


}

/// @nodoc
abstract mixin class _$CodexThreadDtoCopyWith<$Res> implements $CodexThreadDtoCopyWith<$Res> {
  factory _$CodexThreadDtoCopyWith(_CodexThreadDto value, $Res Function(_CodexThreadDto) _then) = __$CodexThreadDtoCopyWithImpl;
@override @useResult
$Res call({
 String? id, String? name, String? cwd, num? createdAt, num? updatedAt, String? modelProvider, String? parentThreadId, String? agentNickname, String? agentRole,@JsonKey(unknownEnumValue: CodexThreadSource.unknown) CodexThreadSource? threadSource,@JsonKey(defaultValue: <CodexThreadTurnDto>[]) List<CodexThreadTurnDto> turns
});




}
/// @nodoc
class __$CodexThreadDtoCopyWithImpl<$Res>
    implements _$CodexThreadDtoCopyWith<$Res> {
  __$CodexThreadDtoCopyWithImpl(this._self, this._then);

  final _CodexThreadDto _self;
  final $Res Function(_CodexThreadDto) _then;

/// Create a copy of CodexThreadDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? name = freezed,Object? cwd = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,Object? modelProvider = freezed,Object? parentThreadId = freezed,Object? agentNickname = freezed,Object? agentRole = freezed,Object? threadSource = freezed,Object? turns = null,}) {
  return _then(_CodexThreadDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,cwd: freezed == cwd ? _self.cwd : cwd // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as num?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as num?,modelProvider: freezed == modelProvider ? _self.modelProvider : modelProvider // ignore: cast_nullable_to_non_nullable
as String?,parentThreadId: freezed == parentThreadId ? _self.parentThreadId : parentThreadId // ignore: cast_nullable_to_non_nullable
as String?,agentNickname: freezed == agentNickname ? _self.agentNickname : agentNickname // ignore: cast_nullable_to_non_nullable
as String?,agentRole: freezed == agentRole ? _self.agentRole : agentRole // ignore: cast_nullable_to_non_nullable
as String?,threadSource: freezed == threadSource ? _self.threadSource : threadSource // ignore: cast_nullable_to_non_nullable
as CodexThreadSource?,turns: null == turns ? _self._turns : turns // ignore: cast_nullable_to_non_nullable
as List<CodexThreadTurnDto>,
  ));
}


}

// dart format on
