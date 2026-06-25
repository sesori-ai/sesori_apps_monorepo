// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'codex_ownership_record.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CodexOwnershipRecord {

 String get ownerSessionId; int get codexPid; String? get codexStartMarker; String get codexExecutablePath; String get codexCommand; List<String> get codexArgs; int get port; int get bridgePid; String? get bridgeStartMarker; DateTime get startedAt; CodexOwnershipStatus get status;
/// Create a copy of CodexOwnershipRecord
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodexOwnershipRecordCopyWith<CodexOwnershipRecord> get copyWith => _$CodexOwnershipRecordCopyWithImpl<CodexOwnershipRecord>(this as CodexOwnershipRecord, _$identity);

  /// Serializes this CodexOwnershipRecord to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodexOwnershipRecord&&(identical(other.ownerSessionId, ownerSessionId) || other.ownerSessionId == ownerSessionId)&&(identical(other.codexPid, codexPid) || other.codexPid == codexPid)&&(identical(other.codexStartMarker, codexStartMarker) || other.codexStartMarker == codexStartMarker)&&(identical(other.codexExecutablePath, codexExecutablePath) || other.codexExecutablePath == codexExecutablePath)&&(identical(other.codexCommand, codexCommand) || other.codexCommand == codexCommand)&&const DeepCollectionEquality().equals(other.codexArgs, codexArgs)&&(identical(other.port, port) || other.port == port)&&(identical(other.bridgePid, bridgePid) || other.bridgePid == bridgePid)&&(identical(other.bridgeStartMarker, bridgeStartMarker) || other.bridgeStartMarker == bridgeStartMarker)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,ownerSessionId,codexPid,codexStartMarker,codexExecutablePath,codexCommand,const DeepCollectionEquality().hash(codexArgs),port,bridgePid,bridgeStartMarker,startedAt,status);

@override
String toString() {
  return 'CodexOwnershipRecord(ownerSessionId: $ownerSessionId, codexPid: $codexPid, codexStartMarker: $codexStartMarker, codexExecutablePath: $codexExecutablePath, codexCommand: $codexCommand, codexArgs: $codexArgs, port: $port, bridgePid: $bridgePid, bridgeStartMarker: $bridgeStartMarker, startedAt: $startedAt, status: $status)';
}


}

