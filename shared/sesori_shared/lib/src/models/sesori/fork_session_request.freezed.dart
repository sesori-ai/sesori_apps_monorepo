// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'fork_session_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ForkSessionRequest {

 String get sessionId; ForkPoint get point;/// Whether an archived origin whose worktree and branch are both gone
/// gets a new worktree from its base branch, at the same path. Sent only
/// on the retry after a `worktreeBranchMissing` refusal.
 bool get recreateFromBase;
/// Create a copy of ForkSessionRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ForkSessionRequestCopyWith<ForkSessionRequest> get copyWith => _$ForkSessionRequestCopyWithImpl<ForkSessionRequest>(this as ForkSessionRequest, _$identity);

  /// Serializes this ForkSessionRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ForkSessionRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ForkSessionRequest&&(identical(other.sessionId, _this.sessionId) || other.sessionId == _this.sessionId)&&(identical(other.point, _this.point) || other.point == _this.point)&&(identical(other.recreateFromBase, _this.recreateFromBase) || other.recreateFromBase == _this.recreateFromBase));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ForkSessionRequest;
  return Object.hash(runtimeType,_this.sessionId,_this.point,_this.recreateFromBase);
}

@override
String toString() {
  final _this = this as ForkSessionRequest;
  return 'ForkSessionRequest(sessionId: ${_this.sessionId}, point: ${_this.point}, recreateFromBase: ${_this.recreateFromBase})';
}


}

/// @nodoc
abstract mixin class $ForkSessionRequestCopyWith<$Res>  {
  factory $ForkSessionRequestCopyWith(ForkSessionRequest value, $Res Function(ForkSessionRequest) _then) = _$ForkSessionRequestCopyWithImpl;
@useResult
$Res call({
 String sessionId, ForkPoint point, bool recreateFromBase
});


$ForkPointCopyWith<$Res> get point;

}
/// @nodoc
class _$ForkSessionRequestCopyWithImpl<$Res>
    implements $ForkSessionRequestCopyWith<$Res> {
  _$ForkSessionRequestCopyWithImpl(this._self, this._then);

  final ForkSessionRequest _self;
  final $Res Function(ForkSessionRequest) _then;

/// Create a copy of ForkSessionRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = null,Object? point = null,Object? recreateFromBase = null,}) {
  return _then(ForkSessionRequest(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,point: null == point ? _self.point : point // ignore: cast_nullable_to_non_nullable
as ForkPoint,recreateFromBase: null == recreateFromBase ? _self.recreateFromBase : recreateFromBase // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of ForkSessionRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ForkPointCopyWith<$Res> get point {
  
  return $ForkPointCopyWith<$Res>(_self.point, (value) {
    return _then(_self.copyWith(point: value));
  });
}
}



/// @nodoc
@JsonSerializable()

class _ForkSessionRequest implements ForkSessionRequest {
  const _ForkSessionRequest({required this.sessionId, required this.point, required this.recreateFromBase});
  factory _ForkSessionRequest.fromJson(Map<String, dynamic> json) => _$ForkSessionRequestFromJson(json);

@override final  String sessionId;
@override final  ForkPoint point;
/// Whether an archived origin whose worktree and branch are both gone
/// gets a new worktree from its base branch, at the same path. Sent only
/// on the retry after a `worktreeBranchMissing` refusal.
@override final  bool recreateFromBase;

/// Create a copy of ForkSessionRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ForkSessionRequestCopyWith<_ForkSessionRequest> get copyWith => __$ForkSessionRequestCopyWithImpl<_ForkSessionRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ForkSessionRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ForkSessionRequest&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.point, point) || other.point == point)&&(identical(other.recreateFromBase, recreateFromBase) || other.recreateFromBase == recreateFromBase));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,sessionId,point,recreateFromBase);
}

@override
String toString() {
    return 'ForkSessionRequest(sessionId: $sessionId, point: $point, recreateFromBase: $recreateFromBase)';
}


}

/// @nodoc
abstract mixin class _$ForkSessionRequestCopyWith<$Res> implements $ForkSessionRequestCopyWith<$Res> {
  factory _$ForkSessionRequestCopyWith(_ForkSessionRequest value, $Res Function(_ForkSessionRequest) _then) = __$ForkSessionRequestCopyWithImpl;
@override @useResult
$Res call({
 String sessionId, ForkPoint point, bool recreateFromBase
});


@override $ForkPointCopyWith<$Res> get point;

}
/// @nodoc
class __$ForkSessionRequestCopyWithImpl<$Res>
    implements _$ForkSessionRequestCopyWith<$Res> {
  __$ForkSessionRequestCopyWithImpl(this._self, this._then);

  final _ForkSessionRequest _self;
  final $Res Function(_ForkSessionRequest) _then;

/// Create a copy of ForkSessionRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? point = null,Object? recreateFromBase = null,}) {
  return _then(_ForkSessionRequest(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,point: null == point ? _self.point : point // ignore: cast_nullable_to_non_nullable
as ForkPoint,recreateFromBase: null == recreateFromBase ? _self.recreateFromBase : recreateFromBase // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of ForkSessionRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ForkPointCopyWith<$Res> get point {
  
  return $ForkPointCopyWith<$Res>(_self.point, (value) {
    return _then(_self.copyWith(point: value));
  });
}
}

ForkPoint _$ForkPointFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'afterMessage':
          return ForkPointAfterMessage.fromJson(
            json
          );
                case 'beforeMessage':
          return ForkPointBeforeMessage.fromJson(
            json
          );
                case 'latest':
          return ForkPointLatest.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'type',
  'ForkPoint',
  'Invalid union type "${json['type']}"!'
);
        }
      
}

