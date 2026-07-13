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

 String get id; String get directory; String? get name; PluginProjectActivity? get activity;
/// Create a copy of PluginProject
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginProjectCopyWith<PluginProject> get copyWith => _$PluginProjectCopyWithImpl<PluginProject>(this as PluginProject, _$identity);

  /// Serializes this PluginProject to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginProject&&(identical(other.id, id) || other.id == id)&&(identical(other.directory, directory) || other.directory == directory)&&(identical(other.name, name) || other.name == name)&&(identical(other.activity, activity) || other.activity == activity));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,directory,name,activity);

@override
String toString() {
  return 'PluginProject(id: $id, directory: $directory, name: $name, activity: $activity)';
}


}

/// @nodoc
abstract mixin class $PluginProjectCopyWith<$Res>  {
  factory $PluginProjectCopyWith(PluginProject value, $Res Function(PluginProject) _then) = _$PluginProjectCopyWithImpl;
@useResult
$Res call({
 String id, String directory, String? name, PluginProjectActivity? activity
});


$PluginProjectActivityCopyWith<$Res>? get activity;

}
/// @nodoc
class _$PluginProjectCopyWithImpl<$Res>
    implements $PluginProjectCopyWith<$Res> {
  _$PluginProjectCopyWithImpl(this._self, this._then);

  final PluginProject _self;
  final $Res Function(PluginProject) _then;

/// Create a copy of PluginProject
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? directory = null,Object? name = freezed,Object? activity = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,directory: null == directory ? _self.directory : directory // ignore: cast_nullable_to_non_nullable
as String,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,activity: freezed == activity ? _self.activity : activity // ignore: cast_nullable_to_non_nullable
as PluginProjectActivity?,
  ));
}
/// Create a copy of PluginProject
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginProjectActivityCopyWith<$Res>? get activity {
    if (_self.activity == null) {
    return null;
  }

  return $PluginProjectActivityCopyWith<$Res>(_self.activity!, (value) {
    return _then(_self.copyWith(activity: value));
  });
}
}



/// @nodoc
@JsonSerializable(createFactory: false)

class _PluginProject implements PluginProject {
  const _PluginProject({required this.id, required this.directory, this.name, this.activity});
  

@override final  String id;
@override final  String directory;
@override final  String? name;
@override final  PluginProjectActivity? activity;

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginProject&&(identical(other.id, id) || other.id == id)&&(identical(other.directory, directory) || other.directory == directory)&&(identical(other.name, name) || other.name == name)&&(identical(other.activity, activity) || other.activity == activity));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,directory,name,activity);

@override
String toString() {
  return 'PluginProject(id: $id, directory: $directory, name: $name, activity: $activity)';
}


}

/// @nodoc
abstract mixin class _$PluginProjectCopyWith<$Res> implements $PluginProjectCopyWith<$Res> {
  factory _$PluginProjectCopyWith(_PluginProject value, $Res Function(_PluginProject) _then) = __$PluginProjectCopyWithImpl;
@override @useResult
$Res call({
 String id, String directory, String? name, PluginProjectActivity? activity
});


@override $PluginProjectActivityCopyWith<$Res>? get activity;

}
/// @nodoc
class __$PluginProjectCopyWithImpl<$Res>
    implements _$PluginProjectCopyWith<$Res> {
  __$PluginProjectCopyWithImpl(this._self, this._then);

  final _PluginProject _self;
  final $Res Function(_PluginProject) _then;

/// Create a copy of PluginProject
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? directory = null,Object? name = freezed,Object? activity = freezed,}) {
  return _then(_PluginProject(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,directory: null == directory ? _self.directory : directory // ignore: cast_nullable_to_non_nullable
as String,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,activity: freezed == activity ? _self.activity : activity // ignore: cast_nullable_to_non_nullable
as PluginProjectActivity?,
  ));
}

/// Create a copy of PluginProject
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginProjectActivityCopyWith<$Res>? get activity {
    if (_self.activity == null) {
    return null;
  }

  return $PluginProjectActivityCopyWith<$Res>(_self.activity!, (value) {
    return _then(_self.copyWith(activity: value));
  });
}
}

/// @nodoc
mixin _$PluginProjectActivity {

 int get createdAt; int get updatedAt;
/// Create a copy of PluginProjectActivity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginProjectActivityCopyWith<PluginProjectActivity> get copyWith => _$PluginProjectActivityCopyWithImpl<PluginProjectActivity>(this as PluginProjectActivity, _$identity);

  /// Serializes this PluginProjectActivity to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginProjectActivity&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,createdAt,updatedAt);

@override
String toString() {
  return 'PluginProjectActivity(createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $PluginProjectActivityCopyWith<$Res>  {
  factory $PluginProjectActivityCopyWith(PluginProjectActivity value, $Res Function(PluginProjectActivity) _then) = _$PluginProjectActivityCopyWithImpl;
@useResult
$Res call({
 int createdAt, int updatedAt
});




}
/// @nodoc
class _$PluginProjectActivityCopyWithImpl<$Res>
    implements $PluginProjectActivityCopyWith<$Res> {
  _$PluginProjectActivityCopyWithImpl(this._self, this._then);

  final PluginProjectActivity _self;
  final $Res Function(PluginProjectActivity) _then;

/// Create a copy of PluginProjectActivity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}



/// @nodoc
@JsonSerializable(createFactory: false)

class _PluginProjectActivity implements PluginProjectActivity {
  const _PluginProjectActivity({required this.createdAt, required this.updatedAt});
  

@override final  int createdAt;
@override final  int updatedAt;

/// Create a copy of PluginProjectActivity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginProjectActivityCopyWith<_PluginProjectActivity> get copyWith => __$PluginProjectActivityCopyWithImpl<_PluginProjectActivity>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginProjectActivityToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginProjectActivity&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,createdAt,updatedAt);

@override
String toString() {
  return 'PluginProjectActivity(createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$PluginProjectActivityCopyWith<$Res> implements $PluginProjectActivityCopyWith<$Res> {
  factory _$PluginProjectActivityCopyWith(_PluginProjectActivity value, $Res Function(_PluginProjectActivity) _then) = __$PluginProjectActivityCopyWithImpl;
@override @useResult
$Res call({
 int createdAt, int updatedAt
});




}
/// @nodoc
class __$PluginProjectActivityCopyWithImpl<$Res>
    implements _$PluginProjectActivityCopyWith<$Res> {
  __$PluginProjectActivityCopyWithImpl(this._self, this._then);

  final _PluginProjectActivity _self;
  final $Res Function(_PluginProjectActivity) _then;

/// Create a copy of PluginProjectActivity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_PluginProjectActivity(
createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
