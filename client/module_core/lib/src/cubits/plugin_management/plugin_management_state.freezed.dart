// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plugin_management_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
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
mixin _$PluginAuthenticationPresentationError {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginAuthenticationPresentationError);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PluginAuthenticationPresentationError()';
}


}

/// @nodoc
class $PluginAuthenticationPresentationErrorCopyWith<$Res>  {
$PluginAuthenticationPresentationErrorCopyWith(PluginAuthenticationPresentationError _, $Res Function(PluginAuthenticationPresentationError) __);
}



/// @nodoc


class PluginAuthenticationPresentationNotFound implements PluginAuthenticationPresentationError {
  const PluginAuthenticationPresentationNotFound();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginAuthenticationPresentationNotFound);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PluginAuthenticationPresentationError.notFound()';
}


}




/// @nodoc


class PluginAuthenticationPresentationUnsupported implements PluginAuthenticationPresentationError {
  const PluginAuthenticationPresentationUnsupported();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginAuthenticationPresentationUnsupported);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PluginAuthenticationPresentationError.unsupported()';
}


}




/// @nodoc


class PluginAuthenticationPresentationConflict implements PluginAuthenticationPresentationError {
  const PluginAuthenticationPresentationConflict({required this.conflict});
  

 final  PluginAuthenticationConflict conflict;

/// Create a copy of PluginAuthenticationPresentationError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginAuthenticationPresentationConflictCopyWith<PluginAuthenticationPresentationConflict> get copyWith => _$PluginAuthenticationPresentationConflictCopyWithImpl<PluginAuthenticationPresentationConflict>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginAuthenticationPresentationConflict&&(identical(other.conflict, conflict) || other.conflict == conflict));
}


@override
int get hashCode => Object.hash(runtimeType,conflict);

@override
String toString() {
  return 'PluginAuthenticationPresentationError.conflict(conflict: $conflict)';
}


}

/// @nodoc
abstract mixin class $PluginAuthenticationPresentationConflictCopyWith<$Res> implements $PluginAuthenticationPresentationErrorCopyWith<$Res> {
  factory $PluginAuthenticationPresentationConflictCopyWith(PluginAuthenticationPresentationConflict value, $Res Function(PluginAuthenticationPresentationConflict) _then) = _$PluginAuthenticationPresentationConflictCopyWithImpl;
@useResult
$Res call({
 PluginAuthenticationConflict conflict
});


$PluginAuthenticationConflictCopyWith<$Res> get conflict;

}
/// @nodoc
class _$PluginAuthenticationPresentationConflictCopyWithImpl<$Res>
    implements $PluginAuthenticationPresentationConflictCopyWith<$Res> {
  _$PluginAuthenticationPresentationConflictCopyWithImpl(this._self, this._then);

  final PluginAuthenticationPresentationConflict _self;
  final $Res Function(PluginAuthenticationPresentationConflict) _then;

/// Create a copy of PluginAuthenticationPresentationError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? conflict = null,}) {
  return _then(PluginAuthenticationPresentationConflict(
conflict: null == conflict ? _self.conflict : conflict // ignore: cast_nullable_to_non_nullable
as PluginAuthenticationConflict,
  ));
}

/// Create a copy of PluginAuthenticationPresentationError
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginAuthenticationConflictCopyWith<$Res> get conflict {
  
  return $PluginAuthenticationConflictCopyWith<$Res>(_self.conflict, (value) {
    return _then(_self.copyWith(conflict: value));
  });
}
}

/// @nodoc


class PluginAuthenticationPresentationUncertain implements PluginAuthenticationPresentationError {
  const PluginAuthenticationPresentationUncertain();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginAuthenticationPresentationUncertain);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PluginAuthenticationPresentationError.uncertain()';
}


}




/// @nodoc


class PluginAuthenticationPresentationInvalidChallenge implements PluginAuthenticationPresentationError {
  const PluginAuthenticationPresentationInvalidChallenge();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginAuthenticationPresentationInvalidChallenge);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PluginAuthenticationPresentationError.invalidChallenge()';
}


}




/// @nodoc


class PluginAuthenticationPresentationRemoteError implements PluginAuthenticationPresentationError {
  const PluginAuthenticationPresentationRemoteError({required this.message});
  

