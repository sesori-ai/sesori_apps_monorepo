// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'message_with_parts.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MessageWithPartsResponse {

 List<MessageWithParts> get messages;/// Cursor for the next older page, to be sent back verbatim as the
/// request's `before`. Null means the transcript is complete.
 int? get nextCursor; SessionPromptDefaults? get replayedPromptDefaults;
/// Create a copy of MessageWithPartsResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageWithPartsResponseCopyWith<MessageWithPartsResponse> get copyWith => _$MessageWithPartsResponseCopyWithImpl<MessageWithPartsResponse>(this as MessageWithPartsResponse, _$identity);

  /// Serializes this MessageWithPartsResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageWithPartsResponse&&const DeepCollectionEquality().equals(other.messages, messages)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor)&&(identical(other.replayedPromptDefaults, replayedPromptDefaults) || other.replayedPromptDefaults == replayedPromptDefaults));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(messages),nextCursor,replayedPromptDefaults);

@override
String toString() {
  return 'MessageWithPartsResponse(messages: $messages, nextCursor: $nextCursor, replayedPromptDefaults: $replayedPromptDefaults)';
}


}

/// @nodoc
abstract mixin class $MessageWithPartsResponseCopyWith<$Res>  {
  factory $MessageWithPartsResponseCopyWith(MessageWithPartsResponse value, $Res Function(MessageWithPartsResponse) _then) = _$MessageWithPartsResponseCopyWithImpl;
@useResult
$Res call({
 List<MessageWithParts> messages, int? nextCursor, SessionPromptDefaults? replayedPromptDefaults
});


$SessionPromptDefaultsCopyWith<$Res>? get replayedPromptDefaults;

}
/// @nodoc
class _$MessageWithPartsResponseCopyWithImpl<$Res>
    implements $MessageWithPartsResponseCopyWith<$Res> {
  _$MessageWithPartsResponseCopyWithImpl(this._self, this._then);

  final MessageWithPartsResponse _self;
  final $Res Function(MessageWithPartsResponse) _then;

/// Create a copy of MessageWithPartsResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? messages = null,Object? nextCursor = freezed,Object? replayedPromptDefaults = freezed,}) {
  return _then(MessageWithPartsResponse(
messages: null == messages ? _self.messages : messages // ignore: cast_nullable_to_non_nullable
as List<MessageWithParts>,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as int?,replayedPromptDefaults: freezed == replayedPromptDefaults ? _self.replayedPromptDefaults : replayedPromptDefaults // ignore: cast_nullable_to_non_nullable
as SessionPromptDefaults?,
  ));
}
/// Create a copy of MessageWithPartsResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SessionPromptDefaultsCopyWith<$Res>? get replayedPromptDefaults {
    if (_self.replayedPromptDefaults == null) {
    return null;
  }

  return $SessionPromptDefaultsCopyWith<$Res>(_self.replayedPromptDefaults!, (value) {
    return _then(_self.copyWith(replayedPromptDefaults: value));
  });
}
}



/// @nodoc
@JsonSerializable()

class _MessageWithPartsResponse implements MessageWithPartsResponse {
  const _MessageWithPartsResponse({required  List<MessageWithParts> messages, required this.nextCursor, required this.replayedPromptDefaults}): _messages = messages;
  factory _MessageWithPartsResponse.fromJson(Map<String, dynamic> json) => _$MessageWithPartsResponseFromJson(json);

 final  List<MessageWithParts> _messages;
@override List<MessageWithParts> get messages {
  if (_messages is EqualUnmodifiableListView) return _messages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_messages);
}

/// Cursor for the next older page, to be sent back verbatim as the
/// request's `before`. Null means the transcript is complete.
@override final  int? nextCursor;
@override final  SessionPromptDefaults? replayedPromptDefaults;

/// Create a copy of MessageWithPartsResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MessageWithPartsResponseCopyWith<_MessageWithPartsResponse> get copyWith => __$MessageWithPartsResponseCopyWithImpl<_MessageWithPartsResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessageWithPartsResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MessageWithPartsResponse&&const DeepCollectionEquality().equals(other._messages, _messages)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor)&&(identical(other.replayedPromptDefaults, replayedPromptDefaults) || other.replayedPromptDefaults == replayedPromptDefaults));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_messages),nextCursor,replayedPromptDefaults);

@override
String toString() {
  return 'MessageWithPartsResponse(messages: $messages, nextCursor: $nextCursor, replayedPromptDefaults: $replayedPromptDefaults)';
}


}

/// @nodoc
abstract mixin class _$MessageWithPartsResponseCopyWith<$Res> implements $MessageWithPartsResponseCopyWith<$Res> {
  factory _$MessageWithPartsResponseCopyWith(_MessageWithPartsResponse value, $Res Function(_MessageWithPartsResponse) _then) = __$MessageWithPartsResponseCopyWithImpl;
@override @useResult
$Res call({
 List<MessageWithParts> messages, int? nextCursor, SessionPromptDefaults? replayedPromptDefaults
});


@override $SessionPromptDefaultsCopyWith<$Res>? get replayedPromptDefaults;

}
/// @nodoc
class __$MessageWithPartsResponseCopyWithImpl<$Res>
    implements _$MessageWithPartsResponseCopyWith<$Res> {
  __$MessageWithPartsResponseCopyWithImpl(this._self, this._then);

  final _MessageWithPartsResponse _self;
  final $Res Function(_MessageWithPartsResponse) _then;

/// Create a copy of MessageWithPartsResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? messages = null,Object? nextCursor = freezed,Object? replayedPromptDefaults = freezed,}) {
  return _then(_MessageWithPartsResponse(
messages: null == messages ? _self._messages : messages // ignore: cast_nullable_to_non_nullable
as List<MessageWithParts>,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as int?,replayedPromptDefaults: freezed == replayedPromptDefaults ? _self.replayedPromptDefaults : replayedPromptDefaults // ignore: cast_nullable_to_non_nullable
as SessionPromptDefaults?,
  ));
}

