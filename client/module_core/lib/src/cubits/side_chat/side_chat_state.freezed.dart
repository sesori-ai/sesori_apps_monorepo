// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'side_chat_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SideChatState {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SideChatState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'SideChatState()';
}


}

/// @nodoc
class $SideChatStateCopyWith<$Res>  {
$SideChatStateCopyWith(SideChatState _, $Res Function(SideChatState) __);
}



/// @nodoc


class SideChatLoading implements SideChatState {
  const SideChatLoading();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SideChatLoading);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'SideChatState.loading()';
}


}




/// @nodoc


class SideChatLoadFailed implements SideChatState {
  const SideChatLoadFailed();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SideChatLoadFailed);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'SideChatState.loadFailed()';
}


}




/// @nodoc


class SideChatReady implements SideChatState {
  const SideChatReady({required  List<SideChat> earlierChats, required this.thread, required this.ask}): _earlierChats = earlierChats;
  

/// The session's other side chats, newest first by their last answer.
/// The chat shown in [thread] is never among them.
 final  List<SideChat> _earlierChats;
/// The session's other side chats, newest first by their last answer.
/// The chat shown in [thread] is never among them.
 List<SideChat> get earlierChats {
  if (_earlierChats is EqualUnmodifiableListView) return _earlierChats;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_earlierChats);
}

 final  SideChatThread thread;
 final  SideQuestionAsk ask;

/// Create a copy of SideChatState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SideChatReadyCopyWith<SideChatReady> get copyWith => _$SideChatReadyCopyWithImpl<SideChatReady>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SideChatReady&&const DeepCollectionEquality().equals(other.earlierChats, _earlierChats)&&(identical(other.thread, thread) || other.thread == thread)&&(identical(other.ask, ask) || other.ask == ask));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_earlierChats),thread,ask);
}

@override
String toString() {
    return 'SideChatState.ready(earlierChats: $earlierChats, thread: $thread, ask: $ask)';
}


}

/// @nodoc
abstract mixin class $SideChatReadyCopyWith<$Res> implements $SideChatStateCopyWith<$Res> {
  factory $SideChatReadyCopyWith(SideChatReady value, $Res Function(SideChatReady) _then) = _$SideChatReadyCopyWithImpl;
@useResult
$Res call({
 List<SideChat> earlierChats, SideChatThread thread, SideQuestionAsk ask
});


$SideChatThreadCopyWith<$Res> get thread;$SideQuestionAskCopyWith<$Res> get ask;

}
/// @nodoc
class _$SideChatReadyCopyWithImpl<$Res>
    implements $SideChatReadyCopyWith<$Res> {
  _$SideChatReadyCopyWithImpl(this._self, this._then);

  final SideChatReady _self;
  final $Res Function(SideChatReady) _then;

/// Create a copy of SideChatState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? earlierChats = null,Object? thread = null,Object? ask = null,}) {
  return _then(SideChatReady(
earlierChats: null == earlierChats ? _self._earlierChats : earlierChats // ignore: cast_nullable_to_non_nullable
as List<SideChat>,thread: null == thread ? _self.thread : thread // ignore: cast_nullable_to_non_nullable
as SideChatThread,ask: null == ask ? _self.ask : ask // ignore: cast_nullable_to_non_nullable
as SideQuestionAsk,
  ));
}

/// Create a copy of SideChatState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SideChatThreadCopyWith<$Res> get thread {
  
  return $SideChatThreadCopyWith<$Res>(_self.thread, (value) {
    return _then(_self.copyWith(thread: value));
  });
}/// Create a copy of SideChatState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SideQuestionAskCopyWith<$Res> get ask {
  
  return $SideQuestionAskCopyWith<$Res>(_self.ask, (value) {
    return _then(_self.copyWith(ask: value));
  });
}
}

/// @nodoc
mixin _$SideChatThread {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SideChatThread);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'SideChatThread()';
}


}

/// @nodoc
class $SideChatThreadCopyWith<$Res>  {
$SideChatThreadCopyWith(SideChatThread _, $Res Function(SideChatThread) __);
}



/// @nodoc


class SideChatNewThread implements SideChatThread {
  const SideChatNewThread();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SideChatNewThread);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'SideChatThread.newChat()';
}


}




/// @nodoc


class SideChatExistingThread implements SideChatThread {
  const SideChatExistingThread({required this.chat});
  

 final  SideChat chat;

/// Create a copy of SideChatThread
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SideChatExistingThreadCopyWith<SideChatExistingThread> get copyWith => _$SideChatExistingThreadCopyWithImpl<SideChatExistingThread>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SideChatExistingThread&&(identical(other.chat, chat) || other.chat == chat));
}


@override
int get hashCode {
    return Object.hash(runtimeType,chat);
}

@override
String toString() {
    return 'SideChatThread.existing(chat: $chat)';
}


}

/// @nodoc
abstract mixin class $SideChatExistingThreadCopyWith<$Res> implements $SideChatThreadCopyWith<$Res> {
  factory $SideChatExistingThreadCopyWith(SideChatExistingThread value, $Res Function(SideChatExistingThread) _then) = _$SideChatExistingThreadCopyWithImpl;
@useResult
$Res call({
 SideChat chat
});


$SideChatCopyWith<$Res> get chat;

}
/// @nodoc
class _$SideChatExistingThreadCopyWithImpl<$Res>
    implements $SideChatExistingThreadCopyWith<$Res> {
  _$SideChatExistingThreadCopyWithImpl(this._self, this._then);

  final SideChatExistingThread _self;
  final $Res Function(SideChatExistingThread) _then;

/// Create a copy of SideChatThread
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? chat = null,}) {
  return _then(SideChatExistingThread(
chat: null == chat ? _self.chat : chat // ignore: cast_nullable_to_non_nullable
as SideChat,
  ));
}

