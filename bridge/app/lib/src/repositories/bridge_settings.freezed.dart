// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bridge_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BridgeAgentToolGroupSettings {

@JsonKey(name: 'disabled') Set<String> get disabledIds;

  /// Serializes this BridgeAgentToolGroupSettings to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as BridgeAgentToolGroupSettings;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BridgeAgentToolGroupSettings&&const DeepCollectionEquality().equals(other.disabledIds, _this.disabledIds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as BridgeAgentToolGroupSettings;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.disabledIds));
}

@override
String toString() {
  final _this = this as BridgeAgentToolGroupSettings;
  return 'BridgeAgentToolGroupSettings(disabledIds: ${_this.disabledIds})';
}


}





/// @nodoc
@JsonSerializable()

class _BridgeAgentToolGroupSettings extends BridgeAgentToolGroupSettings {
  const _BridgeAgentToolGroupSettings({@JsonKey(name: 'disabled')  Set<String> disabledIds = const <String>{}}): _disabledIds = disabledIds,super._();
  factory _BridgeAgentToolGroupSettings.fromJson(Map<String, dynamic> json) => _$BridgeAgentToolGroupSettingsFromJson(json);

 final  Set<String> _disabledIds;
@override@JsonKey(name: 'disabled') Set<String> get disabledIds {
  if (_disabledIds is EqualUnmodifiableSetView) return _disabledIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_disabledIds);
}



@override
Map<String, dynamic> toJson() {
  return _$BridgeAgentToolGroupSettingsToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _BridgeAgentToolGroupSettings&&const DeepCollectionEquality().equals(other.disabledIds, _disabledIds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_disabledIds));
}

@override
String toString() {
    return 'BridgeAgentToolGroupSettings(disabledIds: $disabledIds)';
}


}




// dart format on
