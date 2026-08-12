// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'codex_desktop_state_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CodexDesktopStateDto {

@JsonKey(name: "projectless-thread-ids")@CodexProjectlessThreadIdsConverter() Set<String> get projectlessThreadIds;
/// Create a copy of CodexDesktopStateDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexDesktopStateDtoCopyWith<CodexDesktopStateDto> get copyWith => _$CodexDesktopStateDtoCopyWithImpl<CodexDesktopStateDto>(this as CodexDesktopStateDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexDesktopStateDto&&const DeepCollectionEquality().equals(other.projectlessThreadIds, projectlessThreadIds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(projectlessThreadIds));

@override
String toString() {
  return 'CodexDesktopStateDto(projectlessThreadIds: $projectlessThreadIds)';
}


}

/// @nodoc
abstract mixin class $CodexDesktopStateDtoCopyWith<$Res>  {
  factory $CodexDesktopStateDtoCopyWith(CodexDesktopStateDto value, $Res Function(CodexDesktopStateDto) _then) = _$CodexDesktopStateDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: "projectless-thread-ids")@CodexProjectlessThreadIdsConverter() Set<String> projectlessThreadIds
});




}
/// @nodoc
class _$CodexDesktopStateDtoCopyWithImpl<$Res>
    implements $CodexDesktopStateDtoCopyWith<$Res> {
  _$CodexDesktopStateDtoCopyWithImpl(this._self, this._then);

  final CodexDesktopStateDto _self;
  final $Res Function(CodexDesktopStateDto) _then;

/// Create a copy of CodexDesktopStateDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? projectlessThreadIds = null,}) {
  return _then(CodexDesktopStateDto(
projectlessThreadIds: null == projectlessThreadIds ? _self.projectlessThreadIds : projectlessThreadIds // ignore: cast_nullable_to_non_nullable
as Set<String>,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _CodexDesktopStateDto implements CodexDesktopStateDto {
  const _CodexDesktopStateDto({@JsonKey(name: "projectless-thread-ids")@CodexProjectlessThreadIdsConverter() required  Set<String> projectlessThreadIds}): _projectlessThreadIds = projectlessThreadIds;
  factory _CodexDesktopStateDto.fromJson(Map<String, dynamic> json) => _$CodexDesktopStateDtoFromJson(json);

 final  Set<String> _projectlessThreadIds;
@override@JsonKey(name: "projectless-thread-ids")@CodexProjectlessThreadIdsConverter() Set<String> get projectlessThreadIds {
  if (_projectlessThreadIds is EqualUnmodifiableSetView) return _projectlessThreadIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_projectlessThreadIds);
}


/// Create a copy of CodexDesktopStateDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexDesktopStateDtoCopyWith<_CodexDesktopStateDto> get copyWith => __$CodexDesktopStateDtoCopyWithImpl<_CodexDesktopStateDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexDesktopStateDto&&const DeepCollectionEquality().equals(other._projectlessThreadIds, _projectlessThreadIds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_projectlessThreadIds));

@override
String toString() {
  return 'CodexDesktopStateDto(projectlessThreadIds: $projectlessThreadIds)';
}


}

/// @nodoc
abstract mixin class _$CodexDesktopStateDtoCopyWith<$Res> implements $CodexDesktopStateDtoCopyWith<$Res> {
  factory _$CodexDesktopStateDtoCopyWith(_CodexDesktopStateDto value, $Res Function(_CodexDesktopStateDto) _then) = __$CodexDesktopStateDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: "projectless-thread-ids")@CodexProjectlessThreadIdsConverter() Set<String> projectlessThreadIds
});




}
/// @nodoc
class __$CodexDesktopStateDtoCopyWithImpl<$Res>
    implements _$CodexDesktopStateDtoCopyWith<$Res> {
  __$CodexDesktopStateDtoCopyWithImpl(this._self, this._then);

  final _CodexDesktopStateDto _self;
  final $Res Function(_CodexDesktopStateDto) _then;

/// Create a copy of CodexDesktopStateDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? projectlessThreadIds = null,}) {
  return _then(_CodexDesktopStateDto(
projectlessThreadIds: null == projectlessThreadIds ? _self._projectlessThreadIds : projectlessThreadIds // ignore: cast_nullable_to_non_nullable
as Set<String>,
  ));
}


}

// dart format on
