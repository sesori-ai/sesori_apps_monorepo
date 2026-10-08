// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'open_code_service_registration.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$OpenCodeServiceRegistration {

 String get url; int get pid; String? get password;
/// Create a copy of OpenCodeServiceRegistration
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OpenCodeServiceRegistrationCopyWith<OpenCodeServiceRegistration> get copyWith => _$OpenCodeServiceRegistrationCopyWithImpl<OpenCodeServiceRegistration>(this as OpenCodeServiceRegistration, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as OpenCodeServiceRegistration;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OpenCodeServiceRegistration&&(identical(other.url, _this.url) || other.url == _this.url)&&(identical(other.pid, _this.pid) || other.pid == _this.pid)&&(identical(other.password, _this.password) || other.password == _this.password));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as OpenCodeServiceRegistration;
  return Object.hash(runtimeType,_this.url,_this.pid,_this.password);
}



}

/// @nodoc
abstract mixin class $OpenCodeServiceRegistrationCopyWith<$Res>  {
  factory $OpenCodeServiceRegistrationCopyWith(OpenCodeServiceRegistration value, $Res Function(OpenCodeServiceRegistration) _then) = _$OpenCodeServiceRegistrationCopyWithImpl;
@useResult
$Res call({
 String url, int pid, String? password
});




}
/// @nodoc
class _$OpenCodeServiceRegistrationCopyWithImpl<$Res>
    implements $OpenCodeServiceRegistrationCopyWith<$Res> {
  _$OpenCodeServiceRegistrationCopyWithImpl(this._self, this._then);

  final OpenCodeServiceRegistration _self;
  final $Res Function(OpenCodeServiceRegistration) _then;

/// Create a copy of OpenCodeServiceRegistration
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? url = null,Object? pid = null,Object? password = freezed,}) {
  return _then(OpenCodeServiceRegistration(
url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,pid: null == pid ? _self.pid : pid // ignore: cast_nullable_to_non_nullable
as int,password: freezed == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc

@JsonSerializable(checked: true)
class _OpenCodeServiceRegistration implements OpenCodeServiceRegistration {
  const _OpenCodeServiceRegistration({required this.url, required this.pid, required this.password});
  factory _OpenCodeServiceRegistration.fromJson(Map<String, dynamic> json) => _$OpenCodeServiceRegistrationFromJson(json);

@override final  String url;
@override final  int pid;
@override final  String? password;

/// Create a copy of OpenCodeServiceRegistration
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OpenCodeServiceRegistrationCopyWith<_OpenCodeServiceRegistration> get copyWith => __$OpenCodeServiceRegistrationCopyWithImpl<_OpenCodeServiceRegistration>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _OpenCodeServiceRegistration&&(identical(other.url, url) || other.url == url)&&(identical(other.pid, pid) || other.pid == pid)&&(identical(other.password, password) || other.password == password));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,url,pid,password);
}



}

/// @nodoc
abstract mixin class _$OpenCodeServiceRegistrationCopyWith<$Res> implements $OpenCodeServiceRegistrationCopyWith<$Res> {
  factory _$OpenCodeServiceRegistrationCopyWith(_OpenCodeServiceRegistration value, $Res Function(_OpenCodeServiceRegistration) _then) = __$OpenCodeServiceRegistrationCopyWithImpl;
@override @useResult
$Res call({
 String url, int pid, String? password
});




}
/// @nodoc
class __$OpenCodeServiceRegistrationCopyWithImpl<$Res>
    implements _$OpenCodeServiceRegistrationCopyWith<$Res> {
  __$OpenCodeServiceRegistrationCopyWithImpl(this._self, this._then);

  final _OpenCodeServiceRegistration _self;
  final $Res Function(_OpenCodeServiceRegistration) _then;

/// Create a copy of OpenCodeServiceRegistration
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? url = null,Object? pid = null,Object? password = freezed,}) {
  return _then(_OpenCodeServiceRegistration(
url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,pid: null == pid ? _self.pid : pid // ignore: cast_nullable_to_non_nullable
as int,password: freezed == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
