// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'messages.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
RelayMessage _$RelayMessageFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'request':
          return RelayRequest.fromJson(
            json
          );
                case 'response':
          return RelayResponse.fromJson(
            json
          );
                case 'sse_event':
          return RelaySseEvent.fromJson(
            json
          );
                case 'sse_subscribe':
          return RelaySseSubscribe.fromJson(
            json
          );
                case 'sse_unsubscribe':
          return RelaySseUnsubscribe.fromJson(
            json
          );
                case 'key_exchange':
          return RelayKeyExchange.fromJson(
            json
          );
                case 'ready':
          return RelayReady.fromJson(
            json
          );
                case 'resume':
          return RelayResume.fromJson(
            json
          );
                case 'resume_ack':
          return RelayResumeAck.fromJson(
            json
          );
                case 'rekey_required':
          return RelayRekeyRequired.fromJson(
            json
          );
                case 'auth':
          return AuthRelayMessage.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'type',
  'RelayMessage',
  'Invalid union type "${json['type']}"!'
);
        }
      
}

/// @nodoc
mixin _$RelayMessage {



  /// Serializes this RelayMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RelayMessage);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'RelayMessage()';
}


}

/// @nodoc
class $RelayMessageCopyWith<$Res>  {
$RelayMessageCopyWith(RelayMessage _, $Res Function(RelayMessage) __);
}



/// @nodoc
@JsonSerializable()

class RelayRequest implements RelayMessage {
  const RelayRequest({required this.id, required this.method, required this.path, required final  Map<String, String> headers, required this.body, final  String? $type}): _headers = headers,$type = $type ?? 'request';
  factory RelayRequest.fromJson(Map<String, dynamic> json) => _$RelayRequestFromJson(json);

 final  String id;
 final  String method;
 final  String path;
 final  Map<String, String> _headers;
 Map<String, String> get headers {
  if (_headers is EqualUnmodifiableMapView) return _headers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_headers);
}

 final  String? body;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of RelayMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RelayRequestCopyWith<RelayRequest> get copyWith => _$RelayRequestCopyWithImpl<RelayRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RelayRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RelayRequest&&(identical(other.id, id) || other.id == id)&&(identical(other.method, method) || other.method == method)&&(identical(other.path, path) || other.path == path)&&const DeepCollectionEquality().equals(other._headers, _headers)&&(identical(other.body, body) || other.body == body));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,method,path,const DeepCollectionEquality().hash(_headers),body);

@override
String toString() {
  return 'RelayMessage.request(id: $id, method: $method, path: $path, headers: $headers, body: $body)';
}


}

/// @nodoc
abstract mixin class $RelayRequestCopyWith<$Res> implements $RelayMessageCopyWith<$Res> {
  factory $RelayRequestCopyWith(RelayRequest value, $Res Function(RelayRequest) _then) = _$RelayRequestCopyWithImpl;
@useResult
$Res call({
 String id, String method, String path, Map<String, String> headers, String? body
});




}
/// @nodoc
class _$RelayRequestCopyWithImpl<$Res>
    implements $RelayRequestCopyWith<$Res> {
  _$RelayRequestCopyWithImpl(this._self, this._then);

  final RelayRequest _self;
  final $Res Function(RelayRequest) _then;

/// Create a copy of RelayMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? id = null,Object? method = null,Object? path = null,Object? headers = null,Object? body = freezed,}) {
  return _then(RelayRequest(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as String,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,headers: null == headers ? _self._headers : headers // ignore: cast_nullable_to_non_nullable
as Map<String, String>,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class RelayResponse implements RelayMessage {
  const RelayResponse({required this.id, required this.status, required final  Map<String, String> headers, required this.body, final  String? $type}): _headers = headers,$type = $type ?? 'response';
  factory RelayResponse.fromJson(Map<String, dynamic> json) => _$RelayResponseFromJson(json);

 final  String id;
 final  int status;
 final  Map<String, String> _headers;
 Map<String, String> get headers {
  if (_headers is EqualUnmodifiableMapView) return _headers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_headers);
}

 final  String? body;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of RelayMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RelayResponseCopyWith<RelayResponse> get copyWith => _$RelayResponseCopyWithImpl<RelayResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RelayResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RelayResponse&&(identical(other.id, id) || other.id == id)&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other._headers, _headers)&&(identical(other.body, body) || other.body == body));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,status,const DeepCollectionEquality().hash(_headers),body);

@override
String toString() {
  return 'RelayMessage.response(id: $id, status: $status, headers: $headers, body: $body)';
}


}

