// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_wake_up.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SessionWakeUp {

 String get id;/// When it fires next, in UTC milliseconds.
 int get nextDueAt;/// The agent's one-line label for it.
 String get label;/// Whether it fires again after [nextDueAt], until it is cancelled.
 bool get repeats;/// Whether it runs a shell command when it fires.
 bool get runsCommand;
/// Create a copy of SessionWakeUp
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionWakeUpCopyWith<SessionWakeUp> get copyWith => _$SessionWakeUpCopyWithImpl<SessionWakeUp>(this as SessionWakeUp, _$identity);

  /// Serializes this SessionWakeUp to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SessionWakeUp;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionWakeUp&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.nextDueAt, _this.nextDueAt) || other.nextDueAt == _this.nextDueAt)&&(identical(other.label, _this.label) || other.label == _this.label)&&(identical(other.repeats, _this.repeats) || other.repeats == _this.repeats)&&(identical(other.runsCommand, _this.runsCommand) || other.runsCommand == _this.runsCommand));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SessionWakeUp;
  return Object.hash(runtimeType,_this.id,_this.nextDueAt,_this.label,_this.repeats,_this.runsCommand);
}

@override
String toString() {
  final _this = this as SessionWakeUp;
  return 'SessionWakeUp(id: ${_this.id}, nextDueAt: ${_this.nextDueAt}, label: ${_this.label}, repeats: ${_this.repeats}, runsCommand: ${_this.runsCommand})';
}


}

/// @nodoc
abstract mixin class $SessionWakeUpCopyWith<$Res>  {
  factory $SessionWakeUpCopyWith(SessionWakeUp value, $Res Function(SessionWakeUp) _then) = _$SessionWakeUpCopyWithImpl;
@useResult
$Res call({
 String id, int nextDueAt, String label, bool repeats, bool runsCommand
});




}
/// @nodoc
class _$SessionWakeUpCopyWithImpl<$Res>
    implements $SessionWakeUpCopyWith<$Res> {
  _$SessionWakeUpCopyWithImpl(this._self, this._then);

  final SessionWakeUp _self;
  final $Res Function(SessionWakeUp) _then;

/// Create a copy of SessionWakeUp
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? nextDueAt = null,Object? label = null,Object? repeats = null,Object? runsCommand = null,}) {
  return _then(SessionWakeUp(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,nextDueAt: null == nextDueAt ? _self.nextDueAt : nextDueAt // ignore: cast_nullable_to_non_nullable
as int,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,repeats: null == repeats ? _self.repeats : repeats // ignore: cast_nullable_to_non_nullable
as bool,runsCommand: null == runsCommand ? _self.runsCommand : runsCommand // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _SessionWakeUp implements SessionWakeUp {
  const _SessionWakeUp({required this.id, required this.nextDueAt, required this.label, required this.repeats, required this.runsCommand});
  factory _SessionWakeUp.fromJson(Map<String, dynamic> json) => _$SessionWakeUpFromJson(json);

@override final  String id;
/// When it fires next, in UTC milliseconds.
@override final  int nextDueAt;
/// The agent's one-line label for it.
@override final  String label;
/// Whether it fires again after [nextDueAt], until it is cancelled.
@override final  bool repeats;
/// Whether it runs a shell command when it fires.
@override final  bool runsCommand;

/// Create a copy of SessionWakeUp
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionWakeUpCopyWith<_SessionWakeUp> get copyWith => __$SessionWakeUpCopyWithImpl<_SessionWakeUp>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionWakeUpToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionWakeUp&&(identical(other.id, id) || other.id == id)&&(identical(other.nextDueAt, nextDueAt) || other.nextDueAt == nextDueAt)&&(identical(other.label, label) || other.label == label)&&(identical(other.repeats, repeats) || other.repeats == repeats)&&(identical(other.runsCommand, runsCommand) || other.runsCommand == runsCommand));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,nextDueAt,label,repeats,runsCommand);
}

@override
String toString() {
    return 'SessionWakeUp(id: $id, nextDueAt: $nextDueAt, label: $label, repeats: $repeats, runsCommand: $runsCommand)';
}


}

