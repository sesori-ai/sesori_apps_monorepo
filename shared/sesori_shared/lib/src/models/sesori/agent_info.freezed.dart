// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'agent_info.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Agents {

 List<AgentInfo> get agents;
/// Create a copy of Agents
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentsCopyWith<Agents> get copyWith => _$AgentsCopyWithImpl<Agents>(this as Agents, _$identity);

  /// Serializes this Agents to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Agents&&const DeepCollectionEquality().equals(other.agents, agents));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(agents));

@override
String toString() {
  return 'Agents(agents: $agents)';
}


}

/// @nodoc
abstract mixin class $AgentsCopyWith<$Res>  {
  factory $AgentsCopyWith(Agents value, $Res Function(Agents) _then) = _$AgentsCopyWithImpl;
@useResult
$Res call({
 List<AgentInfo> agents
});




}
/// @nodoc
class _$AgentsCopyWithImpl<$Res>
    implements $AgentsCopyWith<$Res> {
  _$AgentsCopyWithImpl(this._self, this._then);

  final Agents _self;
  final $Res Function(Agents) _then;

/// Create a copy of Agents
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? agents = null,}) {
  return _then(_self.copyWith(
agents: null == agents ? _self.agents : agents // ignore: cast_nullable_to_non_nullable
as List<AgentInfo>,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _Agents implements Agents {
  const _Agents({required final  List<AgentInfo> agents}): _agents = agents;
  factory _Agents.fromJson(Map<String, dynamic> json) => _$AgentsFromJson(json);

 final  List<AgentInfo> _agents;
@override List<AgentInfo> get agents {
  if (_agents is EqualUnmodifiableListView) return _agents;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_agents);
}


/// Create a copy of Agents
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AgentsCopyWith<_Agents> get copyWith => __$AgentsCopyWithImpl<_Agents>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AgentsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Agents&&const DeepCollectionEquality().equals(other._agents, _agents));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_agents));

@override
String toString() {
  return 'Agents(agents: $agents)';
}


}

/// @nodoc
abstract mixin class _$AgentsCopyWith<$Res> implements $AgentsCopyWith<$Res> {
  factory _$AgentsCopyWith(_Agents value, $Res Function(_Agents) _then) = __$AgentsCopyWithImpl;
@override @useResult
$Res call({
 List<AgentInfo> agents
});




}
/// @nodoc
class __$AgentsCopyWithImpl<$Res>
    implements _$AgentsCopyWith<$Res> {
  __$AgentsCopyWithImpl(this._self, this._then);

  final _Agents _self;
  final $Res Function(_Agents) _then;

/// Create a copy of Agents
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? agents = null,}) {
  return _then(_Agents(
agents: null == agents ? _self._agents : agents // ignore: cast_nullable_to_non_nullable
as List<AgentInfo>,
  ));
}


}


/// @nodoc
mixin _$AgentInfo {

 String get name; String? get description; AgentModel? get model;@JsonKey(unknownEnumValue: AgentMode.unknown) AgentMode get mode; bool get hidden;
/// Create a copy of AgentInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentInfoCopyWith<AgentInfo> get copyWith => _$AgentInfoCopyWithImpl<AgentInfo>(this as AgentInfo, _$identity);

  /// Serializes this AgentInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentInfo&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.model, model) || other.model == model)&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.hidden, hidden) || other.hidden == hidden));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,description,model,mode,hidden);

@override
String toString() {
  return 'AgentInfo(name: $name, description: $description, model: $model, mode: $mode, hidden: $hidden)';
}


}

/// @nodoc
abstract mixin class $AgentInfoCopyWith<$Res>  {
  factory $AgentInfoCopyWith(AgentInfo value, $Res Function(AgentInfo) _then) = _$AgentInfoCopyWithImpl;
@useResult
$Res call({
 String name, String? description, AgentModel? model,@JsonKey(unknownEnumValue: AgentMode.unknown) AgentMode mode, bool hidden
});


$AgentModelCopyWith<$Res>? get model;

}
/// @nodoc
class _$AgentInfoCopyWithImpl<$Res>
    implements $AgentInfoCopyWith<$Res> {
  _$AgentInfoCopyWithImpl(this._self, this._then);

  final AgentInfo _self;
  final $Res Function(AgentInfo) _then;

/// Create a copy of AgentInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? description = freezed,Object? model = freezed,Object? mode = null,Object? hidden = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as AgentModel?,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as AgentMode,hidden: null == hidden ? _self.hidden : hidden // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of AgentInfo
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AgentModelCopyWith<$Res>? get model {
    if (_self.model == null) {
    return null;
  }

  return $AgentModelCopyWith<$Res>(_self.model!, (value) {
    return _then(_self.copyWith(model: value));
  });
}
}



/// @nodoc
@JsonSerializable()

class _AgentInfo implements AgentInfo {
  const _AgentInfo({required this.name, required this.description, required this.model, @JsonKey(unknownEnumValue: AgentMode.unknown) required this.mode, this.hidden = false});
  factory _AgentInfo.fromJson(Map<String, dynamic> json) => _$AgentInfoFromJson(json);

@override final  String name;
@override final  String? description;
@override final  AgentModel? model;
@override@JsonKey(unknownEnumValue: AgentMode.unknown) final  AgentMode mode;
@override@JsonKey() final  bool hidden;

/// Create a copy of AgentInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AgentInfoCopyWith<_AgentInfo> get copyWith => __$AgentInfoCopyWithImpl<_AgentInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AgentInfoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AgentInfo&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.model, model) || other.model == model)&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.hidden, hidden) || other.hidden == hidden));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,description,model,mode,hidden);

@override
String toString() {
  return 'AgentInfo(name: $name, description: $description, model: $model, mode: $mode, hidden: $hidden)';
}


}

