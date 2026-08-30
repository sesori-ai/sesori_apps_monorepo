// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bridge_registration_record.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BridgeRegistrationRecord {

 String get bridgeId; String get accountId;
/// Create a copy of BridgeRegistrationRecord
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BridgeRegistrationRecordCopyWith<BridgeRegistrationRecord> get copyWith => _$BridgeRegistrationRecordCopyWithImpl<BridgeRegistrationRecord>(this as BridgeRegistrationRecord, _$identity);

  /// Serializes this BridgeRegistrationRecord to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BridgeRegistrationRecord&&(identical(other.bridgeId, bridgeId) || other.bridgeId == bridgeId)&&(identical(other.accountId, accountId) || other.accountId == accountId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,bridgeId,accountId);

@override
String toString() {
  return 'BridgeRegistrationRecord(bridgeId: $bridgeId, accountId: $accountId)';
}


}

/// @nodoc
abstract mixin class $BridgeRegistrationRecordCopyWith<$Res>  {
  factory $BridgeRegistrationRecordCopyWith(BridgeRegistrationRecord value, $Res Function(BridgeRegistrationRecord) _then) = _$BridgeRegistrationRecordCopyWithImpl;
@useResult
$Res call({
 String bridgeId, String accountId
});




}
/// @nodoc
class _$BridgeRegistrationRecordCopyWithImpl<$Res>
    implements $BridgeRegistrationRecordCopyWith<$Res> {
  _$BridgeRegistrationRecordCopyWithImpl(this._self, this._then);

  final BridgeRegistrationRecord _self;
  final $Res Function(BridgeRegistrationRecord) _then;

/// Create a copy of BridgeRegistrationRecord
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? bridgeId = null,Object? accountId = null,}) {
  return _then(BridgeRegistrationRecord(
bridgeId: null == bridgeId ? _self.bridgeId : bridgeId // ignore: cast_nullable_to_non_nullable
as String,accountId: null == accountId ? _self.accountId : accountId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _BridgeRegistrationRecord implements BridgeRegistrationRecord {
  const _BridgeRegistrationRecord({required this.bridgeId, required this.accountId});
  factory _BridgeRegistrationRecord.fromJson(Map<String, dynamic> json) => _$BridgeRegistrationRecordFromJson(json);

@override final  String bridgeId;
@override final  String accountId;

/// Create a copy of BridgeRegistrationRecord
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BridgeRegistrationRecordCopyWith<_BridgeRegistrationRecord> get copyWith => __$BridgeRegistrationRecordCopyWithImpl<_BridgeRegistrationRecord>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BridgeRegistrationRecordToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BridgeRegistrationRecord&&(identical(other.bridgeId, bridgeId) || other.bridgeId == bridgeId)&&(identical(other.accountId, accountId) || other.accountId == accountId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,bridgeId,accountId);

@override
String toString() {
  return 'BridgeRegistrationRecord(bridgeId: $bridgeId, accountId: $accountId)';
}


}

/// @nodoc
abstract mixin class _$BridgeRegistrationRecordCopyWith<$Res> implements $BridgeRegistrationRecordCopyWith<$Res> {
  factory _$BridgeRegistrationRecordCopyWith(_BridgeRegistrationRecord value, $Res Function(_BridgeRegistrationRecord) _then) = __$BridgeRegistrationRecordCopyWithImpl;
@override @useResult
$Res call({
 String bridgeId, String accountId
});




}
/// @nodoc
class __$BridgeRegistrationRecordCopyWithImpl<$Res>
    implements _$BridgeRegistrationRecordCopyWith<$Res> {
  __$BridgeRegistrationRecordCopyWithImpl(this._self, this._then);

  final _BridgeRegistrationRecord _self;
  final $Res Function(_BridgeRegistrationRecord) _then;

/// Create a copy of BridgeRegistrationRecord
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? bridgeId = null,Object? accountId = null,}) {
  return _then(_BridgeRegistrationRecord(
bridgeId: null == bridgeId ? _self.bridgeId : bridgeId // ignore: cast_nullable_to_non_nullable
as String,accountId: null == accountId ? _self.accountId : accountId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