/// @nodoc
abstract mixin class _$SessionWakeUpCopyWith<$Res> implements $SessionWakeUpCopyWith<$Res> {
  factory _$SessionWakeUpCopyWith(_SessionWakeUp value, $Res Function(_SessionWakeUp) _then) = __$SessionWakeUpCopyWithImpl;
@override @useResult
$Res call({
 String id, int nextDueAt, String label, bool repeats, bool runsCommand
});




}
/// @nodoc
class __$SessionWakeUpCopyWithImpl<$Res>
    implements _$SessionWakeUpCopyWith<$Res> {
  __$SessionWakeUpCopyWithImpl(this._self, this._then);

  final _SessionWakeUp _self;
  final $Res Function(_SessionWakeUp) _then;

/// Create a copy of SessionWakeUp
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? nextDueAt = null,Object? label = null,Object? repeats = null,Object? runsCommand = null,}) {
  return _then(_SessionWakeUp(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,nextDueAt: null == nextDueAt ? _self.nextDueAt : nextDueAt // ignore: cast_nullable_to_non_nullable
as int,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,repeats: null == repeats ? _self.repeats : repeats // ignore: cast_nullable_to_non_nullable
as bool,runsCommand: null == runsCommand ? _self.runsCommand : runsCommand // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

SessionArming _$SessionArmingFromJson(
  Map<String, dynamic> json
) {
        switch (json['kind']) {
                  case 'notArmed':
          return SessionArmingNotArmed.fromJson(
            json
          );
                case 'armed':
          return SessionArmingArmed.fromJson(
            json
          );
        
          default:
            return SessionArmingUnreported.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$SessionArming {



  /// Serializes this SessionArming to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionArming);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'SessionArming()';
}


}

/// @nodoc
class $SessionArmingCopyWith<$Res>  {
$SessionArmingCopyWith(SessionArming _, $Res Function(SessionArming) __);
}



/// @nodoc
@JsonSerializable()

class SessionArmingUnreported implements SessionArming {
  const SessionArmingUnreported({ String? $type}): $type = $type ?? 'unreported';
  factory SessionArmingUnreported.fromJson(Map<String, dynamic> json) => _$SessionArmingUnreportedFromJson(json);



@JsonKey(name: 'kind')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$SessionArmingUnreportedToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionArmingUnreported);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'SessionArming.unreported()';
}


}




/// @nodoc
@JsonSerializable()

class SessionArmingNotArmed implements SessionArming {
  const SessionArmingNotArmed({ String? $type}): $type = $type ?? 'notArmed';
  factory SessionArmingNotArmed.fromJson(Map<String, dynamic> json) => _$SessionArmingNotArmedFromJson(json);



@JsonKey(name: 'kind')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$SessionArmingNotArmedToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionArmingNotArmed);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'SessionArming.notArmed()';
}


}




/// @nodoc
@JsonSerializable()

class SessionArmingArmed implements SessionArming {
  const SessionArmingArmed({required this.name, required this.nextAt,  String? $type}): $type = $type ?? 'armed';
  factory SessionArmingArmed.fromJson(Map<String, dynamic> json) => _$SessionArmingArmedFromJson(json);

 final  String name;
 final  int nextAt;

@JsonKey(name: 'kind')
final String $type;


/// Create a copy of SessionArming
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionArmingArmedCopyWith<SessionArmingArmed> get copyWith => _$SessionArmingArmedCopyWithImpl<SessionArmingArmed>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionArmingArmedToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionArmingArmed&&(identical(other.name, name) || other.name == name)&&(identical(other.nextAt, nextAt) || other.nextAt == nextAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,name,nextAt);
}

@override
String toString() {
    return 'SessionArming.armed(name: $name, nextAt: $nextAt)';
}


}

/// @nodoc
abstract mixin class $SessionArmingArmedCopyWith<$Res> implements $SessionArmingCopyWith<$Res> {
  factory $SessionArmingArmedCopyWith(SessionArmingArmed value, $Res Function(SessionArmingArmed) _then) = _$SessionArmingArmedCopyWithImpl;
@useResult
$Res call({
 String name, int nextAt
});




}
/// @nodoc
class _$SessionArmingArmedCopyWithImpl<$Res>
    implements $SessionArmingArmedCopyWith<$Res> {
  _$SessionArmingArmedCopyWithImpl(this._self, this._then);

  final SessionArmingArmed _self;
  final $Res Function(SessionArmingArmed) _then;

/// Create a copy of SessionArming
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? name = null,Object? nextAt = null,}) {
  return _then(SessionArmingArmed(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,nextAt: null == nextAt ? _self.nextAt : nextAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
