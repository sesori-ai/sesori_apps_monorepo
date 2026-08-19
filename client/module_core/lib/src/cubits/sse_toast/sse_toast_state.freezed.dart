// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sse_toast_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SseToastState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SseToastState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SseToastState()';
}


}

/// @nodoc
class $SseToastStateCopyWith<$Res>  {
$SseToastStateCopyWith(SseToastState _, $Res Function(SseToastState) __);
}



/// @nodoc


class SseToastIdle implements SseToastState {
  const SseToastIdle();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SseToastIdle);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SseToastState.idle()';
}


}




/// @nodoc


class SseToastShow implements SseToastState {
  const SseToastShow({required this.sequence, required this.title, required this.message, required this.variant});
  

 final  int sequence;
 final  String? title;
 final  String message;
 final  SseToastVariant variant;

/// Create a copy of SseToastState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SseToastShowCopyWith<SseToastShow> get copyWith => _$SseToastShowCopyWithImpl<SseToastShow>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SseToastShow&&(identical(other.sequence, sequence) || other.sequence == sequence)&&(identical(other.title, title) || other.title == title)&&(identical(other.message, message) || other.message == message)&&(identical(other.variant, variant) || other.variant == variant));
}


@override
int get hashCode => Object.hash(runtimeType,sequence,title,message,variant);

@override
String toString() {
  return 'SseToastState.show(sequence: $sequence, title: $title, message: $message, variant: $variant)';
}


}

/// @nodoc
abstract mixin class $SseToastShowCopyWith<$Res> implements $SseToastStateCopyWith<$Res> {
  factory $SseToastShowCopyWith(SseToastShow value, $Res Function(SseToastShow) _then) = _$SseToastShowCopyWithImpl;
@useResult
$Res call({
 int sequence, String? title, String message, SseToastVariant variant
});




}
/// @nodoc
class _$SseToastShowCopyWithImpl<$Res>
    implements $SseToastShowCopyWith<$Res> {
  _$SseToastShowCopyWithImpl(this._self, this._then);

  final SseToastShow _self;
  final $Res Function(SseToastShow) _then;

/// Create a copy of SseToastState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sequence = null,Object? title = freezed,Object? message = null,Object? variant = null,}) {
  return _then(SseToastShow(
sequence: null == sequence ? _self.sequence : sequence // ignore: cast_nullable_to_non_nullable
as int,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,variant: null == variant ? _self.variant : variant // ignore: cast_nullable_to_non_nullable
as SseToastVariant,
  ));
}


}

// dart format on
