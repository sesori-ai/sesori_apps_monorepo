// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'model_orbits.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$OrbitLevel {

 EffortLevel get level; SessionVariant get variant;
/// Create a copy of OrbitLevel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OrbitLevelCopyWith<OrbitLevel> get copyWith => _$OrbitLevelCopyWithImpl<OrbitLevel>(this as OrbitLevel, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as OrbitLevel;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OrbitLevel&&(identical(other.level, _this.level) || other.level == _this.level)&&(identical(other.variant, _this.variant) || other.variant == _this.variant));
}


@override
int get hashCode {
  final _this = this as OrbitLevel;
  return Object.hash(runtimeType,_this.level,_this.variant);
}

@override
String toString() {
  final _this = this as OrbitLevel;
  return 'OrbitLevel(level: ${_this.level}, variant: ${_this.variant})';
}


}

/// @nodoc
abstract mixin class $OrbitLevelCopyWith<$Res>  {
  factory $OrbitLevelCopyWith(OrbitLevel value, $Res Function(OrbitLevel) _then) = _$OrbitLevelCopyWithImpl;
@useResult
$Res call({
 EffortLevel level, SessionVariant variant
});


$SessionVariantCopyWith<$Res> get variant;

}
/// @nodoc
class _$OrbitLevelCopyWithImpl<$Res>
    implements $OrbitLevelCopyWith<$Res> {
  _$OrbitLevelCopyWithImpl(this._self, this._then);

  final OrbitLevel _self;
  final $Res Function(OrbitLevel) _then;

/// Create a copy of OrbitLevel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? level = null,Object? variant = null,}) {
  return _then(OrbitLevel(
level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as EffortLevel,variant: null == variant ? _self.variant : variant // ignore: cast_nullable_to_non_nullable
as SessionVariant,
  ));
}
/// Create a copy of OrbitLevel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SessionVariantCopyWith<$Res> get variant {
  
  return $SessionVariantCopyWith<$Res>(_self.variant, (value) {
    return _then(_self.copyWith(variant: value));
  });
}
}



/// @nodoc


class _OrbitLevel implements OrbitLevel {
  const _OrbitLevel({required this.level, required this.variant});
  

@override final  EffortLevel level;
@override final  SessionVariant variant;

/// Create a copy of OrbitLevel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OrbitLevelCopyWith<_OrbitLevel> get copyWith => __$OrbitLevelCopyWithImpl<_OrbitLevel>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _OrbitLevel&&(identical(other.level, level) || other.level == level)&&(identical(other.variant, variant) || other.variant == variant));
}


@override
int get hashCode {
    return Object.hash(runtimeType,level,variant);
}

@override
String toString() {
    return 'OrbitLevel(level: $level, variant: $variant)';
}


}

/// @nodoc
abstract mixin class _$OrbitLevelCopyWith<$Res> implements $OrbitLevelCopyWith<$Res> {
  factory _$OrbitLevelCopyWith(_OrbitLevel value, $Res Function(_OrbitLevel) _then) = __$OrbitLevelCopyWithImpl;
@override @useResult
$Res call({
 EffortLevel level, SessionVariant variant
});


@override $SessionVariantCopyWith<$Res> get variant;

}
/// @nodoc
class __$OrbitLevelCopyWithImpl<$Res>
    implements _$OrbitLevelCopyWith<$Res> {
  __$OrbitLevelCopyWithImpl(this._self, this._then);

  final _OrbitLevel _self;
  final $Res Function(_OrbitLevel) _then;

/// Create a copy of OrbitLevel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? level = null,Object? variant = null,}) {
  return _then(_OrbitLevel(
level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as EffortLevel,variant: null == variant ? _self.variant : variant // ignore: cast_nullable_to_non_nullable
as SessionVariant,
  ));
}

/// Create a copy of OrbitLevel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SessionVariantCopyWith<$Res> get variant {
  
  return $SessionVariantCopyWith<$Res>(_self.variant, (value) {
    return _then(_self.copyWith(variant: value));
  });
}
}

/// @nodoc
mixin _$OrbitRing {

 String get providerID; String get modelID; String get name;/// The levels the model offers, weakest first; empty for a model without
/// effort levels.
 List<OrbitLevel> get levels;/// The model's fast mode, or null when it has none.
 FastModeSupport? get fastMode;
/// Create a copy of OrbitRing
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OrbitRingCopyWith<OrbitRing> get copyWith => _$OrbitRingCopyWithImpl<OrbitRing>(this as OrbitRing, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as OrbitRing;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OrbitRing&&(identical(other.providerID, _this.providerID) || other.providerID == _this.providerID)&&(identical(other.modelID, _this.modelID) || other.modelID == _this.modelID)&&(identical(other.name, _this.name) || other.name == _this.name)&&const DeepCollectionEquality().equals(other.levels, _this.levels)&&(identical(other.fastMode, _this.fastMode) || other.fastMode == _this.fastMode));
}


