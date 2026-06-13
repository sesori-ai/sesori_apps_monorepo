// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'open_code_ownership_record.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$OpenCodeOwnershipRecord {

 String get ownerSessionId; int get openCodePid; String? get openCodeStartMarker; String get openCodeExecutablePath; String get openCodeCommand; List<String> get openCodeArgs; int get port; int get bridgePid; String? get bridgeStartMarker; DateTime get startedAt; OpenCodeOwnershipStatus get status;
/// Create a copy of OpenCodeOwnershipRecord
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OpenCodeOwnershipRecordCopyWith<OpenCodeOwnershipRecord> get copyWith => _$OpenCodeOwnershipRecordCopyWithImpl<OpenCodeOwnershipRecord>(this as OpenCodeOwnershipRecord, _$identity);

  /// Serializes this OpenCodeOwnershipRecord to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OpenCodeOwnershipRecord&&(identical(other.ownerSessionId, ownerSessionId) || other.ownerSessionId == ownerSessionId)&&(identical(other.openCodePid, openCodePid) || other.openCodePid == openCodePid)&&(identical(other.openCodeStartMarker, openCodeStartMarker) || other.openCodeStartMarker == openCodeStartMarker)&&(identical(other.openCodeExecutablePath, openCodeExecutablePath) || other.openCodeExecutablePath == openCodeExecutablePath)&&(identical(other.openCodeCommand, openCodeCommand) || other.openCodeCommand == openCodeCommand)&&const DeepCollectionEquality().equals(other.openCodeArgs, openCodeArgs)&&(identical(other.port, port) || other.port == port)&&(identical(other.bridgePid, bridgePid) || other.bridgePid == bridgePid)&&(identical(other.bridgeStartMarker, bridgeStartMarker) || other.bridgeStartMarker == bridgeStartMarker)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,ownerSessionId,openCodePid,openCodeStartMarker,openCodeExecutablePath,openCodeCommand,const DeepCollectionEquality().hash(openCodeArgs),port,bridgePid,bridgeStartMarker,startedAt,status);

@override
String toString() {
  return 'OpenCodeOwnershipRecord(ownerSessionId: $ownerSessionId, openCodePid: $openCodePid, openCodeStartMarker: $openCodeStartMarker, openCodeExecutablePath: $openCodeExecutablePath, openCodeCommand: $openCodeCommand, openCodeArgs: $openCodeArgs, port: $port, bridgePid: $bridgePid, bridgeStartMarker: $bridgeStartMarker, startedAt: $startedAt, status: $status)';
}


}

