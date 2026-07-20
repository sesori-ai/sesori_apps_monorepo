// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plugin_management_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PluginManagementLoadResult {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginManagementLoadResult);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PluginManagementLoadResult()';
}


}

/// @nodoc
class $PluginManagementLoadResultCopyWith<$Res>  {
$PluginManagementLoadResultCopyWith(PluginManagementLoadResult _, $Res Function(PluginManagementLoadResult) __);
}



/// @nodoc


class PluginManagementSupported implements PluginManagementLoadResult {
  const PluginManagementSupported({required this.response});
  

 final  PluginManagementResponse response;

/// Create a copy of PluginManagementLoadResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginManagementSupportedCopyWith<PluginManagementSupported> get copyWith => _$PluginManagementSupportedCopyWithImpl<PluginManagementSupported>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginManagementSupported&&(identical(other.response, response) || other.response == response));
}


@override
int get hashCode => Object.hash(runtimeType,response);

@override
String toString() {
  return 'PluginManagementLoadResult.supported(response: $response)';
}


}

/// @nodoc
abstract mixin class $PluginManagementSupportedCopyWith<$Res> implements $PluginManagementLoadResultCopyWith<$Res> {
  factory $PluginManagementSupportedCopyWith(PluginManagementSupported value, $Res Function(PluginManagementSupported) _then) = _$PluginManagementSupportedCopyWithImpl;
@useResult
$Res call({
 PluginManagementResponse response
});


$PluginManagementResponseCopyWith<$Res> get response;

}
/// @nodoc
class _$PluginManagementSupportedCopyWithImpl<$Res>
    implements $PluginManagementSupportedCopyWith<$Res> {
  _$PluginManagementSupportedCopyWithImpl(this._self, this._then);

  final PluginManagementSupported _self;
  final $Res Function(PluginManagementSupported) _then;

/// Create a copy of PluginManagementLoadResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? response = null,}) {
  return _then(PluginManagementSupported(
response: null == response ? _self.response : response // ignore: cast_nullable_to_non_nullable
as PluginManagementResponse,
  ));
}

/// Create a copy of PluginManagementLoadResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginManagementResponseCopyWith<$Res> get response {
  
  return $PluginManagementResponseCopyWith<$Res>(_self.response, (value) {
    return _then(_self.copyWith(response: value));
  });
}
}

/// @nodoc


class PluginManagementUnsupported implements PluginManagementLoadResult {
  const PluginManagementUnsupported();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginManagementUnsupported);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PluginManagementLoadResult.unsupported()';
}


}




/// @nodoc


class PluginManagementLoadFailure implements PluginManagementLoadResult {
  const PluginManagementLoadFailure({required this.error});
  

 final  ApiError error;

/// Create a copy of PluginManagementLoadResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginManagementLoadFailureCopyWith<PluginManagementLoadFailure> get copyWith => _$PluginManagementLoadFailureCopyWithImpl<PluginManagementLoadFailure>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginManagementLoadFailure&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,error);

@override
String toString() {
  return 'PluginManagementLoadResult.failure(error: $error)';
}


}

/// @nodoc
abstract mixin class $PluginManagementLoadFailureCopyWith<$Res> implements $PluginManagementLoadResultCopyWith<$Res> {
  factory $PluginManagementLoadFailureCopyWith(PluginManagementLoadFailure value, $Res Function(PluginManagementLoadFailure) _then) = _$PluginManagementLoadFailureCopyWithImpl;
@useResult
$Res call({
 ApiError error
});


$ApiErrorCopyWith<$Res> get error;

}
/// @nodoc
class _$PluginManagementLoadFailureCopyWithImpl<$Res>
    implements $PluginManagementLoadFailureCopyWith<$Res> {
  _$PluginManagementLoadFailureCopyWithImpl(this._self, this._then);

  final PluginManagementLoadFailure _self;
  final $Res Function(PluginManagementLoadFailure) _then;

/// Create a copy of PluginManagementLoadResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? error = null,}) {
  return _then(PluginManagementLoadFailure(
error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as ApiError,
  ));
}

/// Create a copy of PluginManagementLoadResult
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
mixin _$PluginManagementMutationResult {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginManagementMutationResult);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PluginManagementMutationResult()';
}


}

/// @nodoc
class $PluginManagementMutationResultCopyWith<$Res>  {
$PluginManagementMutationResultCopyWith(PluginManagementMutationResult _, $Res Function(PluginManagementMutationResult) __);
}



/// @nodoc


class PluginManagementMutationSuccess implements PluginManagementMutationResult {
  const PluginManagementMutationSuccess({required this.response});
  

 final  PluginManagementResponse response;

/// Create a copy of PluginManagementMutationResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginManagementMutationSuccessCopyWith<PluginManagementMutationSuccess> get copyWith => _$PluginManagementMutationSuccessCopyWithImpl<PluginManagementMutationSuccess>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginManagementMutationSuccess&&(identical(other.response, response) || other.response == response));
}


@override
int get hashCode => Object.hash(runtimeType,response);

@override
String toString() {
  return 'PluginManagementMutationResult.success(response: $response)';
}


}