 final  String message;

/// Create a copy of PluginAuthenticationPresentationError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginAuthenticationPresentationRemoteErrorCopyWith<PluginAuthenticationPresentationRemoteError> get copyWith => _$PluginAuthenticationPresentationRemoteErrorCopyWithImpl<PluginAuthenticationPresentationRemoteError>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginAuthenticationPresentationRemoteError&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'PluginAuthenticationPresentationError.remote(message: $message)';
}


}

/// @nodoc
abstract mixin class $PluginAuthenticationPresentationRemoteErrorCopyWith<$Res> implements $PluginAuthenticationPresentationErrorCopyWith<$Res> {
  factory $PluginAuthenticationPresentationRemoteErrorCopyWith(PluginAuthenticationPresentationRemoteError value, $Res Function(PluginAuthenticationPresentationRemoteError) _then) = _$PluginAuthenticationPresentationRemoteErrorCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$PluginAuthenticationPresentationRemoteErrorCopyWithImpl<$Res>
    implements $PluginAuthenticationPresentationRemoteErrorCopyWith<$Res> {
  _$PluginAuthenticationPresentationRemoteErrorCopyWithImpl(this._self, this._then);

  final PluginAuthenticationPresentationRemoteError _self;
  final $Res Function(PluginAuthenticationPresentationRemoteError) _then;

/// Create a copy of PluginAuthenticationPresentationError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(PluginAuthenticationPresentationRemoteError(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class PluginAuthenticationPresentationRequestError implements PluginAuthenticationPresentationError {
  const PluginAuthenticationPresentationRequestError({required this.error});
  

 final  ApiError error;

/// Create a copy of PluginAuthenticationPresentationError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginAuthenticationPresentationRequestErrorCopyWith<PluginAuthenticationPresentationRequestError> get copyWith => _$PluginAuthenticationPresentationRequestErrorCopyWithImpl<PluginAuthenticationPresentationRequestError>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginAuthenticationPresentationRequestError&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,error);

@override
String toString() {
  return 'PluginAuthenticationPresentationError.request(error: $error)';
}


}

/// @nodoc
abstract mixin class $PluginAuthenticationPresentationRequestErrorCopyWith<$Res> implements $PluginAuthenticationPresentationErrorCopyWith<$Res> {
  factory $PluginAuthenticationPresentationRequestErrorCopyWith(PluginAuthenticationPresentationRequestError value, $Res Function(PluginAuthenticationPresentationRequestError) _then) = _$PluginAuthenticationPresentationRequestErrorCopyWithImpl;
@useResult
$Res call({
 ApiError error
});


$ApiErrorCopyWith<$Res> get error;

}
/// @nodoc
class _$PluginAuthenticationPresentationRequestErrorCopyWithImpl<$Res>
    implements $PluginAuthenticationPresentationRequestErrorCopyWith<$Res> {
  _$PluginAuthenticationPresentationRequestErrorCopyWithImpl(this._self, this._then);

  final PluginAuthenticationPresentationRequestError _self;
  final $Res Function(PluginAuthenticationPresentationRequestError) _then;

/// Create a copy of PluginAuthenticationPresentationError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? error = null,}) {
  return _then(PluginAuthenticationPresentationRequestError(
error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as ApiError,
  ));
}

/// Create a copy of PluginAuthenticationPresentationError
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
mixin _$PluginAuthenticationPresentationState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginAuthenticationPresentationState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PluginAuthenticationPresentationState()';
}


}

/// @nodoc
class $PluginAuthenticationPresentationStateCopyWith<$Res>  {
$PluginAuthenticationPresentationStateCopyWith(PluginAuthenticationPresentationState _, $Res Function(PluginAuthenticationPresentationState) __);
}



/// @nodoc


class PluginAuthenticationPresentationIdle implements PluginAuthenticationPresentationState {
  const PluginAuthenticationPresentationIdle();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginAuthenticationPresentationIdle);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PluginAuthenticationPresentationState.idle()';
}


}




/// @nodoc


class PluginAuthenticationPresentationStarting implements PluginAuthenticationPresentationState {
  const PluginAuthenticationPresentationStarting({required this.pluginId});
  

 final  String pluginId;

/// Create a copy of PluginAuthenticationPresentationState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginAuthenticationPresentationStartingCopyWith<PluginAuthenticationPresentationStarting> get copyWith => _$PluginAuthenticationPresentationStartingCopyWithImpl<PluginAuthenticationPresentationStarting>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginAuthenticationPresentationStarting&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId));
}