/// @nodoc
abstract mixin class $OpenCodeOwnershipRecordCopyWith<$Res>  {
  factory $OpenCodeOwnershipRecordCopyWith(OpenCodeOwnershipRecord value, $Res Function(OpenCodeOwnershipRecord) _then) = _$OpenCodeOwnershipRecordCopyWithImpl;
@useResult
$Res call({
 String ownerSessionId, int openCodePid, String? openCodeStartMarker, String openCodeExecutablePath, String openCodeCommand, List<String> openCodeArgs, int port, int bridgePid, String? bridgeStartMarker, DateTime startedAt, OpenCodeOwnershipStatus status
});




}
/// @nodoc
class _$OpenCodeOwnershipRecordCopyWithImpl<$Res>
    implements $OpenCodeOwnershipRecordCopyWith<$Res> {
  _$OpenCodeOwnershipRecordCopyWithImpl(this._self, this._then);

  final OpenCodeOwnershipRecord _self;
  final $Res Function(OpenCodeOwnershipRecord) _then;

/// Create a copy of OpenCodeOwnershipRecord
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? ownerSessionId = null,Object? openCodePid = null,Object? openCodeStartMarker = freezed,Object? openCodeExecutablePath = null,Object? openCodeCommand = null,Object? openCodeArgs = null,Object? port = null,Object? bridgePid = null,Object? bridgeStartMarker = freezed,Object? startedAt = null,Object? status = null,}) {
  return _then(_self.copyWith(
ownerSessionId: null == ownerSessionId ? _self.ownerSessionId : ownerSessionId // ignore: cast_nullable_to_non_nullable
as String,openCodePid: null == openCodePid ? _self.openCodePid : openCodePid // ignore: cast_nullable_to_non_nullable
as int,openCodeStartMarker: freezed == openCodeStartMarker ? _self.openCodeStartMarker : openCodeStartMarker // ignore: cast_nullable_to_non_nullable
as String?,openCodeExecutablePath: null == openCodeExecutablePath ? _self.openCodeExecutablePath : openCodeExecutablePath // ignore: cast_nullable_to_non_nullable
as String,openCodeCommand: null == openCodeCommand ? _self.openCodeCommand : openCodeCommand // ignore: cast_nullable_to_non_nullable
as String,openCodeArgs: null == openCodeArgs ? _self.openCodeArgs : openCodeArgs // ignore: cast_nullable_to_non_nullable
as List<String>,port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,bridgePid: null == bridgePid ? _self.bridgePid : bridgePid // ignore: cast_nullable_to_non_nullable
as int,bridgeStartMarker: freezed == bridgeStartMarker ? _self.bridgeStartMarker : bridgeStartMarker // ignore: cast_nullable_to_non_nullable
as String?,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as OpenCodeOwnershipStatus,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _OpenCodeOwnershipRecord implements OpenCodeOwnershipRecord {
  const _OpenCodeOwnershipRecord({required this.ownerSessionId, required this.openCodePid, required this.openCodeStartMarker, required this.openCodeExecutablePath, required this.openCodeCommand, required final  List<String> openCodeArgs, required this.port, required this.bridgePid, required this.bridgeStartMarker, required this.startedAt, required this.status}): _openCodeArgs = openCodeArgs;
  factory _OpenCodeOwnershipRecord.fromJson(Map<String, dynamic> json) => _$OpenCodeOwnershipRecordFromJson(json);

@override final  String ownerSessionId;
@override final  int openCodePid;
@override final  String? openCodeStartMarker;
@override final  String openCodeExecutablePath;
@override final  String openCodeCommand;
 final  List<String> _openCodeArgs;
@override List<String> get openCodeArgs {
  if (_openCodeArgs is EqualUnmodifiableListView) return _openCodeArgs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_openCodeArgs);
}

@override final  int port;
@override final  int bridgePid;
@override final  String? bridgeStartMarker;
@override final  DateTime startedAt;
@override final  OpenCodeOwnershipStatus status;

/// Create a copy of OpenCodeOwnershipRecord
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OpenCodeOwnershipRecordCopyWith<_OpenCodeOwnershipRecord> get copyWith => __$OpenCodeOwnershipRecordCopyWithImpl<_OpenCodeOwnershipRecord>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OpenCodeOwnershipRecordToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OpenCodeOwnershipRecord&&(identical(other.ownerSessionId, ownerSessionId) || other.ownerSessionId == ownerSessionId)&&(identical(other.openCodePid, openCodePid) || other.openCodePid == openCodePid)&&(identical(other.openCodeStartMarker, openCodeStartMarker) || other.openCodeStartMarker == openCodeStartMarker)&&(identical(other.openCodeExecutablePath, openCodeExecutablePath) || other.openCodeExecutablePath == openCodeExecutablePath)&&(identical(other.openCodeCommand, openCodeCommand) || other.openCodeCommand == openCodeCommand)&&const DeepCollectionEquality().equals(other._openCodeArgs, _openCodeArgs)&&(identical(other.port, port) || other.port == port)&&(identical(other.bridgePid, bridgePid) || other.bridgePid == bridgePid)&&(identical(other.bridgeStartMarker, bridgeStartMarker) || other.bridgeStartMarker == bridgeStartMarker)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,ownerSessionId,openCodePid,openCodeStartMarker,openCodeExecutablePath,openCodeCommand,const DeepCollectionEquality().hash(_openCodeArgs),port,bridgePid,bridgeStartMarker,startedAt,status);

@override
String toString() {
  return 'OpenCodeOwnershipRecord(ownerSessionId: $ownerSessionId, openCodePid: $openCodePid, openCodeStartMarker: $openCodeStartMarker, openCodeExecutablePath: $openCodeExecutablePath, openCodeCommand: $openCodeCommand, openCodeArgs: $openCodeArgs, port: $port, bridgePid: $bridgePid, bridgeStartMarker: $bridgeStartMarker, startedAt: $startedAt, status: $status)';
}


}

/// @nodoc
abstract mixin class _$OpenCodeOwnershipRecordCopyWith<$Res> implements $OpenCodeOwnershipRecordCopyWith<$Res> {
  factory _$OpenCodeOwnershipRecordCopyWith(_OpenCodeOwnershipRecord value, $Res Function(_OpenCodeOwnershipRecord) _then) = __$OpenCodeOwnershipRecordCopyWithImpl;
@override @useResult
$Res call({
 String ownerSessionId, int openCodePid, String? openCodeStartMarker, String openCodeExecutablePath, String openCodeCommand, List<String> openCodeArgs, int port, int bridgePid, String? bridgeStartMarker, DateTime startedAt, OpenCodeOwnershipStatus status
});




}
/// @nodoc
class __$OpenCodeOwnershipRecordCopyWithImpl<$Res>
    implements _$OpenCodeOwnershipRecordCopyWith<$Res> {
  __$OpenCodeOwnershipRecordCopyWithImpl(this._self, this._then);

  final _OpenCodeOwnershipRecord _self;
  final $Res Function(_OpenCodeOwnershipRecord) _then;

/// Create a copy of OpenCodeOwnershipRecord
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? ownerSessionId = null,Object? openCodePid = null,Object? openCodeStartMarker = freezed,Object? openCodeExecutablePath = null,Object? openCodeCommand = null,Object? openCodeArgs = null,Object? port = null,Object? bridgePid = null,Object? bridgeStartMarker = freezed,Object? startedAt = null,Object? status = null,}) {
  return _then(_OpenCodeOwnershipRecord(
ownerSessionId: null == ownerSessionId ? _self.ownerSessionId : ownerSessionId // ignore: cast_nullable_to_non_nullable
as String,openCodePid: null == openCodePid ? _self.openCodePid : openCodePid // ignore: cast_nullable_to_non_nullable
as int,openCodeStartMarker: freezed == openCodeStartMarker ? _self.openCodeStartMarker : openCodeStartMarker // ignore: cast_nullable_to_non_nullable
as String?,openCodeExecutablePath: null == openCodeExecutablePath ? _self.openCodeExecutablePath : openCodeExecutablePath // ignore: cast_nullable_to_non_nullable
as String,openCodeCommand: null == openCodeCommand ? _self.openCodeCommand : openCodeCommand // ignore: cast_nullable_to_non_nullable
as String,openCodeArgs: null == openCodeArgs ? _self._openCodeArgs : openCodeArgs // ignore: cast_nullable_to_non_nullable
as List<String>,port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,bridgePid: null == bridgePid ? _self.bridgePid : bridgePid // ignore: cast_nullable_to_non_nullable
as int,bridgeStartMarker: freezed == bridgeStartMarker ? _self.bridgeStartMarker : bridgeStartMarker // ignore: cast_nullable_to_non_nullable
as String?,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as OpenCodeOwnershipStatus,
  ));
}


}

// dart format on
