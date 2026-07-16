// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'deleted_sessions_table.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DeletedSessionDto {

 String get ownerIdentity; String get backendSessionId; String get pluginId; int get deletedAt;
/// Create a copy of DeletedSessionDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeletedSessionDtoCopyWith<DeletedSessionDto> get copyWith => _$DeletedSessionDtoCopyWithImpl<DeletedSessionDto>(this as DeletedSessionDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeletedSessionDto&&(identical(other.ownerIdentity, ownerIdentity) || other.ownerIdentity == ownerIdentity)&&(identical(other.backendSessionId, backendSessionId) || other.backendSessionId == backendSessionId)&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt));
}


@override
int get hashCode => Object.hash(runtimeType,ownerIdentity,backendSessionId,pluginId,deletedAt);

@override
String toString() {
  return 'DeletedSessionDto(ownerIdentity: $ownerIdentity, backendSessionId: $backendSessionId, pluginId: $pluginId, deletedAt: $deletedAt)';
}


}

/// @nodoc
abstract mixin class $DeletedSessionDtoCopyWith<$Res>  {
  factory $DeletedSessionDtoCopyWith(DeletedSessionDto value, $Res Function(DeletedSessionDto) _then) = _$DeletedSessionDtoCopyWithImpl;
@useResult
$Res call({
 String ownerIdentity, String backendSessionId, String pluginId, int deletedAt
});




}
/// @nodoc
class _$DeletedSessionDtoCopyWithImpl<$Res>
    implements $DeletedSessionDtoCopyWith<$Res> {
  _$DeletedSessionDtoCopyWithImpl(this._self, this._then);

  final DeletedSessionDto _self;
  final $Res Function(DeletedSessionDto) _then;

/// Create a copy of DeletedSessionDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? ownerIdentity = null,Object? backendSessionId = null,Object? pluginId = null,Object? deletedAt = null,}) {
  return _then(_self.copyWith(
ownerIdentity: null == ownerIdentity ? _self.ownerIdentity : ownerIdentity // ignore: cast_nullable_to_non_nullable
as String,backendSessionId: null == backendSessionId ? _self.backendSessionId : backendSessionId // ignore: cast_nullable_to_non_nullable
as String,pluginId: null == pluginId ? _self.pluginId : pluginId // ignore: cast_nullable_to_non_nullable
as String,deletedAt: null == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}



/// @nodoc


class _DeletedSessionDto extends DeletedSessionDto {
  const _DeletedSessionDto({required this.ownerIdentity, required this.backendSessionId, required this.pluginId, required this.deletedAt}): super._();
  

@override final  String ownerIdentity;
@override final  String backendSessionId;
@override final  String pluginId;
@override final  int deletedAt;

/// Create a copy of DeletedSessionDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeletedSessionDtoCopyWith<_DeletedSessionDto> get copyWith => __$DeletedSessionDtoCopyWithImpl<_DeletedSessionDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeletedSessionDto&&(identical(other.ownerIdentity, ownerIdentity) || other.ownerIdentity == ownerIdentity)&&(identical(other.backendSessionId, backendSessionId) || other.backendSessionId == backendSessionId)&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt));
}


@override
int get hashCode => Object.hash(runtimeType,ownerIdentity,backendSessionId,pluginId,deletedAt);

@override
String toString() {
  return 'DeletedSessionDto(ownerIdentity: $ownerIdentity, backendSessionId: $backendSessionId, pluginId: $pluginId, deletedAt: $deletedAt)';
}


}

/// @nodoc
abstract mixin class _$DeletedSessionDtoCopyWith<$Res> implements $DeletedSessionDtoCopyWith<$Res> {
  factory _$DeletedSessionDtoCopyWith(_DeletedSessionDto value, $Res Function(_DeletedSessionDto) _then) = __$DeletedSessionDtoCopyWithImpl;
@override @useResult
$Res call({
 String ownerIdentity, String backendSessionId, String pluginId, int deletedAt
});




}
/// @nodoc
class __$DeletedSessionDtoCopyWithImpl<$Res>
    implements _$DeletedSessionDtoCopyWith<$Res> {
  __$DeletedSessionDtoCopyWithImpl(this._self, this._then);

  final _DeletedSessionDto _self;
  final $Res Function(_DeletedSessionDto) _then;

/// Create a copy of DeletedSessionDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? ownerIdentity = null,Object? backendSessionId = null,Object? pluginId = null,Object? deletedAt = null,}) {
  return _then(_DeletedSessionDto(
ownerIdentity: null == ownerIdentity ? _self.ownerIdentity : ownerIdentity // ignore: cast_nullable_to_non_nullable
as String,backendSessionId: null == backendSessionId ? _self.backendSessionId : backendSessionId // ignore: cast_nullable_to_non_nullable
as String,pluginId: null == pluginId ? _self.pluginId : pluginId // ignore: cast_nullable_to_non_nullable
as String,deletedAt: null == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
