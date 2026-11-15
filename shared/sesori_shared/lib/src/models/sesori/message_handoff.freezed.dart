// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'message_handoff.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
MessageHandoff _$MessageHandoffFromJson(
  Map<String, dynamic> json
) {
        switch (json['kind']) {
                  case 'sent':
          return MessageHandoffSent.fromJson(
            json
          );
                case 'notSent':
          return MessageHandoffNotSent.fromJson(
            json
          );
                case 'received':
          return MessageHandoffReceived.fromJson(
            json
          );
        
          default:
            return MessageHandoffUnknown.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$MessageHandoff {



  /// Serializes this MessageHandoff to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageHandoff);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;



}

/// @nodoc
class $MessageHandoffCopyWith<$Res>  {
$MessageHandoffCopyWith(MessageHandoff _, $Res Function(MessageHandoff) __);
}



/// @nodoc
@JsonSerializable()

class MessageHandoffSent implements MessageHandoff {
  const MessageHandoffSent({required this.targetSessionId, required this.targetTitle,  String? $type}): $type = $type ?? 'sent';
  factory MessageHandoffSent.fromJson(Map<String, dynamic> json) => _$MessageHandoffSentFromJson(json);

 final  String targetSessionId;
 final  String? targetTitle;

@JsonKey(name: 'kind')
final String $type;


/// Create a copy of MessageHandoff
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageHandoffSentCopyWith<MessageHandoffSent> get copyWith => _$MessageHandoffSentCopyWithImpl<MessageHandoffSent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessageHandoffSentToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageHandoffSent&&(identical(other.targetSessionId, targetSessionId) || other.targetSessionId == targetSessionId)&&(identical(other.targetTitle, targetTitle) || other.targetTitle == targetTitle));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,targetSessionId,targetTitle);
}



}

/// @nodoc
abstract mixin class $MessageHandoffSentCopyWith<$Res> implements $MessageHandoffCopyWith<$Res> {
  factory $MessageHandoffSentCopyWith(MessageHandoffSent value, $Res Function(MessageHandoffSent) _then) = _$MessageHandoffSentCopyWithImpl;
@useResult
$Res call({
 String targetSessionId, String? targetTitle
});




}
/// @nodoc
class _$MessageHandoffSentCopyWithImpl<$Res>
    implements $MessageHandoffSentCopyWith<$Res> {
  _$MessageHandoffSentCopyWithImpl(this._self, this._then);

  final MessageHandoffSent _self;
  final $Res Function(MessageHandoffSent) _then;

/// Create a copy of MessageHandoff
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? targetSessionId = null,Object? targetTitle = freezed,}) {
  return _then(MessageHandoffSent(
targetSessionId: null == targetSessionId ? _self.targetSessionId : targetSessionId // ignore: cast_nullable_to_non_nullable
as String,targetTitle: freezed == targetTitle ? _self.targetTitle : targetTitle // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class MessageHandoffNotSent implements MessageHandoff {
  const MessageHandoffNotSent({required this.targetSessionId, required this.targetTitle,  String? $type}): $type = $type ?? 'notSent';
  factory MessageHandoffNotSent.fromJson(Map<String, dynamic> json) => _$MessageHandoffNotSentFromJson(json);

 final  String targetSessionId;
 final  String? targetTitle;

@JsonKey(name: 'kind')
final String $type;


/// Create a copy of MessageHandoff
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageHandoffNotSentCopyWith<MessageHandoffNotSent> get copyWith => _$MessageHandoffNotSentCopyWithImpl<MessageHandoffNotSent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessageHandoffNotSentToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageHandoffNotSent&&(identical(other.targetSessionId, targetSessionId) || other.targetSessionId == targetSessionId)&&(identical(other.targetTitle, targetTitle) || other.targetTitle == targetTitle));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,targetSessionId,targetTitle);
}



}