/// @nodoc
abstract mixin class $PluginManagementMutationSuccessCopyWith<$Res> implements $PluginManagementMutationResultCopyWith<$Res> {
  factory $PluginManagementMutationSuccessCopyWith(PluginManagementMutationSuccess value, $Res Function(PluginManagementMutationSuccess) _then) = _$PluginManagementMutationSuccessCopyWithImpl;
@useResult
$Res call({
 PluginManagementResponse response
});


$PluginManagementResponseCopyWith<$Res> get response;

}
/// @nodoc
class _$PluginManagementMutationSuccessCopyWithImpl<$Res>
    implements $PluginManagementMutationSuccessCopyWith<$Res> {
  _$PluginManagementMutationSuccessCopyWithImpl(this._self, this._then);

  final PluginManagementMutationSuccess _self;
  final $Res Function(PluginManagementMutationSuccess) _then;

/// Create a copy of PluginManagementMutationResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? response = null,}) {
  return _then(PluginManagementMutationSuccess(
response: null == response ? _self.response : response // ignore: cast_nullable_to_non_nullable
as PluginManagementResponse,
  ));
}

/// Create a copy of PluginManagementMutationResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginManagementResponseCopyWith<$Res> get response {
  
  return $PluginManagementResponseCopyWith<$Res>(_self.response, (value) {
    return _then(_self.copyWith(response: value));
  });
}
}

/// @nodoc


class PluginManagementMutationNotFound implements PluginManagementMutationResult {
  const PluginManagementMutationNotFound();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginManagementMutationNotFound);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PluginManagementMutationResult.notFound()';
}


}




/// @nodoc


class PluginManagementMutationConflict implements PluginManagementMutationResult {
  const PluginManagementMutationConflict({required this.conflict});
  

 final  PluginLifecycleConflict conflict;

/// Create a copy of PluginManagementMutationResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginManagementMutationConflictCopyWith<PluginManagementMutationConflict> get copyWith => _$PluginManagementMutationConflictCopyWithImpl<PluginManagementMutationConflict>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginManagementMutationConflict&&(identical(other.conflict, conflict) || other.conflict == conflict));
}


@override
int get hashCode => Object.hash(runtimeType,conflict);

@override
String toString() {
  return 'PluginManagementMutationResult.conflict(conflict: $conflict)';
}


}

/// @nodoc
abstract mixin class $PluginManagementMutationConflictCopyWith<$Res> implements $PluginManagementMutationResultCopyWith<$Res> {
  factory $PluginManagementMutationConflictCopyWith(PluginManagementMutationConflict value, $Res Function(PluginManagementMutationConflict) _then) = _$PluginManagementMutationConflictCopyWithImpl;
@useResult
$Res call({
 PluginLifecycleConflict conflict
});


$PluginLifecycleConflictCopyWith<$Res> get conflict;

}
/// @nodoc
class _$PluginManagementMutationConflictCopyWithImpl<$Res>
    implements $PluginManagementMutationConflictCopyWith<$Res> {
  _$PluginManagementMutationConflictCopyWithImpl(this._self, this._then);

  final PluginManagementMutationConflict _self;
  final $Res Function(PluginManagementMutationConflict) _then;

/// Create a copy of PluginManagementMutationResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? conflict = null,}) {
  return _then(PluginManagementMutationConflict(
conflict: null == conflict ? _self.conflict : conflict // ignore: cast_nullable_to_non_nullable
as PluginLifecycleConflict,
  ));
}

/// Create a copy of PluginManagementMutationResult
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


class PluginManagementMutationFailure implements PluginManagementMutationResult {
  const PluginManagementMutationFailure({required this.error});
  

 final  ApiError error;

/// Create a copy of PluginManagementMutationResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginManagementMutationFailureCopyWith<PluginManagementMutationFailure> get copyWith => _$PluginManagementMutationFailureCopyWithImpl<PluginManagementMutationFailure>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginManagementMutationFailure&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,error);

@override
String toString() {
  return 'PluginManagementMutationResult.failure(error: $error)';
}


}

/// @nodoc
abstract mixin class $PluginManagementMutationFailureCopyWith<$Res> implements $PluginManagementMutationResultCopyWith<$Res> {
  factory $PluginManagementMutationFailureCopyWith(PluginManagementMutationFailure value, $Res Function(PluginManagementMutationFailure) _then) = _$PluginManagementMutationFailureCopyWithImpl;
@useResult
$Res call({
 ApiError error
});


$ApiErrorCopyWith<$Res> get error;

}
/// @nodoc
class _$PluginManagementMutationFailureCopyWithImpl<$Res>
    implements $PluginManagementMutationFailureCopyWith<$Res> {
  _$PluginManagementMutationFailureCopyWithImpl(this._self, this._then);

  final PluginManagementMutationFailure _self;
  final $Res Function(PluginManagementMutationFailure) _then;

/// Create a copy of PluginManagementMutationResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? error = null,}) {
  return _then(PluginManagementMutationFailure(
error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as ApiError,
  ));
}

/// Create a copy of PluginManagementMutationResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ApiErrorCopyWith<$Res> get error {
  
  return $ApiErrorCopyWith<$Res>(_self.error, (value) {
    return _then(_self.copyWith(error: value));
  });
}
}

// dart format on
