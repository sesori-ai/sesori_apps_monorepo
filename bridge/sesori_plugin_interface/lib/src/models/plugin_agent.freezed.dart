// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plugin_agent.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PluginAgentModel {

 String get modelID; String get providerID;
/// Create a copy of PluginAgentModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginAgentModelCopyWith<PluginAgentModel> get copyWith => _$PluginAgentModelCopyWithImpl<PluginAgentModel>(this as PluginAgentModel, _$identity);

  /// Serializes this PluginAgentModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginAgentModel&&(identical(other.modelID, modelID) || other.modelID == modelID)&&(identical(other.providerID, providerID) || other.providerID == providerID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,modelID,providerID);

@override
String toString() {
  return 'PluginAgentModel(modelID: $modelID, providerID: $providerID)';
}


}

/// @nodoc
abstract mixin class $PluginAgentModelCopyWith<$Res>  {
  factory $PluginAgentModelCopyWith(PluginAgentModel value, $Res Function(PluginAgentModel) _then) = _$PluginAgentModelCopyWithImpl;
@useResult
$Res call({
 String modelID, String providerID
});




}
/// @nodoc
class _$PluginAgentModelCopyWithImpl<$Res>
    implements $PluginAgentModelCopyWith<$Res> {
  _$PluginAgentModelCopyWithImpl(this._self, this._then);

  final PluginAgentModel _self;
  final $Res Function(PluginAgentModel) _then;

/// Create a copy of PluginAgentModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? modelID = null,Object? providerID = null,}) {
  return _then(_self.copyWith(
modelID: null == modelID ? _self.modelID : modelID // ignore: cast_nullable_to_non_nullable
as String,providerID: null == providerID ? _self.providerID : providerID // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable(createFactory: false)

class _PluginAgentModel implements PluginAgentModel {
  const _PluginAgentModel({required this.modelID, required this.providerID});
  

@override final  String modelID;
@override final  String providerID;

/// Create a copy of PluginAgentModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginAgentModelCopyWith<_PluginAgentModel> get copyWith => __$PluginAgentModelCopyWithImpl<_PluginAgentModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginAgentModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginAgentModel&&(identical(other.modelID, modelID) || other.modelID == modelID)&&(identical(other.providerID, providerID) || other.providerID == providerID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,modelID,providerID);

@override
String toString() {
  return 'PluginAgentModel(modelID: $modelID, providerID: $providerID)';
}


}

/// @nodoc
abstract mixin class _$PluginAgentModelCopyWith<$Res> implements $PluginAgentModelCopyWith<$Res> {
  factory _$PluginAgentModelCopyWith(_PluginAgentModel value, $Res Function(_PluginAgentModel) _then) = __$PluginAgentModelCopyWithImpl;
@override @useResult
$Res call({
 String modelID, String providerID
});




}
/// @nodoc
class __$PluginAgentModelCopyWithImpl<$Res>
    implements _$PluginAgentModelCopyWith<$Res> {
  __$PluginAgentModelCopyWithImpl(this._self, this._then);

  final _PluginAgentModel _self;
  final $Res Function(_PluginAgentModel) _then;

/// Create a copy of PluginAgentModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? modelID = null,Object? providerID = null,}) {
  return _then(_PluginAgentModel(
modelID: null == modelID ? _self.modelID : modelID // ignore: cast_nullable_to_non_nullable
as String,providerID: null == providerID ? _self.providerID : providerID // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$PluginAgent {

 String get name; String? get description; PluginAgentModel? get model; String? get variant; PluginAgentMode get mode; bool get hidden;
/// Create a copy of PluginAgent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginAgentCopyWith<PluginAgent> get copyWith => _$PluginAgentCopyWithImpl<PluginAgent>(this as PluginAgent, _$identity);

  /// Serializes this PluginAgent to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginAgent&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.model, model) || other.model == model)&&(identical(other.variant, variant) || other.variant == variant)&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.hidden, hidden) || other.hidden == hidden));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,description,model,variant,mode,hidden);

@override
String toString() {
  return 'PluginAgent(name: $name, description: $description, model: $model, variant: $variant, mode: $mode, hidden: $hidden)';
}


}

/// @nodoc
abstract mixin class $PluginAgentCopyWith<$Res>  {
  factory $PluginAgentCopyWith(PluginAgent value, $Res Function(PluginAgent) _then) = _$PluginAgentCopyWithImpl;
@useResult
$Res call({
 String name, String? description, PluginAgentModel? model, String? variant, PluginAgentMode mode, bool hidden
});


$PluginAgentModelCopyWith<$Res>? get model;

}
/// @nodoc
class _$PluginAgentCopyWithImpl<$Res>
    implements $PluginAgentCopyWith<$Res> {
  _$PluginAgentCopyWithImpl(this._self, this._then);

  final PluginAgent _self;
  final $Res Function(PluginAgent) _then;

/// Create a copy of PluginAgent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? description = freezed,Object? model = freezed,Object? variant = freezed,Object? mode = null,Object? hidden = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as PluginAgentModel?,variant: freezed == variant ? _self.variant : variant // ignore: cast_nullable_to_non_nullable
as String?,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as PluginAgentMode,hidden: null == hidden ? _self.hidden : hidden // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of PluginAgent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginAgentModelCopyWith<$Res>? get model {
    if (_self.model == null) {
    return null;
  }

  return $PluginAgentModelCopyWith<$Res>(_self.model!, (value) {
    return _then(_self.copyWith(model: value));
  });
}
}



/// @nodoc
@JsonSerializable(createFactory: false)

class _PluginAgent implements PluginAgent {
  const _PluginAgent({required this.name, required this.description, required this.model, required this.variant, required this.mode, required this.hidden});
  

@override final  String name;
@override final  String? description;
@override final  PluginAgentModel? model;
@override final  String? variant;
@override final  PluginAgentMode mode;
@override final  bool hidden;

/// Create a copy of PluginAgent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginAgentCopyWith<_PluginAgent> get copyWith => __$PluginAgentCopyWithImpl<_PluginAgent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginAgentToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginAgent&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.model, model) || other.model == model)&&(identical(other.variant, variant) || other.variant == variant)&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.hidden, hidden) || other.hidden == hidden));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,description,model,variant,mode,hidden);

@override
String toString() {
  return 'PluginAgent(name: $name, description: $description, model: $model, variant: $variant, mode: $mode, hidden: $hidden)';
}


}

/// @nodoc
abstract mixin class _$PluginAgentCopyWith<$Res> implements $PluginAgentCopyWith<$Res> {
  factory _$PluginAgentCopyWith(_PluginAgent value, $Res Function(_PluginAgent) _then) = __$PluginAgentCopyWithImpl;
@override @useResult
$Res call({
 String name, String? description, PluginAgentModel? model, String? variant, PluginAgentMode mode, bool hidden
});


@override $PluginAgentModelCopyWith<$Res>? get model;

}
/// @nodoc
class __$PluginAgentCopyWithImpl<$Res>
    implements _$PluginAgentCopyWith<$Res> {
  __$PluginAgentCopyWithImpl(this._self, this._then);

  final _PluginAgent _self;
  final $Res Function(_PluginAgent) _then;

/// Create a copy of PluginAgent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? description = freezed,Object? model = freezed,Object? variant = freezed,Object? mode = null,Object? hidden = null,}) {
  return _then(_PluginAgent(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as PluginAgentModel?,variant: freezed == variant ? _self.variant : variant // ignore: cast_nullable_to_non_nullable
as String?,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as PluginAgentMode,hidden: null == hidden ? _self.hidden : hidden // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of PluginAgent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PluginAgentModelCopyWith<$Res>? get model {
    if (_self.model == null) {
    return null;
  }

  return $PluginAgentModelCopyWith<$Res>(_self.model!, (value) {
    return _then(_self.copyWith(model: value));
  });
}
}

// dart format on