/// @nodoc
abstract mixin class $CodexOwnershipRecordCopyWith<$Res>  {
  factory $CodexOwnershipRecordCopyWith(CodexOwnershipRecord value, $Res Function(CodexOwnershipRecord) _then) = _$CodexOwnershipRecordCopyWithImpl;
@useResult
$Res call({
 String ownerSessionId, int codexPid, String? codexStartMarker, String codexExecutablePath, String codexCommand, List<String> codexArgs, int port, int bridgePid, String? bridgeStartMarker, DateTime startedAt, CodexOwnershipStatus status
});




}
/// @nodoc
class _$CodexOwnershipRecordCopyWithImpl<$Res>
    implements $CodexOwnershipRecordCopyWith<$Res> {
  _$CodexOwnershipRecordCopyWithImpl(this._self, this._then);

  final CodexOwnershipRecord _self;
  final $Res Function(CodexOwnershipRecord) _then;

/// Create a copy of CodexOwnershipRecord
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? ownerSessionId = null,Object? codexPid = null,Object? codexStartMarker = freezed,Object? codexExecutablePath = null,Object? codexCommand = null,Object? codexArgs = null,Object? port = null,Object? bridgePid = null,Object? bridgeStartMarker = freezed,Object? startedAt = null,Object? status = null,}) {
  return _then(_self.copyWith(
ownerSessionId: null == ownerSessionId ? _self.ownerSessionId : ownerSessionId // ignore: cast_nullable_to_non_nullable
as String,codexPid: null == codexPid ? _self.codexPid : codexPid // ignore: cast_nullable_to_non_nullable
as int,codexStartMarker: freezed == codexStartMarker ? _self.codexStartMarker : codexStartMarker // ignore: cast_nullable_to_non_nullable
as String?,codexExecutablePath: null == codexExecutablePath ? _self.codexExecutablePath : codexExecutablePath // ignore: cast_nullable_to_non_nullable
as String,codexCommand: null == codexCommand ? _self.codexCommand : codexCommand // ignore: cast_nullable_to_non_nullable
as String,codexArgs: null == codexArgs ? _self.codexArgs : codexArgs // ignore: cast_nullable_to_non_nullable
as List<String>,port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,bridgePid: null == bridgePid ? _self.bridgePid : bridgePid // ignore: cast_nullable_to_non_nullable
as int,bridgeStartMarker: freezed == bridgeStartMarker ? _self.bridgeStartMarker : bridgeStartMarker // ignore: cast_nullable_to_non_nullable
as String?,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as CodexOwnershipStatus,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _CodexOwnershipRecord implements CodexOwnershipRecord {
  const _CodexOwnershipRecord({required this.ownerSessionId, required this.codexPid, required this.codexStartMarker, required this.codexExecutablePath, required this.codexCommand, required final  List<String> codexArgs, required this.port, required this.bridgePid, required this.bridgeStartMarker, required this.startedAt, required this.status}): _codexArgs = codexArgs;
  factory _CodexOwnershipRecord.fromJson(Map<String, dynamic> json) => _$CodexOwnershipRecordFromJson(json);

@override final  String ownerSessionId;
@override final  int codexPid;
@override final  String? codexStartMarker;
@override final  String codexExecutablePath;
@override final  String codexCommand;
 final  List<String> _codexArgs;
@override List<String> get codexArgs {
  if (_codexArgs is EqualUnmodifiableListView) return _codexArgs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_codexArgs);
}

@override final  int port;
@override final  int bridgePid;
@override final  String? bridgeStartMarker;
@override final  DateTime startedAt;
@override final  CodexOwnershipStatus status;

/// Create a copy of CodexOwnershipRecord
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodexOwnershipRecordCopyWith<_CodexOwnershipRecord> get copyWith => __$CodexOwnershipRecordCopyWithImpl<_CodexOwnershipRecord>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CodexOwnershipRecordToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodexOwnershipRecord&&(identical(other.ownerSessionId, ownerSessionId) || other.ownerSessionId == ownerSessionId)&&(identical(other.codexPid, codexPid) || other.codexPid == codexPid)&&(identical(other.codexStartMarker, codexStartMarker) || other.codexStartMarker == codexStartMarker)&&(identical(other.codexExecutablePath, codexExecutablePath) || other.codexExecutablePath == codexExecutablePath)&&(identical(other.codexCommand, codexCommand) || other.codexCommand == codexCommand)&&const DeepCollectionEquality().equals(other._codexArgs, _codexArgs)&&(identical(other.port, port) || other.port == port)&&(identical(other.bridgePid, bridgePid) || other.bridgePid == bridgePid)&&(identical(other.bridgeStartMarker, bridgeStartMarker) || other.bridgeStartMarker == bridgeStartMarker)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,ownerSessionId,codexPid,codexStartMarker,codexExecutablePath,codexCommand,const DeepCollectionEquality().hash(_codexArgs),port,bridgePid,bridgeStartMarker,startedAt,status);

@override
String toString() {
  return 'CodexOwnershipRecord(ownerSessionId: $ownerSessionId, codexPid: $codexPid, codexStartMarker: $codexStartMarker, codexExecutablePath: $codexExecutablePath, codexCommand: $codexCommand, codexArgs: $codexArgs, port: $port, bridgePid: $bridgePid, bridgeStartMarker: $bridgeStartMarker, startedAt: $startedAt, status: $status)';
}


}

/// @nodoc
abstract mixin class _$CodexOwnershipRecordCopyWith<$Res> implements $CodexOwnershipRecordCopyWith<$Res> {
  factory _$CodexOwnershipRecordCopyWith(_CodexOwnershipRecord value, $Res Function(_CodexOwnershipRecord) _then) = __$CodexOwnershipRecordCopyWithImpl;
@override @useResult
$Res call({
 String ownerSessionId, int codexPid, String? codexStartMarker, String codexExecutablePath, String codexCommand, List<String> codexArgs, int port, int bridgePid, String? bridgeStartMarker, DateTime startedAt, CodexOwnershipStatus status
});




}
/// @nodoc
class __$CodexOwnershipRecordCopyWithImpl<$Res>
    implements _$CodexOwnershipRecordCopyWith<$Res> {
  __$CodexOwnershipRecordCopyWithImpl(this._self, this._then);

  final _CodexOwnershipRecord _self;
  final $Res Function(_CodexOwnershipRecord) _then;

/// Create a copy of CodexOwnershipRecord
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? ownerSessionId = null,Object? codexPid = null,Object? codexStartMarker = freezed,Object? codexExecutablePath = null,Object? codexCommand = null,Object? codexArgs = null,Object? port = null,Object? bridgePid = null,Object? bridgeStartMarker = freezed,Object? startedAt = null,Object? status = null,}) {
  return _then(_CodexOwnershipRecord(
ownerSessionId: null == ownerSessionId ? _self.ownerSessionId : ownerSessionId // ignore: cast_nullable_to_non_nullable
as String,codexPid: null == codexPid ? _self.codexPid : codexPid // ignore: cast_nullable_to_non_nullable
as int,codexStartMarker: freezed == codexStartMarker ? _self.codexStartMarker : codexStartMarker // ignore: cast_nullable_to_non_nullable
as String?,codexExecutablePath: null == codexExecutablePath ? _self.codexExecutablePath : codexExecutablePath // ignore: cast_nullable_to_non_nullable
as String,codexCommand: null == codexCommand ? _self.codexCommand : codexCommand // ignore: cast_nullable_to_non_nullable
as String,codexArgs: null == codexArgs ? _self._codexArgs : codexArgs // ignore: cast_nullable_to_non_nullable
as List<String>,port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,bridgePid: null == bridgePid ? _self.bridgePid : bridgePid // ignore: cast_nullable_to_non_nullable
as int,bridgeStartMarker: freezed == bridgeStartMarker ? _self.bridgeStartMarker : bridgeStartMarker // ignore: cast_nullable_to_non_nullable
as String?,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as CodexOwnershipStatus,
  ));
}


}

// dart format on
