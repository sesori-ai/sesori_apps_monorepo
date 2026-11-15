// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'side_chat.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SideChatExchange {

 String get id; String get question; String get answer;/// A harness note about how the answer was made, for example a fallback
/// model notice; null when there is none.
 String? get answerNotice; int get askedAt; int get answeredAt;
/// Create a copy of SideChatExchange
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SideChatExchangeCopyWith<SideChatExchange> get copyWith => _$SideChatExchangeCopyWithImpl<SideChatExchange>(this as SideChatExchange, _$identity);

  /// Serializes this SideChatExchange to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SideChatExchange;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SideChatExchange&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.question, _this.question) || other.question == _this.question)&&(identical(other.answer, _this.answer) || other.answer == _this.answer)&&(identical(other.answerNotice, _this.answerNotice) || other.answerNotice == _this.answerNotice)&&(identical(other.askedAt, _this.askedAt) || other.askedAt == _this.askedAt)&&(identical(other.answeredAt, _this.answeredAt) || other.answeredAt == _this.answeredAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SideChatExchange;
  return Object.hash(runtimeType,_this.id,_this.question,_this.answer,_this.answerNotice,_this.askedAt,_this.answeredAt);
}



}

/// @nodoc
abstract mixin class $SideChatExchangeCopyWith<$Res>  {
  factory $SideChatExchangeCopyWith(SideChatExchange value, $Res Function(SideChatExchange) _then) = _$SideChatExchangeCopyWithImpl;
@useResult
$Res call({
 String id, String question, String answer, String? answerNotice, int askedAt, int answeredAt
});




}
/// @nodoc
class _$SideChatExchangeCopyWithImpl<$Res>
    implements $SideChatExchangeCopyWith<$Res> {
  _$SideChatExchangeCopyWithImpl(this._self, this._then);

  final SideChatExchange _self;
  final $Res Function(SideChatExchange) _then;

/// Create a copy of SideChatExchange
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? question = null,Object? answer = null,Object? answerNotice = freezed,Object? askedAt = null,Object? answeredAt = null,}) {
  return _then(SideChatExchange(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,question: null == question ? _self.question : question // ignore: cast_nullable_to_non_nullable
as String,answer: null == answer ? _self.answer : answer // ignore: cast_nullable_to_non_nullable
as String,answerNotice: freezed == answerNotice ? _self.answerNotice : answerNotice // ignore: cast_nullable_to_non_nullable
as String?,askedAt: null == askedAt ? _self.askedAt : askedAt // ignore: cast_nullable_to_non_nullable
as int,answeredAt: null == answeredAt ? _self.answeredAt : answeredAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _SideChatExchange implements SideChatExchange {
  const _SideChatExchange({required this.id, required this.question, required this.answer, required this.answerNotice, required this.askedAt, required this.answeredAt});
  factory _SideChatExchange.fromJson(Map<String, dynamic> json) => _$SideChatExchangeFromJson(json);

@override final  String id;
@override final  String question;
@override final  String answer;
/// A harness note about how the answer was made, for example a fallback
/// model notice; null when there is none.
@override final  String? answerNotice;
@override final  int askedAt;
@override final  int answeredAt;

/// Create a copy of SideChatExchange
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SideChatExchangeCopyWith<_SideChatExchange> get copyWith => __$SideChatExchangeCopyWithImpl<_SideChatExchange>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SideChatExchangeToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SideChatExchange&&(identical(other.id, id) || other.id == id)&&(identical(other.question, question) || other.question == question)&&(identical(other.answer, answer) || other.answer == answer)&&(identical(other.answerNotice, answerNotice) || other.answerNotice == answerNotice)&&(identical(other.askedAt, askedAt) || other.askedAt == askedAt)&&(identical(other.answeredAt, answeredAt) || other.answeredAt == answeredAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,question,answer,answerNotice,askedAt,answeredAt);
}



}

/// @nodoc
abstract mixin class _$SideChatExchangeCopyWith<$Res> implements $SideChatExchangeCopyWith<$Res> {
  factory _$SideChatExchangeCopyWith(_SideChatExchange value, $Res Function(_SideChatExchange) _then) = __$SideChatExchangeCopyWithImpl;
@override @useResult
$Res call({
 String id, String question, String answer, String? answerNotice, int askedAt, int answeredAt
});




}
/// @nodoc
class __$SideChatExchangeCopyWithImpl<$Res>
    implements _$SideChatExchangeCopyWith<$Res> {
  __$SideChatExchangeCopyWithImpl(this._self, this._then);

  final _SideChatExchange _self;
  final $Res Function(_SideChatExchange) _then;

/// Create a copy of SideChatExchange
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? question = null,Object? answer = null,Object? answerNotice = freezed,Object? askedAt = null,Object? answeredAt = null,}) {
  return _then(_SideChatExchange(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,question: null == question ? _self.question : question // ignore: cast_nullable_to_non_nullable
as String,answer: null == answer ? _self.answer : answer // ignore: cast_nullable_to_non_nullable
as String,answerNotice: freezed == answerNotice ? _self.answerNotice : answerNotice // ignore: cast_nullable_to_non_nullable
as String?,askedAt: null == askedAt ? _self.askedAt : askedAt // ignore: cast_nullable_to_non_nullable
as int,answeredAt: null == answeredAt ? _self.answeredAt : answeredAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$SideChat {

 String get id; List<SideChatExchange> get exchanges;
/// Create a copy of SideChat
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SideChatCopyWith<SideChat> get copyWith => _$SideChatCopyWithImpl<SideChat>(this as SideChat, _$identity);

  /// Serializes this SideChat to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SideChat;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SideChat&&(identical(other.id, _this.id) || other.id == _this.id)&&const DeepCollectionEquality().equals(other.exchanges, _this.exchanges));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SideChat;
  return Object.hash(runtimeType,_this.id,const DeepCollectionEquality().hash(_this.exchanges));
}

@override
String toString() {
  final _this = this as SideChat;
  return 'SideChat(id: ${_this.id}, exchanges: ${_this.exchanges})';
}


}

/// @nodoc
abstract mixin class $SideChatCopyWith<$Res>  {
  factory $SideChatCopyWith(SideChat value, $Res Function(SideChat) _then) = _$SideChatCopyWithImpl;
@useResult
$Res call({
 String id, List<SideChatExchange> exchanges
});




}
/// @nodoc
class _$SideChatCopyWithImpl<$Res>
    implements $SideChatCopyWith<$Res> {
  _$SideChatCopyWithImpl(this._self, this._then);

  final SideChat _self;
  final $Res Function(SideChat) _then;

/// Create a copy of SideChat
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? exchanges = null,}) {
  return _then(SideChat(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,exchanges: null == exchanges ? _self.exchanges : exchanges // ignore: cast_nullable_to_non_nullable
as List<SideChatExchange>,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _SideChat implements SideChat {
  const _SideChat({required this.id, required  List<SideChatExchange> exchanges}): _exchanges = exchanges;
  factory _SideChat.fromJson(Map<String, dynamic> json) => _$SideChatFromJson(json);

@override final  String id;
 final  List<SideChatExchange> _exchanges;
@override List<SideChatExchange> get exchanges {
  if (_exchanges is EqualUnmodifiableListView) return _exchanges;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_exchanges);
}


/// Create a copy of SideChat
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SideChatCopyWith<_SideChat> get copyWith => __$SideChatCopyWithImpl<_SideChat>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SideChatToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SideChat&&(identical(other.id, id) || other.id == id)&&const DeepCollectionEquality().equals(other.exchanges, _exchanges));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,const DeepCollectionEquality().hash(_exchanges));
}

@override
String toString() {
    return 'SideChat(id: $id, exchanges: $exchanges)';
}


}

/// @nodoc
abstract mixin class _$SideChatCopyWith<$Res> implements $SideChatCopyWith<$Res> {
  factory _$SideChatCopyWith(_SideChat value, $Res Function(_SideChat) _then) = __$SideChatCopyWithImpl;
@override @useResult
$Res call({
 String id, List<SideChatExchange> exchanges
});




}
/// @nodoc
class __$SideChatCopyWithImpl<$Res>
    implements _$SideChatCopyWith<$Res> {
  __$SideChatCopyWithImpl(this._self, this._then);

  final _SideChat _self;
  final $Res Function(_SideChat) _then;

/// Create a copy of SideChat
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? exchanges = null,}) {
  return _then(_SideChat(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,exchanges: null == exchanges ? _self._exchanges : exchanges // ignore: cast_nullable_to_non_nullable
as List<SideChatExchange>,
  ));
}


}