/// Create a copy of MessageWithPartsResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SessionPromptDefaultsCopyWith<$Res>? get replayedPromptDefaults {
    if (_self.replayedPromptDefaults == null) {
    return null;
  }

  return $SessionPromptDefaultsCopyWith<$Res>(_self.replayedPromptDefaults!, (value) {
    return _then(_self.copyWith(replayedPromptDefaults: value));
  });
}
}


/// @nodoc
mixin _$MessageWithParts {

 Message get info; List<MessagePart> get parts;
/// Create a copy of MessageWithParts
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageWithPartsCopyWith<MessageWithParts> get copyWith => _$MessageWithPartsCopyWithImpl<MessageWithParts>(this as MessageWithParts, _$identity);

  /// Serializes this MessageWithParts to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageWithParts&&(identical(other.info, info) || other.info == info)&&const DeepCollectionEquality().equals(other.parts, parts));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,info,const DeepCollectionEquality().hash(parts));

@override
String toString() {
  return 'MessageWithParts(info: $info, parts: $parts)';
}


}

/// @nodoc
abstract mixin class $MessageWithPartsCopyWith<$Res>  {
  factory $MessageWithPartsCopyWith(MessageWithParts value, $Res Function(MessageWithParts) _then) = _$MessageWithPartsCopyWithImpl;
@useResult
$Res call({
 Message info, List<MessagePart> parts
});


$MessageCopyWith<$Res> get info;

}
/// @nodoc
class _$MessageWithPartsCopyWithImpl<$Res>
    implements $MessageWithPartsCopyWith<$Res> {
  _$MessageWithPartsCopyWithImpl(this._self, this._then);

  final MessageWithParts _self;
  final $Res Function(MessageWithParts) _then;

/// Create a copy of MessageWithParts
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? info = null,Object? parts = null,}) {
  return _then(MessageWithParts(
info: null == info ? _self.info : info // ignore: cast_nullable_to_non_nullable
as Message,parts: null == parts ? _self.parts : parts // ignore: cast_nullable_to_non_nullable
as List<MessagePart>,
  ));
}
/// Create a copy of MessageWithParts
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MessageCopyWith<$Res> get info {
  
  return $MessageCopyWith<$Res>(_self.info, (value) {
    return _then(_self.copyWith(info: value));
  });
}
}



/// @nodoc
@JsonSerializable()

class _MessageWithParts implements MessageWithParts {
  const _MessageWithParts({required this.info, required  List<MessagePart> parts}): _parts = parts;
  factory _MessageWithParts.fromJson(Map<String, dynamic> json) => _$MessageWithPartsFromJson(json);

@override final  Message info;
 final  List<MessagePart> _parts;
@override List<MessagePart> get parts {
  if (_parts is EqualUnmodifiableListView) return _parts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_parts);
}


/// Create a copy of MessageWithParts
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MessageWithPartsCopyWith<_MessageWithParts> get copyWith => __$MessageWithPartsCopyWithImpl<_MessageWithParts>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessageWithPartsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MessageWithParts&&(identical(other.info, info) || other.info == info)&&const DeepCollectionEquality().equals(other._parts, _parts));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,info,const DeepCollectionEquality().hash(_parts));

@override
String toString() {
  return 'MessageWithParts(info: $info, parts: $parts)';
}


}

/// @nodoc
abstract mixin class _$MessageWithPartsCopyWith<$Res> implements $MessageWithPartsCopyWith<$Res> {
  factory _$MessageWithPartsCopyWith(_MessageWithParts value, $Res Function(_MessageWithParts) _then) = __$MessageWithPartsCopyWithImpl;
@override @useResult
$Res call({
 Message info, List<MessagePart> parts
});


@override $MessageCopyWith<$Res> get info;

}
/// @nodoc
class __$MessageWithPartsCopyWithImpl<$Res>
    implements _$MessageWithPartsCopyWith<$Res> {
  __$MessageWithPartsCopyWithImpl(this._self, this._then);

  final _MessageWithParts _self;
  final $Res Function(_MessageWithParts) _then;

/// Create a copy of MessageWithParts
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? info = null,Object? parts = null,}) {
  return _then(_MessageWithParts(
info: null == info ? _self.info : info // ignore: cast_nullable_to_non_nullable
as Message,parts: null == parts ? _self._parts : parts // ignore: cast_nullable_to_non_nullable
as List<MessagePart>,
  ));
}

/// Create a copy of MessageWithParts
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MessageCopyWith<$Res> get info {
  
  return $MessageCopyWith<$Res>(_self.info, (value) {
    return _then(_self.copyWith(info: value));
  });
}
}

// dart format on
