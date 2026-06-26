// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'control_message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
ControlMessage _$ControlMessageFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'token_request':
          return ControlTokenRequest.fromJson(
            json
          );
                case 'token_response':
          return ControlTokenResponse.fromJson(
            json
          );
                case 'token_update':
          return ControlTokenUpdate.fromJson(
            json
          );
                case 'status':
          return ControlStatus.fromJson(
            json
          );
                case 'prompt_request':
          return ControlPromptRequest.fromJson(
            json
          );
                case 'prompt_response':
          return ControlPromptResponse.fromJson(
            json
          );
                case 'restart':
          return ControlRestart.fromJson(
            json
          );
                case 'unregister_and_exit':
          return ControlUnregisterAndExit.fromJson(
            json
          );
                case 'registered':
          return ControlRegistered.fromJson(
            json
          );
                case 'provision_progress':
          return ControlProvisionProgressMessage.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'type',
  'ControlMessage',
  'Invalid union type "${json['type']}"!'
);
        }
      
}

/// @nodoc
mixin _$ControlMessage {



  /// Serializes this ControlMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ControlMessage);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ControlMessage()';
}


}

/// @nodoc
class $ControlMessageCopyWith<$Res>  {
$ControlMessageCopyWith(ControlMessage _, $Res Function(ControlMessage) __);
}



/// @nodoc
@JsonSerializable()

class ControlTokenRequest implements ControlMessage {
  const ControlTokenRequest({required this.id, this.forceRefresh = false, final  String? $type}): $type = $type ?? 'token_request';
  factory ControlTokenRequest.fromJson(Map<String, dynamic> json) => _$ControlTokenRequestFromJson(json);

 final  String id;
@JsonKey() final  bool forceRefresh;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of ControlMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ControlTokenRequestCopyWith<ControlTokenRequest> get copyWith => _$ControlTokenRequestCopyWithImpl<ControlTokenRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ControlTokenRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ControlTokenRequest&&(identical(other.id, id) || other.id == id)&&(identical(other.forceRefresh, forceRefresh) || other.forceRefresh == forceRefresh));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,forceRefresh);

@override
String toString() {
  return 'ControlMessage.tokenRequest(id: $id, forceRefresh: $forceRefresh)';
}


}

