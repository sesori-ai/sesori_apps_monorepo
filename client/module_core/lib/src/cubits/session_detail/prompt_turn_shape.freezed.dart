// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'prompt_turn_shape.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PromptTurnShape {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PromptTurnShape);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'PromptTurnShape()';
}


}

/// @nodoc
class $PromptTurnShapeCopyWith<$Res>  {
$PromptTurnShapeCopyWith(PromptTurnShape _, $Res Function(PromptTurnShape) __);
}



/// @nodoc


class InvocationPromptTurnShape implements PromptTurnShape {
  const InvocationPromptTurnShape({required this.name, required this.source, required this.arguments});
  

 final  String name;
 final  CommandSource source;
 final  String? arguments;

/// Create a copy of PromptTurnShape
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InvocationPromptTurnShapeCopyWith<InvocationPromptTurnShape> get copyWith => _$InvocationPromptTurnShapeCopyWithImpl<InvocationPromptTurnShape>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is InvocationPromptTurnShape&&(identical(other.name, name) || other.name == name)&&(identical(other.source, source) || other.source == source)&&(identical(other.arguments, arguments) || other.arguments == arguments));
}


@override
int get hashCode {
    return Object.hash(runtimeType,name,source,arguments);
}

@override
String toString() {
    return 'PromptTurnShape.invocation(name: $name, source: $source, arguments: $arguments)';
}


}

/// @nodoc
abstract mixin class $InvocationPromptTurnShapeCopyWith<$Res> implements $PromptTurnShapeCopyWith<$Res> {
  factory $InvocationPromptTurnShapeCopyWith(InvocationPromptTurnShape value, $Res Function(InvocationPromptTurnShape) _then) = _$InvocationPromptTurnShapeCopyWithImpl;
@useResult
$Res call({
 String name, CommandSource source, String? arguments
});




}
/// @nodoc
class _$InvocationPromptTurnShapeCopyWithImpl<$Res>
    implements $InvocationPromptTurnShapeCopyWith<$Res> {
  _$InvocationPromptTurnShapeCopyWithImpl(this._self, this._then);

  final InvocationPromptTurnShape _self;
  final $Res Function(InvocationPromptTurnShape) _then;

/// Create a copy of PromptTurnShape
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? name = null,Object? source = null,Object? arguments = freezed,}) {
  return _then(InvocationPromptTurnShape(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as CommandSource,arguments: freezed == arguments ? _self.arguments : arguments // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc


class BubblePromptTurnShape implements PromptTurnShape {
  const BubblePromptTurnShape();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is BubblePromptTurnShape);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'PromptTurnShape.bubble()';
}


}




/// @nodoc
mixin _$PromptTurnShapes {

/// The launch's first message, while the state shows it.
 PromptTurnShape get launch;/// Confirmed user messages, by message id.
 Map<String, InvocationPromptTurnShape> get messages;/// Prompts the transcript does not hold yet, by prompt id: local
/// submissions, launch follow-ups and bridge-queued prompts.
 Map<String, InvocationPromptTurnShape> get prompts;
/// Create a copy of PromptTurnShapes
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PromptTurnShapesCopyWith<PromptTurnShapes> get copyWith => _$PromptTurnShapesCopyWithImpl<PromptTurnShapes>(this as PromptTurnShapes, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as PromptTurnShapes;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PromptTurnShapes&&(identical(other.launch, _this.launch) || other.launch == _this.launch)&&const DeepCollectionEquality().equals(other.messages, _this.messages)&&const DeepCollectionEquality().equals(other.prompts, _this.prompts));
}


@override
int get hashCode {
  final _this = this as PromptTurnShapes;
  return Object.hash(runtimeType,_this.launch,const DeepCollectionEquality().hash(_this.messages),const DeepCollectionEquality().hash(_this.prompts));
}

@override
String toString() {
  final _this = this as PromptTurnShapes;
  return 'PromptTurnShapes(launch: ${_this.launch}, messages: ${_this.messages}, prompts: ${_this.prompts})';
}


}

