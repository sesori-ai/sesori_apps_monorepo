// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_prompt_index.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SessionPromptIndexResponse {

 List<SessionPromptIndexEntry> get entries;
/// Create a copy of SessionPromptIndexResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionPromptIndexResponseCopyWith<SessionPromptIndexResponse> get copyWith => _$SessionPromptIndexResponseCopyWithImpl<SessionPromptIndexResponse>(this as SessionPromptIndexResponse, _$identity);

  /// Serializes this SessionPromptIndexResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SessionPromptIndexResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionPromptIndexResponse&&const DeepCollectionEquality().equals(other.entries, _this.entries));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SessionPromptIndexResponse;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.entries));
}

@override
String toString() {
  final _this = this as SessionPromptIndexResponse;
  return 'SessionPromptIndexResponse(entries: ${_this.entries})';
}


}

/// @nodoc
abstract mixin class $SessionPromptIndexResponseCopyWith<$Res>  {
  factory $SessionPromptIndexResponseCopyWith(SessionPromptIndexResponse value, $Res Function(SessionPromptIndexResponse) _then) = _$SessionPromptIndexResponseCopyWithImpl;
@useResult
$Res call({
 List<SessionPromptIndexEntry> entries
});




}
/// @nodoc
class _$SessionPromptIndexResponseCopyWithImpl<$Res>
    implements $SessionPromptIndexResponseCopyWith<$Res> {
  _$SessionPromptIndexResponseCopyWithImpl(this._self, this._then);

  final SessionPromptIndexResponse _self;
  final $Res Function(SessionPromptIndexResponse) _then;

/// Create a copy of SessionPromptIndexResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? entries = null,}) {
  return _then(SessionPromptIndexResponse(
entries: null == entries ? _self.entries : entries // ignore: cast_nullable_to_non_nullable
as List<SessionPromptIndexEntry>,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _SessionPromptIndexResponse implements SessionPromptIndexResponse {
  const _SessionPromptIndexResponse({required  List<SessionPromptIndexEntry> entries}): _entries = entries;
  factory _SessionPromptIndexResponse.fromJson(Map<String, dynamic> json) => _$SessionPromptIndexResponseFromJson(json);

 final  List<SessionPromptIndexEntry> _entries;
@override List<SessionPromptIndexEntry> get entries {
  if (_entries is EqualUnmodifiableListView) return _entries;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_entries);
}


/// Create a copy of SessionPromptIndexResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionPromptIndexResponseCopyWith<_SessionPromptIndexResponse> get copyWith => __$SessionPromptIndexResponseCopyWithImpl<_SessionPromptIndexResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionPromptIndexResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionPromptIndexResponse&&const DeepCollectionEquality().equals(other.entries, _entries));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_entries));
}

@override
String toString() {
    return 'SessionPromptIndexResponse(entries: $entries)';
}


}

/// @nodoc
abstract mixin class _$SessionPromptIndexResponseCopyWith<$Res> implements $SessionPromptIndexResponseCopyWith<$Res> {
  factory _$SessionPromptIndexResponseCopyWith(_SessionPromptIndexResponse value, $Res Function(_SessionPromptIndexResponse) _then) = __$SessionPromptIndexResponseCopyWithImpl;
@override @useResult
$Res call({
 List<SessionPromptIndexEntry> entries
});




}
/// @nodoc
class __$SessionPromptIndexResponseCopyWithImpl<$Res>
    implements _$SessionPromptIndexResponseCopyWith<$Res> {
  __$SessionPromptIndexResponseCopyWithImpl(this._self, this._then);

  final _SessionPromptIndexResponse _self;
  final $Res Function(_SessionPromptIndexResponse) _then;

/// Create a copy of SessionPromptIndexResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? entries = null,}) {
  return _then(_SessionPromptIndexResponse(
entries: null == entries ? _self._entries : entries // ignore: cast_nullable_to_non_nullable
as List<SessionPromptIndexEntry>,
  ));
}


}

SessionPromptIndexEntry _$SessionPromptIndexEntryFromJson(
  Map<String, dynamic> json
) {
        switch (json['kind']) {
                  case 'opener':
          return SessionPromptIndexOpener.fromJson(
            json
          );
                case 'followUp':
          return SessionPromptIndexFollowUp.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'kind',
  'SessionPromptIndexEntry',
  'Invalid union type "${json['kind']}"!'
);
        }
      
}

/// @nodoc
mixin _$SessionPromptIndexEntry {

 String get messageId; int get seq; int get number; int? get createdAt; String? get preview;

  /// Serializes this SessionPromptIndexEntry to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SessionPromptIndexEntry;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionPromptIndexEntry&&(identical(other.messageId, _this.messageId) || other.messageId == _this.messageId)&&(identical(other.seq, _this.seq) || other.seq == _this.seq)&&(identical(other.number, _this.number) || other.number == _this.number)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.preview, _this.preview) || other.preview == _this.preview));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SessionPromptIndexEntry;
  return Object.hash(runtimeType,_this.messageId,_this.seq,_this.number,_this.createdAt,_this.preview);
}

@override
String toString() {
  final _this = this as SessionPromptIndexEntry;
  return 'SessionPromptIndexEntry(messageId: ${_this.messageId}, seq: ${_this.seq}, number: ${_this.number}, createdAt: ${_this.createdAt}, preview: ${_this.preview})';
}


}





/// @nodoc
@JsonSerializable()

class SessionPromptIndexOpener implements SessionPromptIndexEntry {
  const SessionPromptIndexOpener({required this.messageId, required this.seq, required this.number, required this.createdAt, required this.preview,  String? $type}): $type = $type ?? 'opener';
  factory SessionPromptIndexOpener.fromJson(Map<String, dynamic> json) => _$SessionPromptIndexOpenerFromJson(json);

@override final  String messageId;
@override final  int seq;
@override final  int number;
@override final  int? createdAt;
@override final  String? preview;

@JsonKey(name: 'kind')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$SessionPromptIndexOpenerToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionPromptIndexOpener&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.seq, seq) || other.seq == seq)&&(identical(other.number, number) || other.number == number)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.preview, preview) || other.preview == preview));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,messageId,seq,number,createdAt,preview);
}

@override
String toString() {
    return 'SessionPromptIndexEntry.opener(messageId: $messageId, seq: $seq, number: $number, createdAt: $createdAt, preview: $preview)';
}


}




/// @nodoc
@JsonSerializable()

class SessionPromptIndexFollowUp implements SessionPromptIndexEntry {
  const SessionPromptIndexFollowUp({required this.messageId, required this.seq, required this.number, required this.createdAt, required this.preview, required this.openerMessageId,  String? $type}): $type = $type ?? 'followUp';
  factory SessionPromptIndexFollowUp.fromJson(Map<String, dynamic> json) => _$SessionPromptIndexFollowUpFromJson(json);

@override final  String messageId;
@override final  int seq;
@override final  int number;
@override final  int? createdAt;
@override final  String? preview;
 final  String openerMessageId;

@JsonKey(name: 'kind')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$SessionPromptIndexFollowUpToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionPromptIndexFollowUp&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.seq, seq) || other.seq == seq)&&(identical(other.number, number) || other.number == number)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.preview, preview) || other.preview == preview)&&(identical(other.openerMessageId, openerMessageId) || other.openerMessageId == openerMessageId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,messageId,seq,number,createdAt,preview,openerMessageId);
}

@override
String toString() {
    return 'SessionPromptIndexEntry.followUp(messageId: $messageId, seq: $seq, number: $number, createdAt: $createdAt, preview: $preview, openerMessageId: $openerMessageId)';
}


}




// dart format on
