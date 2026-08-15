// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'new_session_submission_snapshot.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$NewSessionSubmissionSnapshot {

 ComposerDraft get draft;
/// Create a copy of NewSessionSubmissionSnapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NewSessionSubmissionSnapshotCopyWith<NewSessionSubmissionSnapshot> get copyWith => _$NewSessionSubmissionSnapshotCopyWithImpl<NewSessionSubmissionSnapshot>(this as NewSessionSubmissionSnapshot, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NewSessionSubmissionSnapshot&&(identical(other.draft, draft) || other.draft == draft));
}


@override
int get hashCode => Object.hash(runtimeType,draft);

@override
String toString() {
  return 'NewSessionSubmissionSnapshot(draft: $draft)';
}


}

/// @nodoc
abstract mixin class $NewSessionSubmissionSnapshotCopyWith<$Res>  {
  factory $NewSessionSubmissionSnapshotCopyWith(NewSessionSubmissionSnapshot value, $Res Function(NewSessionSubmissionSnapshot) _then) = _$NewSessionSubmissionSnapshotCopyWithImpl;
@useResult
$Res call({
 ComposerDraft draft
});




}
/// @nodoc
class _$NewSessionSubmissionSnapshotCopyWithImpl<$Res>
    implements $NewSessionSubmissionSnapshotCopyWith<$Res> {
  _$NewSessionSubmissionSnapshotCopyWithImpl(this._self, this._then);

  final NewSessionSubmissionSnapshot _self;
  final $Res Function(NewSessionSubmissionSnapshot) _then;

/// Create a copy of NewSessionSubmissionSnapshot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? draft = null,}) {
  return _then(_self.copyWith(
draft: null == draft ? _self.draft : draft // ignore: cast_nullable_to_non_nullable
as ComposerDraft,
  ));
}

}



/// @nodoc


class NewSessionTextSubmissionSnapshot extends NewSessionSubmissionSnapshot {
  const NewSessionTextSubmissionSnapshot({required this.draft, required  List<ComposerAttachment> attachments}): _attachments = attachments,super._();
  

@override final  ComposerDraft draft;
 final  List<ComposerAttachment> _attachments;
 List<ComposerAttachment> get attachments {
  if (_attachments is EqualUnmodifiableListView) return _attachments;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_attachments);
}


/// Create a copy of NewSessionSubmissionSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NewSessionTextSubmissionSnapshotCopyWith<NewSessionTextSubmissionSnapshot> get copyWith => _$NewSessionTextSubmissionSnapshotCopyWithImpl<NewSessionTextSubmissionSnapshot>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NewSessionTextSubmissionSnapshot&&(identical(other.draft, draft) || other.draft == draft)&&const DeepCollectionEquality().equals(other._attachments, _attachments));
}


@override
int get hashCode => Object.hash(runtimeType,draft,const DeepCollectionEquality().hash(_attachments));

@override
String toString() {
  return 'NewSessionSubmissionSnapshot.text(draft: $draft, attachments: $attachments)';
}


}

/// @nodoc
abstract mixin class $NewSessionTextSubmissionSnapshotCopyWith<$Res> implements $NewSessionSubmissionSnapshotCopyWith<$Res> {
  factory $NewSessionTextSubmissionSnapshotCopyWith(NewSessionTextSubmissionSnapshot value, $Res Function(NewSessionTextSubmissionSnapshot) _then) = _$NewSessionTextSubmissionSnapshotCopyWithImpl;
@override @useResult
$Res call({
 ComposerDraft draft, List<ComposerAttachment> attachments
});




}
/// @nodoc
class _$NewSessionTextSubmissionSnapshotCopyWithImpl<$Res>
    implements $NewSessionTextSubmissionSnapshotCopyWith<$Res> {
  _$NewSessionTextSubmissionSnapshotCopyWithImpl(this._self, this._then);

  final NewSessionTextSubmissionSnapshot _self;
  final $Res Function(NewSessionTextSubmissionSnapshot) _then;

/// Create a copy of NewSessionSubmissionSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? draft = null,Object? attachments = null,}) {
  return _then(NewSessionTextSubmissionSnapshot(
draft: null == draft ? _self.draft : draft // ignore: cast_nullable_to_non_nullable
as ComposerDraft,attachments: null == attachments ? _self._attachments : attachments // ignore: cast_nullable_to_non_nullable
as List<ComposerAttachment>,
  ));
}


}

/// @nodoc


class NewSessionCommandSubmissionSnapshot extends NewSessionSubmissionSnapshot {
  const NewSessionCommandSubmissionSnapshot({required this.draft, required this.command}): super._();
  

@override final  ComposerDraft draft;
 final  String command;

/// Create a copy of NewSessionSubmissionSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NewSessionCommandSubmissionSnapshotCopyWith<NewSessionCommandSubmissionSnapshot> get copyWith => _$NewSessionCommandSubmissionSnapshotCopyWithImpl<NewSessionCommandSubmissionSnapshot>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NewSessionCommandSubmissionSnapshot&&(identical(other.draft, draft) || other.draft == draft)&&(identical(other.command, command) || other.command == command));
}


@override
int get hashCode => Object.hash(runtimeType,draft,command);

@override
String toString() {
  return 'NewSessionSubmissionSnapshot.command(draft: $draft, command: $command)';
}


}

/// @nodoc
abstract mixin class $NewSessionCommandSubmissionSnapshotCopyWith<$Res> implements $NewSessionSubmissionSnapshotCopyWith<$Res> {
  factory $NewSessionCommandSubmissionSnapshotCopyWith(NewSessionCommandSubmissionSnapshot value, $Res Function(NewSessionCommandSubmissionSnapshot) _then) = _$NewSessionCommandSubmissionSnapshotCopyWithImpl;
@override @useResult
$Res call({
 ComposerDraft draft, String command
});




}
/// @nodoc
class _$NewSessionCommandSubmissionSnapshotCopyWithImpl<$Res>
    implements $NewSessionCommandSubmissionSnapshotCopyWith<$Res> {
  _$NewSessionCommandSubmissionSnapshotCopyWithImpl(this._self, this._then);

  final NewSessionCommandSubmissionSnapshot _self;
  final $Res Function(NewSessionCommandSubmissionSnapshot) _then;

/// Create a copy of NewSessionSubmissionSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? draft = null,Object? command = null,}) {
  return _then(NewSessionCommandSubmissionSnapshot(
draft: null == draft ? _self.draft : draft // ignore: cast_nullable_to_non_nullable
as ComposerDraft,command: null == command ? _self.command : command // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
