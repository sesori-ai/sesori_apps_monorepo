// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plugin_management_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PluginManagementActionError {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginManagementActionError);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PluginManagementActionError()';
}


}

/// @nodoc
class $PluginManagementActionErrorCopyWith<$Res>  {
$PluginManagementActionErrorCopyWith(PluginManagementActionError _, $Res Function(PluginManagementActionError) __);
}



/// @nodoc


class PluginManagementInvalidIdleTimeout implements PluginManagementActionError {
  const PluginManagementInvalidIdleTimeout();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginManagementInvalidIdleTimeout);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PluginManagementActionError.invalidIdleTimeout()';
}


}




/// @nodoc


class PluginManagementActionNotFound implements PluginManagementActionError {
  const PluginManagementActionNotFound();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginManagementActionNotFound);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PluginManagementActionError.notFound()';
}


}




/// @nodoc


class PluginManagementActionConflict implements PluginManagementActionError {
  const PluginManagementActionConflict({required this.conflict});
  

 final  PluginLifecycleConflict conflict;

/// Create a copy of PluginManagementActionError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginManagementActionConflictCopyWith<PluginManagementActionConflict> get copyWith => _$PluginManagementActionConflictCopyWithImpl<PluginManagementActionConflict>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginManagementActionConflict&&(identical(other.conflict, conflict) || other.conflict == conflict));
}


@override
int get hashCode => Object.hash(runtimeType,conflict);

@override
String toString() {
  return 'PluginManagementActionError.conflict(conflict: $conflict)';
}


}

/// @nodoc
abstract mixin class $PluginManagementActionConflictCopyWith<$Res> implements $PluginManagementActionErrorCopyWith<$Res> {
  factory $PluginManagementActionConflictCopyWith(PluginManagementActionConflict value, $Res Function(PluginManagementActionConflict) _then) = _$PluginManagementActionConflictCopyWithImpl;
@useResult
$Res call({
 PluginLifecycleConflict conflict
});


$PluginLifecycleConflictCopyWith<$Res> get conflict;

}
/// @nodoc
class _$PluginManagementActionConflictCopyWithImpl<$Res>
    implements $PluginManagementActionConflictCopyWith<$Res> {
  _$PluginManagementActionConflictCopyWithImpl(this._self, this._then);

  final PluginManagementActionConflict _self;
  final $Res Function(PluginManagementActionConflict) _then;

/// Create a copy of PluginManagementActionError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? conflict = null,}) {
  return _then(PluginManagementActionConflict(
conflict: null == conflict ? _self.conflict : conflict // ignore: cast_nullable_to_non_nullable
as PluginLifecycleConflict,
  ));
}

/// Create a copy of PluginManagementActionError
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginLifecycleConflictCopyWith<$Res> get conflict {
  
  return $PluginLifecycleConflictCopyWith<$Res>(_self.conflict, (value) {
    return _then(_self.copyWith(conflict: value));
  });
}
}

/// @nodoc


class PluginManagementActionRequestError implements PluginManagementActionError {
  const PluginManagementActionRequestError({required this.error});
  

 final  ApiError error;

/// Create a copy of PluginManagementActionError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginManagementActionRequestErrorCopyWith<PluginManagementActionRequestError> get copyWith => _$PluginManagementActionRequestErrorCopyWithImpl<PluginManagementActionRequestError>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginManagementActionRequestError&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,error);

@override
String toString() {
  return 'PluginManagementActionError.request(error: $error)';
}


}

/// @nodoc
abstract mixin class $PluginManagementActionRequestErrorCopyWith<$Res> implements $PluginManagementActionErrorCopyWith<$Res> {
  factory $PluginManagementActionRequestErrorCopyWith(PluginManagementActionRequestError value, $Res Function(PluginManagementActionRequestError) _then) = _$PluginManagementActionRequestErrorCopyWithImpl;
@useResult
$Res call({
 ApiError error
});


$ApiErrorCopyWith<$Res> get error;

}
/// @nodoc
class _$PluginManagementActionRequestErrorCopyWithImpl<$Res>
    implements $PluginManagementActionRequestErrorCopyWith<$Res> {
  _$PluginManagementActionRequestErrorCopyWithImpl(this._self, this._then);

  final PluginManagementActionRequestError _self;
  final $Res Function(PluginManagementActionRequestError) _then;

/// Create a copy of PluginManagementActionError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? error = null,}) {
  return _then(PluginManagementActionRequestError(
error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as ApiError,
  ));
}

/// Create a copy of PluginManagementActionError
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ApiErrorCopyWith<$Res> get error {
  
  return $ApiErrorCopyWith<$Res>(_self.error, (value) {
    return _then(_self.copyWith(error: value));
  });
}
}

/// @nodoc
mixin _$PluginManagementState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginManagementState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PluginManagementState()';
}


}

/// @nodoc
class $PluginManagementStateCopyWith<$Res>  {
$PluginManagementStateCopyWith(PluginManagementState _, $Res Function(PluginManagementState) __);
}



/// @nodoc


class PluginManagementLoading implements PluginManagementState {
  const PluginManagementLoading();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginManagementLoading);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PluginManagementState.loading()';
}


}




/// @nodoc


class PluginManagementUnsupportedState implements PluginManagementState {
  const PluginManagementUnsupportedState();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginManagementUnsupportedState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PluginManagementState.unsupported()';
}


}




/// @nodoc