/// @nodoc
abstract mixin class $MessageHandoffNotSentCopyWith<$Res> implements $MessageHandoffCopyWith<$Res> {
  factory $MessageHandoffNotSentCopyWith(MessageHandoffNotSent value, $Res Function(MessageHandoffNotSent) _then) = _$MessageHandoffNotSentCopyWithImpl;
@useResult
$Res call({
 String targetSessionId, String? targetTitle
});




}
/// @nodoc
class _$MessageHandoffNotSentCopyWithImpl<$Res>
    implements $MessageHandoffNotSentCopyWith<$Res> {
  _$MessageHandoffNotSentCopyWithImpl(this._self, this._then);

  final MessageHandoffNotSent _self;
  final $Res Function(MessageHandoffNotSent) _then;

/// Create a copy of MessageHandoff
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? targetSessionId = null,Object? targetTitle = freezed,}) {
  return _then(MessageHandoffNotSent(
targetSessionId: null == targetSessionId ? _self.targetSessionId : targetSessionId // ignore: cast_nullable_to_non_nullable
as String,targetTitle: freezed == targetTitle ? _self.targetTitle : targetTitle // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class MessageHandoffReceived implements MessageHandoff {
  const MessageHandoffReceived({required this.sourceSessionId, required this.sourceTitle, required this.summary, required this.transcriptPath,  String? $type}): $type = $type ?? 'received';
  factory MessageHandoffReceived.fromJson(Map<String, dynamic> json) => _$MessageHandoffReceivedFromJson(json);

 final  String sourceSessionId;
 final  String? sourceTitle;
 final  String summary;
 final  String transcriptPath;

@JsonKey(name: 'kind')
final String $type;


/// Create a copy of MessageHandoff
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageHandoffReceivedCopyWith<MessageHandoffReceived> get copyWith => _$MessageHandoffReceivedCopyWithImpl<MessageHandoffReceived>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessageHandoffReceivedToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageHandoffReceived&&(identical(other.sourceSessionId, sourceSessionId) || other.sourceSessionId == sourceSessionId)&&(identical(other.sourceTitle, sourceTitle) || other.sourceTitle == sourceTitle)&&(identical(other.summary, summary) || other.summary == summary)&&(identical(other.transcriptPath, transcriptPath) || other.transcriptPath == transcriptPath));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,sourceSessionId,sourceTitle,summary,transcriptPath);
}



}

/// @nodoc
abstract mixin class $MessageHandoffReceivedCopyWith<$Res> implements $MessageHandoffCopyWith<$Res> {
  factory $MessageHandoffReceivedCopyWith(MessageHandoffReceived value, $Res Function(MessageHandoffReceived) _then) = _$MessageHandoffReceivedCopyWithImpl;
@useResult
$Res call({
 String sourceSessionId, String? sourceTitle, String summary, String transcriptPath
});




}
/// @nodoc
class _$MessageHandoffReceivedCopyWithImpl<$Res>
    implements $MessageHandoffReceivedCopyWith<$Res> {
  _$MessageHandoffReceivedCopyWithImpl(this._self, this._then);

  final MessageHandoffReceived _self;
  final $Res Function(MessageHandoffReceived) _then;

/// Create a copy of MessageHandoff
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sourceSessionId = null,Object? sourceTitle = freezed,Object? summary = null,Object? transcriptPath = null,}) {
  return _then(MessageHandoffReceived(
sourceSessionId: null == sourceSessionId ? _self.sourceSessionId : sourceSessionId // ignore: cast_nullable_to_non_nullable
as String,sourceTitle: freezed == sourceTitle ? _self.sourceTitle : sourceTitle // ignore: cast_nullable_to_non_nullable
as String?,summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as String,transcriptPath: null == transcriptPath ? _self.transcriptPath : transcriptPath // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class MessageHandoffUnknown implements MessageHandoff {
  const MessageHandoffUnknown({ String? $type}): $type = $type ?? 'unknown';
  factory MessageHandoffUnknown.fromJson(Map<String, dynamic> json) => _$MessageHandoffUnknownFromJson(json);



@JsonKey(name: 'kind')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$MessageHandoffUnknownToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageHandoffUnknown);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;



}




// dart format on