/// @nodoc
mixin _$ForkPoint {



  /// Serializes this ForkPoint to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ForkPoint);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ForkPoint()';
}


}

/// @nodoc
class $ForkPointCopyWith<$Res>  {
$ForkPointCopyWith(ForkPoint _, $Res Function(ForkPoint) __);
}



/// @nodoc
@JsonSerializable()

class ForkPointAfterMessage implements ForkPoint {
  const ForkPointAfterMessage({required this.messageId,  String? $type}): $type = $type ?? 'afterMessage';
  factory ForkPointAfterMessage.fromJson(Map<String, dynamic> json) => _$ForkPointAfterMessageFromJson(json);

 final  String messageId;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of ForkPoint
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ForkPointAfterMessageCopyWith<ForkPointAfterMessage> get copyWith => _$ForkPointAfterMessageCopyWithImpl<ForkPointAfterMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ForkPointAfterMessageToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ForkPointAfterMessage&&(identical(other.messageId, messageId) || other.messageId == messageId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,messageId);
}

@override
String toString() {
    return 'ForkPoint.afterMessage(messageId: $messageId)';
}


}

/// @nodoc
abstract mixin class $ForkPointAfterMessageCopyWith<$Res> implements $ForkPointCopyWith<$Res> {
  factory $ForkPointAfterMessageCopyWith(ForkPointAfterMessage value, $Res Function(ForkPointAfterMessage) _then) = _$ForkPointAfterMessageCopyWithImpl;
@useResult
$Res call({
 String messageId
});




}
/// @nodoc
class _$ForkPointAfterMessageCopyWithImpl<$Res>
    implements $ForkPointAfterMessageCopyWith<$Res> {
  _$ForkPointAfterMessageCopyWithImpl(this._self, this._then);

  final ForkPointAfterMessage _self;
  final $Res Function(ForkPointAfterMessage) _then;

/// Create a copy of ForkPoint
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? messageId = null,}) {
  return _then(ForkPointAfterMessage(
messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class ForkPointBeforeMessage implements ForkPoint {
  const ForkPointBeforeMessage({required this.messageId,  String? $type}): $type = $type ?? 'beforeMessage';
  factory ForkPointBeforeMessage.fromJson(Map<String, dynamic> json) => _$ForkPointBeforeMessageFromJson(json);

 final  String messageId;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of ForkPoint
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ForkPointBeforeMessageCopyWith<ForkPointBeforeMessage> get copyWith => _$ForkPointBeforeMessageCopyWithImpl<ForkPointBeforeMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ForkPointBeforeMessageToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ForkPointBeforeMessage&&(identical(other.messageId, messageId) || other.messageId == messageId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,messageId);
}

@override
String toString() {
    return 'ForkPoint.beforeMessage(messageId: $messageId)';
}


}

/// @nodoc
abstract mixin class $ForkPointBeforeMessageCopyWith<$Res> implements $ForkPointCopyWith<$Res> {
  factory $ForkPointBeforeMessageCopyWith(ForkPointBeforeMessage value, $Res Function(ForkPointBeforeMessage) _then) = _$ForkPointBeforeMessageCopyWithImpl;
@useResult
$Res call({
 String messageId
});




}
/// @nodoc
class _$ForkPointBeforeMessageCopyWithImpl<$Res>
    implements $ForkPointBeforeMessageCopyWith<$Res> {
  _$ForkPointBeforeMessageCopyWithImpl(this._self, this._then);

  final ForkPointBeforeMessage _self;
  final $Res Function(ForkPointBeforeMessage) _then;

/// Create a copy of ForkPoint
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? messageId = null,}) {
  return _then(ForkPointBeforeMessage(
messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class ForkPointLatest implements ForkPoint {
  const ForkPointLatest({ String? $type}): $type = $type ?? 'latest';
  factory ForkPointLatest.fromJson(Map<String, dynamic> json) => _$ForkPointLatestFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$ForkPointLatestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ForkPointLatest);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'ForkPoint.latest()';
}


}




// dart format on
