// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bridge_tool_group_setting.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BridgeToolGroupSetting {

 String get id; String get title; String get summary; bool get enabled;
/// Create a copy of BridgeToolGroupSetting
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BridgeToolGroupSettingCopyWith<BridgeToolGroupSetting> get copyWith => _$BridgeToolGroupSettingCopyWithImpl<BridgeToolGroupSetting>(this as BridgeToolGroupSetting, _$identity);

  /// Serializes this BridgeToolGroupSetting to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as BridgeToolGroupSetting;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BridgeToolGroupSetting&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.summary, _this.summary) || other.summary == _this.summary)&&(identical(other.enabled, _this.enabled) || other.enabled == _this.enabled));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as BridgeToolGroupSetting;
  return Object.hash(runtimeType,_this.id,_this.title,_this.summary,_this.enabled);
}

@override
String toString() {
  final _this = this as BridgeToolGroupSetting;
  return 'BridgeToolGroupSetting(id: ${_this.id}, title: ${_this.title}, summary: ${_this.summary}, enabled: ${_this.enabled})';
}


}

/// @nodoc
abstract mixin class $BridgeToolGroupSettingCopyWith<$Res>  {
  factory $BridgeToolGroupSettingCopyWith(BridgeToolGroupSetting value, $Res Function(BridgeToolGroupSetting) _then) = _$BridgeToolGroupSettingCopyWithImpl;
@useResult
$Res call({
 String id, String title, String summary, bool enabled
});




}
/// @nodoc
class _$BridgeToolGroupSettingCopyWithImpl<$Res>
    implements $BridgeToolGroupSettingCopyWith<$Res> {
  _$BridgeToolGroupSettingCopyWithImpl(this._self, this._then);

  final BridgeToolGroupSetting _self;
  final $Res Function(BridgeToolGroupSetting) _then;

/// Create a copy of BridgeToolGroupSetting
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? summary = null,Object? enabled = null,}) {
  return _then(BridgeToolGroupSetting(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as String,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _BridgeToolGroupSetting implements BridgeToolGroupSetting {
  const _BridgeToolGroupSetting({required this.id, required this.title, required this.summary, required this.enabled});
  factory _BridgeToolGroupSetting.fromJson(Map<String, dynamic> json) => _$BridgeToolGroupSettingFromJson(json);

@override final  String id;
@override final  String title;
@override final  String summary;
@override final  bool enabled;

/// Create a copy of BridgeToolGroupSetting
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BridgeToolGroupSettingCopyWith<_BridgeToolGroupSetting> get copyWith => __$BridgeToolGroupSettingCopyWithImpl<_BridgeToolGroupSetting>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BridgeToolGroupSettingToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _BridgeToolGroupSetting&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.summary, summary) || other.summary == summary)&&(identical(other.enabled, enabled) || other.enabled == enabled));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,title,summary,enabled);
}

@override
String toString() {
    return 'BridgeToolGroupSetting(id: $id, title: $title, summary: $summary, enabled: $enabled)';
}


}

/// @nodoc
abstract mixin class _$BridgeToolGroupSettingCopyWith<$Res> implements $BridgeToolGroupSettingCopyWith<$Res> {
  factory _$BridgeToolGroupSettingCopyWith(_BridgeToolGroupSetting value, $Res Function(_BridgeToolGroupSetting) _then) = __$BridgeToolGroupSettingCopyWithImpl;
@override @useResult
$Res call({
 String id, String title, String summary, bool enabled
});




}
/// @nodoc
class __$BridgeToolGroupSettingCopyWithImpl<$Res>
    implements _$BridgeToolGroupSettingCopyWith<$Res> {
  __$BridgeToolGroupSettingCopyWithImpl(this._self, this._then);

  final _BridgeToolGroupSetting _self;
  final $Res Function(_BridgeToolGroupSetting) _then;

/// Create a copy of BridgeToolGroupSetting
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? summary = null,Object? enabled = null,}) {
  return _then(_BridgeToolGroupSetting(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as String,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
