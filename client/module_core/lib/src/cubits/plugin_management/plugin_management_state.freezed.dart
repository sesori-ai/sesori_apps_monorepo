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


class PluginManagementActionUncertain implements PluginManagementActionError {
  const PluginManagementActionUncertain();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginManagementActionUncertain);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PluginManagementActionError.uncertain()';
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
mixin _$PluginManagementRefreshState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginManagementRefreshState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PluginManagementRefreshState()';
}


}

/// @nodoc
class $PluginManagementRefreshStateCopyWith<$Res>  {
$PluginManagementRefreshStateCopyWith(PluginManagementRefreshState _, $Res Function(PluginManagementRefreshState) __);
}



/// @nodoc


class PluginManagementRefreshIdle implements PluginManagementRefreshState {
  const PluginManagementRefreshIdle();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginManagementRefreshIdle);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PluginManagementRefreshState.idle()';
}


}




/// @nodoc


class PluginManagementRefreshFailed implements PluginManagementRefreshState {
  const PluginManagementRefreshFailed({required this.error});
  

 final  ApiError error;

/// Create a copy of PluginManagementRefreshState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginManagementRefreshFailedCopyWith<PluginManagementRefreshFailed> get copyWith => _$PluginManagementRefreshFailedCopyWithImpl<PluginManagementRefreshFailed>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginManagementRefreshFailed&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,error);

@override
String toString() {
  return 'PluginManagementRefreshState.failed(error: $error)';
}


}

/// @nodoc
abstract mixin class $PluginManagementRefreshFailedCopyWith<$Res> implements $PluginManagementRefreshStateCopyWith<$Res> {
  factory $PluginManagementRefreshFailedCopyWith(PluginManagementRefreshFailed value, $Res Function(PluginManagementRefreshFailed) _then) = _$PluginManagementRefreshFailedCopyWithImpl;
@useResult
$Res call({
 ApiError error
});


$ApiErrorCopyWith<$Res> get error;

}
/// @nodoc
class _$PluginManagementRefreshFailedCopyWithImpl<$Res>
    implements $PluginManagementRefreshFailedCopyWith<$Res> {
  _$PluginManagementRefreshFailedCopyWithImpl(this._self, this._then);

  final PluginManagementRefreshFailed _self;
  final $Res Function(PluginManagementRefreshFailed) _then;

/// Create a copy of PluginManagementRefreshState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? error = null,}) {
  return _then(PluginManagementRefreshFailed(
error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as ApiError,
  ));
}

/// Create a copy of PluginManagementRefreshState
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
mixin _$PluginManagementActionTarget {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginManagementActionTarget);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PluginManagementActionTarget()';
}


}

/// @nodoc
class $PluginManagementActionTargetCopyWith<$Res>  {
$PluginManagementActionTargetCopyWith(PluginManagementActionTarget _, $Res Function(PluginManagementActionTarget) __);
}



/// @nodoc


class PluginManagementActionTargetAllHarnesses implements PluginManagementActionTarget {
  const PluginManagementActionTargetAllHarnesses();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginManagementActionTargetAllHarnesses);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PluginManagementActionTarget.allHarnesses()';
}


}




/// @nodoc


class PluginManagementActionTargetHarness implements PluginManagementActionTarget {
  const PluginManagementActionTargetHarness({required this.pluginId});
  

 final  String pluginId;

/// Create a copy of PluginManagementActionTarget
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginManagementActionTargetHarnessCopyWith<PluginManagementActionTargetHarness> get copyWith => _$PluginManagementActionTargetHarnessCopyWithImpl<PluginManagementActionTargetHarness>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginManagementActionTargetHarness&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId));
}


@override
int get hashCode => Object.hash(runtimeType,pluginId);

@override
String toString() {
  return 'PluginManagementActionTarget.harness(pluginId: $pluginId)';
}


}