/// @nodoc
mixin _$SideChatListResponse {

 List<SideChat> get sideChats;
/// Create a copy of SideChatListResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SideChatListResponseCopyWith<SideChatListResponse> get copyWith => _$SideChatListResponseCopyWithImpl<SideChatListResponse>(this as SideChatListResponse, _$identity);

  /// Serializes this SideChatListResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SideChatListResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SideChatListResponse&&const DeepCollectionEquality().equals(other.sideChats, _this.sideChats));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SideChatListResponse;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.sideChats));
}

@override
String toString() {
  final _this = this as SideChatListResponse;
  return 'SideChatListResponse(sideChats: ${_this.sideChats})';
}


}

/// @nodoc
abstract mixin class $SideChatListResponseCopyWith<$Res>  {
  factory $SideChatListResponseCopyWith(SideChatListResponse value, $Res Function(SideChatListResponse) _then) = _$SideChatListResponseCopyWithImpl;
@useResult
$Res call({
 List<SideChat> sideChats
});




}
/// @nodoc
class _$SideChatListResponseCopyWithImpl<$Res>
    implements $SideChatListResponseCopyWith<$Res> {
  _$SideChatListResponseCopyWithImpl(this._self, this._then);

  final SideChatListResponse _self;
  final $Res Function(SideChatListResponse) _then;

/// Create a copy of SideChatListResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sideChats = null,}) {
  return _then(SideChatListResponse(
sideChats: null == sideChats ? _self.sideChats : sideChats // ignore: cast_nullable_to_non_nullable
as List<SideChat>,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _SideChatListResponse implements SideChatListResponse {
  const _SideChatListResponse({required  List<SideChat> sideChats}): _sideChats = sideChats;
  factory _SideChatListResponse.fromJson(Map<String, dynamic> json) => _$SideChatListResponseFromJson(json);

 final  List<SideChat> _sideChats;
@override List<SideChat> get sideChats {
  if (_sideChats is EqualUnmodifiableListView) return _sideChats;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_sideChats);
}


/// Create a copy of SideChatListResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SideChatListResponseCopyWith<_SideChatListResponse> get copyWith => __$SideChatListResponseCopyWithImpl<_SideChatListResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SideChatListResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SideChatListResponse&&const DeepCollectionEquality().equals(other.sideChats, _sideChats));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_sideChats));
}

@override
String toString() {
    return 'SideChatListResponse(sideChats: $sideChats)';
}


}

/// @nodoc
abstract mixin class _$SideChatListResponseCopyWith<$Res> implements $SideChatListResponseCopyWith<$Res> {
  factory _$SideChatListResponseCopyWith(_SideChatListResponse value, $Res Function(_SideChatListResponse) _then) = __$SideChatListResponseCopyWithImpl;
@override @useResult
$Res call({
 List<SideChat> sideChats
});




}
/// @nodoc
class __$SideChatListResponseCopyWithImpl<$Res>
    implements _$SideChatListResponseCopyWith<$Res> {
  __$SideChatListResponseCopyWithImpl(this._self, this._then);

  final _SideChatListResponse _self;
  final $Res Function(_SideChatListResponse) _then;

/// Create a copy of SideChatListResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sideChats = null,}) {
  return _then(_SideChatListResponse(
sideChats: null == sideChats ? _self._sideChats : sideChats // ignore: cast_nullable_to_non_nullable
as List<SideChat>,
  ));
}


}


