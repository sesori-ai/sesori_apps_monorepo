// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'notification_preferences_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$NotificationPreferencesState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NotificationPreferencesState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'NotificationPreferencesState()';
}


}

/// @nodoc
class $NotificationPreferencesStateCopyWith<$Res>  {
$NotificationPreferencesStateCopyWith(NotificationPreferencesState _, $Res Function(NotificationPreferencesState) __);
}



/// @nodoc


class NotificationPreferencesLoading implements NotificationPreferencesState {
  const NotificationPreferencesLoading();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NotificationPreferencesLoading);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'NotificationPreferencesState.loading()';
}


}




/// @nodoc


class NotificationPreferencesLoaded implements NotificationPreferencesState {
  const NotificationPreferencesLoaded({required final  Map<NotificationCategory, bool> preferences}): _preferences = preferences;
  

 final  Map<NotificationCategory, bool> _preferences;
 Map<NotificationCategory, bool> get preferences {
  if (_preferences is EqualUnmodifiableMapView) return _preferences;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_preferences);
}


/// Create a copy of NotificationPreferencesState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NotificationPreferencesLoadedCopyWith<NotificationPreferencesLoaded> get copyWith => _$NotificationPreferencesLoadedCopyWithImpl<NotificationPreferencesLoaded>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NotificationPreferencesLoaded&&const DeepCollectionEquality().equals(other._preferences, _preferences));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_preferences));

@override
String toString() {
  return 'NotificationPreferencesState.loaded(preferences: $preferences)';
}


}

/// @nodoc
abstract mixin class $NotificationPreferencesLoadedCopyWith<$Res> implements $NotificationPreferencesStateCopyWith<$Res> {
  factory $NotificationPreferencesLoadedCopyWith(NotificationPreferencesLoaded value, $Res Function(NotificationPreferencesLoaded) _then) = _$NotificationPreferencesLoadedCopyWithImpl;
@useResult
$Res call({
 Map<NotificationCategory, bool> preferences
});




}
/// @nodoc
class _$NotificationPreferencesLoadedCopyWithImpl<$Res>
    implements $NotificationPreferencesLoadedCopyWith<$Res> {
  _$NotificationPreferencesLoadedCopyWithImpl(this._self, this._then);

  final NotificationPreferencesLoaded _self;
  final $Res Function(NotificationPreferencesLoaded) _then;

/// Create a copy of NotificationPreferencesState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? preferences = null,}) {
  return _then(NotificationPreferencesLoaded(
preferences: null == preferences ? _self._preferences : preferences // ignore: cast_nullable_to_non_nullable
as Map<NotificationCategory, bool>,
  ));
}


}

// dart format on