/// @nodoc
abstract mixin class $RelayResponseCopyWith<$Res> implements $RelayMessageCopyWith<$Res> {
  factory $RelayResponseCopyWith(RelayResponse value, $Res Function(RelayResponse) _then) = _$RelayResponseCopyWithImpl;
@useResult
$Res call({
 String id, int status, Map<String, String> headers, String? body
});




}
/// @nodoc
class _$RelayResponseCopyWithImpl<$Res>
    implements $RelayResponseCopyWith<$Res> {
  _$RelayResponseCopyWithImpl(this._self, this._then);

  final RelayResponse _self;
  final $Res Function(RelayResponse) _then;

/// Create a copy of RelayMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? id = null,Object? status = null,Object? headers = null,Object? body = freezed,}) {
  return _then(RelayResponse(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as int,headers: null == headers ? _self._headers : headers // ignore: cast_nullable_to_non_nullable
as Map<String, String>,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class RelaySseEvent implements RelayMessage {
  const RelaySseEvent({required this.data, final  String? $type}): $type = $type ?? 'sse_event';
  factory RelaySseEvent.fromJson(Map<String, dynamic> json) => _$RelaySseEventFromJson(json);

 final  String data;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of RelayMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RelaySseEventCopyWith<RelaySseEvent> get copyWith => _$RelaySseEventCopyWithImpl<RelaySseEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RelaySseEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RelaySseEvent&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'RelayMessage.sseEvent(data: $data)';
}


}

/// @nodoc
abstract mixin class $RelaySseEventCopyWith<$Res> implements $RelayMessageCopyWith<$Res> {
  factory $RelaySseEventCopyWith(RelaySseEvent value, $Res Function(RelaySseEvent) _then) = _$RelaySseEventCopyWithImpl;
@useResult
$Res call({
 String data
});




}
/// @nodoc
class _$RelaySseEventCopyWithImpl<$Res>
    implements $RelaySseEventCopyWith<$Res> {
  _$RelaySseEventCopyWithImpl(this._self, this._then);

  final RelaySseEvent _self;
  final $Res Function(RelaySseEvent) _then;

/// Create a copy of RelayMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(RelaySseEvent(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class RelaySseSubscribe implements RelayMessage {
  const RelaySseSubscribe({required this.path, final  String? $type}): $type = $type ?? 'sse_subscribe';
  factory RelaySseSubscribe.fromJson(Map<String, dynamic> json) => _$RelaySseSubscribeFromJson(json);

 final  String path;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of RelayMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RelaySseSubscribeCopyWith<RelaySseSubscribe> get copyWith => _$RelaySseSubscribeCopyWithImpl<RelaySseSubscribe>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RelaySseSubscribeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RelaySseSubscribe&&(identical(other.path, path) || other.path == path));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,path);

@override
String toString() {
  return 'RelayMessage.sseSubscribe(path: $path)';
}


}

/// @nodoc
abstract mixin class $RelaySseSubscribeCopyWith<$Res> implements $RelayMessageCopyWith<$Res> {
  factory $RelaySseSubscribeCopyWith(RelaySseSubscribe value, $Res Function(RelaySseSubscribe) _then) = _$RelaySseSubscribeCopyWithImpl;
@useResult
$Res call({
 String path
});




}
/// @nodoc
class _$RelaySseSubscribeCopyWithImpl<$Res>
    implements $RelaySseSubscribeCopyWith<$Res> {
  _$RelaySseSubscribeCopyWithImpl(this._self, this._then);

  final RelaySseSubscribe _self;
  final $Res Function(RelaySseSubscribe) _then;

/// Create a copy of RelayMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? path = null,}) {
  return _then(RelaySseSubscribe(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class RelaySseUnsubscribe implements RelayMessage {
  const RelaySseUnsubscribe({final  String? $type}): $type = $type ?? 'sse_unsubscribe';
  factory RelaySseUnsubscribe.fromJson(Map<String, dynamic> json) => _$RelaySseUnsubscribeFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$RelaySseUnsubscribeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RelaySseUnsubscribe);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'RelayMessage.sseUnsubscribe()';
}


}




/// @nodoc
@JsonSerializable()

class RelayKeyExchange implements RelayMessage {
  const RelayKeyExchange({required this.publicKey, final  String? $type}): $type = $type ?? 'key_exchange';
  factory RelayKeyExchange.fromJson(Map<String, dynamic> json) => _$RelayKeyExchangeFromJson(json);

 final  String publicKey;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of RelayMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RelayKeyExchangeCopyWith<RelayKeyExchange> get copyWith => _$RelayKeyExchangeCopyWithImpl<RelayKeyExchange>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RelayKeyExchangeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RelayKeyExchange&&(identical(other.publicKey, publicKey) || other.publicKey == publicKey));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,publicKey);

@override
String toString() {
  return 'RelayMessage.keyExchange(publicKey: $publicKey)';
}


}