/// @nodoc
mixin _$AskSideQuestionRequest {

 String get sessionId; String? get sideChatId; String get question;
/// Create a copy of AskSideQuestionRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AskSideQuestionRequestCopyWith<AskSideQuestionRequest> get copyWith => _$AskSideQuestionRequestCopyWithImpl<AskSideQuestionRequest>(this as AskSideQuestionRequest, _$identity);

  /// Serializes this AskSideQuestionRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AskSideQuestionRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AskSideQuestionRequest&&(identical(other.sessionId, _this.sessionId) || other.sessionId == _this.sessionId)&&(identical(other.sideChatId, _this.sideChatId) || other.sideChatId == _this.sideChatId)&&(identical(other.question, _this.question) || other.question == _this.question));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AskSideQuestionRequest;
  return Object.hash(runtimeType,_this.sessionId,_this.sideChatId,_this.question);
}



}

/// @nodoc
abstract mixin class $AskSideQuestionRequestCopyWith<$Res>  {
  factory $AskSideQuestionRequestCopyWith(AskSideQuestionRequest value, $Res Function(AskSideQuestionRequest) _then) = _$AskSideQuestionRequestCopyWithImpl;
@useResult
$Res call({
 String sessionId, String? sideChatId, String question
});




}
/// @nodoc
class _$AskSideQuestionRequestCopyWithImpl<$Res>
    implements $AskSideQuestionRequestCopyWith<$Res> {
  _$AskSideQuestionRequestCopyWithImpl(this._self, this._then);

  final AskSideQuestionRequest _self;
  final $Res Function(AskSideQuestionRequest) _then;

/// Create a copy of AskSideQuestionRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = null,Object? sideChatId = freezed,Object? question = null,}) {
  return _then(AskSideQuestionRequest(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,sideChatId: freezed == sideChatId ? _self.sideChatId : sideChatId // ignore: cast_nullable_to_non_nullable
as String?,question: null == question ? _self.question : question // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _AskSideQuestionRequest implements AskSideQuestionRequest {
  const _AskSideQuestionRequest({required this.sessionId, required this.sideChatId, required this.question});
  factory _AskSideQuestionRequest.fromJson(Map<String, dynamic> json) => _$AskSideQuestionRequestFromJson(json);

@override final  String sessionId;
@override final  String? sideChatId;
@override final  String question;

/// Create a copy of AskSideQuestionRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AskSideQuestionRequestCopyWith<_AskSideQuestionRequest> get copyWith => __$AskSideQuestionRequestCopyWithImpl<_AskSideQuestionRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AskSideQuestionRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AskSideQuestionRequest&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.sideChatId, sideChatId) || other.sideChatId == sideChatId)&&(identical(other.question, question) || other.question == question));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,sessionId,sideChatId,question);
}



}

/// @nodoc
abstract mixin class _$AskSideQuestionRequestCopyWith<$Res> implements $AskSideQuestionRequestCopyWith<$Res> {
  factory _$AskSideQuestionRequestCopyWith(_AskSideQuestionRequest value, $Res Function(_AskSideQuestionRequest) _then) = __$AskSideQuestionRequestCopyWithImpl;
@override @useResult
$Res call({
 String sessionId, String? sideChatId, String question
});




}
/// @nodoc
class __$AskSideQuestionRequestCopyWithImpl<$Res>
    implements _$AskSideQuestionRequestCopyWith<$Res> {
  __$AskSideQuestionRequestCopyWithImpl(this._self, this._then);

  final _AskSideQuestionRequest _self;
  final $Res Function(_AskSideQuestionRequest) _then;

/// Create a copy of AskSideQuestionRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? sideChatId = freezed,Object? question = null,}) {
  return _then(_AskSideQuestionRequest(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,sideChatId: freezed == sideChatId ? _self.sideChatId : sideChatId // ignore: cast_nullable_to_non_nullable
as String?,question: null == question ? _self.question : question // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

AskSideQuestionResponse _$AskSideQuestionResponseFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'answered':
          return AskSideQuestionAnswered.fromJson(
            json
          );
                case 'refused':
          return AskSideQuestionRefused.fromJson(
            json
          );
        
          default:
            return AskSideQuestionUnknown.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$AskSideQuestionResponse {



  /// Serializes this AskSideQuestionResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AskSideQuestionResponse);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'AskSideQuestionResponse()';
}


}





/// @nodoc
@JsonSerializable()

class AskSideQuestionAnswered implements AskSideQuestionResponse {
  const AskSideQuestionAnswered({required this.sideChatId, required this.exchange,  String? $type}): $type = $type ?? 'answered';
  factory AskSideQuestionAnswered.fromJson(Map<String, dynamic> json) => _$AskSideQuestionAnsweredFromJson(json);

 final  String sideChatId;
 final  SideChatExchange exchange;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$AskSideQuestionAnsweredToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AskSideQuestionAnswered&&(identical(other.sideChatId, sideChatId) || other.sideChatId == sideChatId)&&(identical(other.exchange, exchange) || other.exchange == exchange));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,sideChatId,exchange);
}

@override
String toString() {
    return 'AskSideQuestionResponse.answered(sideChatId: $sideChatId, exchange: $exchange)';
}


}




/// @nodoc
@JsonSerializable()

class AskSideQuestionRefused implements AskSideQuestionResponse {
  const AskSideQuestionRefused({@JsonKey(unknownEnumValue: SideQuestionRefusal.unknown) required this.reason,  String? $type}): $type = $type ?? 'refused';
  factory AskSideQuestionRefused.fromJson(Map<String, dynamic> json) => _$AskSideQuestionRefusedFromJson(json);

@JsonKey(unknownEnumValue: SideQuestionRefusal.unknown) final  SideQuestionRefusal reason;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$AskSideQuestionRefusedToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AskSideQuestionRefused&&(identical(other.reason, reason) || other.reason == reason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,reason);
}

@override
String toString() {
    return 'AskSideQuestionResponse.refused(reason: $reason)';
}


}




/// @nodoc
@JsonSerializable()

class AskSideQuestionUnknown implements AskSideQuestionResponse {
  const AskSideQuestionUnknown({ String? $type}): $type = $type ?? 'unknown';
  factory AskSideQuestionUnknown.fromJson(Map<String, dynamic> json) => _$AskSideQuestionUnknownFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$AskSideQuestionUnknownToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AskSideQuestionUnknown);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'AskSideQuestionResponse.unknown()';
}


}




// dart format on