/// @nodoc
abstract mixin class _$AgentInfoCopyWith<$Res> implements $AgentInfoCopyWith<$Res> {
  factory _$AgentInfoCopyWith(_AgentInfo value, $Res Function(_AgentInfo) _then) = __$AgentInfoCopyWithImpl;
@override @useResult
$Res call({
 String name, String? description, AgentModel? model,@JsonKey(unknownEnumValue: AgentMode.unknown) AgentMode mode, bool hidden
});


@override $AgentModelCopyWith<$Res>? get model;

}
/// @nodoc
class __$AgentInfoCopyWithImpl<$Res>
    implements _$AgentInfoCopyWith<$Res> {
  __$AgentInfoCopyWithImpl(this._self, this._then);

  final _AgentInfo _self;
  final $Res Function(_AgentInfo) _then;

/// Create a copy of AgentInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? description = freezed,Object? model = freezed,Object? mode = null,Object? hidden = null,}) {
  return _then(_AgentInfo(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as AgentModel?,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as AgentMode,hidden: null == hidden ? _self.hidden : hidden // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of AgentInfo
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AgentModelCopyWith<$Res>? get model {
    if (_self.model == null) {
    return null;
  }

  return $AgentModelCopyWith<$Res>(_self.model!, (value) {
    return _then(_self.copyWith(model: value));
  });
}
}


/// @nodoc
mixin _$AgentModel {

 String get modelID; String get providerID; String? get variant;
/// Create a copy of AgentModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentModelCopyWith<AgentModel> get copyWith => _$AgentModelCopyWithImpl<AgentModel>(this as AgentModel, _$identity);

  /// Serializes this AgentModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentModel&&(identical(other.modelID, modelID) || other.modelID == modelID)&&(identical(other.providerID, providerID) || other.providerID == providerID)&&(identical(other.variant, variant) || other.variant == variant));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,modelID,providerID,variant);

@override
String toString() {
  return 'AgentModel(modelID: $modelID, providerID: $providerID, variant: $variant)';
}


}

/// @nodoc
abstract mixin class $AgentModelCopyWith<$Res>  {
  factory $AgentModelCopyWith(AgentModel value, $Res Function(AgentModel) _then) = _$AgentModelCopyWithImpl;
@useResult
$Res call({
 String modelID, String providerID, String? variant
});




}
/// @nodoc
class _$AgentModelCopyWithImpl<$Res>
    implements $AgentModelCopyWith<$Res> {
  _$AgentModelCopyWithImpl(this._self, this._then);

  final AgentModel _self;
  final $Res Function(AgentModel) _then;

/// Create a copy of AgentModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? modelID = null,Object? providerID = null,Object? variant = freezed,}) {
  return _then(_self.copyWith(
modelID: null == modelID ? _self.modelID : modelID // ignore: cast_nullable_to_non_nullable
as String,providerID: null == providerID ? _self.providerID : providerID // ignore: cast_nullable_to_non_nullable
as String,variant: freezed == variant ? _self.variant : variant // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _AgentModel implements AgentModel {
  const _AgentModel({required this.modelID, required this.providerID, required this.variant});
  factory _AgentModel.fromJson(Map<String, dynamic> json) => _$AgentModelFromJson(json);

@override final  String modelID;
@override final  String providerID;
@override final  String? variant;

/// Create a copy of AgentModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AgentModelCopyWith<_AgentModel> get copyWith => __$AgentModelCopyWithImpl<_AgentModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AgentModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AgentModel&&(identical(other.modelID, modelID) || other.modelID == modelID)&&(identical(other.providerID, providerID) || other.providerID == providerID)&&(identical(other.variant, variant) || other.variant == variant));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,modelID,providerID,variant);

@override
String toString() {
  return 'AgentModel(modelID: $modelID, providerID: $providerID, variant: $variant)';
}


}

/// @nodoc
abstract mixin class _$AgentModelCopyWith<$Res> implements $AgentModelCopyWith<$Res> {
  factory _$AgentModelCopyWith(_AgentModel value, $Res Function(_AgentModel) _then) = __$AgentModelCopyWithImpl;
@override @useResult
$Res call({
 String modelID, String providerID, String? variant
});




}
/// @nodoc
class __$AgentModelCopyWithImpl<$Res>
    implements _$AgentModelCopyWith<$Res> {
  __$AgentModelCopyWithImpl(this._self, this._then);

  final _AgentModel _self;
  final $Res Function(_AgentModel) _then;

/// Create a copy of AgentModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? modelID = null,Object? providerID = null,Object? variant = freezed,}) {
  return _then(_AgentModel(
modelID: null == modelID ? _self.modelID : modelID // ignore: cast_nullable_to_non_nullable
as String,providerID: null == providerID ? _self.providerID : providerID // ignore: cast_nullable_to_non_nullable
as String,variant: freezed == variant ? _self.variant : variant // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