@override
int get hashCode {
  final _this = this as OrbitRing;
  return Object.hash(runtimeType,_this.providerID,_this.modelID,_this.name,const DeepCollectionEquality().hash(_this.levels),_this.fastMode);
}

@override
String toString() {
  final _this = this as OrbitRing;
  return 'OrbitRing(providerID: ${_this.providerID}, modelID: ${_this.modelID}, name: ${_this.name}, levels: ${_this.levels}, fastMode: ${_this.fastMode})';
}


}

/// @nodoc
abstract mixin class $OrbitRingCopyWith<$Res>  {
  factory $OrbitRingCopyWith(OrbitRing value, $Res Function(OrbitRing) _then) = _$OrbitRingCopyWithImpl;
@useResult
$Res call({
 String providerID, String modelID, String name, List<OrbitLevel> levels, FastModeSupport? fastMode
});


$FastModeSupportCopyWith<$Res>? get fastMode;

}
/// @nodoc
class _$OrbitRingCopyWithImpl<$Res>
    implements $OrbitRingCopyWith<$Res> {
  _$OrbitRingCopyWithImpl(this._self, this._then);

  final OrbitRing _self;
  final $Res Function(OrbitRing) _then;

/// Create a copy of OrbitRing
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? providerID = null,Object? modelID = null,Object? name = null,Object? levels = null,Object? fastMode = freezed,}) {
  return _then(OrbitRing(
providerID: null == providerID ? _self.providerID : providerID // ignore: cast_nullable_to_non_nullable
as String,modelID: null == modelID ? _self.modelID : modelID // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,levels: null == levels ? _self.levels : levels // ignore: cast_nullable_to_non_nullable
as List<OrbitLevel>,fastMode: freezed == fastMode ? _self.fastMode : fastMode // ignore: cast_nullable_to_non_nullable
as FastModeSupport?,
  ));
}
/// Create a copy of OrbitRing
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FastModeSupportCopyWith<$Res>? get fastMode {
    if (_self.fastMode == null) {
    return null;
  }

  return $FastModeSupportCopyWith<$Res>(_self.fastMode!, (value) {
    return _then(_self.copyWith(fastMode: value));
  });
}
}



/// @nodoc


class _OrbitRing implements OrbitRing {
  const _OrbitRing({required this.providerID, required this.modelID, required this.name, required  List<OrbitLevel> levels, required this.fastMode}): _levels = levels;
  

@override final  String providerID;
@override final  String modelID;
@override final  String name;
/// The levels the model offers, weakest first; empty for a model without
/// effort levels.
 final  List<OrbitLevel> _levels;
/// The levels the model offers, weakest first; empty for a model without
/// effort levels.
@override List<OrbitLevel> get levels {
  if (_levels is EqualUnmodifiableListView) return _levels;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_levels);
}

/// The model's fast mode, or null when it has none.
@override final  FastModeSupport? fastMode;

/// Create a copy of OrbitRing
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OrbitRingCopyWith<_OrbitRing> get copyWith => __$OrbitRingCopyWithImpl<_OrbitRing>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _OrbitRing&&(identical(other.providerID, providerID) || other.providerID == providerID)&&(identical(other.modelID, modelID) || other.modelID == modelID)&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other.levels, _levels)&&(identical(other.fastMode, fastMode) || other.fastMode == fastMode));
}


@override
int get hashCode {
    return Object.hash(runtimeType,providerID,modelID,name,const DeepCollectionEquality().hash(_levels),fastMode);
}

@override
String toString() {
    return 'OrbitRing(providerID: $providerID, modelID: $modelID, name: $name, levels: $levels, fastMode: $fastMode)';
}


}

/// @nodoc
abstract mixin class _$OrbitRingCopyWith<$Res> implements $OrbitRingCopyWith<$Res> {
  factory _$OrbitRingCopyWith(_OrbitRing value, $Res Function(_OrbitRing) _then) = __$OrbitRingCopyWithImpl;
@override @useResult
$Res call({
 String providerID, String modelID, String name, List<OrbitLevel> levels, FastModeSupport? fastMode
});


@override $FastModeSupportCopyWith<$Res>? get fastMode;

}
/// @nodoc
class __$OrbitRingCopyWithImpl<$Res>
    implements _$OrbitRingCopyWith<$Res> {
  __$OrbitRingCopyWithImpl(this._self, this._then);

  final _OrbitRing _self;
  final $Res Function(_OrbitRing) _then;

/// Create a copy of OrbitRing
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? providerID = null,Object? modelID = null,Object? name = null,Object? levels = null,Object? fastMode = freezed,}) {
  return _then(_OrbitRing(
providerID: null == providerID ? _self.providerID : providerID // ignore: cast_nullable_to_non_nullable
as String,modelID: null == modelID ? _self.modelID : modelID // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,levels: null == levels ? _self._levels : levels // ignore: cast_nullable_to_non_nullable
as List<OrbitLevel>,fastMode: freezed == fastMode ? _self.fastMode : fastMode // ignore: cast_nullable_to_non_nullable
as FastModeSupport?,
  ));
}