/// @nodoc
abstract mixin class $RelayKeyExchangeCopyWith<$Res> implements $RelayMessageCopyWith<$Res> {
  factory $RelayKeyExchangeCopyWith(RelayKeyExchange value, $Res Function(RelayKeyExchange) _then) = _$RelayKeyExchangeCopyWithImpl;
@useResult
$Res call({
 String publicKey
});




}
/// @nodoc
class _$RelayKeyExchangeCopyWithImpl<$Res>
    implements $RelayKeyExchangeCopyWith<$Res> {
  _$RelayKeyExchangeCopyWithImpl(this._self, this._then);

  final RelayKeyExchange _self;
  final $Res Function(RelayKeyExchange) _then;

/// Create a copy of RelayMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? publicKey = null,}) {
  return _then(RelayKeyExchange(
publicKey: null == publicKey ? _self.publicKey : publicKey // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class RelayReady implements RelayMessage {
  const RelayReady({required this.publicKey, required this.roomKey, final  String? $type}): $type = $type ?? 'ready';
  factory RelayReady.fromJson(Map<String, dynamic> json) => _$RelayReadyFromJson(json);

 final  String publicKey;
 final  String roomKey;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of RelayMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RelayReadyCopyWith<RelayReady> get copyWith => _$RelayReadyCopyWithImpl<RelayReady>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RelayReadyToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RelayReady&&(identical(other.publicKey, publicKey) || other.publicKey == publicKey)&&(identical(other.roomKey, roomKey) || other.roomKey == roomKey));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,publicKey,roomKey);

@override
String toString() {
  return 'RelayMessage.ready(publicKey: $publicKey, roomKey: $roomKey)';
}


}

/// @nodoc
abstract mixin class $RelayReadyCopyWith<$Res> implements $RelayMessageCopyWith<$Res> {
  factory $RelayReadyCopyWith(RelayReady value, $Res Function(RelayReady) _then) = _$RelayReadyCopyWithImpl;
@useResult
$Res call({
 String publicKey, String roomKey
});




}
/// @nodoc
class _$RelayReadyCopyWithImpl<$Res>
    implements $RelayReadyCopyWith<$Res> {
  _$RelayReadyCopyWithImpl(this._self, this._then);

  final RelayReady _self;
  final $Res Function(RelayReady) _then;

/// Create a copy of RelayMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? publicKey = null,Object? roomKey = null,}) {
  return _then(RelayReady(
publicKey: null == publicKey ? _self.publicKey : publicKey // ignore: cast_nullable_to_non_nullable
as String,roomKey: null == roomKey ? _self.roomKey : roomKey // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class RelayResume implements RelayMessage {
  const RelayResume({final  String? $type}): $type = $type ?? 'resume';
  factory RelayResume.fromJson(Map<String, dynamic> json) => _$RelayResumeFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$RelayResumeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RelayResume);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'RelayMessage.resume()';
}


}




/// @nodoc
@JsonSerializable()

class RelayResumeAck implements RelayMessage {
  const RelayResumeAck({final  String? $type}): $type = $type ?? 'resume_ack';
  factory RelayResumeAck.fromJson(Map<String, dynamic> json) => _$RelayResumeAckFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$RelayResumeAckToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RelayResumeAck);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'RelayMessage.resumeAck()';
}


}




/// @nodoc
@JsonSerializable()

class RelayRekeyRequired implements RelayMessage {
  const RelayRekeyRequired({final  String? $type}): $type = $type ?? 'rekey_required';
  factory RelayRekeyRequired.fromJson(Map<String, dynamic> json) => _$RelayRekeyRequiredFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$RelayRekeyRequiredToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RelayRekeyRequired);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'RelayMessage.rekeyRequired()';
}


}




/// @nodoc
@JsonSerializable()

class AuthRelayMessage implements RelayMessage {
  const AuthRelayMessage({required this.token, required this.role, final  String? $type}): $type = $type ?? 'auth';
  factory AuthRelayMessage.fromJson(Map<String, dynamic> json) => _$AuthRelayMessageFromJson(json);

 final  String token;
 final  String role;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of RelayMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthRelayMessageCopyWith<AuthRelayMessage> get copyWith => _$AuthRelayMessageCopyWithImpl<AuthRelayMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AuthRelayMessageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthRelayMessage&&(identical(other.token, token) || other.token == token)&&(identical(other.role, role) || other.role == role));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,token,role);

@override
String toString() {
  return 'RelayMessage.auth(token: $token, role: $role)';
}


}

/// @nodoc
abstract mixin class $AuthRelayMessageCopyWith<$Res> implements $RelayMessageCopyWith<$Res> {
  factory $AuthRelayMessageCopyWith(AuthRelayMessage value, $Res Function(AuthRelayMessage) _then) = _$AuthRelayMessageCopyWithImpl;
@useResult
$Res call({
 String token, String role
});




}
/// @nodoc
class _$AuthRelayMessageCopyWithImpl<$Res>
    implements $AuthRelayMessageCopyWith<$Res> {
  _$AuthRelayMessageCopyWithImpl(this._self, this._then);

  final AuthRelayMessage _self;
  final $Res Function(AuthRelayMessage) _then;

/// Create a copy of RelayMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? token = null,Object? role = null,}) {
  return _then(AuthRelayMessage(
token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