@override
int get hashCode => Object.hash(runtimeType,pluginId);

@override
String toString() {
  return 'PluginAuthenticationPresentationState.starting(pluginId: $pluginId)';
}


}

/// @nodoc
abstract mixin class $PluginAuthenticationPresentationStartingCopyWith<$Res> implements $PluginAuthenticationPresentationStateCopyWith<$Res> {
  factory $PluginAuthenticationPresentationStartingCopyWith(PluginAuthenticationPresentationStarting value, $Res Function(PluginAuthenticationPresentationStarting) _then) = _$PluginAuthenticationPresentationStartingCopyWithImpl;
@useResult
$Res call({
 String pluginId
});




}
/// @nodoc
class _$PluginAuthenticationPresentationStartingCopyWithImpl<$Res>
    implements $PluginAuthenticationPresentationStartingCopyWith<$Res> {
  _$PluginAuthenticationPresentationStartingCopyWithImpl(this._self, this._then);

  final PluginAuthenticationPresentationStarting _self;
  final $Res Function(PluginAuthenticationPresentationStarting) _then;

/// Create a copy of PluginAuthenticationPresentationState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? pluginId = null,}) {
  return _then(PluginAuthenticationPresentationStarting(
pluginId: null == pluginId ? _self.pluginId : pluginId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class PluginAuthenticationPresentationChallenge implements PluginAuthenticationPresentationState {
  const PluginAuthenticationPresentationChallenge({required this.pluginId, required this.verificationUri, required this.userCode});
  

 final  String pluginId;
 final  Uri verificationUri;
 final  String userCode;

/// Create a copy of PluginAuthenticationPresentationState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginAuthenticationPresentationChallengeCopyWith<PluginAuthenticationPresentationChallenge> get copyWith => _$PluginAuthenticationPresentationChallengeCopyWithImpl<PluginAuthenticationPresentationChallenge>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginAuthenticationPresentationChallenge&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId)&&(identical(other.verificationUri, verificationUri) || other.verificationUri == verificationUri)&&(identical(other.userCode, userCode) || other.userCode == userCode));
}


@override
int get hashCode => Object.hash(runtimeType,pluginId,verificationUri,userCode);

@override
String toString() {
  return 'PluginAuthenticationPresentationState.challenge(pluginId: $pluginId, verificationUri: $verificationUri, userCode: $userCode)';
}


}

/// @nodoc
abstract mixin class $PluginAuthenticationPresentationChallengeCopyWith<$Res> implements $PluginAuthenticationPresentationStateCopyWith<$Res> {
  factory $PluginAuthenticationPresentationChallengeCopyWith(PluginAuthenticationPresentationChallenge value, $Res Function(PluginAuthenticationPresentationChallenge) _then) = _$PluginAuthenticationPresentationChallengeCopyWithImpl;
@useResult
$Res call({
 String pluginId, Uri verificationUri, String userCode
});




}
/// @nodoc
class _$PluginAuthenticationPresentationChallengeCopyWithImpl<$Res>
    implements $PluginAuthenticationPresentationChallengeCopyWith<$Res> {
  _$PluginAuthenticationPresentationChallengeCopyWithImpl(this._self, this._then);

  final PluginAuthenticationPresentationChallenge _self;
  final $Res Function(PluginAuthenticationPresentationChallenge) _then;

/// Create a copy of PluginAuthenticationPresentationState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? pluginId = null,Object? verificationUri = null,Object? userCode = null,}) {
  return _then(PluginAuthenticationPresentationChallenge(
pluginId: null == pluginId ? _self.pluginId : pluginId // ignore: cast_nullable_to_non_nullable
as String,verificationUri: null == verificationUri ? _self.verificationUri : verificationUri // ignore: cast_nullable_to_non_nullable
as Uri,userCode: null == userCode ? _self.userCode : userCode // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class PluginAuthenticationPresentationBrowserLaunchFailedState implements PluginAuthenticationPresentationState {
  const PluginAuthenticationPresentationBrowserLaunchFailedState({required this.pluginId, required this.verificationUri, required this.userCode});
  

 final  String pluginId;
 final  Uri verificationUri;
 final  String userCode;

/// Create a copy of PluginAuthenticationPresentationState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginAuthenticationPresentationBrowserLaunchFailedStateCopyWith<PluginAuthenticationPresentationBrowserLaunchFailedState> get copyWith => _$PluginAuthenticationPresentationBrowserLaunchFailedStateCopyWithImpl<PluginAuthenticationPresentationBrowserLaunchFailedState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginAuthenticationPresentationBrowserLaunchFailedState&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId)&&(identical(other.verificationUri, verificationUri) || other.verificationUri == verificationUri)&&(identical(other.userCode, userCode) || other.userCode == userCode));
}


@override
int get hashCode => Object.hash(runtimeType,pluginId,verificationUri,userCode);

@override
String toString() {
  return 'PluginAuthenticationPresentationState.browserLaunchFailed(pluginId: $pluginId, verificationUri: $verificationUri, userCode: $userCode)';
}


}

/// @nodoc
abstract mixin class $PluginAuthenticationPresentationBrowserLaunchFailedStateCopyWith<$Res> implements $PluginAuthenticationPresentationStateCopyWith<$Res> {
  factory $PluginAuthenticationPresentationBrowserLaunchFailedStateCopyWith(PluginAuthenticationPresentationBrowserLaunchFailedState value, $Res Function(PluginAuthenticationPresentationBrowserLaunchFailedState) _then) = _$PluginAuthenticationPresentationBrowserLaunchFailedStateCopyWithImpl;
@useResult
$Res call({
 String pluginId, Uri verificationUri, String userCode
});




}
/// @nodoc
class _$PluginAuthenticationPresentationBrowserLaunchFailedStateCopyWithImpl<$Res>
    implements $PluginAuthenticationPresentationBrowserLaunchFailedStateCopyWith<$Res> {
  _$PluginAuthenticationPresentationBrowserLaunchFailedStateCopyWithImpl(this._self, this._then);

  final PluginAuthenticationPresentationBrowserLaunchFailedState _self;
  final $Res Function(PluginAuthenticationPresentationBrowserLaunchFailedState) _then;

/// Create a copy of PluginAuthenticationPresentationState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? pluginId = null,Object? verificationUri = null,Object? userCode = null,}) {
  return _then(PluginAuthenticationPresentationBrowserLaunchFailedState(
pluginId: null == pluginId ? _self.pluginId : pluginId // ignore: cast_nullable_to_non_nullable
as String,verificationUri: null == verificationUri ? _self.verificationUri : verificationUri // ignore: cast_nullable_to_non_nullable
as Uri,userCode: null == userCode ? _self.userCode : userCode // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class PluginAuthenticationPresentationCancelling implements PluginAuthenticationPresentationState {
  const PluginAuthenticationPresentationCancelling({required this.pluginId, required this.verificationUri, required this.userCode});
  

 final  String pluginId;
 final  Uri verificationUri;
 final  String userCode;

/// Create a copy of PluginAuthenticationPresentationState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginAuthenticationPresentationCancellingCopyWith<PluginAuthenticationPresentationCancelling> get copyWith => _$PluginAuthenticationPresentationCancellingCopyWithImpl<PluginAuthenticationPresentationCancelling>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginAuthenticationPresentationCancelling&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId)&&(identical(other.verificationUri, verificationUri) || other.verificationUri == verificationUri)&&(identical(other.userCode, userCode) || other.userCode == userCode));
}


@override
int get hashCode => Object.hash(runtimeType,pluginId,verificationUri,userCode);

@override
String toString() {
  return 'PluginAuthenticationPresentationState.cancelling(pluginId: $pluginId, verificationUri: $verificationUri, userCode: $userCode)';
}


}

/// @nodoc
abstract mixin class $PluginAuthenticationPresentationCancellingCopyWith<$Res> implements $PluginAuthenticationPresentationStateCopyWith<$Res> {
  factory $PluginAuthenticationPresentationCancellingCopyWith(PluginAuthenticationPresentationCancelling value, $Res Function(PluginAuthenticationPresentationCancelling) _then) = _$PluginAuthenticationPresentationCancellingCopyWithImpl;
@useResult
$Res call({
 String pluginId, Uri verificationUri, String userCode
});




}
/// @nodoc
class _$PluginAuthenticationPresentationCancellingCopyWithImpl<$Res>
    implements $PluginAuthenticationPresentationCancellingCopyWith<$Res> {
  _$PluginAuthenticationPresentationCancellingCopyWithImpl(this._self, this._then);

  final PluginAuthenticationPresentationCancelling _self;
  final $Res Function(PluginAuthenticationPresentationCancelling) _then;

/// Create a copy of PluginAuthenticationPresentationState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? pluginId = null,Object? verificationUri = null,Object? userCode = null,}) {
  return _then(PluginAuthenticationPresentationCancelling(
pluginId: null == pluginId ? _self.pluginId : pluginId // ignore: cast_nullable_to_non_nullable
as String,verificationUri: null == verificationUri ? _self.verificationUri : verificationUri // ignore: cast_nullable_to_non_nullable
as Uri,userCode: null == userCode ? _self.userCode : userCode // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class PluginAuthenticationPresentationCancellingUncertain implements PluginAuthenticationPresentationState {
  const PluginAuthenticationPresentationCancellingUncertain({required this.pluginId, required this.verificationUri, required this.userCode});
  

 final  String pluginId;
 final  Uri verificationUri;
 final  String userCode;

/// Create a copy of PluginAuthenticationPresentationState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginAuthenticationPresentationCancellingUncertainCopyWith<PluginAuthenticationPresentationCancellingUncertain> get copyWith => _$PluginAuthenticationPresentationCancellingUncertainCopyWithImpl<PluginAuthenticationPresentationCancellingUncertain>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginAuthenticationPresentationCancellingUncertain&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId)&&(identical(other.verificationUri, verificationUri) || other.verificationUri == verificationUri)&&(identical(other.userCode, userCode) || other.userCode == userCode));
}


@override
int get hashCode => Object.hash(runtimeType,pluginId,verificationUri,userCode);

@override
String toString() {
  return 'PluginAuthenticationPresentationState.cancellingUncertain(pluginId: $pluginId, verificationUri: $verificationUri, userCode: $userCode)';
}


}

/// @nodoc
abstract mixin class $PluginAuthenticationPresentationCancellingUncertainCopyWith<$Res> implements $PluginAuthenticationPresentationStateCopyWith<$Res> {
  factory $PluginAuthenticationPresentationCancellingUncertainCopyWith(PluginAuthenticationPresentationCancellingUncertain value, $Res Function(PluginAuthenticationPresentationCancellingUncertain) _then) = _$PluginAuthenticationPresentationCancellingUncertainCopyWithImpl;
@useResult
$Res call({
 String pluginId, Uri verificationUri, String userCode
});




}
/// @nodoc
class _$PluginAuthenticationPresentationCancellingUncertainCopyWithImpl<$Res>
    implements $PluginAuthenticationPresentationCancellingUncertainCopyWith<$Res> {
  _$PluginAuthenticationPresentationCancellingUncertainCopyWithImpl(this._self, this._then);

  final PluginAuthenticationPresentationCancellingUncertain _self;
  final $Res Function(PluginAuthenticationPresentationCancellingUncertain) _then;

/// Create a copy of PluginAuthenticationPresentationState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? pluginId = null,Object? verificationUri = null,Object? userCode = null,}) {
  return _then(PluginAuthenticationPresentationCancellingUncertain(
pluginId: null == pluginId ? _self.pluginId : pluginId // ignore: cast_nullable_to_non_nullable
as String,verificationUri: null == verificationUri ? _self.verificationUri : verificationUri // ignore: cast_nullable_to_non_nullable
as Uri,userCode: null == userCode ? _self.userCode : userCode // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class PluginAuthenticationPresentationFailed implements PluginAuthenticationPresentationState {
  const PluginAuthenticationPresentationFailed({required this.pluginId, required this.error});
  

 final  String? pluginId;
 final  PluginAuthenticationPresentationError error;

/// Create a copy of PluginAuthenticationPresentationState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginAuthenticationPresentationFailedCopyWith<PluginAuthenticationPresentationFailed> get copyWith => _$PluginAuthenticationPresentationFailedCopyWithImpl<PluginAuthenticationPresentationFailed>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginAuthenticationPresentationFailed&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,pluginId,error);

@override
String toString() {
  return 'PluginAuthenticationPresentationState.failed(pluginId: $pluginId, error: $error)';
}


}

/// @nodoc
abstract mixin class $PluginAuthenticationPresentationFailedCopyWith<$Res> implements $PluginAuthenticationPresentationStateCopyWith<$Res> {
  factory $PluginAuthenticationPresentationFailedCopyWith(PluginAuthenticationPresentationFailed value, $Res Function(PluginAuthenticationPresentationFailed) _then) = _$PluginAuthenticationPresentationFailedCopyWithImpl;
@useResult
$Res call({
 String? pluginId, PluginAuthenticationPresentationError error
});


$PluginAuthenticationPresentationErrorCopyWith<$Res> get error;

}
/// @nodoc
class _$PluginAuthenticationPresentationFailedCopyWithImpl<$Res>
    implements $PluginAuthenticationPresentationFailedCopyWith<$Res> {
  _$PluginAuthenticationPresentationFailedCopyWithImpl(this._self, this._then);

  final PluginAuthenticationPresentationFailed _self;
  final $Res Function(PluginAuthenticationPresentationFailed) _then;

/// Create a copy of PluginAuthenticationPresentationState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? pluginId = freezed,Object? error = null,}) {
  return _then(PluginAuthenticationPresentationFailed(
pluginId: freezed == pluginId ? _self.pluginId : pluginId // ignore: cast_nullable_to_non_nullable
as String?,error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as PluginAuthenticationPresentationError,
  ));
}

/// Create a copy of PluginAuthenticationPresentationState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginAuthenticationPresentationErrorCopyWith<$Res> get error {
  
  return $PluginAuthenticationPresentationErrorCopyWith<$Res>(_self.error, (value) {
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
  const PluginManagementReady({required this.response, required this.refresh, required this.action, required this.authentication, required  Map<String, PluginInstallProgress> installs}): _installs = installs;
  

 final  PluginManagementResponse response;
 final  PluginManagementRefreshState refresh;
 final  PluginManagementActionState action;
 final  PluginAuthenticationPresentationState authentication;
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginManagementReady&&(identical(other.response, response) || other.response == response)&&(identical(other.refresh, refresh) || other.refresh == refresh)&&(identical(other.action, action) || other.action == action)&&(identical(other.authentication, authentication) || other.authentication == authentication)&&const DeepCollectionEquality().equals(other._installs, _installs));
}


@override
int get hashCode => Object.hash(runtimeType,response,refresh,action,authentication,const DeepCollectionEquality().hash(_installs));

@override
String toString() {
  return 'PluginManagementState.ready(response: $response, refresh: $refresh, action: $action, authentication: $authentication, installs: $installs)';
}


}

/// @nodoc
abstract mixin class $PluginManagementReadyCopyWith<$Res> implements $PluginManagementStateCopyWith<$Res> {
  factory $PluginManagementReadyCopyWith(PluginManagementReady value, $Res Function(PluginManagementReady) _then) = _$PluginManagementReadyCopyWithImpl;
@useResult
$Res call({
 PluginManagementResponse response, PluginManagementRefreshState refresh, PluginManagementActionState action, PluginAuthenticationPresentationState authentication, Map<String, PluginInstallProgress> installs
});


$PluginManagementResponseCopyWith<$Res> get response;$PluginManagementRefreshStateCopyWith<$Res> get refresh;$PluginManagementActionStateCopyWith<$Res> get action;$PluginAuthenticationPresentationStateCopyWith<$Res> get authentication;

}
/// @nodoc
class _$PluginManagementReadyCopyWithImpl<$Res>
    implements $PluginManagementReadyCopyWith<$Res> {
  _$PluginManagementReadyCopyWithImpl(this._self, this._then);

  final PluginManagementReady _self;
  final $Res Function(PluginManagementReady) _then;

/// Create a copy of PluginManagementState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? response = null,Object? refresh = null,Object? action = null,Object? authentication = null,Object? installs = null,}) {
  return _then(PluginManagementReady(
response: null == response ? _self.response : response // ignore: cast_nullable_to_non_nullable
as PluginManagementResponse,refresh: null == refresh ? _self.refresh : refresh // ignore: cast_nullable_to_non_nullable
as PluginManagementRefreshState,action: null == action ? _self.action : action // ignore: cast_nullable_to_non_nullable
as PluginManagementActionState,authentication: null == authentication ? _self.authentication : authentication // ignore: cast_nullable_to_non_nullable
as PluginAuthenticationPresentationState,installs: null == installs ? _self._installs : installs // ignore: cast_nullable_to_non_nullable
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
}/// Create a copy of PluginManagementState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginAuthenticationPresentationStateCopyWith<$Res> get authentication {
  
  return $PluginAuthenticationPresentationStateCopyWith<$Res>(_self.authentication, (value) {
    return _then(_self.copyWith(authentication: value));
  });
}
}

// dart format on