/// Create a copy of SideChatThread
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SideChatCopyWith<$Res> get chat {
  
  return $SideChatCopyWith<$Res>(_self.chat, (value) {
    return _then(_self.copyWith(chat: value));
  });
}
}

/// @nodoc
mixin _$SideQuestionAsk {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SideQuestionAsk);
}


@override
int get hashCode => runtimeType.hashCode;



}

/// @nodoc
class $SideQuestionAskCopyWith<$Res>  {
$SideQuestionAskCopyWith(SideQuestionAsk _, $Res Function(SideQuestionAsk) __);
}



/// @nodoc


class SideQuestionIdle implements SideQuestionAsk {
  const SideQuestionIdle();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SideQuestionIdle);
}


@override
int get hashCode => runtimeType.hashCode;



}




/// @nodoc


class SideQuestionWaiting implements SideQuestionAsk {
  const SideQuestionWaiting({required this.question});
  

 final  String question;

/// Create a copy of SideQuestionAsk
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SideQuestionWaitingCopyWith<SideQuestionWaiting> get copyWith => _$SideQuestionWaitingCopyWithImpl<SideQuestionWaiting>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SideQuestionWaiting&&(identical(other.question, question) || other.question == question));
}


@override
int get hashCode {
    return Object.hash(runtimeType,question);
}



}

/// @nodoc
abstract mixin class $SideQuestionWaitingCopyWith<$Res> implements $SideQuestionAskCopyWith<$Res> {
  factory $SideQuestionWaitingCopyWith(SideQuestionWaiting value, $Res Function(SideQuestionWaiting) _then) = _$SideQuestionWaitingCopyWithImpl;
@useResult
$Res call({
 String question
});




}
/// @nodoc
class _$SideQuestionWaitingCopyWithImpl<$Res>
    implements $SideQuestionWaitingCopyWith<$Res> {
  _$SideQuestionWaitingCopyWithImpl(this._self, this._then);

  final SideQuestionWaiting _self;
  final $Res Function(SideQuestionWaiting) _then;

/// Create a copy of SideQuestionAsk
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? question = null,}) {
  return _then(SideQuestionWaiting(
question: null == question ? _self.question : question // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class SideQuestionRefused implements SideQuestionAsk {
  const SideQuestionRefused({required this.question, required this.reason});
  

 final  String question;
 final  SideQuestionRefusal reason;

/// Create a copy of SideQuestionAsk
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SideQuestionRefusedCopyWith<SideQuestionRefused> get copyWith => _$SideQuestionRefusedCopyWithImpl<SideQuestionRefused>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SideQuestionRefused&&(identical(other.question, question) || other.question == question)&&(identical(other.reason, reason) || other.reason == reason));
}


@override
int get hashCode {
    return Object.hash(runtimeType,question,reason);
}



}

/// @nodoc
abstract mixin class $SideQuestionRefusedCopyWith<$Res> implements $SideQuestionAskCopyWith<$Res> {
  factory $SideQuestionRefusedCopyWith(SideQuestionRefused value, $Res Function(SideQuestionRefused) _then) = _$SideQuestionRefusedCopyWithImpl;
@useResult
$Res call({
 String question, SideQuestionRefusal reason
});




}
/// @nodoc
class _$SideQuestionRefusedCopyWithImpl<$Res>
    implements $SideQuestionRefusedCopyWith<$Res> {
  _$SideQuestionRefusedCopyWithImpl(this._self, this._then);

  final SideQuestionRefused _self;
  final $Res Function(SideQuestionRefused) _then;

/// Create a copy of SideQuestionAsk
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? question = null,Object? reason = null,}) {
  return _then(SideQuestionRefused(
question: null == question ? _self.question : question // ignore: cast_nullable_to_non_nullable
as String,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as SideQuestionRefusal,
  ));
}


}

/// @nodoc


class SideQuestionFailed implements SideQuestionAsk {
  const SideQuestionFailed({required this.question});
  

 final  String question;

/// Create a copy of SideQuestionAsk
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SideQuestionFailedCopyWith<SideQuestionFailed> get copyWith => _$SideQuestionFailedCopyWithImpl<SideQuestionFailed>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SideQuestionFailed&&(identical(other.question, question) || other.question == question));
}


@override
int get hashCode {
    return Object.hash(runtimeType,question);
}



}

/// @nodoc
abstract mixin class $SideQuestionFailedCopyWith<$Res> implements $SideQuestionAskCopyWith<$Res> {
  factory $SideQuestionFailedCopyWith(SideQuestionFailed value, $Res Function(SideQuestionFailed) _then) = _$SideQuestionFailedCopyWithImpl;
@useResult
$Res call({
 String question
});




}
/// @nodoc
class _$SideQuestionFailedCopyWithImpl<$Res>
    implements $SideQuestionFailedCopyWith<$Res> {
  _$SideQuestionFailedCopyWithImpl(this._self, this._then);

  final SideQuestionFailed _self;
  final $Res Function(SideQuestionFailed) _then;

/// Create a copy of SideQuestionAsk
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? question = null,}) {
  return _then(SideQuestionFailed(
question: null == question ? _self.question : question // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
