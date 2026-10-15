// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bridge_summary.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BridgeSummary {

 String get id;/// The display name: the user's nickname when set, otherwise [hostname].
 String get name;/// The name the computer registered with.
 String get hostname;@JsonKey(unknownEnumValue: BridgePlatform.unknown) BridgePlatform get platform; BridgeRegistrationStatus get status; DateTime get addedAt; DateTime? get lastSeenAt;
/// Create a copy of BridgeSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BridgeSummaryCopyWith<BridgeSummary> get copyWith => _$BridgeSummaryCopyWithImpl<BridgeSummary>(this as BridgeSummary, _$identity);

  /// Serializes this BridgeSummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as BridgeSummary;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BridgeSummary&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.hostname, _this.hostname) || other.hostname == _this.hostname)&&(identical(other.platform, _this.platform) || other.platform == _this.platform)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.addedAt, _this.addedAt) || other.addedAt == _this.addedAt)&&(identical(other.lastSeenAt, _this.lastSeenAt) || other.lastSeenAt == _this.lastSeenAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as BridgeSummary;
  return Object.hash(runtimeType,_this.id,_this.name,_this.hostname,_this.platform,_this.status,_this.addedAt,_this.lastSeenAt);
}

@override
String toString() {
  final _this = this as BridgeSummary;
  return 'BridgeSummary(id: ${_this.id}, name: ${_this.name}, hostname: ${_this.hostname}, platform: ${_this.platform}, status: ${_this.status}, addedAt: ${_this.addedAt}, lastSeenAt: ${_this.lastSeenAt})';
}


}

/// @nodoc
abstract mixin class $BridgeSummaryCopyWith<$Res>  {
  factory $BridgeSummaryCopyWith(BridgeSummary value, $Res Function(BridgeSummary) _then) = _$BridgeSummaryCopyWithImpl;
@useResult
$Res call({
 String id, String name, String hostname,@JsonKey(unknownEnumValue: BridgePlatform.unknown) BridgePlatform platform, BridgeRegistrationStatus status, DateTime addedAt, DateTime? lastSeenAt
});




}
/// @nodoc
class _$BridgeSummaryCopyWithImpl<$Res>
    implements $BridgeSummaryCopyWith<$Res> {
  _$BridgeSummaryCopyWithImpl(this._self, this._then);

  final BridgeSummary _self;
  final $Res Function(BridgeSummary) _then;

/// Create a copy of BridgeSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? hostname = null,Object? platform = null,Object? status = null,Object? addedAt = null,Object? lastSeenAt = freezed,}) {
  return _then(BridgeSummary(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,hostname: null == hostname ? _self.hostname : hostname // ignore: cast_nullable_to_non_nullable
as String,platform: null == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as BridgePlatform,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as BridgeRegistrationStatus,addedAt: null == addedAt ? _self.addedAt : addedAt // ignore: cast_nullable_to_non_nullable
as DateTime,lastSeenAt: freezed == lastSeenAt ? _self.lastSeenAt : lastSeenAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _BridgeSummary implements BridgeSummary {
  const _BridgeSummary({required this.id, required this.name, required this.hostname, @JsonKey(unknownEnumValue: BridgePlatform.unknown) required this.platform, required this.status, required this.addedAt, required this.lastSeenAt});
  factory _BridgeSummary.fromJson(Map<String, dynamic> json) => _$BridgeSummaryFromJson(json);

@override final  String id;
/// The display name: the user's nickname when set, otherwise [hostname].
@override final  String name;
/// The name the computer registered with.
@override final  String hostname;
@override@JsonKey(unknownEnumValue: BridgePlatform.unknown) final  BridgePlatform platform;
@override final  BridgeRegistrationStatus status;
@override final  DateTime addedAt;
@override final  DateTime? lastSeenAt;

/// Create a copy of BridgeSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BridgeSummaryCopyWith<_BridgeSummary> get copyWith => __$BridgeSummaryCopyWithImpl<_BridgeSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BridgeSummaryToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _BridgeSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.hostname, hostname) || other.hostname == hostname)&&(identical(other.platform, platform) || other.platform == platform)&&(identical(other.status, status) || other.status == status)&&(identical(other.addedAt, addedAt) || other.addedAt == addedAt)&&(identical(other.lastSeenAt, lastSeenAt) || other.lastSeenAt == lastSeenAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,name,hostname,platform,status,addedAt,lastSeenAt);
}

@override
String toString() {
    return 'BridgeSummary(id: $id, name: $name, hostname: $hostname, platform: $platform, status: $status, addedAt: $addedAt, lastSeenAt: $lastSeenAt)';
}


}

/// @nodoc
abstract mixin class _$BridgeSummaryCopyWith<$Res> implements $BridgeSummaryCopyWith<$Res> {
  factory _$BridgeSummaryCopyWith(_BridgeSummary value, $Res Function(_BridgeSummary) _then) = __$BridgeSummaryCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String hostname,@JsonKey(unknownEnumValue: BridgePlatform.unknown) BridgePlatform platform, BridgeRegistrationStatus status, DateTime addedAt, DateTime? lastSeenAt
});




}
/// @nodoc
class __$BridgeSummaryCopyWithImpl<$Res>
    implements _$BridgeSummaryCopyWith<$Res> {
  __$BridgeSummaryCopyWithImpl(this._self, this._then);

  final _BridgeSummary _self;
  final $Res Function(_BridgeSummary) _then;

/// Create a copy of BridgeSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? hostname = null,Object? platform = null,Object? status = null,Object? addedAt = null,Object? lastSeenAt = freezed,}) {
  return _then(_BridgeSummary(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,hostname: null == hostname ? _self.hostname : hostname // ignore: cast_nullable_to_non_nullable
as String,platform: null == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as BridgePlatform,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as BridgeRegistrationStatus,addedAt: null == addedAt ? _self.addedAt : addedAt // ignore: cast_nullable_to_non_nullable
as DateTime,lastSeenAt: freezed == lastSeenAt ? _self.lastSeenAt : lastSeenAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
