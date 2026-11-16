// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'interrupted_turn.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$InterruptedTurnView {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is InterruptedTurnView);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'InterruptedTurnView()';
}


}

/// @nodoc
class $InterruptedTurnViewCopyWith<$Res>  {
$InterruptedTurnViewCopyWith(InterruptedTurnView _, $Res Function(InterruptedTurnView) __);
}



/// @nodoc


class InterruptedTurnAbsent extends InterruptedTurnView {
  const InterruptedTurnAbsent(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is InterruptedTurnAbsent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'InterruptedTurnView.absent()';
}


}




/// @nodoc


class InterruptedTurnShown extends InterruptedTurnView {
  const InterruptedTurnShown({required this.afterMessageId, required this.lineAfterMessageId, required  Set<String> supersededStoppedIds, required this.continueRefusal}): _supersededStoppedIds = supersededStoppedIds,super._();
  

/// The message the bridge recorded the stop after. The turn ends there, so
/// a later prompt opens a new turn even when the cut-off one had no reply.
 final  String afterMessageId;
/// The cut-off turn's last loaded message, which the line follows.
 final  String lineAfterMessageId;
/// The cut-off turn's stopped rows. The Interrupted line says how the turn
/// ended, so they draw no Stopped line of their own.
 final  Set<String> _supersededStoppedIds;
/// The cut-off turn's stopped rows. The Interrupted line says how the turn
/// ended, so they draw no Stopped line of their own.
 Set<String> get supersededStoppedIds {
  if (_supersededStoppedIds is EqualUnmodifiableSetView) return _supersededStoppedIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_supersededStoppedIds);
}

/// Why the line offers no Continue, or null while it does.
 final  InterruptedTurnContinueRefusal? continueRefusal;

/// Create a copy of InterruptedTurnView
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InterruptedTurnShownCopyWith<InterruptedTurnShown> get copyWith => _$InterruptedTurnShownCopyWithImpl<InterruptedTurnShown>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is InterruptedTurnShown&&(identical(other.afterMessageId, afterMessageId) || other.afterMessageId == afterMessageId)&&(identical(other.lineAfterMessageId, lineAfterMessageId) || other.lineAfterMessageId == lineAfterMessageId)&&const DeepCollectionEquality().equals(other.supersededStoppedIds, _supersededStoppedIds)&&(identical(other.continueRefusal, continueRefusal) || other.continueRefusal == continueRefusal));
}


@override
int get hashCode {
    return Object.hash(runtimeType,afterMessageId,lineAfterMessageId,const DeepCollectionEquality().hash(_supersededStoppedIds),continueRefusal);
}

@override
String toString() {
    return 'InterruptedTurnView.shown(afterMessageId: $afterMessageId, lineAfterMessageId: $lineAfterMessageId, supersededStoppedIds: $supersededStoppedIds, continueRefusal: $continueRefusal)';
}


}

/// @nodoc
abstract mixin class $InterruptedTurnShownCopyWith<$Res> implements $InterruptedTurnViewCopyWith<$Res> {
  factory $InterruptedTurnShownCopyWith(InterruptedTurnShown value, $Res Function(InterruptedTurnShown) _then) = _$InterruptedTurnShownCopyWithImpl;
@useResult
$Res call({
 String afterMessageId, String lineAfterMessageId, Set<String> supersededStoppedIds, InterruptedTurnContinueRefusal? continueRefusal
});




}
/// @nodoc
class _$InterruptedTurnShownCopyWithImpl<$Res>
    implements $InterruptedTurnShownCopyWith<$Res> {
  _$InterruptedTurnShownCopyWithImpl(this._self, this._then);

  final InterruptedTurnShown _self;
  final $Res Function(InterruptedTurnShown) _then;

/// Create a copy of InterruptedTurnView
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? afterMessageId = null,Object? lineAfterMessageId = null,Object? supersededStoppedIds = null,Object? continueRefusal = freezed,}) {
  return _then(InterruptedTurnShown(
afterMessageId: null == afterMessageId ? _self.afterMessageId : afterMessageId // ignore: cast_nullable_to_non_nullable
as String,lineAfterMessageId: null == lineAfterMessageId ? _self.lineAfterMessageId : lineAfterMessageId // ignore: cast_nullable_to_non_nullable
as String,supersededStoppedIds: null == supersededStoppedIds ? _self._supersededStoppedIds : supersededStoppedIds // ignore: cast_nullable_to_non_nullable
as Set<String>,continueRefusal: freezed == continueRefusal ? _self.continueRefusal : continueRefusal // ignore: cast_nullable_to_non_nullable
as InterruptedTurnContinueRefusal?,
  ));
}


}

// dart format on