/// @nodoc
abstract mixin class $ControlTokenRequestCopyWith<$Res> implements $ControlMessageCopyWith<$Res> {
  factory $ControlTokenRequestCopyWith(ControlTokenRequest value, $Res Function(ControlTokenRequest) _then) = _$ControlTokenRequestCopyWithImpl;
@useResult
$Res call({
 String id, bool forceRefresh
});




}
/// @nodoc
class _$ControlTokenRequestCopyWithImpl<$Res>
    implements $ControlTokenRequestCopyWith<$Res> {
  _$ControlTokenRequestCopyWithImpl(this._self, this._then);

  final ControlTokenRequest _self;
  final $Res Function(ControlTokenRequest) _then;

/// Create a copy of ControlMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? id = null,Object? forceRefresh = null,}) {
  return _then(ControlTokenRequest(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,forceRefresh: null == forceRefresh ? _self.forceRefresh : forceRefresh // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
@JsonSerializable()

class ControlTokenResponse implements ControlMessage {
  const ControlTokenResponse({required this.id, required this.accessToken, final  String? $type}): $type = $type ?? 'token_response';
  factory ControlTokenResponse.fromJson(Map<String, dynamic> json) => _$ControlTokenResponseFromJson(json);

 final  String id;
 final  String? accessToken;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of ControlMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ControlTokenResponseCopyWith<ControlTokenResponse> get copyWith => _$ControlTokenResponseCopyWithImpl<ControlTokenResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ControlTokenResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ControlTokenResponse&&(identical(other.id, id) || other.id == id)&&(identical(other.accessToken, accessToken) || other.accessToken == accessToken));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,accessToken);

@override
String toString() {
  return 'ControlMessage.tokenResponse(id: $id, accessToken: $accessToken)';
}


}

/// @nodoc
abstract mixin class $ControlTokenResponseCopyWith<$Res> implements $ControlMessageCopyWith<$Res> {
  factory $ControlTokenResponseCopyWith(ControlTokenResponse value, $Res Function(ControlTokenResponse) _then) = _$ControlTokenResponseCopyWithImpl;
@useResult
$Res call({
 String id, String? accessToken
});




}
/// @nodoc
class _$ControlTokenResponseCopyWithImpl<$Res>
    implements $ControlTokenResponseCopyWith<$Res> {
  _$ControlTokenResponseCopyWithImpl(this._self, this._then);

  final ControlTokenResponse _self;
  final $Res Function(ControlTokenResponse) _then;

/// Create a copy of ControlMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? id = null,Object? accessToken = freezed,}) {
  return _then(ControlTokenResponse(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,accessToken: freezed == accessToken ? _self.accessToken : accessToken // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class ControlTokenUpdate implements ControlMessage {
  const ControlTokenUpdate({required this.accessToken, final  String? $type}): $type = $type ?? 'token_update';
  factory ControlTokenUpdate.fromJson(Map<String, dynamic> json) => _$ControlTokenUpdateFromJson(json);

 final  String accessToken;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of ControlMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ControlTokenUpdateCopyWith<ControlTokenUpdate> get copyWith => _$ControlTokenUpdateCopyWithImpl<ControlTokenUpdate>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ControlTokenUpdateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ControlTokenUpdate&&(identical(other.accessToken, accessToken) || other.accessToken == accessToken));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,accessToken);

@override
String toString() {
  return 'ControlMessage.tokenUpdate(accessToken: $accessToken)';
}


}

/// @nodoc
abstract mixin class $ControlTokenUpdateCopyWith<$Res> implements $ControlMessageCopyWith<$Res> {
  factory $ControlTokenUpdateCopyWith(ControlTokenUpdate value, $Res Function(ControlTokenUpdate) _then) = _$ControlTokenUpdateCopyWithImpl;
@useResult
$Res call({
 String accessToken
});




}
/// @nodoc
class _$ControlTokenUpdateCopyWithImpl<$Res>
    implements $ControlTokenUpdateCopyWith<$Res> {
  _$ControlTokenUpdateCopyWithImpl(this._self, this._then);

  final ControlTokenUpdate _self;
  final $Res Function(ControlTokenUpdate) _then;

/// Create a copy of ControlMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? accessToken = null,}) {
  return _then(ControlTokenUpdate(
accessToken: null == accessToken ? _self.accessToken : accessToken // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class ControlStatus implements ControlMessage {
  const ControlStatus({@JsonKey(unknownEnumValue: ControlRelayConnectionState.unknown) required this.relay, @JsonKey(unknownEnumValue: ControlPluginHealthState.unknown) required this.plugin, this.activeSessionCount = 0, final  String? $type}): $type = $type ?? 'status';
  factory ControlStatus.fromJson(Map<String, dynamic> json) => _$ControlStatusFromJson(json);

@JsonKey(unknownEnumValue: ControlRelayConnectionState.unknown) final  ControlRelayConnectionState relay;
@JsonKey(unknownEnumValue: ControlPluginHealthState.unknown) final  ControlPluginHealthState plugin;
@JsonKey() final  int activeSessionCount;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of ControlMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ControlStatusCopyWith<ControlStatus> get copyWith => _$ControlStatusCopyWithImpl<ControlStatus>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ControlStatusToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ControlStatus&&(identical(other.relay, relay) || other.relay == relay)&&(identical(other.plugin, plugin) || other.plugin == plugin)&&(identical(other.activeSessionCount, activeSessionCount) || other.activeSessionCount == activeSessionCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,relay,plugin,activeSessionCount);

@override
String toString() {
  return 'ControlMessage.status(relay: $relay, plugin: $plugin, activeSessionCount: $activeSessionCount)';
}


}

/// @nodoc
abstract mixin class $ControlStatusCopyWith<$Res> implements $ControlMessageCopyWith<$Res> {
  factory $ControlStatusCopyWith(ControlStatus value, $Res Function(ControlStatus) _then) = _$ControlStatusCopyWithImpl;
@useResult
$Res call({
@JsonKey(unknownEnumValue: ControlRelayConnectionState.unknown) ControlRelayConnectionState relay,@JsonKey(unknownEnumValue: ControlPluginHealthState.unknown) ControlPluginHealthState plugin, int activeSessionCount
});




}
/// @nodoc
class _$ControlStatusCopyWithImpl<$Res>
    implements $ControlStatusCopyWith<$Res> {
  _$ControlStatusCopyWithImpl(this._self, this._then);

  final ControlStatus _self;
  final $Res Function(ControlStatus) _then;

/// Create a copy of ControlMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? relay = null,Object? plugin = null,Object? activeSessionCount = null,}) {
  return _then(ControlStatus(
relay: null == relay ? _self.relay : relay // ignore: cast_nullable_to_non_nullable
as ControlRelayConnectionState,plugin: null == plugin ? _self.plugin : plugin // ignore: cast_nullable_to_non_nullable
as ControlPluginHealthState,activeSessionCount: null == activeSessionCount ? _self.activeSessionCount : activeSessionCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
@JsonSerializable()

class ControlPromptRequest implements ControlMessage {
  const ControlPromptRequest({required this.id, @JsonKey(unknownEnumValue: ControlPromptKind.unknown) required this.kind, required this.message, final  String? $type}): $type = $type ?? 'prompt_request';
  factory ControlPromptRequest.fromJson(Map<String, dynamic> json) => _$ControlPromptRequestFromJson(json);

 final  String id;
@JsonKey(unknownEnumValue: ControlPromptKind.unknown) final  ControlPromptKind kind;
 final  String? message;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of ControlMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ControlPromptRequestCopyWith<ControlPromptRequest> get copyWith => _$ControlPromptRequestCopyWithImpl<ControlPromptRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ControlPromptRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ControlPromptRequest&&(identical(other.id, id) || other.id == id)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,kind,message);

@override
String toString() {
  return 'ControlMessage.promptRequest(id: $id, kind: $kind, message: $message)';
}


}

/// @nodoc
abstract mixin class $ControlPromptRequestCopyWith<$Res> implements $ControlMessageCopyWith<$Res> {
  factory $ControlPromptRequestCopyWith(ControlPromptRequest value, $Res Function(ControlPromptRequest) _then) = _$ControlPromptRequestCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(unknownEnumValue: ControlPromptKind.unknown) ControlPromptKind kind, String? message
});




}
/// @nodoc
class _$ControlPromptRequestCopyWithImpl<$Res>
    implements $ControlPromptRequestCopyWith<$Res> {
  _$ControlPromptRequestCopyWithImpl(this._self, this._then);

  final ControlPromptRequest _self;
  final $Res Function(ControlPromptRequest) _then;

/// Create a copy of ControlMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? id = null,Object? kind = null,Object? message = freezed,}) {
  return _then(ControlPromptRequest(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as ControlPromptKind,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class ControlPromptResponse implements ControlMessage {
  const ControlPromptResponse({required this.id, required this.accepted, final  String? $type}): $type = $type ?? 'prompt_response';
  factory ControlPromptResponse.fromJson(Map<String, dynamic> json) => _$ControlPromptResponseFromJson(json);

 final  String id;
 final  bool accepted;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of ControlMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ControlPromptResponseCopyWith<ControlPromptResponse> get copyWith => _$ControlPromptResponseCopyWithImpl<ControlPromptResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ControlPromptResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ControlPromptResponse&&(identical(other.id, id) || other.id == id)&&(identical(other.accepted, accepted) || other.accepted == accepted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,accepted);

@override
String toString() {
  return 'ControlMessage.promptResponse(id: $id, accepted: $accepted)';
}


}

/// @nodoc
abstract mixin class $ControlPromptResponseCopyWith<$Res> implements $ControlMessageCopyWith<$Res> {
  factory $ControlPromptResponseCopyWith(ControlPromptResponse value, $Res Function(ControlPromptResponse) _then) = _$ControlPromptResponseCopyWithImpl;
@useResult
$Res call({
 String id, bool accepted
});




}
/// @nodoc
class _$ControlPromptResponseCopyWithImpl<$Res>
    implements $ControlPromptResponseCopyWith<$Res> {
  _$ControlPromptResponseCopyWithImpl(this._self, this._then);

  final ControlPromptResponse _self;
  final $Res Function(ControlPromptResponse) _then;

/// Create a copy of ControlMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? id = null,Object? accepted = null,}) {
  return _then(ControlPromptResponse(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,accepted: null == accepted ? _self.accepted : accepted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
@JsonSerializable()

class ControlRestart implements ControlMessage {
  const ControlRestart({final  String? $type}): $type = $type ?? 'restart';
  factory ControlRestart.fromJson(Map<String, dynamic> json) => _$ControlRestartFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$ControlRestartToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ControlRestart);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ControlMessage.restart()';
}


}




/// @nodoc
@JsonSerializable()

class ControlUnregisterAndExit implements ControlMessage {
  const ControlUnregisterAndExit({final  String? $type}): $type = $type ?? 'unregister_and_exit';
  factory ControlUnregisterAndExit.fromJson(Map<String, dynamic> json) => _$ControlUnregisterAndExitFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$ControlUnregisterAndExitToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ControlUnregisterAndExit);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ControlMessage.unregisterAndExit()';
}


}




/// @nodoc
@JsonSerializable()

class ControlRegistered implements ControlMessage {
  const ControlRegistered({required this.bridgeId, final  String? $type}): $type = $type ?? 'registered';
  factory ControlRegistered.fromJson(Map<String, dynamic> json) => _$ControlRegisteredFromJson(json);

 final  String bridgeId;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of ControlMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ControlRegisteredCopyWith<ControlRegistered> get copyWith => _$ControlRegisteredCopyWithImpl<ControlRegistered>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ControlRegisteredToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ControlRegistered&&(identical(other.bridgeId, bridgeId) || other.bridgeId == bridgeId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,bridgeId);

@override
String toString() {
  return 'ControlMessage.registered(bridgeId: $bridgeId)';
}


}

/// @nodoc
abstract mixin class $ControlRegisteredCopyWith<$Res> implements $ControlMessageCopyWith<$Res> {
  factory $ControlRegisteredCopyWith(ControlRegistered value, $Res Function(ControlRegistered) _then) = _$ControlRegisteredCopyWithImpl;
@useResult
$Res call({
 String bridgeId
});




}
/// @nodoc
class _$ControlRegisteredCopyWithImpl<$Res>
    implements $ControlRegisteredCopyWith<$Res> {
  _$ControlRegisteredCopyWithImpl(this._self, this._then);

  final ControlRegistered _self;
  final $Res Function(ControlRegistered) _then;

/// Create a copy of ControlMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? bridgeId = null,}) {
  return _then(ControlRegistered(
bridgeId: null == bridgeId ? _self.bridgeId : bridgeId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class ControlProvisionProgressMessage implements ControlMessage {
  const ControlProvisionProgressMessage({required this.progress, final  String? $type}): $type = $type ?? 'provision_progress';
  factory ControlProvisionProgressMessage.fromJson(Map<String, dynamic> json) => _$ControlProvisionProgressMessageFromJson(json);

 final  ControlProvisionProgress progress;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of ControlMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ControlProvisionProgressMessageCopyWith<ControlProvisionProgressMessage> get copyWith => _$ControlProvisionProgressMessageCopyWithImpl<ControlProvisionProgressMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ControlProvisionProgressMessageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ControlProvisionProgressMessage&&(identical(other.progress, progress) || other.progress == progress));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,progress);

@override
String toString() {
  return 'ControlMessage.provisionProgress(progress: $progress)';
}


}

/// @nodoc
abstract mixin class $ControlProvisionProgressMessageCopyWith<$Res> implements $ControlMessageCopyWith<$Res> {
  factory $ControlProvisionProgressMessageCopyWith(ControlProvisionProgressMessage value, $Res Function(ControlProvisionProgressMessage) _then) = _$ControlProvisionProgressMessageCopyWithImpl;
@useResult
$Res call({
 ControlProvisionProgress progress
});


$ControlProvisionProgressCopyWith<$Res> get progress;

}
/// @nodoc
class _$ControlProvisionProgressMessageCopyWithImpl<$Res>
    implements $ControlProvisionProgressMessageCopyWith<$Res> {
  _$ControlProvisionProgressMessageCopyWithImpl(this._self, this._then);

  final ControlProvisionProgressMessage _self;
  final $Res Function(ControlProvisionProgressMessage) _then;

/// Create a copy of ControlMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? progress = null,}) {
  return _then(ControlProvisionProgressMessage(
progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as ControlProvisionProgress,
  ));
}

/// Create a copy of ControlMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ControlProvisionProgressCopyWith<$Res> get progress {
  
  return $ControlProvisionProgressCopyWith<$Res>(_self.progress, (value) {
    return _then(_self.copyWith(progress: value));
  });
}
}

// dart format on