/// Create a copy of OrbitRing
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FastModeSupportCopyWith<$Res>? get fastMode {
    if (_self.fastMode == null) {
    return null;
  }

  return $FastModeSupportCopyWith<$Res>(_self.fastMode!, (value) {
    return _then(_self.copyWith(fastMode: value));
  });
}
}

/// @nodoc
mixin _$ModelOrbits {

/// The rings in catalog order, outermost first. Always holds [current].
 List<OrbitRing> get rings;/// The ladder levels any ring offers, weakest first.
 List<EffortLevel> get levels;/// How many models the catalog offers, so the picker can offer the rest
/// when there are more than [rings].
 int get totalModels;/// Whether every ring's model has fast mode, so the picker need not tag
/// the ones that do.
 bool get allRingsFast;/// The selected model's ring.
 OrbitRing get current;/// The selected level, or null when [current] offers no levels.
 EffortLevel? get currentLevel;
/// Create a copy of ModelOrbits
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ModelOrbitsCopyWith<ModelOrbits> get copyWith => _$ModelOrbitsCopyWithImpl<ModelOrbits>(this as ModelOrbits, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ModelOrbits;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ModelOrbits&&const DeepCollectionEquality().equals(other.rings, _this.rings)&&const DeepCollectionEquality().equals(other.levels, _this.levels)&&(identical(other.totalModels, _this.totalModels) || other.totalModels == _this.totalModels)&&(identical(other.allRingsFast, _this.allRingsFast) || other.allRingsFast == _this.allRingsFast)&&(identical(other.current, _this.current) || other.current == _this.current)&&(identical(other.currentLevel, _this.currentLevel) || other.currentLevel == _this.currentLevel));
}


@override
int get hashCode {
  final _this = this as ModelOrbits;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.rings),const DeepCollectionEquality().hash(_this.levels),_this.totalModels,_this.allRingsFast,_this.current,_this.currentLevel);
}

@override
String toString() {
  final _this = this as ModelOrbits;
  return 'ModelOrbits(rings: ${_this.rings}, levels: ${_this.levels}, totalModels: ${_this.totalModels}, allRingsFast: ${_this.allRingsFast}, current: ${_this.current}, currentLevel: ${_this.currentLevel})';
}


}

/// @nodoc
abstract mixin class $ModelOrbitsCopyWith<$Res>  {
  factory $ModelOrbitsCopyWith(ModelOrbits value, $Res Function(ModelOrbits) _then) = _$ModelOrbitsCopyWithImpl;
@useResult
$Res call({
 List<OrbitRing> rings, List<EffortLevel> levels, int totalModels, bool allRingsFast, OrbitRing current, EffortLevel? currentLevel
});


$OrbitRingCopyWith<$Res> get current;

}
/// @nodoc
class _$ModelOrbitsCopyWithImpl<$Res>
    implements $ModelOrbitsCopyWith<$Res> {
  _$ModelOrbitsCopyWithImpl(this._self, this._then);

  final ModelOrbits _self;
  final $Res Function(ModelOrbits) _then;

/// Create a copy of ModelOrbits
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? rings = null,Object? levels = null,Object? totalModels = null,Object? allRingsFast = null,Object? current = null,Object? currentLevel = freezed,}) {
  return _then(ModelOrbits(
rings: null == rings ? _self.rings : rings // ignore: cast_nullable_to_non_nullable
as List<OrbitRing>,levels: null == levels ? _self.levels : levels // ignore: cast_nullable_to_non_nullable
as List<EffortLevel>,totalModels: null == totalModels ? _self.totalModels : totalModels // ignore: cast_nullable_to_non_nullable
as int,allRingsFast: null == allRingsFast ? _self.allRingsFast : allRingsFast // ignore: cast_nullable_to_non_nullable
as bool,current: null == current ? _self.current : current // ignore: cast_nullable_to_non_nullable
as OrbitRing,currentLevel: freezed == currentLevel ? _self.currentLevel : currentLevel // ignore: cast_nullable_to_non_nullable
as EffortLevel?,
  ));
}
/// Create a copy of ModelOrbits
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OrbitRingCopyWith<$Res> get current {
  
  return $OrbitRingCopyWith<$Res>(_self.current, (value) {
    return _then(_self.copyWith(current: value));
  });
}
}