class PluginManagementFailure implements PluginManagementState {
  const PluginManagementFailure({required this.error});
  

 final  ApiError error;

/// Create a copy of PluginManagementState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginManagementFailureCopyWith<PluginManagementFailure> get copyWith => _$PluginManagementFailureCopyWithImpl<PluginManagementFailure>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginManagementFailure&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,error);

@override
String toString() {
  return 'PluginManagementState.failure(error: $error)';
}


}

/// @nodoc
abstract mixin class $PluginManagementFailureCopyWith<$Res> implements $PluginManagementStateCopyWith<$Res> {
  factory $PluginManagementFailureCopyWith(PluginManagementFailure value, $Res Function(PluginManagementFailure) _then) = _$PluginManagementFailureCopyWithImpl;
@useResult
$Res call({
 ApiError error
});


$ApiErrorCopyWith<$Res> get error;

}
/// @nodoc
class _$PluginManagementFailureCopyWithImpl<$Res>
    implements $PluginManagementFailureCopyWith<$Res> {
  _$PluginManagementFailureCopyWithImpl(this._self, this._then);

  final PluginManagementFailure _self;
  final $Res Function(PluginManagementFailure) _then;

/// Create a copy of PluginManagementState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? error = null,}) {
  return _then(PluginManagementFailure(
error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as ApiError,
  ));
}

/// Create a copy of PluginManagementState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ApiErrorCopyWith<$Res> get error {
  
  return $ApiErrorCopyWith<$Res>(_self.error, (value) {
    return _then(_self.copyWith(error: value));
  });
}
}

/// @nodoc


class PluginManagementReady implements PluginManagementState {
  const PluginManagementReady({required this.response, required this.actionStatus, required this.actingPluginId, required this.pendingForceAction, required this.actionError});
  

 final  PluginManagementResponse response;
 final  PluginManagementActionStatus actionStatus;
 final  String? actingPluginId;
 final  PluginManagementForceAction? pendingForceAction;
 final  PluginManagementActionError? actionError;

/// Create a copy of PluginManagementState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginManagementReadyCopyWith<PluginManagementReady> get copyWith => _$PluginManagementReadyCopyWithImpl<PluginManagementReady>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginManagementReady&&(identical(other.response, response) || other.response == response)&&(identical(other.actionStatus, actionStatus) || other.actionStatus == actionStatus)&&(identical(other.actingPluginId, actingPluginId) || other.actingPluginId == actingPluginId)&&(identical(other.pendingForceAction, pendingForceAction) || other.pendingForceAction == pendingForceAction)&&(identical(other.actionError, actionError) || other.actionError == actionError));
}


@override
int get hashCode => Object.hash(runtimeType,response,actionStatus,actingPluginId,pendingForceAction,actionError);

@override
String toString() {
  return 'PluginManagementState.ready(response: $response, actionStatus: $actionStatus, actingPluginId: $actingPluginId, pendingForceAction: $pendingForceAction, actionError: $actionError)';
}


}

/// @nodoc
abstract mixin class $PluginManagementReadyCopyWith<$Res> implements $PluginManagementStateCopyWith<$Res> {
  factory $PluginManagementReadyCopyWith(PluginManagementReady value, $Res Function(PluginManagementReady) _then) = _$PluginManagementReadyCopyWithImpl;
@useResult
$Res call({
 PluginManagementResponse response, PluginManagementActionStatus actionStatus, String? actingPluginId, PluginManagementForceAction? pendingForceAction, PluginManagementActionError? actionError
});


$PluginManagementResponseCopyWith<$Res> get response;$PluginManagementActionErrorCopyWith<$Res>? get actionError;

}
/// @nodoc
class _$PluginManagementReadyCopyWithImpl<$Res>
    implements $PluginManagementReadyCopyWith<$Res> {
  _$PluginManagementReadyCopyWithImpl(this._self, this._then);

  final PluginManagementReady _self;
  final $Res Function(PluginManagementReady) _then;

/// Create a copy of PluginManagementState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? response = null,Object? actionStatus = null,Object? actingPluginId = freezed,Object? pendingForceAction = freezed,Object? actionError = freezed,}) {
  return _then(PluginManagementReady(
response: null == response ? _self.response : response // ignore: cast_nullable_to_non_nullable
as PluginManagementResponse,actionStatus: null == actionStatus ? _self.actionStatus : actionStatus // ignore: cast_nullable_to_non_nullable
as PluginManagementActionStatus,actingPluginId: freezed == actingPluginId ? _self.actingPluginId : actingPluginId // ignore: cast_nullable_to_non_nullable
as String?,pendingForceAction: freezed == pendingForceAction ? _self.pendingForceAction : pendingForceAction // ignore: cast_nullable_to_non_nullable
as PluginManagementForceAction?,actionError: freezed == actionError ? _self.actionError : actionError // ignore: cast_nullable_to_non_nullable
as PluginManagementActionError?,
  ));
}

/// Create a copy of PluginManagementState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginManagementResponseCopyWith<$Res> get response {
  
  return $PluginManagementResponseCopyWith<$Res>(_self.response, (value) {
    return _then(_self.copyWith(response: value));
  });
}/// Create a copy of PluginManagementState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginManagementActionErrorCopyWith<$Res>? get actionError {
    if (_self.actionError == null) {
    return null;
  }

  return $PluginManagementActionErrorCopyWith<$Res>(_self.actionError!, (value) {
    return _then(_self.copyWith(actionError: value));
  });
}
}

// dart format on