/// @nodoc
abstract mixin class $PluginManagementActionTargetHarnessCopyWith<$Res> implements $PluginManagementActionTargetCopyWith<$Res> {
  factory $PluginManagementActionTargetHarnessCopyWith(PluginManagementActionTargetHarness value, $Res Function(PluginManagementActionTargetHarness) _then) = _$PluginManagementActionTargetHarnessCopyWithImpl;
@useResult
$Res call({
 String pluginId
});




}
/// @nodoc
class _$PluginManagementActionTargetHarnessCopyWithImpl<$Res>
    implements $PluginManagementActionTargetHarnessCopyWith<$Res> {
  _$PluginManagementActionTargetHarnessCopyWithImpl(this._self, this._then);

  final PluginManagementActionTargetHarness _self;
  final $Res Function(PluginManagementActionTargetHarness) _then;

/// Create a copy of PluginManagementActionTarget
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? pluginId = null,}) {
  return _then(PluginManagementActionTargetHarness(
pluginId: null == pluginId ? _self.pluginId : pluginId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$PluginManagementActionState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginManagementActionState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PluginManagementActionState()';
}


}

/// @nodoc
class $PluginManagementActionStateCopyWith<$Res>  {
$PluginManagementActionStateCopyWith(PluginManagementActionState _, $Res Function(PluginManagementActionState) __);
}



/// @nodoc


class PluginManagementActionIdle implements PluginManagementActionState {
  const PluginManagementActionIdle();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginManagementActionIdle);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PluginManagementActionState.idle()';
}


}




/// @nodoc


class PluginManagementActionInProgress implements PluginManagementActionState {
  const PluginManagementActionInProgress({required this.target});
  

 final  PluginManagementActionTarget target;

/// Create a copy of PluginManagementActionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginManagementActionInProgressCopyWith<PluginManagementActionInProgress> get copyWith => _$PluginManagementActionInProgressCopyWithImpl<PluginManagementActionInProgress>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginManagementActionInProgress&&(identical(other.target, target) || other.target == target));
}


@override
int get hashCode => Object.hash(runtimeType,target);

@override
String toString() {
  return 'PluginManagementActionState.inProgress(target: $target)';
}


}

/// @nodoc
abstract mixin class $PluginManagementActionInProgressCopyWith<$Res> implements $PluginManagementActionStateCopyWith<$Res> {
  factory $PluginManagementActionInProgressCopyWith(PluginManagementActionInProgress value, $Res Function(PluginManagementActionInProgress) _then) = _$PluginManagementActionInProgressCopyWithImpl;
@useResult
$Res call({
 PluginManagementActionTarget target
});


$PluginManagementActionTargetCopyWith<$Res> get target;

}
/// @nodoc
class _$PluginManagementActionInProgressCopyWithImpl<$Res>
    implements $PluginManagementActionInProgressCopyWith<$Res> {
  _$PluginManagementActionInProgressCopyWithImpl(this._self, this._then);

  final PluginManagementActionInProgress _self;
  final $Res Function(PluginManagementActionInProgress) _then;

/// Create a copy of PluginManagementActionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? target = null,}) {
  return _then(PluginManagementActionInProgress(
target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as PluginManagementActionTarget,
  ));
}

/// Create a copy of PluginManagementActionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginManagementActionTargetCopyWith<$Res> get target {
  
  return $PluginManagementActionTargetCopyWith<$Res>(_self.target, (value) {
    return _then(_self.copyWith(target: value));
  });
}
}

/// @nodoc


class PluginManagementActionFailed implements PluginManagementActionState {
  const PluginManagementActionFailed({required this.target, required this.error});
  

 final  PluginManagementActionTarget target;
 final  PluginManagementActionError error;

/// Create a copy of PluginManagementActionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginManagementActionFailedCopyWith<PluginManagementActionFailed> get copyWith => _$PluginManagementActionFailedCopyWithImpl<PluginManagementActionFailed>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginManagementActionFailed&&(identical(other.target, target) || other.target == target)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,target,error);

@override
String toString() {
  return 'PluginManagementActionState.failed(target: $target, error: $error)';
}


}