/// @nodoc


class _ModelOrbits implements ModelOrbits {
  const _ModelOrbits({required  List<OrbitRing> rings, required  List<EffortLevel> levels, required this.totalModels, required this.allRingsFast, required this.current, required this.currentLevel}): _rings = rings,_levels = levels;
  

/// The rings in catalog order, outermost first. Always holds [current].
 final  List<OrbitRing> _rings;
/// The rings in catalog order, outermost first. Always holds [current].
@override List<OrbitRing> get rings {
  if (_rings is EqualUnmodifiableListView) return _rings;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_rings);
}

/// The ladder levels any ring offers, weakest first.
 final  List<EffortLevel> _levels;
/// The ladder levels any ring offers, weakest first.
@override List<EffortLevel> get levels {
  if (_levels is EqualUnmodifiableListView) return _levels;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_levels);
}

/// How many models the catalog offers, so the picker can offer the rest
/// when there are more than [rings].
@override final  int totalModels;
/// Whether every ring's model has fast mode, so the picker need not tag
/// the ones that do.
@override final  bool allRingsFast;
/// The selected model's ring.
@override final  OrbitRing current;
/// The selected level, or null when [current] offers no levels.
@override final  EffortLevel? currentLevel;

/// Create a copy of ModelOrbits
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ModelOrbitsCopyWith<_ModelOrbits> get copyWith => __$ModelOrbitsCopyWithImpl<_ModelOrbits>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ModelOrbits&&const DeepCollectionEquality().equals(other.rings, _rings)&&const DeepCollectionEquality().equals(other.levels, _levels)&&(identical(other.totalModels, totalModels) || other.totalModels == totalModels)&&(identical(other.allRingsFast, allRingsFast) || other.allRingsFast == allRingsFast)&&(identical(other.current, current) || other.current == current)&&(identical(other.currentLevel, currentLevel) || other.currentLevel == currentLevel));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_rings),const DeepCollectionEquality().hash(_levels),totalModels,allRingsFast,current,currentLevel);
}

@override
String toString() {
    return 'ModelOrbits(rings: $rings, levels: $levels, totalModels: $totalModels, allRingsFast: $allRingsFast, current: $current, currentLevel: $currentLevel)';
}


}

/// @nodoc
abstract mixin class _$ModelOrbitsCopyWith<$Res> implements $ModelOrbitsCopyWith<$Res> {
  factory _$ModelOrbitsCopyWith(_ModelOrbits value, $Res Function(_ModelOrbits) _then) = __$ModelOrbitsCopyWithImpl;
@override @useResult
$Res call({
 List<OrbitRing> rings, List<EffortLevel> levels, int totalModels, bool allRingsFast, OrbitRing current, EffortLevel? currentLevel
});


@override $OrbitRingCopyWith<$Res> get current;

}
/// @nodoc
class __$ModelOrbitsCopyWithImpl<$Res>
    implements _$ModelOrbitsCopyWith<$Res> {
  __$ModelOrbitsCopyWithImpl(this._self, this._then);

  final _ModelOrbits _self;
  final $Res Function(_ModelOrbits) _then;

/// Create a copy of ModelOrbits
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? rings = null,Object? levels = null,Object? totalModels = null,Object? allRingsFast = null,Object? current = null,Object? currentLevel = freezed,}) {
  return _then(_ModelOrbits(
rings: null == rings ? _self._rings : rings // ignore: cast_nullable_to_non_nullable
as List<OrbitRing>,levels: null == levels ? _self._levels : levels // ignore: cast_nullable_to_non_nullable
as List<EffortLevel>,totalModels: null == totalModels ? _self.totalModels : totalModels // ignore: cast_nullable_to_non_nullable
as int,allRingsFast: null == allRingsFast ? _self.allRingsFast : allRingsFast // ignore: cast_nullable_to_non_nullable
as bool,current: null == current ? _self.current : current // ignore: cast_nullable_to_non_nullable
as OrbitRing,currentLevel: freezed == currentLevel ? _self.currentLevel : currentLevel // ignore: cast_nullable_to_non_nullable
as EffortLevel?,
  ));
}

/// Create a copy of ModelOrbits
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OrbitRingCopyWith<$Res> get current {
  
  return $OrbitRingCopyWith<$Res>(_self.current, (value) {
    return _then(_self.copyWith(current: value));
  });
}
}

// dart format on