/// @nodoc
abstract mixin class $PromptTurnShapesCopyWith<$Res>  {
  factory $PromptTurnShapesCopyWith(PromptTurnShapes value, $Res Function(PromptTurnShapes) _then) = _$PromptTurnShapesCopyWithImpl;
@useResult
$Res call({
 PromptTurnShape launch, Map<String, InvocationPromptTurnShape> messages, Map<String, InvocationPromptTurnShape> prompts
});


$PromptTurnShapeCopyWith<$Res> get launch;

}
/// @nodoc
class _$PromptTurnShapesCopyWithImpl<$Res>
    implements $PromptTurnShapesCopyWith<$Res> {
  _$PromptTurnShapesCopyWithImpl(this._self, this._then);

  final PromptTurnShapes _self;
  final $Res Function(PromptTurnShapes) _then;

/// Create a copy of PromptTurnShapes
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? launch = null,Object? messages = null,Object? prompts = null,}) {
  return _then(PromptTurnShapes(
launch: null == launch ? _self.launch : launch // ignore: cast_nullable_to_non_nullable
as PromptTurnShape,messages: null == messages ? _self.messages : messages // ignore: cast_nullable_to_non_nullable
as Map<String, InvocationPromptTurnShape>,prompts: null == prompts ? _self.prompts : prompts // ignore: cast_nullable_to_non_nullable
as Map<String, InvocationPromptTurnShape>,
  ));
}
/// Create a copy of PromptTurnShapes
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PromptTurnShapeCopyWith<$Res> get launch {
  
  return $PromptTurnShapeCopyWith<$Res>(_self.launch, (value) {
    return _then(_self.copyWith(launch: value));
  });
}
}



/// @nodoc


class _PromptTurnShapes extends PromptTurnShapes {
  const _PromptTurnShapes({this.launch = const PromptTurnShape.bubble(),  Map<String, InvocationPromptTurnShape> messages = const {},  Map<String, InvocationPromptTurnShape> prompts = const {}}): _messages = messages,_prompts = prompts,super._();
  

/// The launch's first message, while the state shows it.
@override@JsonKey() final  PromptTurnShape launch;
/// Confirmed user messages, by message id.
 final  Map<String, InvocationPromptTurnShape> _messages;
/// Confirmed user messages, by message id.
@override@JsonKey() Map<String, InvocationPromptTurnShape> get messages {
  if (_messages is EqualUnmodifiableMapView) return _messages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_messages);
}

/// Prompts the transcript does not hold yet, by prompt id: local
/// submissions, launch follow-ups and bridge-queued prompts.
 final  Map<String, InvocationPromptTurnShape> _prompts;
/// Prompts the transcript does not hold yet, by prompt id: local
/// submissions, launch follow-ups and bridge-queued prompts.
@override@JsonKey() Map<String, InvocationPromptTurnShape> get prompts {
  if (_prompts is EqualUnmodifiableMapView) return _prompts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_prompts);
}


/// Create a copy of PromptTurnShapes
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PromptTurnShapesCopyWith<_PromptTurnShapes> get copyWith => __$PromptTurnShapesCopyWithImpl<_PromptTurnShapes>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PromptTurnShapes&&(identical(other.launch, launch) || other.launch == launch)&&const DeepCollectionEquality().equals(other.messages, _messages)&&const DeepCollectionEquality().equals(other.prompts, _prompts));
}


@override
int get hashCode {
    return Object.hash(runtimeType,launch,const DeepCollectionEquality().hash(_messages),const DeepCollectionEquality().hash(_prompts));
}

@override
String toString() {
    return 'PromptTurnShapes(launch: $launch, messages: $messages, prompts: $prompts)';
}


}

/// @nodoc
abstract mixin class _$PromptTurnShapesCopyWith<$Res> implements $PromptTurnShapesCopyWith<$Res> {
  factory _$PromptTurnShapesCopyWith(_PromptTurnShapes value, $Res Function(_PromptTurnShapes) _then) = __$PromptTurnShapesCopyWithImpl;
@override @useResult
$Res call({
 PromptTurnShape launch, Map<String, InvocationPromptTurnShape> messages, Map<String, InvocationPromptTurnShape> prompts
});


@override $PromptTurnShapeCopyWith<$Res> get launch;

}
/// @nodoc
class __$PromptTurnShapesCopyWithImpl<$Res>
    implements _$PromptTurnShapesCopyWith<$Res> {
  __$PromptTurnShapesCopyWithImpl(this._self, this._then);

  final _PromptTurnShapes _self;
  final $Res Function(_PromptTurnShapes) _then;

/// Create a copy of PromptTurnShapes
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? launch = null,Object? messages = null,Object? prompts = null,}) {
  return _then(_PromptTurnShapes(
launch: null == launch ? _self.launch : launch // ignore: cast_nullable_to_non_nullable
as PromptTurnShape,messages: null == messages ? _self._messages : messages // ignore: cast_nullable_to_non_nullable
as Map<String, InvocationPromptTurnShape>,prompts: null == prompts ? _self._prompts : prompts // ignore: cast_nullable_to_non_nullable
as Map<String, InvocationPromptTurnShape>,
  ));
}

/// Create a copy of PromptTurnShapes
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PromptTurnShapeCopyWith<$Res> get launch {
  
  return $PromptTurnShapeCopyWith<$Res>(_self.launch, (value) {
    return _then(_self.copyWith(launch: value));
  });
}
}

// dart format on