/// @nodoc
abstract mixin class $PluginManagementActionFailedCopyWith<$Res> implements $PluginManagementActionStateCopyWith<$Res> {
  factory $PluginManagementActionFailedCopyWith(PluginManagementActionFailed value, $Res Function(PluginManagementActionFailed) _then) = _$PluginManagementActionFailedCopyWithImpl;
@useResult
$Res call({
 PluginManagementActionTarget target, PluginManagementActionError error
});


$PluginManagementActionTargetCopyWith<$Res> get target;$PluginManagementActionErrorCopyWith<$Res> get error;

}
/// @nodoc
class _$PluginManagementActionFailedCopyWithImpl<$Res>
    implements $PluginManagementActionFailedCopyWith<$Res> {
  _$PluginManagementActionFailedCopyWithImpl(this._self, this._then);

  final PluginManagementActionFailed _self;
  final $Res Function(PluginManagementActionFailed) _then;

/// Create a copy of PluginManagementActionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? target = null,Object? error = null,}) {
  return _then(PluginManagementActionFailed(
target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as PluginManagementActionTarget,error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as PluginManagementActionError,
  ));
}

/// Create a copy of PluginManagementActionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginManagementActionTargetCopyWith<$Res> get target {
  
  return $PluginManagementActionTargetCopyWith<$Res>(_self.target, (value) {
    return _then(_self.copyWith(target: value));
  });
}/// Create a copy of PluginManagementActionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginManagementActionErrorCopyWith<$Res> get error {
  
  return $PluginManagementActionErrorCopyWith<$Res>(_self.error, (value) {
    return _then(_self.copyWith(error: value));
  });
}
}

/// @nodoc


class PluginManagementActionForceConfirmationRequired implements PluginManagementActionState {
  const PluginManagementActionForceConfirmationRequired({required this.pluginId, required this.action, required this.conflict, required this.request});
  

 final  String pluginId;
 final  PluginManagementForceAction action;
 final  PluginLifecycleConflict conflict;
 final  PluginLifecycleCommandRequest request;

/// Create a copy of PluginManagementActionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginManagementActionForceConfirmationRequiredCopyWith<PluginManagementActionForceConfirmationRequired> get copyWith => _$PluginManagementActionForceConfirmationRequiredCopyWithImpl<PluginManagementActionForceConfirmationRequired>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginManagementActionForceConfirmationRequired&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId)&&(identical(other.action, action) || other.action == action)&&(identical(other.conflict, conflict) || other.conflict == conflict)&&(identical(other.request, request) || other.request == request));
}


@override
int get hashCode => Object.hash(runtimeType,pluginId,action,conflict,request);

@override
String toString() {
  return 'PluginManagementActionState.forceConfirmationRequired(pluginId: $pluginId, action: $action, conflict: $conflict, request: $request)';
}


}

/// @nodoc
abstract mixin class $PluginManagementActionForceConfirmationRequiredCopyWith<$Res> implements $PluginManagementActionStateCopyWith<$Res> {
  factory $PluginManagementActionForceConfirmationRequiredCopyWith(PluginManagementActionForceConfirmationRequired value, $Res Function(PluginManagementActionForceConfirmationRequired) _then) = _$PluginManagementActionForceConfirmationRequiredCopyWithImpl;
@useResult
$Res call({
 String pluginId, PluginManagementForceAction action, PluginLifecycleConflict conflict, PluginLifecycleCommandRequest request
});


$PluginLifecycleConflictCopyWith<$Res> get conflict;

}
/// @nodoc
class _$PluginManagementActionForceConfirmationRequiredCopyWithImpl<$Res>
    implements $PluginManagementActionForceConfirmationRequiredCopyWith<$Res> {
  _$PluginManagementActionForceConfirmationRequiredCopyWithImpl(this._self, this._then);

  final PluginManagementActionForceConfirmationRequired _self;
  final $Res Function(PluginManagementActionForceConfirmationRequired) _then;

/// Create a copy of PluginManagementActionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? pluginId = null,Object? action = null,Object? conflict = null,Object? request = null,}) {
  return _then(PluginManagementActionForceConfirmationRequired(
pluginId: null == pluginId ? _self.pluginId : pluginId // ignore: cast_nullable_to_non_nullable
as String,action: null == action ? _self.action : action // ignore: cast_nullable_to_non_nullable
as PluginManagementForceAction,conflict: null == conflict ? _self.conflict : conflict // ignore: cast_nullable_to_non_nullable
as PluginLifecycleConflict,request: null == request ? _self.request : request // ignore: cast_nullable_to_non_nullable
as PluginLifecycleCommandRequest,
  ));
}

