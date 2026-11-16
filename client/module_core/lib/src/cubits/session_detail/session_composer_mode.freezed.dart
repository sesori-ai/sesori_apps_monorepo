// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_composer_mode.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SessionComposerMode {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionComposerMode);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'SessionComposerMode()';
}


}

/// @nodoc
class $SessionComposerModeCopyWith<$Res>  {
$SessionComposerModeCopyWith(SessionComposerMode _, $Res Function(SessionComposerMode) __);
}



/// @nodoc


class SessionComposerNormal implements SessionComposerMode {
  const SessionComposerNormal();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionComposerNormal);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'SessionComposerMode.normal()';
}


}




/// @nodoc


class SessionComposerEditing implements SessionComposerMode {
  const SessionComposerEditing({required this.messageId, required this.phase, required this.leftOutCount});
  

 final  String messageId;
 final  SessionEditPhase phase;
 final  int leftOutCount;

/// Create a copy of SessionComposerMode
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionComposerEditingCopyWith<SessionComposerEditing> get copyWith => _$SessionComposerEditingCopyWithImpl<SessionComposerEditing>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionComposerEditing&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.phase, phase) || other.phase == phase)&&(identical(other.leftOutCount, leftOutCount) || other.leftOutCount == leftOutCount));
}


@override
int get hashCode {
    return Object.hash(runtimeType,messageId,phase,leftOutCount);
}

@override
String toString() {
    return 'SessionComposerMode.editing(messageId: $messageId, phase: $phase, leftOutCount: $leftOutCount)';
}


}

/// @nodoc
abstract mixin class $SessionComposerEditingCopyWith<$Res> implements $SessionComposerModeCopyWith<$Res> {
  factory $SessionComposerEditingCopyWith(SessionComposerEditing value, $Res Function(SessionComposerEditing) _then) = _$SessionComposerEditingCopyWithImpl;
@useResult
$Res call({
 String messageId, SessionEditPhase phase, int leftOutCount
});




}
/// @nodoc
class _$SessionComposerEditingCopyWithImpl<$Res>
    implements $SessionComposerEditingCopyWith<$Res> {
  _$SessionComposerEditingCopyWithImpl(this._self, this._then);

  final SessionComposerEditing _self;
  final $Res Function(SessionComposerEditing) _then;

/// Create a copy of SessionComposerMode
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? messageId = null,Object? phase = null,Object? leftOutCount = null,}) {
  return _then(SessionComposerEditing(
messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as SessionEditPhase,leftOutCount: null == leftOutCount ? _self.leftOutCount : leftOutCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
