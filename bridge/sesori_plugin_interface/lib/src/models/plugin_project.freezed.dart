// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plugin_project.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PluginProject {

 String get id; String? get name; PluginProjectTime? get time;
/// Create a copy of PluginProject
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginProjectCopyWith<PluginProject> get copyWith => _$PluginProjectCopyWithImpl<PluginProject>(this as PluginProject, _$identity);

  /// Serializes this PluginProject to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginProject&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.time, time) || other.time == time));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,time);

@override
String toString() {
  return 'PluginProject(id: $id, name: $name, time: $time)';
}


}

/// @nodoc
abstract mixin class $PluginProjectCopyWith<$Res>  {
  factory $PluginProjectCopyWith(PluginProject value, $Res Function(PluginProject) _then) = _$PluginProjectCopyWithImpl;
@useResult
$Res call({
 String id, String? name, PluginProjectTime? time
});


$PluginProjectTimeCopyWith<$Res>? get time;

}
/// @nodoc
class _$PluginProjectCopyWithImpl<$Res>
    implements $PluginProjectCopyWith<$Res> {
  _$PluginProjectCopyWithImpl(this._self, this._then);

  final PluginProject _self;
  final $Res Function(PluginProject) _then;

/// Create a copy of PluginProject
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = freezed,Object? time = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,time: freezed == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as PluginProjectTime?,
  ));
}
/// Create a copy of PluginProject
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginProjectTimeCopyWith<$Res>? get time {
    if (_self.time == null) {
    return null;
  }

  return $PluginProjectTimeCopyWith<$Res>(_self.time!, (value) {
    return _then(_self.copyWith(time: value));
  });
}
}



/// @nodoc
@JsonSerializable(createFactory: false)

class _PluginProject implements PluginProject {
  const _PluginProject({required this.id, this.name, this.time});
  

@override final  String id;
@override final  String? name;
@override final  PluginProjectTime? time;

/// Create a copy of PluginProject
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginProjectCopyWith<_PluginProject> get copyWith => __$PluginProjectCopyWithImpl<_PluginProject>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginProjectToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginProject&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.time, time) || other.time == time));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,time);

@override
String toString() {
  return 'PluginProject(id: $id, name: $name, time: $time)';
}


}

/// @nodoc
abstract mixin class _$PluginProjectCopyWith<$Res> implements $PluginProjectCopyWith<$Res> {
  factory _$PluginProjectCopyWith(_PluginProject value, $Res Function(_PluginProject) _then) = __$PluginProjectCopyWithImpl;
@override @useResult
$Res call({
 String id, String? name, PluginProjectTime? time
});


@override $PluginProjectTimeCopyWith<$Res>? get time;

}
/// @nodoc
class __$PluginProjectCopyWithImpl<$Res>
    implements _$PluginProjectCopyWith<$Res> {
  __$PluginProjectCopyWithImpl(this._self, this._then);

  final _PluginProject _self;
  final $Res Function(_PluginProject) _then;

/// Create a copy of PluginProject
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = freezed,Object? time = freezed,}) {
  return _then(_PluginProject(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,time: freezed == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as PluginProjectTime?,
  ));
}

/// Create a copy of PluginProject
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginProjectTimeCopyWith<$Res>? get time {
    if (_self.time == null) {
    return null;
  }

  return $PluginProjectTimeCopyWith<$Res>(_self.time!, (value) {
    return _then(_self.copyWith(time: value));
  });
}
}

/// @nodoc
mixin _$PluginProjectTime {

 int get created; int get updated; int? get initialized;
/// Create a copy of PluginProjectTime
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginProjectTimeCopyWith<PluginProjectTime> get copyWith => _$PluginProjectTimeCopyWithImpl<PluginProjectTime>(this as PluginProjectTime, _$identity);

  /// Serializes this PluginProjectTime to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginProjectTime&&(identical(other.created, created) || other.created == created)&&(identical(other.updated, updated) || other.updated == updated)&&(identical(other.initialized, initialized) || other.initialized == initialized));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,created,updated,initialized);

@override
String toString() {
  return 'PluginProjectTime(created: $created, updated: $updated, initialized: $initialized)';
}


}

/// @nodoc
abstract mixin class $PluginProjectTimeCopyWith<$Res>  {
  factory $PluginProjectTimeCopyWith(PluginProjectTime value, $Res Function(PluginProjectTime) _then) = _$PluginProjectTimeCopyWithImpl;
@useResult
$Res call({
 int created, int updated, int? initialized
});




}
/// @nodoc
class _$PluginProjectTimeCopyWithImpl<$Res>
    implements $PluginProjectTimeCopyWith<$Res> {
  _$PluginProjectTimeCopyWithImpl(this._self, this._then);

  final PluginProjectTime _self;
  final $Res Function(PluginProjectTime) _then;

/// Create a copy of PluginProjectTime
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? created = null,Object? updated = null,Object? initialized = freezed,}) {
  return _then(_self.copyWith(
created: null == created ? _self.created : created // ignore: cast_nullable_to_non_nullable
as int,updated: null == updated ? _self.updated : updated // ignore: cast_nullable_to_non_nullable
as int,initialized: freezed == initialized ? _self.initialized : initialized // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}



/// @nodoc
@JsonSerializable(createFactory: false)

class _PluginProjectTime implements PluginProjectTime {
  const _PluginProjectTime({required this.created, required this.updated, this.initialized});
  

@override final  int created;
@override final  int updated;
@override final  int? initialized;

/// Create a copy of PluginProjectTime
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginProjectTimeCopyWith<_PluginProjectTime> get copyWith => __$PluginProjectTimeCopyWithImpl<_PluginProjectTime>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginProjectTimeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginProjectTime&&(identical(other.created, created) || other.created == created)&&(identical(other.updated, updated) || other.updated == updated)&&(identical(other.initialized, initialized) || other.initialized == initialized));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,created,updated,initialized);

@override
String toString() {
  return 'PluginProjectTime(created: $created, updated: $updated, initialized: $initialized)';
}


}

/// @nodoc
abstract mixin class _$PluginProjectTimeCopyWith<$Res> implements $PluginProjectTimeCopyWith<$Res> {
  factory _$PluginProjectTimeCopyWith(_PluginProjectTime value, $Res Function(_PluginProjectTime) _then) = __$PluginProjectTimeCopyWithImpl;
@override @useResult
$Res call({
 int created, int updated, int? initialized
});




}
/// @nodoc
class __$PluginProjectTimeCopyWithImpl<$Res>
    implements _$PluginProjectTimeCopyWith<$Res> {
  __$PluginProjectTimeCopyWithImpl(this._self, this._then);

  final _PluginProjectTime _self;
  final $Res Function(_PluginProjectTime) _then;

/// Create a copy of PluginProjectTime
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? created = null,Object? updated = null,Object? initialized = freezed,}) {
  return _then(_PluginProjectTime(
created: null == created ? _self.created : created // ignore: cast_nullable_to_non_nullable
as int,updated: null == updated ? _self.updated : updated // ignore: cast_nullable_to_non_nullable
as int,initialized: freezed == initialized ? _self.initialized : initialized // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