/// Create a copy of PluginManagementActionState
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


class PluginManagementUnsupported implements PluginManagementState {
  const PluginManagementUnsupported();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginManagementUnsupported);
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
  const PluginManagementReady({required this.response, required this.refresh, required this.action, required final  Map<String, PluginInstallProgress> installs}): _installs = installs;
  

 final  PluginManagementResponse response;
 final  PluginManagementRefreshState refresh;
 final  PluginManagementActionState action;
/// In-flight managed runtime installs, keyed by plugin id.
 final  Map<String, PluginInstallProgress> _installs;
/// In-flight managed runtime installs, keyed by plugin id.
 Map<String, PluginInstallProgress> get installs {
  if (_installs is EqualUnmodifiableMapView) return _installs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_installs);
}


/// Create a copy of PluginManagementState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginManagementReadyCopyWith<PluginManagementReady> get copyWith => _$PluginManagementReadyCopyWithImpl<PluginManagementReady>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginManagementReady&&(identical(other.response, response) || other.response == response)&&(identical(other.refresh, refresh) || other.refresh == refresh)&&(identical(other.action, action) || other.action == action)&&const DeepCollectionEquality().equals(other._installs, _installs));
}


@override
int get hashCode => Object.hash(runtimeType,response,refresh,action,const DeepCollectionEquality().hash(_installs));

@override
String toString() {
  return 'PluginManagementState.ready(response: $response, refresh: $refresh, action: $action, installs: $installs)';
}


}

/// @nodoc
abstract mixin class $PluginManagementReadyCopyWith<$Res> implements $PluginManagementStateCopyWith<$Res> {
  factory $PluginManagementReadyCopyWith(PluginManagementReady value, $Res Function(PluginManagementReady) _then) = _$PluginManagementReadyCopyWithImpl;
@useResult
$Res call({
 PluginManagementResponse response, PluginManagementRefreshState refresh, PluginManagementActionState action, Map<String, PluginInstallProgress> installs
});


$PluginManagementResponseCopyWith<$Res> get response;$PluginManagementRefreshStateCopyWith<$Res> get refresh;$PluginManagementActionStateCopyWith<$Res> get action;

}
/// @nodoc
class _$PluginManagementReadyCopyWithImpl<$Res>
    implements $PluginManagementReadyCopyWith<$Res> {
  _$PluginManagementReadyCopyWithImpl(this._self, this._then);

  final PluginManagementReady _self;
  final $Res Function(PluginManagementReady) _then;

/// Create a copy of PluginManagementState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? response = null,Object? refresh = null,Object? action = null,Object? installs = null,}) {
  return _then(PluginManagementReady(
response: null == response ? _self.response : response // ignore: cast_nullable_to_non_nullable
as PluginManagementResponse,refresh: null == refresh ? _self.refresh : refresh // ignore: cast_nullable_to_non_nullable
as PluginManagementRefreshState,action: null == action ? _self.action : action // ignore: cast_nullable_to_non_nullable
as PluginManagementActionState,installs: null == installs ? _self._installs : installs // ignore: cast_nullable_to_non_nullable
as Map<String, PluginInstallProgress>,
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
$PluginManagementRefreshStateCopyWith<$Res> get refresh {
  
  return $PluginManagementRefreshStateCopyWith<$Res>(_self.refresh, (value) {
    return _then(_self.copyWith(refresh: value));
  });
}/// Create a copy of PluginManagementState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginManagementActionStateCopyWith<$Res> get action {
  
  return $PluginManagementActionStateCopyWith<$Res>(_self.action, (value) {
    return _then(_self.copyWith(action: value));
  });
}
}

// dart format on
