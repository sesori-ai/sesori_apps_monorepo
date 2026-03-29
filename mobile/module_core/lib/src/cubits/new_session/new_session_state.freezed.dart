// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'new_session_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$NewSessionState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NewSessionState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'NewSessionState()';
}


}

/// @nodoc
class $NewSessionStateCopyWith<$Res>  {
$NewSessionStateCopyWith(NewSessionState _, $Res Function(NewSessionState) __);
}



/// @nodoc


class NewSessionIdle implements NewSessionState {
  const NewSessionIdle();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NewSessionIdle);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'NewSessionState.idle()';
}


}




/// @nodoc


class NewSessionSending implements NewSessionState {
  const NewSessionSending();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NewSessionSending);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'NewSessionState.sending()';
}


}




/// @nodoc


class NewSessionError implements NewSessionState {
  const NewSessionError({required this.message});
  

 final  String message;

/// Create a copy of NewSessionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NewSessionErrorCopyWith<NewSessionError> get copyWith => _$NewSessionErrorCopyWithImpl<NewSessionError>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NewSessionError&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'NewSessionState.error(message: $message)';
}


}

/// @nodoc
abstract mixin class $NewSessionErrorCopyWith<$Res> implements $NewSessionStateCopyWith<$Res> {
  factory $NewSessionErrorCopyWith(NewSessionError value, $Res Function(NewSessionError) _then) = _$NewSessionErrorCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$NewSessionErrorCopyWithImpl<$Res>
    implements $NewSessionErrorCopyWith<$Res> {
  _$NewSessionErrorCopyWithImpl(this._self, this._then);

  final NewSessionError _self;
  final $Res Function(NewSessionError) _then;

/// Create a copy of NewSessionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(NewSessionError(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class NewSessionCreated implements NewSessionState {
  const NewSessionCreated({required this.session});
  

 final  Session session;

/// Create a copy of NewSessionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NewSessionCreatedCopyWith<NewSessionCreated> get copyWith => _$NewSessionCreatedCopyWithImpl<NewSessionCreated>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NewSessionCreated&&(identical(other.session, session) || other.session == session));
}


@override
int get hashCode => Object.hash(runtimeType,session);

@override
String toString() {
  return 'NewSessionState.created(session: $session)';
}


}

/// @nodoc
abstract mixin class $NewSessionCreatedCopyWith<$Res> implements $NewSessionStateCopyWith<$Res> {
  factory $NewSessionCreatedCopyWith(NewSessionCreated value, $Res Function(NewSessionCreated) _then) = _$NewSessionCreatedCopyWithImpl;
@useResult
$Res call({
 Session session
});


$SessionCopyWith<$Res> get session;

}
/// @nodoc
class _$NewSessionCreatedCopyWithImpl<$Res>
    implements $NewSessionCreatedCopyWith<$Res> {
  _$NewSessionCreatedCopyWithImpl(this._self, this._then);

  final NewSessionCreated _self;
  final $Res Function(NewSessionCreated) _then;

/// Create a copy of NewSessionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? session = null,}) {
  return _then(NewSessionCreated(
session: null == session ? _self.session : session // ignore: cast_nullable_to_non_nullable
as Session,
  ));
}

/// Create a copy of NewSessionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SessionCopyWith<$Res> get session {
  
  return $SessionCopyWith<$Res>(_self.session, (value) {
    return _then(_self.copyWith(session: value));
  });
}
}

// dart format on
