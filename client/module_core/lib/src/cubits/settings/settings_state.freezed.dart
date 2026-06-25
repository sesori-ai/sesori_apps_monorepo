// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'settings_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SettingsState {

/// The account this device is signed in as, or `null` when there is no
/// authenticated session. Driven reactively by the auth state stream.
 AuthUser? get account; SettingsLogoutStatus get logoutStatus;
/// Create a copy of SettingsState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SettingsStateCopyWith<SettingsState> get copyWith => _$SettingsStateCopyWithImpl<SettingsState>(this as SettingsState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SettingsState&&(identical(other.account, account) || other.account == account)&&(identical(other.logoutStatus, logoutStatus) || other.logoutStatus == logoutStatus));
}


@override
int get hashCode => Object.hash(runtimeType,account,logoutStatus);

@override
String toString() {
  return 'SettingsState(account: $account, logoutStatus: $logoutStatus)';
}


}

/// @nodoc
abstract mixin class $SettingsStateCopyWith<$Res>  {
  factory $SettingsStateCopyWith(SettingsState value, $Res Function(SettingsState) _then) = _$SettingsStateCopyWithImpl;
@useResult
$Res call({
 AuthUser? account, SettingsLogoutStatus logoutStatus
});


$AuthUserCopyWith<$Res>? get account;

}
/// @nodoc
class _$SettingsStateCopyWithImpl<$Res>
    implements $SettingsStateCopyWith<$Res> {
  _$SettingsStateCopyWithImpl(this._self, this._then);

  final SettingsState _self;
  final $Res Function(SettingsState) _then;

/// Create a copy of SettingsState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? account = freezed,Object? logoutStatus = null,}) {
  return _then(_self.copyWith(
account: freezed == account ? _self.account : account // ignore: cast_nullable_to_non_nullable
as AuthUser?,logoutStatus: null == logoutStatus ? _self.logoutStatus : logoutStatus // ignore: cast_nullable_to_non_nullable
as SettingsLogoutStatus,
  ));
}
/// Create a copy of SettingsState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AuthUserCopyWith<$Res>? get account {
    if (_self.account == null) {
    return null;
  }

  return $AuthUserCopyWith<$Res>(_self.account!, (value) {
    return _then(_self.copyWith(account: value));
  });
}
}



/// @nodoc


class _SettingsState implements SettingsState {
  const _SettingsState({required this.account, this.logoutStatus = SettingsLogoutStatus.idle});
  

/// The account this device is signed in as, or `null` when there is no
/// authenticated session. Driven reactively by the auth state stream.
@override final  AuthUser? account;
@override@JsonKey() final  SettingsLogoutStatus logoutStatus;

/// Create a copy of SettingsState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SettingsStateCopyWith<_SettingsState> get copyWith => __$SettingsStateCopyWithImpl<_SettingsState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SettingsState&&(identical(other.account, account) || other.account == account)&&(identical(other.logoutStatus, logoutStatus) || other.logoutStatus == logoutStatus));
}


@override
int get hashCode => Object.hash(runtimeType,account,logoutStatus);

@override
String toString() {
  return 'SettingsState(account: $account, logoutStatus: $logoutStatus)';
}


}

/// @nodoc
abstract mixin class _$SettingsStateCopyWith<$Res> implements $SettingsStateCopyWith<$Res> {
  factory _$SettingsStateCopyWith(_SettingsState value, $Res Function(_SettingsState) _then) = __$SettingsStateCopyWithImpl;
@override @useResult
$Res call({
 AuthUser? account, SettingsLogoutStatus logoutStatus
});


@override $AuthUserCopyWith<$Res>? get account;

}
/// @nodoc
class __$SettingsStateCopyWithImpl<$Res>
    implements _$SettingsStateCopyWith<$Res> {
  __$SettingsStateCopyWithImpl(this._self, this._then);

  final _SettingsState _self;
  final $Res Function(_SettingsState) _then;

/// Create a copy of SettingsState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? account = freezed,Object? logoutStatus = null,}) {
  return _then(_SettingsState(
account: freezed == account ? _self.account : account // ignore: cast_nullable_to_non_nullable
as AuthUser?,logoutStatus: null == logoutStatus ? _self.logoutStatus : logoutStatus // ignore: cast_nullable_to_non_nullable
as SettingsLogoutStatus,
  ));
}

/// Create a copy of SettingsState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AuthUserCopyWith<$Res>? get account {
    if (_self.account == null) {
    return null;
  }

  return $AuthUserCopyWith<$Res>(_self.account!, (value) {
    return _then(_self.copyWith(account: value));
  });
}
}

// dart format on
