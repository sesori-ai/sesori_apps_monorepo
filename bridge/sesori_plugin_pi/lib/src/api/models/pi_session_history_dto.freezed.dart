// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pi_session_history_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PiSessionEntriesDto {

 List<PiSessionEntryDto> get entries; String? get leafId;
/// Create a copy of PiSessionEntriesDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiSessionEntriesDtoCopyWith<PiSessionEntriesDto> get copyWith => _$PiSessionEntriesDtoCopyWithImpl<PiSessionEntriesDto>(this as PiSessionEntriesDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiSessionEntriesDto&&const DeepCollectionEquality().equals(other.entries, entries)&&(identical(other.leafId, leafId) || other.leafId == leafId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(entries),leafId);



}

/// @nodoc
abstract mixin class $PiSessionEntriesDtoCopyWith<$Res>  {
  factory $PiSessionEntriesDtoCopyWith(PiSessionEntriesDto value, $Res Function(PiSessionEntriesDto) _then) = _$PiSessionEntriesDtoCopyWithImpl;
@useResult
$Res call({
 List<PiSessionEntryDto> entries, String? leafId
});




}
/// @nodoc
class _$PiSessionEntriesDtoCopyWithImpl<$Res>
    implements $PiSessionEntriesDtoCopyWith<$Res> {
  _$PiSessionEntriesDtoCopyWithImpl(this._self, this._then);

  final PiSessionEntriesDto _self;
  final $Res Function(PiSessionEntriesDto) _then;

/// Create a copy of PiSessionEntriesDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? entries = null,Object? leafId = freezed,}) {
  return _then(PiSessionEntriesDto(
entries: null == entries ? _self.entries : entries // ignore: cast_nullable_to_non_nullable
as List<PiSessionEntryDto>,leafId: freezed == leafId ? _self.leafId : leafId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _PiSessionEntriesDto implements PiSessionEntriesDto {
  const _PiSessionEntriesDto({required  List<PiSessionEntryDto> entries, required this.leafId}): _entries = entries;
  factory _PiSessionEntriesDto.fromJson(Map<String, dynamic> json) => _$PiSessionEntriesDtoFromJson(json);

 final  List<PiSessionEntryDto> _entries;
@override List<PiSessionEntryDto> get entries {
  if (_entries is EqualUnmodifiableListView) return _entries;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_entries);
}

@override final  String? leafId;

/// Create a copy of PiSessionEntriesDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PiSessionEntriesDtoCopyWith<_PiSessionEntriesDto> get copyWith => __$PiSessionEntriesDtoCopyWithImpl<_PiSessionEntriesDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PiSessionEntriesDto&&const DeepCollectionEquality().equals(other._entries, _entries)&&(identical(other.leafId, leafId) || other.leafId == leafId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_entries),leafId);



}

/// @nodoc
abstract mixin class _$PiSessionEntriesDtoCopyWith<$Res> implements $PiSessionEntriesDtoCopyWith<$Res> {
  factory _$PiSessionEntriesDtoCopyWith(_PiSessionEntriesDto value, $Res Function(_PiSessionEntriesDto) _then) = __$PiSessionEntriesDtoCopyWithImpl;
@override @useResult
$Res call({
 List<PiSessionEntryDto> entries, String? leafId
});




}
/// @nodoc
class __$PiSessionEntriesDtoCopyWithImpl<$Res>
    implements _$PiSessionEntriesDtoCopyWith<$Res> {
  __$PiSessionEntriesDtoCopyWithImpl(this._self, this._then);

  final _PiSessionEntriesDto _self;
  final $Res Function(_PiSessionEntriesDto) _then;

/// Create a copy of PiSessionEntriesDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? entries = null,Object? leafId = freezed,}) {
  return _then(_PiSessionEntriesDto(
entries: null == entries ? _self._entries : entries // ignore: cast_nullable_to_non_nullable
as List<PiSessionEntryDto>,leafId: freezed == leafId ? _self.leafId : leafId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$PiSessionFileHistoryDto {

 PiSessionFileHeaderDto get header; List<PiSessionFileEntryDto> get entries;
/// Create a copy of PiSessionFileHistoryDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiSessionFileHistoryDtoCopyWith<PiSessionFileHistoryDto> get copyWith => _$PiSessionFileHistoryDtoCopyWithImpl<PiSessionFileHistoryDto>(this as PiSessionFileHistoryDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiSessionFileHistoryDto&&(identical(other.header, header) || other.header == header)&&const DeepCollectionEquality().equals(other.entries, entries));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,header,const DeepCollectionEquality().hash(entries));



}

/// @nodoc
abstract mixin class $PiSessionFileHistoryDtoCopyWith<$Res>  {
  factory $PiSessionFileHistoryDtoCopyWith(PiSessionFileHistoryDto value, $Res Function(PiSessionFileHistoryDto) _then) = _$PiSessionFileHistoryDtoCopyWithImpl;
@useResult
$Res call({
 PiSessionFileHeaderDto header, List<PiSessionFileEntryDto> entries
});


$PiSessionFileHeaderDtoCopyWith<$Res> get header;

}
/// @nodoc
class _$PiSessionFileHistoryDtoCopyWithImpl<$Res>
    implements $PiSessionFileHistoryDtoCopyWith<$Res> {
  _$PiSessionFileHistoryDtoCopyWithImpl(this._self, this._then);

  final PiSessionFileHistoryDto _self;
  final $Res Function(PiSessionFileHistoryDto) _then;

/// Create a copy of PiSessionFileHistoryDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? header = null,Object? entries = null,}) {
  return _then(PiSessionFileHistoryDto(
header: null == header ? _self.header : header // ignore: cast_nullable_to_non_nullable
as PiSessionFileHeaderDto,entries: null == entries ? _self.entries : entries // ignore: cast_nullable_to_non_nullable
as List<PiSessionFileEntryDto>,
  ));
}
/// Create a copy of PiSessionFileHistoryDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PiSessionFileHeaderDtoCopyWith<$Res> get header {
  
  return $PiSessionFileHeaderDtoCopyWith<$Res>(_self.header, (value) {
    return _then(_self.copyWith(header: value));
  });
}
}



/// @nodoc
@JsonSerializable(createToJson: false)

class _PiSessionFileHistoryDto implements PiSessionFileHistoryDto {
  const _PiSessionFileHistoryDto({required this.header, required  List<PiSessionFileEntryDto> entries}): _entries = entries;
  factory _PiSessionFileHistoryDto.fromJson(Map<String, dynamic> json) => _$PiSessionFileHistoryDtoFromJson(json);

@override final  PiSessionFileHeaderDto header;
 final  List<PiSessionFileEntryDto> _entries;
@override List<PiSessionFileEntryDto> get entries {
  if (_entries is EqualUnmodifiableListView) return _entries;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_entries);
}


/// Create a copy of PiSessionFileHistoryDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PiSessionFileHistoryDtoCopyWith<_PiSessionFileHistoryDto> get copyWith => __$PiSessionFileHistoryDtoCopyWithImpl<_PiSessionFileHistoryDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PiSessionFileHistoryDto&&(identical(other.header, header) || other.header == header)&&const DeepCollectionEquality().equals(other._entries, _entries));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,header,const DeepCollectionEquality().hash(_entries));



}

/// @nodoc
abstract mixin class _$PiSessionFileHistoryDtoCopyWith<$Res> implements $PiSessionFileHistoryDtoCopyWith<$Res> {
  factory _$PiSessionFileHistoryDtoCopyWith(_PiSessionFileHistoryDto value, $Res Function(_PiSessionFileHistoryDto) _then) = __$PiSessionFileHistoryDtoCopyWithImpl;
@override @useResult
$Res call({
 PiSessionFileHeaderDto header, List<PiSessionFileEntryDto> entries
});


@override $PiSessionFileHeaderDtoCopyWith<$Res> get header;

}
/// @nodoc
class __$PiSessionFileHistoryDtoCopyWithImpl<$Res>
    implements _$PiSessionFileHistoryDtoCopyWith<$Res> {
  __$PiSessionFileHistoryDtoCopyWithImpl(this._self, this._then);

  final _PiSessionFileHistoryDto _self;
  final $Res Function(_PiSessionFileHistoryDto) _then;

/// Create a copy of PiSessionFileHistoryDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? header = null,Object? entries = null,}) {
  return _then(_PiSessionFileHistoryDto(
header: null == header ? _self.header : header // ignore: cast_nullable_to_non_nullable
as PiSessionFileHeaderDto,entries: null == entries ? _self._entries : entries // ignore: cast_nullable_to_non_nullable
as List<PiSessionFileEntryDto>,
  ));
}

/// Create a copy of PiSessionFileHistoryDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PiSessionFileHeaderDtoCopyWith<$Res> get header {
  
  return $PiSessionFileHeaderDtoCopyWith<$Res>(_self.header, (value) {
    return _then(_self.copyWith(header: value));
  });
}
}


/// @nodoc
mixin _$PiSessionFileHeaderDto {

@JsonKey(fromJson: _intOrNull) int? get version; String get id;
/// Create a copy of PiSessionFileHeaderDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiSessionFileHeaderDtoCopyWith<PiSessionFileHeaderDto> get copyWith => _$PiSessionFileHeaderDtoCopyWithImpl<PiSessionFileHeaderDto>(this as PiSessionFileHeaderDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiSessionFileHeaderDto&&(identical(other.version, version) || other.version == version)&&(identical(other.id, id) || other.id == id));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,version,id);



}

/// @nodoc
abstract mixin class $PiSessionFileHeaderDtoCopyWith<$Res>  {
  factory $PiSessionFileHeaderDtoCopyWith(PiSessionFileHeaderDto value, $Res Function(PiSessionFileHeaderDto) _then) = _$PiSessionFileHeaderDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _intOrNull) int? version, String id
});




}
/// @nodoc
class _$PiSessionFileHeaderDtoCopyWithImpl<$Res>
    implements $PiSessionFileHeaderDtoCopyWith<$Res> {
  _$PiSessionFileHeaderDtoCopyWithImpl(this._self, this._then);

  final PiSessionFileHeaderDto _self;
  final $Res Function(PiSessionFileHeaderDto) _then;

/// Create a copy of PiSessionFileHeaderDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? version = freezed,Object? id = null,}) {
  return _then(PiSessionFileHeaderDto(
version: freezed == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int?,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _PiSessionFileHeaderDto implements PiSessionFileHeaderDto {
  const _PiSessionFileHeaderDto({@JsonKey(fromJson: _intOrNull) required this.version, required this.id});
  factory _PiSessionFileHeaderDto.fromJson(Map<String, dynamic> json) => _$PiSessionFileHeaderDtoFromJson(json);

@override@JsonKey(fromJson: _intOrNull) final  int? version;
@override final  String id;

/// Create a copy of PiSessionFileHeaderDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PiSessionFileHeaderDtoCopyWith<_PiSessionFileHeaderDto> get copyWith => __$PiSessionFileHeaderDtoCopyWithImpl<_PiSessionFileHeaderDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PiSessionFileHeaderDto&&(identical(other.version, version) || other.version == version)&&(identical(other.id, id) || other.id == id));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,version,id);



}

/// @nodoc
abstract mixin class _$PiSessionFileHeaderDtoCopyWith<$Res> implements $PiSessionFileHeaderDtoCopyWith<$Res> {
  factory _$PiSessionFileHeaderDtoCopyWith(_PiSessionFileHeaderDto value, $Res Function(_PiSessionFileHeaderDto) _then) = __$PiSessionFileHeaderDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _intOrNull) int? version, String id
});




}
/// @nodoc
class __$PiSessionFileHeaderDtoCopyWithImpl<$Res>
    implements _$PiSessionFileHeaderDtoCopyWith<$Res> {
  __$PiSessionFileHeaderDtoCopyWithImpl(this._self, this._then);

  final _PiSessionFileHeaderDto _self;
  final $Res Function(_PiSessionFileHeaderDto) _then;

/// Create a copy of PiSessionFileHeaderDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? version = freezed,Object? id = null,}) {
  return _then(_PiSessionFileHeaderDto(
version: freezed == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int?,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

PiSessionEntryDto _$PiSessionEntryDtoFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'message':
          return PiMessageEntryDto.fromJson(
            json
          );
                case 'thinking_level_change':
          return PiThinkingLevelChangeEntryDto.fromJson(
            json
          );
                case 'model_change':
          return PiModelChangeEntryDto.fromJson(
            json
          );
                case 'compaction':
          return PiCompactionEntryDto.fromJson(
            json
          );
                case 'branch_summary':
          return PiBranchSummaryEntryDto.fromJson(
            json
          );
                case 'custom':
          return PiCustomEntryDto.fromJson(
            json
          );
                case 'custom_message':
          return PiCustomMessageEntryDto.fromJson(
            json
          );
                case 'label':
          return PiLabelEntryDto.fromJson(
            json
          );
                case 'session_info':
          return PiSessionInfoEntryDto.fromJson(
            json
          );
        
          default:
            return PiUnknownEntryDto.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$PiSessionEntryDto {

 String get id; String? get parentId; DateTime get timestamp;
/// Create a copy of PiSessionEntryDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiSessionEntryDtoCopyWith<PiSessionEntryDto> get copyWith => _$PiSessionEntryDtoCopyWithImpl<PiSessionEntryDto>(this as PiSessionEntryDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiSessionEntryDto&&(identical(other.id, id) || other.id == id)&&(identical(other.parentId, parentId) || other.parentId == parentId)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,parentId,timestamp);



}

/// @nodoc
abstract mixin class $PiSessionEntryDtoCopyWith<$Res>  {
  factory $PiSessionEntryDtoCopyWith(PiSessionEntryDto value, $Res Function(PiSessionEntryDto) _then) = _$PiSessionEntryDtoCopyWithImpl;
@useResult
$Res call({
 String id, String? parentId, DateTime timestamp
});




}
/// @nodoc
class _$PiSessionEntryDtoCopyWithImpl<$Res>
    implements $PiSessionEntryDtoCopyWith<$Res> {
  _$PiSessionEntryDtoCopyWithImpl(this._self, this._then);

  final PiSessionEntryDto _self;
  final $Res Function(PiSessionEntryDto) _then;

/// Create a copy of PiSessionEntryDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? parentId = freezed,Object? timestamp = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String?,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class PiMessageEntryDto implements PiSessionEntryDto {
  const PiMessageEntryDto({required this.id, required this.parentId, required this.timestamp, required this.message,  String? $type}): $type = $type ?? 'message';
  factory PiMessageEntryDto.fromJson(Map<String, dynamic> json) => _$PiMessageEntryDtoFromJson(json);

@override final  String id;
@override final  String? parentId;
@override final  DateTime timestamp;
 final  PiAgentMessageDto message;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of PiSessionEntryDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiMessageEntryDtoCopyWith<PiMessageEntryDto> get copyWith => _$PiMessageEntryDtoCopyWithImpl<PiMessageEntryDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiMessageEntryDto&&(identical(other.id, id) || other.id == id)&&(identical(other.parentId, parentId) || other.parentId == parentId)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,parentId,timestamp,message);



}

/// @nodoc
abstract mixin class $PiMessageEntryDtoCopyWith<$Res> implements $PiSessionEntryDtoCopyWith<$Res> {
  factory $PiMessageEntryDtoCopyWith(PiMessageEntryDto value, $Res Function(PiMessageEntryDto) _then) = _$PiMessageEntryDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String? parentId, DateTime timestamp, PiAgentMessageDto message
});


$PiAgentMessageDtoCopyWith<$Res> get message;

}
/// @nodoc
class _$PiMessageEntryDtoCopyWithImpl<$Res>
    implements $PiMessageEntryDtoCopyWith<$Res> {
  _$PiMessageEntryDtoCopyWithImpl(this._self, this._then);

  final PiMessageEntryDto _self;
  final $Res Function(PiMessageEntryDto) _then;

/// Create a copy of PiSessionEntryDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? parentId = freezed,Object? timestamp = null,Object? message = null,}) {
  return _then(PiMessageEntryDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String?,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as PiAgentMessageDto,
  ));
}

/// Create a copy of PiSessionEntryDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PiAgentMessageDtoCopyWith<$Res> get message {
  
  return $PiAgentMessageDtoCopyWith<$Res>(_self.message, (value) {
    return _then(_self.copyWith(message: value));
  });
}
}

/// @nodoc
@JsonSerializable(createToJson: false)

class PiThinkingLevelChangeEntryDto implements PiSessionEntryDto {
  const PiThinkingLevelChangeEntryDto({required this.id, required this.parentId, required this.timestamp, @JsonKey(fromJson: _thinkingLevelOrNull) required this.thinkingLevel,  String? $type}): $type = $type ?? 'thinking_level_change';
  factory PiThinkingLevelChangeEntryDto.fromJson(Map<String, dynamic> json) => _$PiThinkingLevelChangeEntryDtoFromJson(json);

@override final  String id;
@override final  String? parentId;
@override final  DateTime timestamp;
@JsonKey(fromJson: _thinkingLevelOrNull) final  PiThinkingLevel? thinkingLevel;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of PiSessionEntryDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiThinkingLevelChangeEntryDtoCopyWith<PiThinkingLevelChangeEntryDto> get copyWith => _$PiThinkingLevelChangeEntryDtoCopyWithImpl<PiThinkingLevelChangeEntryDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiThinkingLevelChangeEntryDto&&(identical(other.id, id) || other.id == id)&&(identical(other.parentId, parentId) || other.parentId == parentId)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.thinkingLevel, thinkingLevel) || other.thinkingLevel == thinkingLevel));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,parentId,timestamp,thinkingLevel);



}

/// @nodoc
abstract mixin class $PiThinkingLevelChangeEntryDtoCopyWith<$Res> implements $PiSessionEntryDtoCopyWith<$Res> {
  factory $PiThinkingLevelChangeEntryDtoCopyWith(PiThinkingLevelChangeEntryDto value, $Res Function(PiThinkingLevelChangeEntryDto) _then) = _$PiThinkingLevelChangeEntryDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String? parentId, DateTime timestamp,@JsonKey(fromJson: _thinkingLevelOrNull) PiThinkingLevel? thinkingLevel
});




}
/// @nodoc
class _$PiThinkingLevelChangeEntryDtoCopyWithImpl<$Res>
    implements $PiThinkingLevelChangeEntryDtoCopyWith<$Res> {
  _$PiThinkingLevelChangeEntryDtoCopyWithImpl(this._self, this._then);

  final PiThinkingLevelChangeEntryDto _self;
  final $Res Function(PiThinkingLevelChangeEntryDto) _then;

/// Create a copy of PiSessionEntryDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? parentId = freezed,Object? timestamp = null,Object? thinkingLevel = freezed,}) {
  return _then(PiThinkingLevelChangeEntryDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String?,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,thinkingLevel: freezed == thinkingLevel ? _self.thinkingLevel : thinkingLevel // ignore: cast_nullable_to_non_nullable
as PiThinkingLevel?,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class PiModelChangeEntryDto implements PiSessionEntryDto {
  const PiModelChangeEntryDto({required this.id, required this.parentId, required this.timestamp,  String? $type}): $type = $type ?? 'model_change';
  factory PiModelChangeEntryDto.fromJson(Map<String, dynamic> json) => _$PiModelChangeEntryDtoFromJson(json);

@override final  String id;
@override final  String? parentId;
@override final  DateTime timestamp;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of PiSessionEntryDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiModelChangeEntryDtoCopyWith<PiModelChangeEntryDto> get copyWith => _$PiModelChangeEntryDtoCopyWithImpl<PiModelChangeEntryDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiModelChangeEntryDto&&(identical(other.id, id) || other.id == id)&&(identical(other.parentId, parentId) || other.parentId == parentId)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,parentId,timestamp);



}

/// @nodoc
abstract mixin class $PiModelChangeEntryDtoCopyWith<$Res> implements $PiSessionEntryDtoCopyWith<$Res> {
  factory $PiModelChangeEntryDtoCopyWith(PiModelChangeEntryDto value, $Res Function(PiModelChangeEntryDto) _then) = _$PiModelChangeEntryDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String? parentId, DateTime timestamp
});




}
/// @nodoc
class _$PiModelChangeEntryDtoCopyWithImpl<$Res>
    implements $PiModelChangeEntryDtoCopyWith<$Res> {
  _$PiModelChangeEntryDtoCopyWithImpl(this._self, this._then);

  final PiModelChangeEntryDto _self;
  final $Res Function(PiModelChangeEntryDto) _then;

/// Create a copy of PiSessionEntryDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? parentId = freezed,Object? timestamp = null,}) {
  return _then(PiModelChangeEntryDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String?,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class PiCompactionEntryDto implements PiSessionEntryDto {
  const PiCompactionEntryDto({required this.id, required this.parentId, required this.timestamp,  String? $type}): $type = $type ?? 'compaction';
  factory PiCompactionEntryDto.fromJson(Map<String, dynamic> json) => _$PiCompactionEntryDtoFromJson(json);

@override final  String id;
@override final  String? parentId;
@override final  DateTime timestamp;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of PiSessionEntryDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiCompactionEntryDtoCopyWith<PiCompactionEntryDto> get copyWith => _$PiCompactionEntryDtoCopyWithImpl<PiCompactionEntryDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiCompactionEntryDto&&(identical(other.id, id) || other.id == id)&&(identical(other.parentId, parentId) || other.parentId == parentId)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,parentId,timestamp);



}

/// @nodoc
abstract mixin class $PiCompactionEntryDtoCopyWith<$Res> implements $PiSessionEntryDtoCopyWith<$Res> {
  factory $PiCompactionEntryDtoCopyWith(PiCompactionEntryDto value, $Res Function(PiCompactionEntryDto) _then) = _$PiCompactionEntryDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String? parentId, DateTime timestamp
});




}
/// @nodoc
class _$PiCompactionEntryDtoCopyWithImpl<$Res>
    implements $PiCompactionEntryDtoCopyWith<$Res> {
  _$PiCompactionEntryDtoCopyWithImpl(this._self, this._then);

  final PiCompactionEntryDto _self;
  final $Res Function(PiCompactionEntryDto) _then;

/// Create a copy of PiSessionEntryDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? parentId = freezed,Object? timestamp = null,}) {
  return _then(PiCompactionEntryDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String?,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class PiBranchSummaryEntryDto implements PiSessionEntryDto {
  const PiBranchSummaryEntryDto({required this.id, required this.parentId, required this.timestamp,  String? $type}): $type = $type ?? 'branch_summary';
  factory PiBranchSummaryEntryDto.fromJson(Map<String, dynamic> json) => _$PiBranchSummaryEntryDtoFromJson(json);

@override final  String id;
@override final  String? parentId;
@override final  DateTime timestamp;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of PiSessionEntryDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiBranchSummaryEntryDtoCopyWith<PiBranchSummaryEntryDto> get copyWith => _$PiBranchSummaryEntryDtoCopyWithImpl<PiBranchSummaryEntryDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiBranchSummaryEntryDto&&(identical(other.id, id) || other.id == id)&&(identical(other.parentId, parentId) || other.parentId == parentId)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,parentId,timestamp);



}

/// @nodoc
abstract mixin class $PiBranchSummaryEntryDtoCopyWith<$Res> implements $PiSessionEntryDtoCopyWith<$Res> {
  factory $PiBranchSummaryEntryDtoCopyWith(PiBranchSummaryEntryDto value, $Res Function(PiBranchSummaryEntryDto) _then) = _$PiBranchSummaryEntryDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String? parentId, DateTime timestamp
});




}
/// @nodoc
class _$PiBranchSummaryEntryDtoCopyWithImpl<$Res>
    implements $PiBranchSummaryEntryDtoCopyWith<$Res> {
  _$PiBranchSummaryEntryDtoCopyWithImpl(this._self, this._then);

  final PiBranchSummaryEntryDto _self;
  final $Res Function(PiBranchSummaryEntryDto) _then;

/// Create a copy of PiSessionEntryDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? parentId = freezed,Object? timestamp = null,}) {
  return _then(PiBranchSummaryEntryDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String?,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class PiCustomEntryDto implements PiSessionEntryDto {
  const PiCustomEntryDto({required this.id, required this.parentId, required this.timestamp,  String? $type}): $type = $type ?? 'custom';
  factory PiCustomEntryDto.fromJson(Map<String, dynamic> json) => _$PiCustomEntryDtoFromJson(json);

@override final  String id;
@override final  String? parentId;
@override final  DateTime timestamp;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of PiSessionEntryDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiCustomEntryDtoCopyWith<PiCustomEntryDto> get copyWith => _$PiCustomEntryDtoCopyWithImpl<PiCustomEntryDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiCustomEntryDto&&(identical(other.id, id) || other.id == id)&&(identical(other.parentId, parentId) || other.parentId == parentId)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,parentId,timestamp);



}

/// @nodoc
abstract mixin class $PiCustomEntryDtoCopyWith<$Res> implements $PiSessionEntryDtoCopyWith<$Res> {
  factory $PiCustomEntryDtoCopyWith(PiCustomEntryDto value, $Res Function(PiCustomEntryDto) _then) = _$PiCustomEntryDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String? parentId, DateTime timestamp
});




}
/// @nodoc
class _$PiCustomEntryDtoCopyWithImpl<$Res>
    implements $PiCustomEntryDtoCopyWith<$Res> {
  _$PiCustomEntryDtoCopyWithImpl(this._self, this._then);

  final PiCustomEntryDto _self;
  final $Res Function(PiCustomEntryDto) _then;

/// Create a copy of PiSessionEntryDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? parentId = freezed,Object? timestamp = null,}) {
  return _then(PiCustomEntryDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String?,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class PiCustomMessageEntryDto implements PiSessionEntryDto {
  const PiCustomMessageEntryDto({required this.id, required this.parentId, required this.timestamp, @JsonKey(fromJson: _contentFromJson) required  List<PiContentDto> content, required this.display,  String? $type}): _content = content,$type = $type ?? 'custom_message';
  factory PiCustomMessageEntryDto.fromJson(Map<String, dynamic> json) => _$PiCustomMessageEntryDtoFromJson(json);

@override final  String id;
@override final  String? parentId;
@override final  DateTime timestamp;
 final  List<PiContentDto> _content;
@JsonKey(fromJson: _contentFromJson) List<PiContentDto> get content {
  if (_content is EqualUnmodifiableListView) return _content;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_content);
}

 final  bool display;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of PiSessionEntryDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiCustomMessageEntryDtoCopyWith<PiCustomMessageEntryDto> get copyWith => _$PiCustomMessageEntryDtoCopyWithImpl<PiCustomMessageEntryDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiCustomMessageEntryDto&&(identical(other.id, id) || other.id == id)&&(identical(other.parentId, parentId) || other.parentId == parentId)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&const DeepCollectionEquality().equals(other._content, _content)&&(identical(other.display, display) || other.display == display));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,parentId,timestamp,const DeepCollectionEquality().hash(_content),display);



}

/// @nodoc
abstract mixin class $PiCustomMessageEntryDtoCopyWith<$Res> implements $PiSessionEntryDtoCopyWith<$Res> {
  factory $PiCustomMessageEntryDtoCopyWith(PiCustomMessageEntryDto value, $Res Function(PiCustomMessageEntryDto) _then) = _$PiCustomMessageEntryDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String? parentId, DateTime timestamp,@JsonKey(fromJson: _contentFromJson) List<PiContentDto> content, bool display
});




}
/// @nodoc
class _$PiCustomMessageEntryDtoCopyWithImpl<$Res>
    implements $PiCustomMessageEntryDtoCopyWith<$Res> {
  _$PiCustomMessageEntryDtoCopyWithImpl(this._self, this._then);

  final PiCustomMessageEntryDto _self;
  final $Res Function(PiCustomMessageEntryDto) _then;

/// Create a copy of PiSessionEntryDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? parentId = freezed,Object? timestamp = null,Object? content = null,Object? display = null,}) {
  return _then(PiCustomMessageEntryDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String?,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,content: null == content ? _self._content : content // ignore: cast_nullable_to_non_nullable
as List<PiContentDto>,display: null == display ? _self.display : display // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class PiLabelEntryDto implements PiSessionEntryDto {
  const PiLabelEntryDto({required this.id, required this.parentId, required this.timestamp,  String? $type}): $type = $type ?? 'label';
  factory PiLabelEntryDto.fromJson(Map<String, dynamic> json) => _$PiLabelEntryDtoFromJson(json);

@override final  String id;
@override final  String? parentId;
@override final  DateTime timestamp;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of PiSessionEntryDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiLabelEntryDtoCopyWith<PiLabelEntryDto> get copyWith => _$PiLabelEntryDtoCopyWithImpl<PiLabelEntryDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiLabelEntryDto&&(identical(other.id, id) || other.id == id)&&(identical(other.parentId, parentId) || other.parentId == parentId)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,parentId,timestamp);



}

/// @nodoc
abstract mixin class $PiLabelEntryDtoCopyWith<$Res> implements $PiSessionEntryDtoCopyWith<$Res> {
  factory $PiLabelEntryDtoCopyWith(PiLabelEntryDto value, $Res Function(PiLabelEntryDto) _then) = _$PiLabelEntryDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String? parentId, DateTime timestamp
});




}
/// @nodoc
class _$PiLabelEntryDtoCopyWithImpl<$Res>
    implements $PiLabelEntryDtoCopyWith<$Res> {
  _$PiLabelEntryDtoCopyWithImpl(this._self, this._then);

  final PiLabelEntryDto _self;
  final $Res Function(PiLabelEntryDto) _then;

/// Create a copy of PiSessionEntryDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? parentId = freezed,Object? timestamp = null,}) {
  return _then(PiLabelEntryDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String?,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class PiSessionInfoEntryDto implements PiSessionEntryDto {
  const PiSessionInfoEntryDto({required this.id, required this.parentId, required this.timestamp,  String? $type}): $type = $type ?? 'session_info';
  factory PiSessionInfoEntryDto.fromJson(Map<String, dynamic> json) => _$PiSessionInfoEntryDtoFromJson(json);

@override final  String id;
@override final  String? parentId;
@override final  DateTime timestamp;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of PiSessionEntryDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiSessionInfoEntryDtoCopyWith<PiSessionInfoEntryDto> get copyWith => _$PiSessionInfoEntryDtoCopyWithImpl<PiSessionInfoEntryDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiSessionInfoEntryDto&&(identical(other.id, id) || other.id == id)&&(identical(other.parentId, parentId) || other.parentId == parentId)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,parentId,timestamp);



}

/// @nodoc
abstract mixin class $PiSessionInfoEntryDtoCopyWith<$Res> implements $PiSessionEntryDtoCopyWith<$Res> {
  factory $PiSessionInfoEntryDtoCopyWith(PiSessionInfoEntryDto value, $Res Function(PiSessionInfoEntryDto) _then) = _$PiSessionInfoEntryDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String? parentId, DateTime timestamp
});




}
/// @nodoc
class _$PiSessionInfoEntryDtoCopyWithImpl<$Res>
    implements $PiSessionInfoEntryDtoCopyWith<$Res> {
  _$PiSessionInfoEntryDtoCopyWithImpl(this._self, this._then);

  final PiSessionInfoEntryDto _self;
  final $Res Function(PiSessionInfoEntryDto) _then;

/// Create a copy of PiSessionEntryDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? parentId = freezed,Object? timestamp = null,}) {
  return _then(PiSessionInfoEntryDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String?,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class PiUnknownEntryDto implements PiSessionEntryDto {
  const PiUnknownEntryDto({required this.id, required this.parentId, required this.timestamp,  String? $type}): $type = $type ?? 'unknown';
  factory PiUnknownEntryDto.fromJson(Map<String, dynamic> json) => _$PiUnknownEntryDtoFromJson(json);

@override final  String id;
@override final  String? parentId;
@override final  DateTime timestamp;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of PiSessionEntryDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiUnknownEntryDtoCopyWith<PiUnknownEntryDto> get copyWith => _$PiUnknownEntryDtoCopyWithImpl<PiUnknownEntryDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiUnknownEntryDto&&(identical(other.id, id) || other.id == id)&&(identical(other.parentId, parentId) || other.parentId == parentId)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,parentId,timestamp);



}

/// @nodoc
abstract mixin class $PiUnknownEntryDtoCopyWith<$Res> implements $PiSessionEntryDtoCopyWith<$Res> {
  factory $PiUnknownEntryDtoCopyWith(PiUnknownEntryDto value, $Res Function(PiUnknownEntryDto) _then) = _$PiUnknownEntryDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String? parentId, DateTime timestamp
});




}
/// @nodoc
class _$PiUnknownEntryDtoCopyWithImpl<$Res>
    implements $PiUnknownEntryDtoCopyWith<$Res> {
  _$PiUnknownEntryDtoCopyWithImpl(this._self, this._then);

  final PiUnknownEntryDto _self;
  final $Res Function(PiUnknownEntryDto) _then;

/// Create a copy of PiSessionEntryDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? parentId = freezed,Object? timestamp = null,}) {
  return _then(PiUnknownEntryDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String?,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

PiSessionFileEntryDto _$PiSessionFileEntryDtoFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'message':
          return PiSessionFileMessageEntryDto.fromJson(
            json
          );
                case 'thinking_level_change':
          return PiSessionFileThinkingLevelChangeEntryDto.fromJson(
            json
          );
                case 'model_change':
          return PiSessionFileModelChangeEntryDto.fromJson(
            json
          );
                case 'compaction':
          return PiSessionFileCompactionEntryDto.fromJson(
            json
          );
                case 'branch_summary':
          return PiSessionFileBranchSummaryEntryDto.fromJson(
            json
          );
                case 'custom':
          return PiSessionFileCustomEntryDto.fromJson(
            json
          );
                case 'custom_message':
          return PiSessionFileCustomMessageEntryDto.fromJson(
            json
          );
                case 'label':
          return PiSessionFileLabelEntryDto.fromJson(
            json
          );
                case 'session_info':
          return PiSessionFileSessionInfoEntryDto.fromJson(
            json
          );
        
          default:
            return PiSessionFileUnknownEntryDto.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$PiSessionFileEntryDto {

 String? get id; String? get parentId; DateTime get timestamp;
/// Create a copy of PiSessionFileEntryDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiSessionFileEntryDtoCopyWith<PiSessionFileEntryDto> get copyWith => _$PiSessionFileEntryDtoCopyWithImpl<PiSessionFileEntryDto>(this as PiSessionFileEntryDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiSessionFileEntryDto&&(identical(other.id, id) || other.id == id)&&(identical(other.parentId, parentId) || other.parentId == parentId)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,parentId,timestamp);



}

/// @nodoc
abstract mixin class $PiSessionFileEntryDtoCopyWith<$Res>  {
  factory $PiSessionFileEntryDtoCopyWith(PiSessionFileEntryDto value, $Res Function(PiSessionFileEntryDto) _then) = _$PiSessionFileEntryDtoCopyWithImpl;
@useResult
$Res call({
 String? id, String? parentId, DateTime timestamp
});




}
/// @nodoc
class _$PiSessionFileEntryDtoCopyWithImpl<$Res>
    implements $PiSessionFileEntryDtoCopyWith<$Res> {
  _$PiSessionFileEntryDtoCopyWithImpl(this._self, this._then);

  final PiSessionFileEntryDto _self;
  final $Res Function(PiSessionFileEntryDto) _then;

/// Create a copy of PiSessionFileEntryDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? parentId = freezed,Object? timestamp = null,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String?,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class PiSessionFileMessageEntryDto implements PiSessionFileEntryDto {
  const PiSessionFileMessageEntryDto({required this.id, required this.parentId, required this.timestamp, required this.message,  String? $type}): $type = $type ?? 'message';
  factory PiSessionFileMessageEntryDto.fromJson(Map<String, dynamic> json) => _$PiSessionFileMessageEntryDtoFromJson(json);

@override final  String? id;
@override final  String? parentId;
@override final  DateTime timestamp;
 final  PiSessionFileAgentMessageDto message;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of PiSessionFileEntryDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiSessionFileMessageEntryDtoCopyWith<PiSessionFileMessageEntryDto> get copyWith => _$PiSessionFileMessageEntryDtoCopyWithImpl<PiSessionFileMessageEntryDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiSessionFileMessageEntryDto&&(identical(other.id, id) || other.id == id)&&(identical(other.parentId, parentId) || other.parentId == parentId)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,parentId,timestamp,message);



}

/// @nodoc
abstract mixin class $PiSessionFileMessageEntryDtoCopyWith<$Res> implements $PiSessionFileEntryDtoCopyWith<$Res> {
  factory $PiSessionFileMessageEntryDtoCopyWith(PiSessionFileMessageEntryDto value, $Res Function(PiSessionFileMessageEntryDto) _then) = _$PiSessionFileMessageEntryDtoCopyWithImpl;
@override @useResult
$Res call({
 String? id, String? parentId, DateTime timestamp, PiSessionFileAgentMessageDto message
});


$PiSessionFileAgentMessageDtoCopyWith<$Res> get message;

}
/// @nodoc
class _$PiSessionFileMessageEntryDtoCopyWithImpl<$Res>
    implements $PiSessionFileMessageEntryDtoCopyWith<$Res> {
  _$PiSessionFileMessageEntryDtoCopyWithImpl(this._self, this._then);

  final PiSessionFileMessageEntryDto _self;
  final $Res Function(PiSessionFileMessageEntryDto) _then;

/// Create a copy of PiSessionFileEntryDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? parentId = freezed,Object? timestamp = null,Object? message = null,}) {
  return _then(PiSessionFileMessageEntryDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String?,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as PiSessionFileAgentMessageDto,
  ));
}

/// Create a copy of PiSessionFileEntryDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PiSessionFileAgentMessageDtoCopyWith<$Res> get message {
  
  return $PiSessionFileAgentMessageDtoCopyWith<$Res>(_self.message, (value) {
    return _then(_self.copyWith(message: value));
  });
}
}

/// @nodoc
@JsonSerializable(createToJson: false)

class PiSessionFileThinkingLevelChangeEntryDto implements PiSessionFileEntryDto {
  const PiSessionFileThinkingLevelChangeEntryDto({required this.id, required this.parentId, required this.timestamp, @JsonKey(fromJson: _thinkingLevelOrNull) required this.thinkingLevel,  String? $type}): $type = $type ?? 'thinking_level_change';
  factory PiSessionFileThinkingLevelChangeEntryDto.fromJson(Map<String, dynamic> json) => _$PiSessionFileThinkingLevelChangeEntryDtoFromJson(json);

@override final  String? id;
@override final  String? parentId;
@override final  DateTime timestamp;
@JsonKey(fromJson: _thinkingLevelOrNull) final  PiThinkingLevel? thinkingLevel;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of PiSessionFileEntryDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiSessionFileThinkingLevelChangeEntryDtoCopyWith<PiSessionFileThinkingLevelChangeEntryDto> get copyWith => _$PiSessionFileThinkingLevelChangeEntryDtoCopyWithImpl<PiSessionFileThinkingLevelChangeEntryDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiSessionFileThinkingLevelChangeEntryDto&&(identical(other.id, id) || other.id == id)&&(identical(other.parentId, parentId) || other.parentId == parentId)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.thinkingLevel, thinkingLevel) || other.thinkingLevel == thinkingLevel));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,parentId,timestamp,thinkingLevel);



}

/// @nodoc
abstract mixin class $PiSessionFileThinkingLevelChangeEntryDtoCopyWith<$Res> implements $PiSessionFileEntryDtoCopyWith<$Res> {
  factory $PiSessionFileThinkingLevelChangeEntryDtoCopyWith(PiSessionFileThinkingLevelChangeEntryDto value, $Res Function(PiSessionFileThinkingLevelChangeEntryDto) _then) = _$PiSessionFileThinkingLevelChangeEntryDtoCopyWithImpl;
@override @useResult
$Res call({
 String? id, String? parentId, DateTime timestamp,@JsonKey(fromJson: _thinkingLevelOrNull) PiThinkingLevel? thinkingLevel
});




}
/// @nodoc
class _$PiSessionFileThinkingLevelChangeEntryDtoCopyWithImpl<$Res>
    implements $PiSessionFileThinkingLevelChangeEntryDtoCopyWith<$Res> {
  _$PiSessionFileThinkingLevelChangeEntryDtoCopyWithImpl(this._self, this._then);

  final PiSessionFileThinkingLevelChangeEntryDto _self;
  final $Res Function(PiSessionFileThinkingLevelChangeEntryDto) _then;

/// Create a copy of PiSessionFileEntryDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? parentId = freezed,Object? timestamp = null,Object? thinkingLevel = freezed,}) {
  return _then(PiSessionFileThinkingLevelChangeEntryDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String?,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,thinkingLevel: freezed == thinkingLevel ? _self.thinkingLevel : thinkingLevel // ignore: cast_nullable_to_non_nullable
as PiThinkingLevel?,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class PiSessionFileModelChangeEntryDto implements PiSessionFileEntryDto {
  const PiSessionFileModelChangeEntryDto({required this.id, required this.parentId, required this.timestamp,  String? $type}): $type = $type ?? 'model_change';
  factory PiSessionFileModelChangeEntryDto.fromJson(Map<String, dynamic> json) => _$PiSessionFileModelChangeEntryDtoFromJson(json);

@override final  String? id;
@override final  String? parentId;
@override final  DateTime timestamp;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of PiSessionFileEntryDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiSessionFileModelChangeEntryDtoCopyWith<PiSessionFileModelChangeEntryDto> get copyWith => _$PiSessionFileModelChangeEntryDtoCopyWithImpl<PiSessionFileModelChangeEntryDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiSessionFileModelChangeEntryDto&&(identical(other.id, id) || other.id == id)&&(identical(other.parentId, parentId) || other.parentId == parentId)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,parentId,timestamp);



}

/// @nodoc
abstract mixin class $PiSessionFileModelChangeEntryDtoCopyWith<$Res> implements $PiSessionFileEntryDtoCopyWith<$Res> {
  factory $PiSessionFileModelChangeEntryDtoCopyWith(PiSessionFileModelChangeEntryDto value, $Res Function(PiSessionFileModelChangeEntryDto) _then) = _$PiSessionFileModelChangeEntryDtoCopyWithImpl;
@override @useResult
$Res call({
 String? id, String? parentId, DateTime timestamp
});




}
/// @nodoc
class _$PiSessionFileModelChangeEntryDtoCopyWithImpl<$Res>
    implements $PiSessionFileModelChangeEntryDtoCopyWith<$Res> {
  _$PiSessionFileModelChangeEntryDtoCopyWithImpl(this._self, this._then);

  final PiSessionFileModelChangeEntryDto _self;
  final $Res Function(PiSessionFileModelChangeEntryDto) _then;

/// Create a copy of PiSessionFileEntryDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? parentId = freezed,Object? timestamp = null,}) {
  return _then(PiSessionFileModelChangeEntryDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String?,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class PiSessionFileCompactionEntryDto implements PiSessionFileEntryDto {
  const PiSessionFileCompactionEntryDto({required this.id, required this.parentId, required this.timestamp,  String? $type}): $type = $type ?? 'compaction';
  factory PiSessionFileCompactionEntryDto.fromJson(Map<String, dynamic> json) => _$PiSessionFileCompactionEntryDtoFromJson(json);

@override final  String? id;
@override final  String? parentId;
@override final  DateTime timestamp;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of PiSessionFileEntryDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiSessionFileCompactionEntryDtoCopyWith<PiSessionFileCompactionEntryDto> get copyWith => _$PiSessionFileCompactionEntryDtoCopyWithImpl<PiSessionFileCompactionEntryDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiSessionFileCompactionEntryDto&&(identical(other.id, id) || other.id == id)&&(identical(other.parentId, parentId) || other.parentId == parentId)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,parentId,timestamp);



}

/// @nodoc
abstract mixin class $PiSessionFileCompactionEntryDtoCopyWith<$Res> implements $PiSessionFileEntryDtoCopyWith<$Res> {
  factory $PiSessionFileCompactionEntryDtoCopyWith(PiSessionFileCompactionEntryDto value, $Res Function(PiSessionFileCompactionEntryDto) _then) = _$PiSessionFileCompactionEntryDtoCopyWithImpl;
@override @useResult
$Res call({
 String? id, String? parentId, DateTime timestamp
});




}
/// @nodoc
class _$PiSessionFileCompactionEntryDtoCopyWithImpl<$Res>
    implements $PiSessionFileCompactionEntryDtoCopyWith<$Res> {
  _$PiSessionFileCompactionEntryDtoCopyWithImpl(this._self, this._then);

  final PiSessionFileCompactionEntryDto _self;
  final $Res Function(PiSessionFileCompactionEntryDto) _then;

/// Create a copy of PiSessionFileEntryDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? parentId = freezed,Object? timestamp = null,}) {
  return _then(PiSessionFileCompactionEntryDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String?,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class PiSessionFileBranchSummaryEntryDto implements PiSessionFileEntryDto {
  const PiSessionFileBranchSummaryEntryDto({required this.id, required this.parentId, required this.timestamp,  String? $type}): $type = $type ?? 'branch_summary';
  factory PiSessionFileBranchSummaryEntryDto.fromJson(Map<String, dynamic> json) => _$PiSessionFileBranchSummaryEntryDtoFromJson(json);

@override final  String? id;
@override final  String? parentId;
@override final  DateTime timestamp;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of PiSessionFileEntryDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiSessionFileBranchSummaryEntryDtoCopyWith<PiSessionFileBranchSummaryEntryDto> get copyWith => _$PiSessionFileBranchSummaryEntryDtoCopyWithImpl<PiSessionFileBranchSummaryEntryDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiSessionFileBranchSummaryEntryDto&&(identical(other.id, id) || other.id == id)&&(identical(other.parentId, parentId) || other.parentId == parentId)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,parentId,timestamp);



}

/// @nodoc
abstract mixin class $PiSessionFileBranchSummaryEntryDtoCopyWith<$Res> implements $PiSessionFileEntryDtoCopyWith<$Res> {
  factory $PiSessionFileBranchSummaryEntryDtoCopyWith(PiSessionFileBranchSummaryEntryDto value, $Res Function(PiSessionFileBranchSummaryEntryDto) _then) = _$PiSessionFileBranchSummaryEntryDtoCopyWithImpl;
@override @useResult
$Res call({
 String? id, String? parentId, DateTime timestamp
});




}
/// @nodoc
class _$PiSessionFileBranchSummaryEntryDtoCopyWithImpl<$Res>
    implements $PiSessionFileBranchSummaryEntryDtoCopyWith<$Res> {
  _$PiSessionFileBranchSummaryEntryDtoCopyWithImpl(this._self, this._then);

  final PiSessionFileBranchSummaryEntryDto _self;
  final $Res Function(PiSessionFileBranchSummaryEntryDto) _then;

/// Create a copy of PiSessionFileEntryDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? parentId = freezed,Object? timestamp = null,}) {
  return _then(PiSessionFileBranchSummaryEntryDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String?,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class PiSessionFileCustomEntryDto implements PiSessionFileEntryDto {
  const PiSessionFileCustomEntryDto({required this.id, required this.parentId, required this.timestamp,  String? $type}): $type = $type ?? 'custom';
  factory PiSessionFileCustomEntryDto.fromJson(Map<String, dynamic> json) => _$PiSessionFileCustomEntryDtoFromJson(json);

@override final  String? id;
@override final  String? parentId;
@override final  DateTime timestamp;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of PiSessionFileEntryDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiSessionFileCustomEntryDtoCopyWith<PiSessionFileCustomEntryDto> get copyWith => _$PiSessionFileCustomEntryDtoCopyWithImpl<PiSessionFileCustomEntryDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiSessionFileCustomEntryDto&&(identical(other.id, id) || other.id == id)&&(identical(other.parentId, parentId) || other.parentId == parentId)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,parentId,timestamp);



}

/// @nodoc
abstract mixin class $PiSessionFileCustomEntryDtoCopyWith<$Res> implements $PiSessionFileEntryDtoCopyWith<$Res> {
  factory $PiSessionFileCustomEntryDtoCopyWith(PiSessionFileCustomEntryDto value, $Res Function(PiSessionFileCustomEntryDto) _then) = _$PiSessionFileCustomEntryDtoCopyWithImpl;
@override @useResult
$Res call({
 String? id, String? parentId, DateTime timestamp
});




}
/// @nodoc
class _$PiSessionFileCustomEntryDtoCopyWithImpl<$Res>
    implements $PiSessionFileCustomEntryDtoCopyWith<$Res> {
  _$PiSessionFileCustomEntryDtoCopyWithImpl(this._self, this._then);

  final PiSessionFileCustomEntryDto _self;
  final $Res Function(PiSessionFileCustomEntryDto) _then;

/// Create a copy of PiSessionFileEntryDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? parentId = freezed,Object? timestamp = null,}) {
  return _then(PiSessionFileCustomEntryDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String?,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class PiSessionFileCustomMessageEntryDto implements PiSessionFileEntryDto {
  const PiSessionFileCustomMessageEntryDto({required this.id, required this.parentId, required this.timestamp, @JsonKey(fromJson: _contentFromJson) required  List<PiContentDto> content, required this.display,  String? $type}): _content = content,$type = $type ?? 'custom_message';
  factory PiSessionFileCustomMessageEntryDto.fromJson(Map<String, dynamic> json) => _$PiSessionFileCustomMessageEntryDtoFromJson(json);

@override final  String? id;
@override final  String? parentId;
@override final  DateTime timestamp;
 final  List<PiContentDto> _content;
@JsonKey(fromJson: _contentFromJson) List<PiContentDto> get content {
  if (_content is EqualUnmodifiableListView) return _content;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_content);
}

 final  bool display;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of PiSessionFileEntryDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiSessionFileCustomMessageEntryDtoCopyWith<PiSessionFileCustomMessageEntryDto> get copyWith => _$PiSessionFileCustomMessageEntryDtoCopyWithImpl<PiSessionFileCustomMessageEntryDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiSessionFileCustomMessageEntryDto&&(identical(other.id, id) || other.id == id)&&(identical(other.parentId, parentId) || other.parentId == parentId)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&const DeepCollectionEquality().equals(other._content, _content)&&(identical(other.display, display) || other.display == display));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,parentId,timestamp,const DeepCollectionEquality().hash(_content),display);



}

/// @nodoc
abstract mixin class $PiSessionFileCustomMessageEntryDtoCopyWith<$Res> implements $PiSessionFileEntryDtoCopyWith<$Res> {
  factory $PiSessionFileCustomMessageEntryDtoCopyWith(PiSessionFileCustomMessageEntryDto value, $Res Function(PiSessionFileCustomMessageEntryDto) _then) = _$PiSessionFileCustomMessageEntryDtoCopyWithImpl;
@override @useResult
$Res call({
 String? id, String? parentId, DateTime timestamp,@JsonKey(fromJson: _contentFromJson) List<PiContentDto> content, bool display
});




}
/// @nodoc
class _$PiSessionFileCustomMessageEntryDtoCopyWithImpl<$Res>
    implements $PiSessionFileCustomMessageEntryDtoCopyWith<$Res> {
  _$PiSessionFileCustomMessageEntryDtoCopyWithImpl(this._self, this._then);

  final PiSessionFileCustomMessageEntryDto _self;
  final $Res Function(PiSessionFileCustomMessageEntryDto) _then;

/// Create a copy of PiSessionFileEntryDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? parentId = freezed,Object? timestamp = null,Object? content = null,Object? display = null,}) {
  return _then(PiSessionFileCustomMessageEntryDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String?,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,content: null == content ? _self._content : content // ignore: cast_nullable_to_non_nullable
as List<PiContentDto>,display: null == display ? _self.display : display // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class PiSessionFileLabelEntryDto implements PiSessionFileEntryDto {
  const PiSessionFileLabelEntryDto({required this.id, required this.parentId, required this.timestamp,  String? $type}): $type = $type ?? 'label';
  factory PiSessionFileLabelEntryDto.fromJson(Map<String, dynamic> json) => _$PiSessionFileLabelEntryDtoFromJson(json);

@override final  String? id;
@override final  String? parentId;
@override final  DateTime timestamp;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of PiSessionFileEntryDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiSessionFileLabelEntryDtoCopyWith<PiSessionFileLabelEntryDto> get copyWith => _$PiSessionFileLabelEntryDtoCopyWithImpl<PiSessionFileLabelEntryDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiSessionFileLabelEntryDto&&(identical(other.id, id) || other.id == id)&&(identical(other.parentId, parentId) || other.parentId == parentId)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,parentId,timestamp);



}

/// @nodoc
abstract mixin class $PiSessionFileLabelEntryDtoCopyWith<$Res> implements $PiSessionFileEntryDtoCopyWith<$Res> {
  factory $PiSessionFileLabelEntryDtoCopyWith(PiSessionFileLabelEntryDto value, $Res Function(PiSessionFileLabelEntryDto) _then) = _$PiSessionFileLabelEntryDtoCopyWithImpl;
@override @useResult
$Res call({
 String? id, String? parentId, DateTime timestamp
});




}
/// @nodoc
class _$PiSessionFileLabelEntryDtoCopyWithImpl<$Res>
    implements $PiSessionFileLabelEntryDtoCopyWith<$Res> {
  _$PiSessionFileLabelEntryDtoCopyWithImpl(this._self, this._then);

  final PiSessionFileLabelEntryDto _self;
  final $Res Function(PiSessionFileLabelEntryDto) _then;

/// Create a copy of PiSessionFileEntryDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? parentId = freezed,Object? timestamp = null,}) {
  return _then(PiSessionFileLabelEntryDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String?,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class PiSessionFileSessionInfoEntryDto implements PiSessionFileEntryDto {
  const PiSessionFileSessionInfoEntryDto({required this.id, required this.parentId, required this.timestamp,  String? $type}): $type = $type ?? 'session_info';
  factory PiSessionFileSessionInfoEntryDto.fromJson(Map<String, dynamic> json) => _$PiSessionFileSessionInfoEntryDtoFromJson(json);

@override final  String? id;
@override final  String? parentId;
@override final  DateTime timestamp;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of PiSessionFileEntryDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiSessionFileSessionInfoEntryDtoCopyWith<PiSessionFileSessionInfoEntryDto> get copyWith => _$PiSessionFileSessionInfoEntryDtoCopyWithImpl<PiSessionFileSessionInfoEntryDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiSessionFileSessionInfoEntryDto&&(identical(other.id, id) || other.id == id)&&(identical(other.parentId, parentId) || other.parentId == parentId)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,parentId,timestamp);



}

/// @nodoc
abstract mixin class $PiSessionFileSessionInfoEntryDtoCopyWith<$Res> implements $PiSessionFileEntryDtoCopyWith<$Res> {
  factory $PiSessionFileSessionInfoEntryDtoCopyWith(PiSessionFileSessionInfoEntryDto value, $Res Function(PiSessionFileSessionInfoEntryDto) _then) = _$PiSessionFileSessionInfoEntryDtoCopyWithImpl;
@override @useResult
$Res call({
 String? id, String? parentId, DateTime timestamp
});




}
/// @nodoc
class _$PiSessionFileSessionInfoEntryDtoCopyWithImpl<$Res>
    implements $PiSessionFileSessionInfoEntryDtoCopyWith<$Res> {
  _$PiSessionFileSessionInfoEntryDtoCopyWithImpl(this._self, this._then);

  final PiSessionFileSessionInfoEntryDto _self;
  final $Res Function(PiSessionFileSessionInfoEntryDto) _then;

/// Create a copy of PiSessionFileEntryDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? parentId = freezed,Object? timestamp = null,}) {
  return _then(PiSessionFileSessionInfoEntryDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String?,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class PiSessionFileUnknownEntryDto implements PiSessionFileEntryDto {
  const PiSessionFileUnknownEntryDto({required this.id, required this.parentId, required this.timestamp,  String? $type}): $type = $type ?? 'unknown';
  factory PiSessionFileUnknownEntryDto.fromJson(Map<String, dynamic> json) => _$PiSessionFileUnknownEntryDtoFromJson(json);

@override final  String? id;
@override final  String? parentId;
@override final  DateTime timestamp;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of PiSessionFileEntryDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiSessionFileUnknownEntryDtoCopyWith<PiSessionFileUnknownEntryDto> get copyWith => _$PiSessionFileUnknownEntryDtoCopyWithImpl<PiSessionFileUnknownEntryDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiSessionFileUnknownEntryDto&&(identical(other.id, id) || other.id == id)&&(identical(other.parentId, parentId) || other.parentId == parentId)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,parentId,timestamp);



}

/// @nodoc
abstract mixin class $PiSessionFileUnknownEntryDtoCopyWith<$Res> implements $PiSessionFileEntryDtoCopyWith<$Res> {
  factory $PiSessionFileUnknownEntryDtoCopyWith(PiSessionFileUnknownEntryDto value, $Res Function(PiSessionFileUnknownEntryDto) _then) = _$PiSessionFileUnknownEntryDtoCopyWithImpl;
@override @useResult
$Res call({
 String? id, String? parentId, DateTime timestamp
});




}
/// @nodoc
class _$PiSessionFileUnknownEntryDtoCopyWithImpl<$Res>
    implements $PiSessionFileUnknownEntryDtoCopyWith<$Res> {
  _$PiSessionFileUnknownEntryDtoCopyWithImpl(this._self, this._then);

  final PiSessionFileUnknownEntryDto _self;
  final $Res Function(PiSessionFileUnknownEntryDto) _then;

/// Create a copy of PiSessionFileEntryDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? parentId = freezed,Object? timestamp = null,}) {
  return _then(PiSessionFileUnknownEntryDto(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String?,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

PiSessionFileAgentMessageDto _$PiSessionFileAgentMessageDtoFromJson(
  Map<String, dynamic> json
) {
        switch (json['role']) {
                  case 'user':
          return PiSessionFileUserMessageDto.fromJson(
            json
          );
                case 'assistant':
          return PiSessionFileAssistantMessageDto.fromJson(
            json
          );
                case 'toolResult':
          return PiSessionFileToolResultMessageDto.fromJson(
            json
          );
                case 'bashExecution':
          return PiSessionFileBashExecutionMessageDto.fromJson(
            json
          );
                case 'custom':
          return PiSessionFileCustomMessageDto.fromJson(
            json
          );
                case 'hookMessage':
          return PiSessionFileHookMessageDto.fromJson(
            json
          );
                case 'branchSummary':
          return PiSessionFileBranchSummaryMessageDto.fromJson(
            json
          );
                case 'compactionSummary':
          return PiSessionFileCompactionSummaryMessageDto.fromJson(
            json
          );
        
          default:
            return PiSessionFileUnknownMessageDto.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$PiSessionFileAgentMessageDto {

@JsonKey(fromJson: _intOrNull) int? get timestamp;
/// Create a copy of PiSessionFileAgentMessageDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiSessionFileAgentMessageDtoCopyWith<PiSessionFileAgentMessageDto> get copyWith => _$PiSessionFileAgentMessageDtoCopyWithImpl<PiSessionFileAgentMessageDto>(this as PiSessionFileAgentMessageDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiSessionFileAgentMessageDto&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,timestamp);



}

/// @nodoc
abstract mixin class $PiSessionFileAgentMessageDtoCopyWith<$Res>  {
  factory $PiSessionFileAgentMessageDtoCopyWith(PiSessionFileAgentMessageDto value, $Res Function(PiSessionFileAgentMessageDto) _then) = _$PiSessionFileAgentMessageDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _intOrNull) int? timestamp
});




}
/// @nodoc
class _$PiSessionFileAgentMessageDtoCopyWithImpl<$Res>
    implements $PiSessionFileAgentMessageDtoCopyWith<$Res> {
  _$PiSessionFileAgentMessageDtoCopyWithImpl(this._self, this._then);

  final PiSessionFileAgentMessageDto _self;
  final $Res Function(PiSessionFileAgentMessageDto) _then;

/// Create a copy of PiSessionFileAgentMessageDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? timestamp = freezed,}) {
  return _then(_self.copyWith(
timestamp: freezed == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class PiSessionFileUserMessageDto implements PiSessionFileAgentMessageDto {
  const PiSessionFileUserMessageDto({@JsonKey(fromJson: _contentFromJson) required  List<PiContentDto> content, @JsonKey(fromJson: _intOrNull) required this.timestamp,  String? $type}): _content = content,$type = $type ?? 'user';
  factory PiSessionFileUserMessageDto.fromJson(Map<String, dynamic> json) => _$PiSessionFileUserMessageDtoFromJson(json);

 final  List<PiContentDto> _content;
@JsonKey(fromJson: _contentFromJson) List<PiContentDto> get content {
  if (_content is EqualUnmodifiableListView) return _content;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_content);
}

@override@JsonKey(fromJson: _intOrNull) final  int? timestamp;

@JsonKey(name: 'role')
final String $type;


/// Create a copy of PiSessionFileAgentMessageDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiSessionFileUserMessageDtoCopyWith<PiSessionFileUserMessageDto> get copyWith => _$PiSessionFileUserMessageDtoCopyWithImpl<PiSessionFileUserMessageDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiSessionFileUserMessageDto&&const DeepCollectionEquality().equals(other._content, _content)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_content),timestamp);



}

/// @nodoc
abstract mixin class $PiSessionFileUserMessageDtoCopyWith<$Res> implements $PiSessionFileAgentMessageDtoCopyWith<$Res> {
  factory $PiSessionFileUserMessageDtoCopyWith(PiSessionFileUserMessageDto value, $Res Function(PiSessionFileUserMessageDto) _then) = _$PiSessionFileUserMessageDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _contentFromJson) List<PiContentDto> content,@JsonKey(fromJson: _intOrNull) int? timestamp
});




}
/// @nodoc
class _$PiSessionFileUserMessageDtoCopyWithImpl<$Res>
    implements $PiSessionFileUserMessageDtoCopyWith<$Res> {
  _$PiSessionFileUserMessageDtoCopyWithImpl(this._self, this._then);

  final PiSessionFileUserMessageDto _self;
  final $Res Function(PiSessionFileUserMessageDto) _then;

/// Create a copy of PiSessionFileAgentMessageDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? content = null,Object? timestamp = freezed,}) {
  return _then(PiSessionFileUserMessageDto(
content: null == content ? _self._content : content // ignore: cast_nullable_to_non_nullable
as List<PiContentDto>,timestamp: freezed == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class PiSessionFileAssistantMessageDto implements PiSessionFileAgentMessageDto {
  const PiSessionFileAssistantMessageDto({@JsonKey(fromJson: _contentFromJson) required  List<PiContentDto> content, required this.provider, required this.model, @JsonKey(fromJson: _stopReasonOrNull) required this.stopReason, required this.errorMessage, @JsonKey(fromJson: _intOrNull) required this.timestamp,  String? $type}): _content = content,$type = $type ?? 'assistant';
  factory PiSessionFileAssistantMessageDto.fromJson(Map<String, dynamic> json) => _$PiSessionFileAssistantMessageDtoFromJson(json);

 final  List<PiContentDto> _content;
@JsonKey(fromJson: _contentFromJson) List<PiContentDto> get content {
  if (_content is EqualUnmodifiableListView) return _content;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_content);
}

 final  String? provider;
 final  String? model;
@JsonKey(fromJson: _stopReasonOrNull) final  PiAssistantStopReason? stopReason;
 final  String? errorMessage;
@override@JsonKey(fromJson: _intOrNull) final  int? timestamp;

@JsonKey(name: 'role')
final String $type;


/// Create a copy of PiSessionFileAgentMessageDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiSessionFileAssistantMessageDtoCopyWith<PiSessionFileAssistantMessageDto> get copyWith => _$PiSessionFileAssistantMessageDtoCopyWithImpl<PiSessionFileAssistantMessageDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiSessionFileAssistantMessageDto&&const DeepCollectionEquality().equals(other._content, _content)&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.model, model) || other.model == model)&&(identical(other.stopReason, stopReason) || other.stopReason == stopReason)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_content),provider,model,stopReason,errorMessage,timestamp);



}

/// @nodoc
abstract mixin class $PiSessionFileAssistantMessageDtoCopyWith<$Res> implements $PiSessionFileAgentMessageDtoCopyWith<$Res> {
  factory $PiSessionFileAssistantMessageDtoCopyWith(PiSessionFileAssistantMessageDto value, $Res Function(PiSessionFileAssistantMessageDto) _then) = _$PiSessionFileAssistantMessageDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _contentFromJson) List<PiContentDto> content, String? provider, String? model,@JsonKey(fromJson: _stopReasonOrNull) PiAssistantStopReason? stopReason, String? errorMessage,@JsonKey(fromJson: _intOrNull) int? timestamp
});




}
/// @nodoc
class _$PiSessionFileAssistantMessageDtoCopyWithImpl<$Res>
    implements $PiSessionFileAssistantMessageDtoCopyWith<$Res> {
  _$PiSessionFileAssistantMessageDtoCopyWithImpl(this._self, this._then);

  final PiSessionFileAssistantMessageDto _self;
  final $Res Function(PiSessionFileAssistantMessageDto) _then;

/// Create a copy of PiSessionFileAgentMessageDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? content = null,Object? provider = freezed,Object? model = freezed,Object? stopReason = freezed,Object? errorMessage = freezed,Object? timestamp = freezed,}) {
  return _then(PiSessionFileAssistantMessageDto(
content: null == content ? _self._content : content // ignore: cast_nullable_to_non_nullable
as List<PiContentDto>,provider: freezed == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,stopReason: freezed == stopReason ? _self.stopReason : stopReason // ignore: cast_nullable_to_non_nullable
as PiAssistantStopReason?,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,timestamp: freezed == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class PiSessionFileToolResultMessageDto implements PiSessionFileAgentMessageDto {
  const PiSessionFileToolResultMessageDto({required this.toolCallId, required this.toolName, @JsonKey(fromJson: _contentFromJson) required  List<PiContentDto> content, required this.isError, @JsonKey(fromJson: _intOrNull) required this.timestamp,  String? $type}): _content = content,$type = $type ?? 'toolResult';
  factory PiSessionFileToolResultMessageDto.fromJson(Map<String, dynamic> json) => _$PiSessionFileToolResultMessageDtoFromJson(json);

 final  String toolCallId;
 final  String toolName;
 final  List<PiContentDto> _content;
@JsonKey(fromJson: _contentFromJson) List<PiContentDto> get content {
  if (_content is EqualUnmodifiableListView) return _content;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_content);
}

 final  bool isError;
@override@JsonKey(fromJson: _intOrNull) final  int? timestamp;

@JsonKey(name: 'role')
final String $type;


/// Create a copy of PiSessionFileAgentMessageDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiSessionFileToolResultMessageDtoCopyWith<PiSessionFileToolResultMessageDto> get copyWith => _$PiSessionFileToolResultMessageDtoCopyWithImpl<PiSessionFileToolResultMessageDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiSessionFileToolResultMessageDto&&(identical(other.toolCallId, toolCallId) || other.toolCallId == toolCallId)&&(identical(other.toolName, toolName) || other.toolName == toolName)&&const DeepCollectionEquality().equals(other._content, _content)&&(identical(other.isError, isError) || other.isError == isError)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,toolCallId,toolName,const DeepCollectionEquality().hash(_content),isError,timestamp);



}

/// @nodoc
abstract mixin class $PiSessionFileToolResultMessageDtoCopyWith<$Res> implements $PiSessionFileAgentMessageDtoCopyWith<$Res> {
  factory $PiSessionFileToolResultMessageDtoCopyWith(PiSessionFileToolResultMessageDto value, $Res Function(PiSessionFileToolResultMessageDto) _then) = _$PiSessionFileToolResultMessageDtoCopyWithImpl;
@override @useResult
$Res call({
 String toolCallId, String toolName,@JsonKey(fromJson: _contentFromJson) List<PiContentDto> content, bool isError,@JsonKey(fromJson: _intOrNull) int? timestamp
});




}
/// @nodoc
class _$PiSessionFileToolResultMessageDtoCopyWithImpl<$Res>
    implements $PiSessionFileToolResultMessageDtoCopyWith<$Res> {
  _$PiSessionFileToolResultMessageDtoCopyWithImpl(this._self, this._then);

  final PiSessionFileToolResultMessageDto _self;
  final $Res Function(PiSessionFileToolResultMessageDto) _then;

/// Create a copy of PiSessionFileAgentMessageDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? toolCallId = null,Object? toolName = null,Object? content = null,Object? isError = null,Object? timestamp = freezed,}) {
  return _then(PiSessionFileToolResultMessageDto(
toolCallId: null == toolCallId ? _self.toolCallId : toolCallId // ignore: cast_nullable_to_non_nullable
as String,toolName: null == toolName ? _self.toolName : toolName // ignore: cast_nullable_to_non_nullable
as String,content: null == content ? _self._content : content // ignore: cast_nullable_to_non_nullable
as List<PiContentDto>,isError: null == isError ? _self.isError : isError // ignore: cast_nullable_to_non_nullable
as bool,timestamp: freezed == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class PiSessionFileBashExecutionMessageDto implements PiSessionFileAgentMessageDto {
  const PiSessionFileBashExecutionMessageDto({required this.command, required this.output, @JsonKey(fromJson: _intOrNull) required this.exitCode, required this.cancelled, required this.truncated, @JsonKey(fromJson: _intOrNull) required this.timestamp,  String? $type}): $type = $type ?? 'bashExecution';
  factory PiSessionFileBashExecutionMessageDto.fromJson(Map<String, dynamic> json) => _$PiSessionFileBashExecutionMessageDtoFromJson(json);

 final  String command;
 final  String output;
@JsonKey(fromJson: _intOrNull) final  int? exitCode;
 final  bool cancelled;
 final  bool truncated;
@override@JsonKey(fromJson: _intOrNull) final  int? timestamp;

@JsonKey(name: 'role')
final String $type;


/// Create a copy of PiSessionFileAgentMessageDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiSessionFileBashExecutionMessageDtoCopyWith<PiSessionFileBashExecutionMessageDto> get copyWith => _$PiSessionFileBashExecutionMessageDtoCopyWithImpl<PiSessionFileBashExecutionMessageDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiSessionFileBashExecutionMessageDto&&(identical(other.command, command) || other.command == command)&&(identical(other.output, output) || other.output == output)&&(identical(other.exitCode, exitCode) || other.exitCode == exitCode)&&(identical(other.cancelled, cancelled) || other.cancelled == cancelled)&&(identical(other.truncated, truncated) || other.truncated == truncated)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,command,output,exitCode,cancelled,truncated,timestamp);



}

/// @nodoc
abstract mixin class $PiSessionFileBashExecutionMessageDtoCopyWith<$Res> implements $PiSessionFileAgentMessageDtoCopyWith<$Res> {
  factory $PiSessionFileBashExecutionMessageDtoCopyWith(PiSessionFileBashExecutionMessageDto value, $Res Function(PiSessionFileBashExecutionMessageDto) _then) = _$PiSessionFileBashExecutionMessageDtoCopyWithImpl;
@override @useResult
$Res call({
 String command, String output,@JsonKey(fromJson: _intOrNull) int? exitCode, bool cancelled, bool truncated,@JsonKey(fromJson: _intOrNull) int? timestamp
});




}
/// @nodoc
class _$PiSessionFileBashExecutionMessageDtoCopyWithImpl<$Res>
    implements $PiSessionFileBashExecutionMessageDtoCopyWith<$Res> {
  _$PiSessionFileBashExecutionMessageDtoCopyWithImpl(this._self, this._then);

  final PiSessionFileBashExecutionMessageDto _self;
  final $Res Function(PiSessionFileBashExecutionMessageDto) _then;

/// Create a copy of PiSessionFileAgentMessageDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? command = null,Object? output = null,Object? exitCode = freezed,Object? cancelled = null,Object? truncated = null,Object? timestamp = freezed,}) {
  return _then(PiSessionFileBashExecutionMessageDto(
command: null == command ? _self.command : command // ignore: cast_nullable_to_non_nullable
as String,output: null == output ? _self.output : output // ignore: cast_nullable_to_non_nullable
as String,exitCode: freezed == exitCode ? _self.exitCode : exitCode // ignore: cast_nullable_to_non_nullable
as int?,cancelled: null == cancelled ? _self.cancelled : cancelled // ignore: cast_nullable_to_non_nullable
as bool,truncated: null == truncated ? _self.truncated : truncated // ignore: cast_nullable_to_non_nullable
as bool,timestamp: freezed == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class PiSessionFileCustomMessageDto implements PiSessionFileAgentMessageDto {
  const PiSessionFileCustomMessageDto({@JsonKey(fromJson: _contentFromJson) required  List<PiContentDto> content, required this.display, @JsonKey(fromJson: _intOrNull) required this.timestamp,  String? $type}): _content = content,$type = $type ?? 'custom';
  factory PiSessionFileCustomMessageDto.fromJson(Map<String, dynamic> json) => _$PiSessionFileCustomMessageDtoFromJson(json);

 final  List<PiContentDto> _content;
@JsonKey(fromJson: _contentFromJson) List<PiContentDto> get content {
  if (_content is EqualUnmodifiableListView) return _content;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_content);
}

 final  bool display;
@override@JsonKey(fromJson: _intOrNull) final  int? timestamp;

@JsonKey(name: 'role')
final String $type;


/// Create a copy of PiSessionFileAgentMessageDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiSessionFileCustomMessageDtoCopyWith<PiSessionFileCustomMessageDto> get copyWith => _$PiSessionFileCustomMessageDtoCopyWithImpl<PiSessionFileCustomMessageDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiSessionFileCustomMessageDto&&const DeepCollectionEquality().equals(other._content, _content)&&(identical(other.display, display) || other.display == display)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_content),display,timestamp);



}

/// @nodoc
abstract mixin class $PiSessionFileCustomMessageDtoCopyWith<$Res> implements $PiSessionFileAgentMessageDtoCopyWith<$Res> {
  factory $PiSessionFileCustomMessageDtoCopyWith(PiSessionFileCustomMessageDto value, $Res Function(PiSessionFileCustomMessageDto) _then) = _$PiSessionFileCustomMessageDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _contentFromJson) List<PiContentDto> content, bool display,@JsonKey(fromJson: _intOrNull) int? timestamp
});




}
/// @nodoc
class _$PiSessionFileCustomMessageDtoCopyWithImpl<$Res>
    implements $PiSessionFileCustomMessageDtoCopyWith<$Res> {
  _$PiSessionFileCustomMessageDtoCopyWithImpl(this._self, this._then);

  final PiSessionFileCustomMessageDto _self;
  final $Res Function(PiSessionFileCustomMessageDto) _then;

/// Create a copy of PiSessionFileAgentMessageDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? content = null,Object? display = null,Object? timestamp = freezed,}) {
  return _then(PiSessionFileCustomMessageDto(
content: null == content ? _self._content : content // ignore: cast_nullable_to_non_nullable
as List<PiContentDto>,display: null == display ? _self.display : display // ignore: cast_nullable_to_non_nullable
as bool,timestamp: freezed == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class PiSessionFileHookMessageDto implements PiSessionFileAgentMessageDto {
  const PiSessionFileHookMessageDto({@JsonKey(fromJson: _contentFromJson) required  List<PiContentDto> content, required this.display, @JsonKey(fromJson: _intOrNull) required this.timestamp,  String? $type}): _content = content,$type = $type ?? 'hookMessage';
  factory PiSessionFileHookMessageDto.fromJson(Map<String, dynamic> json) => _$PiSessionFileHookMessageDtoFromJson(json);

 final  List<PiContentDto> _content;
@JsonKey(fromJson: _contentFromJson) List<PiContentDto> get content {
  if (_content is EqualUnmodifiableListView) return _content;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_content);
}

 final  bool display;
@override@JsonKey(fromJson: _intOrNull) final  int? timestamp;

@JsonKey(name: 'role')
final String $type;


/// Create a copy of PiSessionFileAgentMessageDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiSessionFileHookMessageDtoCopyWith<PiSessionFileHookMessageDto> get copyWith => _$PiSessionFileHookMessageDtoCopyWithImpl<PiSessionFileHookMessageDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiSessionFileHookMessageDto&&const DeepCollectionEquality().equals(other._content, _content)&&(identical(other.display, display) || other.display == display)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_content),display,timestamp);



}

/// @nodoc
abstract mixin class $PiSessionFileHookMessageDtoCopyWith<$Res> implements $PiSessionFileAgentMessageDtoCopyWith<$Res> {
  factory $PiSessionFileHookMessageDtoCopyWith(PiSessionFileHookMessageDto value, $Res Function(PiSessionFileHookMessageDto) _then) = _$PiSessionFileHookMessageDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _contentFromJson) List<PiContentDto> content, bool display,@JsonKey(fromJson: _intOrNull) int? timestamp
});




}
/// @nodoc
class _$PiSessionFileHookMessageDtoCopyWithImpl<$Res>
    implements $PiSessionFileHookMessageDtoCopyWith<$Res> {
  _$PiSessionFileHookMessageDtoCopyWithImpl(this._self, this._then);

  final PiSessionFileHookMessageDto _self;
  final $Res Function(PiSessionFileHookMessageDto) _then;

/// Create a copy of PiSessionFileAgentMessageDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? content = null,Object? display = null,Object? timestamp = freezed,}) {
  return _then(PiSessionFileHookMessageDto(
content: null == content ? _self._content : content // ignore: cast_nullable_to_non_nullable
as List<PiContentDto>,display: null == display ? _self.display : display // ignore: cast_nullable_to_non_nullable
as bool,timestamp: freezed == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class PiSessionFileBranchSummaryMessageDto implements PiSessionFileAgentMessageDto {
  const PiSessionFileBranchSummaryMessageDto({@JsonKey(fromJson: _intOrNull) required this.timestamp,  String? $type}): $type = $type ?? 'branchSummary';
  factory PiSessionFileBranchSummaryMessageDto.fromJson(Map<String, dynamic> json) => _$PiSessionFileBranchSummaryMessageDtoFromJson(json);

@override@JsonKey(fromJson: _intOrNull) final  int? timestamp;

@JsonKey(name: 'role')
final String $type;


/// Create a copy of PiSessionFileAgentMessageDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiSessionFileBranchSummaryMessageDtoCopyWith<PiSessionFileBranchSummaryMessageDto> get copyWith => _$PiSessionFileBranchSummaryMessageDtoCopyWithImpl<PiSessionFileBranchSummaryMessageDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiSessionFileBranchSummaryMessageDto&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,timestamp);



}

/// @nodoc
abstract mixin class $PiSessionFileBranchSummaryMessageDtoCopyWith<$Res> implements $PiSessionFileAgentMessageDtoCopyWith<$Res> {
  factory $PiSessionFileBranchSummaryMessageDtoCopyWith(PiSessionFileBranchSummaryMessageDto value, $Res Function(PiSessionFileBranchSummaryMessageDto) _then) = _$PiSessionFileBranchSummaryMessageDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _intOrNull) int? timestamp
});




}
/// @nodoc
class _$PiSessionFileBranchSummaryMessageDtoCopyWithImpl<$Res>
    implements $PiSessionFileBranchSummaryMessageDtoCopyWith<$Res> {
  _$PiSessionFileBranchSummaryMessageDtoCopyWithImpl(this._self, this._then);

  final PiSessionFileBranchSummaryMessageDto _self;
  final $Res Function(PiSessionFileBranchSummaryMessageDto) _then;

/// Create a copy of PiSessionFileAgentMessageDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? timestamp = freezed,}) {
  return _then(PiSessionFileBranchSummaryMessageDto(
timestamp: freezed == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class PiSessionFileCompactionSummaryMessageDto implements PiSessionFileAgentMessageDto {
  const PiSessionFileCompactionSummaryMessageDto({@JsonKey(fromJson: _intOrNull) required this.timestamp,  String? $type}): $type = $type ?? 'compactionSummary';
  factory PiSessionFileCompactionSummaryMessageDto.fromJson(Map<String, dynamic> json) => _$PiSessionFileCompactionSummaryMessageDtoFromJson(json);

@override@JsonKey(fromJson: _intOrNull) final  int? timestamp;

@JsonKey(name: 'role')
final String $type;


/// Create a copy of PiSessionFileAgentMessageDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiSessionFileCompactionSummaryMessageDtoCopyWith<PiSessionFileCompactionSummaryMessageDto> get copyWith => _$PiSessionFileCompactionSummaryMessageDtoCopyWithImpl<PiSessionFileCompactionSummaryMessageDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiSessionFileCompactionSummaryMessageDto&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,timestamp);



}

/// @nodoc
abstract mixin class $PiSessionFileCompactionSummaryMessageDtoCopyWith<$Res> implements $PiSessionFileAgentMessageDtoCopyWith<$Res> {
  factory $PiSessionFileCompactionSummaryMessageDtoCopyWith(PiSessionFileCompactionSummaryMessageDto value, $Res Function(PiSessionFileCompactionSummaryMessageDto) _then) = _$PiSessionFileCompactionSummaryMessageDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _intOrNull) int? timestamp
});




}
/// @nodoc
class _$PiSessionFileCompactionSummaryMessageDtoCopyWithImpl<$Res>
    implements $PiSessionFileCompactionSummaryMessageDtoCopyWith<$Res> {
  _$PiSessionFileCompactionSummaryMessageDtoCopyWithImpl(this._self, this._then);

  final PiSessionFileCompactionSummaryMessageDto _self;
  final $Res Function(PiSessionFileCompactionSummaryMessageDto) _then;

/// Create a copy of PiSessionFileAgentMessageDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? timestamp = freezed,}) {
  return _then(PiSessionFileCompactionSummaryMessageDto(
timestamp: freezed == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class PiSessionFileUnknownMessageDto implements PiSessionFileAgentMessageDto {
  const PiSessionFileUnknownMessageDto({@JsonKey(fromJson: _intOrNull) required this.timestamp,  String? $type}): $type = $type ?? 'unknown';
  factory PiSessionFileUnknownMessageDto.fromJson(Map<String, dynamic> json) => _$PiSessionFileUnknownMessageDtoFromJson(json);

@override@JsonKey(fromJson: _intOrNull) final  int? timestamp;

@JsonKey(name: 'role')
final String $type;


/// Create a copy of PiSessionFileAgentMessageDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiSessionFileUnknownMessageDtoCopyWith<PiSessionFileUnknownMessageDto> get copyWith => _$PiSessionFileUnknownMessageDtoCopyWithImpl<PiSessionFileUnknownMessageDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiSessionFileUnknownMessageDto&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,timestamp);



}

/// @nodoc
abstract mixin class $PiSessionFileUnknownMessageDtoCopyWith<$Res> implements $PiSessionFileAgentMessageDtoCopyWith<$Res> {
  factory $PiSessionFileUnknownMessageDtoCopyWith(PiSessionFileUnknownMessageDto value, $Res Function(PiSessionFileUnknownMessageDto) _then) = _$PiSessionFileUnknownMessageDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _intOrNull) int? timestamp
});




}
/// @nodoc
class _$PiSessionFileUnknownMessageDtoCopyWithImpl<$Res>
    implements $PiSessionFileUnknownMessageDtoCopyWith<$Res> {
  _$PiSessionFileUnknownMessageDtoCopyWithImpl(this._self, this._then);

  final PiSessionFileUnknownMessageDto _self;
  final $Res Function(PiSessionFileUnknownMessageDto) _then;

/// Create a copy of PiSessionFileAgentMessageDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? timestamp = freezed,}) {
  return _then(PiSessionFileUnknownMessageDto(
timestamp: freezed == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

PiAgentMessageDto _$PiAgentMessageDtoFromJson(
  Map<String, dynamic> json
) {
        switch (json['role']) {
                  case 'user':
          return PiUserMessageDto.fromJson(
            json
          );
                case 'assistant':
          return PiAssistantMessageDto.fromJson(
            json
          );
                case 'toolResult':
          return PiToolResultMessageDto.fromJson(
            json
          );
                case 'bashExecution':
          return PiBashExecutionMessageDto.fromJson(
            json
          );
                case 'custom':
          return PiCustomMessageDto.fromJson(
            json
          );
                case 'branchSummary':
          return PiBranchSummaryMessageDto.fromJson(
            json
          );
                case 'compactionSummary':
          return PiCompactionSummaryMessageDto.fromJson(
            json
          );
        
          default:
            return PiUnknownMessageDto.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$PiAgentMessageDto {

@JsonKey(fromJson: _intOrNull) int? get timestamp;
/// Create a copy of PiAgentMessageDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiAgentMessageDtoCopyWith<PiAgentMessageDto> get copyWith => _$PiAgentMessageDtoCopyWithImpl<PiAgentMessageDto>(this as PiAgentMessageDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiAgentMessageDto&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,timestamp);



}

/// @nodoc
abstract mixin class $PiAgentMessageDtoCopyWith<$Res>  {
  factory $PiAgentMessageDtoCopyWith(PiAgentMessageDto value, $Res Function(PiAgentMessageDto) _then) = _$PiAgentMessageDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _intOrNull) int? timestamp
});




}
/// @nodoc
class _$PiAgentMessageDtoCopyWithImpl<$Res>
    implements $PiAgentMessageDtoCopyWith<$Res> {
  _$PiAgentMessageDtoCopyWithImpl(this._self, this._then);

  final PiAgentMessageDto _self;
  final $Res Function(PiAgentMessageDto) _then;

/// Create a copy of PiAgentMessageDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? timestamp = freezed,}) {
  return _then(_self.copyWith(
timestamp: freezed == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class PiUserMessageDto implements PiAgentMessageDto {
  const PiUserMessageDto({@JsonKey(fromJson: _contentFromJson) required  List<PiContentDto> content, @JsonKey(fromJson: _intOrNull) required this.timestamp,  String? $type}): _content = content,$type = $type ?? 'user';
  factory PiUserMessageDto.fromJson(Map<String, dynamic> json) => _$PiUserMessageDtoFromJson(json);

 final  List<PiContentDto> _content;
@JsonKey(fromJson: _contentFromJson) List<PiContentDto> get content {
  if (_content is EqualUnmodifiableListView) return _content;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_content);
}

@override@JsonKey(fromJson: _intOrNull) final  int? timestamp;

@JsonKey(name: 'role')
final String $type;


/// Create a copy of PiAgentMessageDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiUserMessageDtoCopyWith<PiUserMessageDto> get copyWith => _$PiUserMessageDtoCopyWithImpl<PiUserMessageDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiUserMessageDto&&const DeepCollectionEquality().equals(other._content, _content)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_content),timestamp);



}

/// @nodoc
abstract mixin class $PiUserMessageDtoCopyWith<$Res> implements $PiAgentMessageDtoCopyWith<$Res> {
  factory $PiUserMessageDtoCopyWith(PiUserMessageDto value, $Res Function(PiUserMessageDto) _then) = _$PiUserMessageDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _contentFromJson) List<PiContentDto> content,@JsonKey(fromJson: _intOrNull) int? timestamp
});




}
/// @nodoc
class _$PiUserMessageDtoCopyWithImpl<$Res>
    implements $PiUserMessageDtoCopyWith<$Res> {
  _$PiUserMessageDtoCopyWithImpl(this._self, this._then);

  final PiUserMessageDto _self;
  final $Res Function(PiUserMessageDto) _then;

/// Create a copy of PiAgentMessageDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? content = null,Object? timestamp = freezed,}) {
  return _then(PiUserMessageDto(
content: null == content ? _self._content : content // ignore: cast_nullable_to_non_nullable
as List<PiContentDto>,timestamp: freezed == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class PiAssistantMessageDto implements PiAgentMessageDto {
  const PiAssistantMessageDto({@JsonKey(fromJson: _contentFromJson) required  List<PiContentDto> content, required this.provider, required this.model, @JsonKey(fromJson: _stopReasonOrNull) required this.stopReason, required this.errorMessage, @JsonKey(fromJson: _intOrNull) required this.timestamp,  String? $type}): _content = content,$type = $type ?? 'assistant';
  factory PiAssistantMessageDto.fromJson(Map<String, dynamic> json) => _$PiAssistantMessageDtoFromJson(json);

 final  List<PiContentDto> _content;
@JsonKey(fromJson: _contentFromJson) List<PiContentDto> get content {
  if (_content is EqualUnmodifiableListView) return _content;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_content);
}

 final  String? provider;
 final  String? model;
@JsonKey(fromJson: _stopReasonOrNull) final  PiAssistantStopReason? stopReason;
 final  String? errorMessage;
@override@JsonKey(fromJson: _intOrNull) final  int? timestamp;

@JsonKey(name: 'role')
final String $type;


/// Create a copy of PiAgentMessageDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiAssistantMessageDtoCopyWith<PiAssistantMessageDto> get copyWith => _$PiAssistantMessageDtoCopyWithImpl<PiAssistantMessageDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiAssistantMessageDto&&const DeepCollectionEquality().equals(other._content, _content)&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.model, model) || other.model == model)&&(identical(other.stopReason, stopReason) || other.stopReason == stopReason)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_content),provider,model,stopReason,errorMessage,timestamp);



}

/// @nodoc
abstract mixin class $PiAssistantMessageDtoCopyWith<$Res> implements $PiAgentMessageDtoCopyWith<$Res> {
  factory $PiAssistantMessageDtoCopyWith(PiAssistantMessageDto value, $Res Function(PiAssistantMessageDto) _then) = _$PiAssistantMessageDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _contentFromJson) List<PiContentDto> content, String? provider, String? model,@JsonKey(fromJson: _stopReasonOrNull) PiAssistantStopReason? stopReason, String? errorMessage,@JsonKey(fromJson: _intOrNull) int? timestamp
});




}
/// @nodoc
class _$PiAssistantMessageDtoCopyWithImpl<$Res>
    implements $PiAssistantMessageDtoCopyWith<$Res> {
  _$PiAssistantMessageDtoCopyWithImpl(this._self, this._then);

  final PiAssistantMessageDto _self;
  final $Res Function(PiAssistantMessageDto) _then;

/// Create a copy of PiAgentMessageDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? content = null,Object? provider = freezed,Object? model = freezed,Object? stopReason = freezed,Object? errorMessage = freezed,Object? timestamp = freezed,}) {
  return _then(PiAssistantMessageDto(
content: null == content ? _self._content : content // ignore: cast_nullable_to_non_nullable
as List<PiContentDto>,provider: freezed == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,stopReason: freezed == stopReason ? _self.stopReason : stopReason // ignore: cast_nullable_to_non_nullable
as PiAssistantStopReason?,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,timestamp: freezed == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class PiToolResultMessageDto implements PiAgentMessageDto {
  const PiToolResultMessageDto({required this.toolCallId, required this.toolName, @JsonKey(fromJson: _contentFromJson) required  List<PiContentDto> content, required this.isError, @JsonKey(fromJson: _intOrNull) required this.timestamp,  String? $type}): _content = content,$type = $type ?? 'toolResult';
  factory PiToolResultMessageDto.fromJson(Map<String, dynamic> json) => _$PiToolResultMessageDtoFromJson(json);

 final  String toolCallId;
 final  String toolName;
 final  List<PiContentDto> _content;
@JsonKey(fromJson: _contentFromJson) List<PiContentDto> get content {
  if (_content is EqualUnmodifiableListView) return _content;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_content);
}

 final  bool isError;
@override@JsonKey(fromJson: _intOrNull) final  int? timestamp;

@JsonKey(name: 'role')
final String $type;


/// Create a copy of PiAgentMessageDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiToolResultMessageDtoCopyWith<PiToolResultMessageDto> get copyWith => _$PiToolResultMessageDtoCopyWithImpl<PiToolResultMessageDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiToolResultMessageDto&&(identical(other.toolCallId, toolCallId) || other.toolCallId == toolCallId)&&(identical(other.toolName, toolName) || other.toolName == toolName)&&const DeepCollectionEquality().equals(other._content, _content)&&(identical(other.isError, isError) || other.isError == isError)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,toolCallId,toolName,const DeepCollectionEquality().hash(_content),isError,timestamp);



}

/// @nodoc
abstract mixin class $PiToolResultMessageDtoCopyWith<$Res> implements $PiAgentMessageDtoCopyWith<$Res> {
  factory $PiToolResultMessageDtoCopyWith(PiToolResultMessageDto value, $Res Function(PiToolResultMessageDto) _then) = _$PiToolResultMessageDtoCopyWithImpl;
@override @useResult
$Res call({
 String toolCallId, String toolName,@JsonKey(fromJson: _contentFromJson) List<PiContentDto> content, bool isError,@JsonKey(fromJson: _intOrNull) int? timestamp
});




}
/// @nodoc
class _$PiToolResultMessageDtoCopyWithImpl<$Res>
    implements $PiToolResultMessageDtoCopyWith<$Res> {
  _$PiToolResultMessageDtoCopyWithImpl(this._self, this._then);

  final PiToolResultMessageDto _self;
  final $Res Function(PiToolResultMessageDto) _then;

/// Create a copy of PiAgentMessageDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? toolCallId = null,Object? toolName = null,Object? content = null,Object? isError = null,Object? timestamp = freezed,}) {
  return _then(PiToolResultMessageDto(
toolCallId: null == toolCallId ? _self.toolCallId : toolCallId // ignore: cast_nullable_to_non_nullable
as String,toolName: null == toolName ? _self.toolName : toolName // ignore: cast_nullable_to_non_nullable
as String,content: null == content ? _self._content : content // ignore: cast_nullable_to_non_nullable
as List<PiContentDto>,isError: null == isError ? _self.isError : isError // ignore: cast_nullable_to_non_nullable
as bool,timestamp: freezed == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class PiBashExecutionMessageDto implements PiAgentMessageDto {
  const PiBashExecutionMessageDto({required this.command, required this.output, @JsonKey(fromJson: _intOrNull) required this.exitCode, required this.cancelled, required this.truncated, @JsonKey(fromJson: _intOrNull) required this.timestamp,  String? $type}): $type = $type ?? 'bashExecution';
  factory PiBashExecutionMessageDto.fromJson(Map<String, dynamic> json) => _$PiBashExecutionMessageDtoFromJson(json);

 final  String command;
 final  String output;
@JsonKey(fromJson: _intOrNull) final  int? exitCode;
 final  bool cancelled;
 final  bool truncated;
@override@JsonKey(fromJson: _intOrNull) final  int? timestamp;

@JsonKey(name: 'role')
final String $type;


/// Create a copy of PiAgentMessageDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiBashExecutionMessageDtoCopyWith<PiBashExecutionMessageDto> get copyWith => _$PiBashExecutionMessageDtoCopyWithImpl<PiBashExecutionMessageDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiBashExecutionMessageDto&&(identical(other.command, command) || other.command == command)&&(identical(other.output, output) || other.output == output)&&(identical(other.exitCode, exitCode) || other.exitCode == exitCode)&&(identical(other.cancelled, cancelled) || other.cancelled == cancelled)&&(identical(other.truncated, truncated) || other.truncated == truncated)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,command,output,exitCode,cancelled,truncated,timestamp);



}

/// @nodoc
abstract mixin class $PiBashExecutionMessageDtoCopyWith<$Res> implements $PiAgentMessageDtoCopyWith<$Res> {
  factory $PiBashExecutionMessageDtoCopyWith(PiBashExecutionMessageDto value, $Res Function(PiBashExecutionMessageDto) _then) = _$PiBashExecutionMessageDtoCopyWithImpl;
@override @useResult
$Res call({
 String command, String output,@JsonKey(fromJson: _intOrNull) int? exitCode, bool cancelled, bool truncated,@JsonKey(fromJson: _intOrNull) int? timestamp
});




}
/// @nodoc
class _$PiBashExecutionMessageDtoCopyWithImpl<$Res>
    implements $PiBashExecutionMessageDtoCopyWith<$Res> {
  _$PiBashExecutionMessageDtoCopyWithImpl(this._self, this._then);

  final PiBashExecutionMessageDto _self;
  final $Res Function(PiBashExecutionMessageDto) _then;

/// Create a copy of PiAgentMessageDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? command = null,Object? output = null,Object? exitCode = freezed,Object? cancelled = null,Object? truncated = null,Object? timestamp = freezed,}) {
  return _then(PiBashExecutionMessageDto(
command: null == command ? _self.command : command // ignore: cast_nullable_to_non_nullable
as String,output: null == output ? _self.output : output // ignore: cast_nullable_to_non_nullable
as String,exitCode: freezed == exitCode ? _self.exitCode : exitCode // ignore: cast_nullable_to_non_nullable
as int?,cancelled: null == cancelled ? _self.cancelled : cancelled // ignore: cast_nullable_to_non_nullable
as bool,truncated: null == truncated ? _self.truncated : truncated // ignore: cast_nullable_to_non_nullable
as bool,timestamp: freezed == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class PiCustomMessageDto implements PiAgentMessageDto {
  const PiCustomMessageDto({@JsonKey(fromJson: _contentFromJson) required  List<PiContentDto> content, required this.display, @JsonKey(fromJson: _intOrNull) required this.timestamp,  String? $type}): _content = content,$type = $type ?? 'custom';
  factory PiCustomMessageDto.fromJson(Map<String, dynamic> json) => _$PiCustomMessageDtoFromJson(json);

 final  List<PiContentDto> _content;
@JsonKey(fromJson: _contentFromJson) List<PiContentDto> get content {
  if (_content is EqualUnmodifiableListView) return _content;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_content);
}

 final  bool display;
@override@JsonKey(fromJson: _intOrNull) final  int? timestamp;

@JsonKey(name: 'role')
final String $type;


/// Create a copy of PiAgentMessageDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiCustomMessageDtoCopyWith<PiCustomMessageDto> get copyWith => _$PiCustomMessageDtoCopyWithImpl<PiCustomMessageDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiCustomMessageDto&&const DeepCollectionEquality().equals(other._content, _content)&&(identical(other.display, display) || other.display == display)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_content),display,timestamp);



}

/// @nodoc
abstract mixin class $PiCustomMessageDtoCopyWith<$Res> implements $PiAgentMessageDtoCopyWith<$Res> {
  factory $PiCustomMessageDtoCopyWith(PiCustomMessageDto value, $Res Function(PiCustomMessageDto) _then) = _$PiCustomMessageDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _contentFromJson) List<PiContentDto> content, bool display,@JsonKey(fromJson: _intOrNull) int? timestamp
});




}
/// @nodoc
class _$PiCustomMessageDtoCopyWithImpl<$Res>
    implements $PiCustomMessageDtoCopyWith<$Res> {
  _$PiCustomMessageDtoCopyWithImpl(this._self, this._then);

  final PiCustomMessageDto _self;
  final $Res Function(PiCustomMessageDto) _then;

/// Create a copy of PiAgentMessageDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? content = null,Object? display = null,Object? timestamp = freezed,}) {
  return _then(PiCustomMessageDto(
content: null == content ? _self._content : content // ignore: cast_nullable_to_non_nullable
as List<PiContentDto>,display: null == display ? _self.display : display // ignore: cast_nullable_to_non_nullable
as bool,timestamp: freezed == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class PiBranchSummaryMessageDto implements PiAgentMessageDto {
  const PiBranchSummaryMessageDto({@JsonKey(fromJson: _intOrNull) required this.timestamp,  String? $type}): $type = $type ?? 'branchSummary';
  factory PiBranchSummaryMessageDto.fromJson(Map<String, dynamic> json) => _$PiBranchSummaryMessageDtoFromJson(json);

@override@JsonKey(fromJson: _intOrNull) final  int? timestamp;

@JsonKey(name: 'role')
final String $type;


/// Create a copy of PiAgentMessageDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiBranchSummaryMessageDtoCopyWith<PiBranchSummaryMessageDto> get copyWith => _$PiBranchSummaryMessageDtoCopyWithImpl<PiBranchSummaryMessageDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiBranchSummaryMessageDto&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,timestamp);



}

/// @nodoc
abstract mixin class $PiBranchSummaryMessageDtoCopyWith<$Res> implements $PiAgentMessageDtoCopyWith<$Res> {
  factory $PiBranchSummaryMessageDtoCopyWith(PiBranchSummaryMessageDto value, $Res Function(PiBranchSummaryMessageDto) _then) = _$PiBranchSummaryMessageDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _intOrNull) int? timestamp
});




}
/// @nodoc
class _$PiBranchSummaryMessageDtoCopyWithImpl<$Res>
    implements $PiBranchSummaryMessageDtoCopyWith<$Res> {
  _$PiBranchSummaryMessageDtoCopyWithImpl(this._self, this._then);

  final PiBranchSummaryMessageDto _self;
  final $Res Function(PiBranchSummaryMessageDto) _then;

/// Create a copy of PiAgentMessageDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? timestamp = freezed,}) {
  return _then(PiBranchSummaryMessageDto(
timestamp: freezed == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class PiCompactionSummaryMessageDto implements PiAgentMessageDto {
  const PiCompactionSummaryMessageDto({@JsonKey(fromJson: _intOrNull) required this.timestamp,  String? $type}): $type = $type ?? 'compactionSummary';
  factory PiCompactionSummaryMessageDto.fromJson(Map<String, dynamic> json) => _$PiCompactionSummaryMessageDtoFromJson(json);

@override@JsonKey(fromJson: _intOrNull) final  int? timestamp;

@JsonKey(name: 'role')
final String $type;


/// Create a copy of PiAgentMessageDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiCompactionSummaryMessageDtoCopyWith<PiCompactionSummaryMessageDto> get copyWith => _$PiCompactionSummaryMessageDtoCopyWithImpl<PiCompactionSummaryMessageDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiCompactionSummaryMessageDto&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,timestamp);



}

/// @nodoc
abstract mixin class $PiCompactionSummaryMessageDtoCopyWith<$Res> implements $PiAgentMessageDtoCopyWith<$Res> {
  factory $PiCompactionSummaryMessageDtoCopyWith(PiCompactionSummaryMessageDto value, $Res Function(PiCompactionSummaryMessageDto) _then) = _$PiCompactionSummaryMessageDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _intOrNull) int? timestamp
});




}
/// @nodoc
class _$PiCompactionSummaryMessageDtoCopyWithImpl<$Res>
    implements $PiCompactionSummaryMessageDtoCopyWith<$Res> {
  _$PiCompactionSummaryMessageDtoCopyWithImpl(this._self, this._then);

  final PiCompactionSummaryMessageDto _self;
  final $Res Function(PiCompactionSummaryMessageDto) _then;

/// Create a copy of PiAgentMessageDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? timestamp = freezed,}) {
  return _then(PiCompactionSummaryMessageDto(
timestamp: freezed == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class PiUnknownMessageDto implements PiAgentMessageDto {
  const PiUnknownMessageDto({@JsonKey(fromJson: _intOrNull) required this.timestamp,  String? $type}): $type = $type ?? 'unknown';
  factory PiUnknownMessageDto.fromJson(Map<String, dynamic> json) => _$PiUnknownMessageDtoFromJson(json);

@override@JsonKey(fromJson: _intOrNull) final  int? timestamp;

@JsonKey(name: 'role')
final String $type;


/// Create a copy of PiAgentMessageDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiUnknownMessageDtoCopyWith<PiUnknownMessageDto> get copyWith => _$PiUnknownMessageDtoCopyWithImpl<PiUnknownMessageDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiUnknownMessageDto&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,timestamp);



}

/// @nodoc
abstract mixin class $PiUnknownMessageDtoCopyWith<$Res> implements $PiAgentMessageDtoCopyWith<$Res> {
  factory $PiUnknownMessageDtoCopyWith(PiUnknownMessageDto value, $Res Function(PiUnknownMessageDto) _then) = _$PiUnknownMessageDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _intOrNull) int? timestamp
});




}
/// @nodoc
class _$PiUnknownMessageDtoCopyWithImpl<$Res>
    implements $PiUnknownMessageDtoCopyWith<$Res> {
  _$PiUnknownMessageDtoCopyWithImpl(this._self, this._then);

  final PiUnknownMessageDto _self;
  final $Res Function(PiUnknownMessageDto) _then;

/// Create a copy of PiAgentMessageDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? timestamp = freezed,}) {
  return _then(PiUnknownMessageDto(
timestamp: freezed == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

PiContentDto _$PiContentDtoFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'text':
          return PiTextContentDto.fromJson(
            json
          );
                case 'image':
          return PiImageContentDto.fromJson(
            json
          );
                case 'thinking':
          return PiThinkingContentDto.fromJson(
            json
          );
                case 'toolCall':
          return PiToolCallContentDto.fromJson(
            json
          );
        
          default:
            return PiUnknownContentDto.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$PiContentDto {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiContentDto);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;



}

/// @nodoc
class $PiContentDtoCopyWith<$Res>  {
$PiContentDtoCopyWith(PiContentDto _, $Res Function(PiContentDto) __);
}



/// @nodoc
@JsonSerializable(createToJson: false)

class PiTextContentDto implements PiContentDto {
  const PiTextContentDto({required this.text,  String? $type}): $type = $type ?? 'text';
  factory PiTextContentDto.fromJson(Map<String, dynamic> json) => _$PiTextContentDtoFromJson(json);

 final  String text;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of PiContentDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiTextContentDtoCopyWith<PiTextContentDto> get copyWith => _$PiTextContentDtoCopyWithImpl<PiTextContentDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiTextContentDto&&(identical(other.text, text) || other.text == text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,text);



}

/// @nodoc
abstract mixin class $PiTextContentDtoCopyWith<$Res> implements $PiContentDtoCopyWith<$Res> {
  factory $PiTextContentDtoCopyWith(PiTextContentDto value, $Res Function(PiTextContentDto) _then) = _$PiTextContentDtoCopyWithImpl;
@useResult
$Res call({
 String text
});




}
/// @nodoc
class _$PiTextContentDtoCopyWithImpl<$Res>
    implements $PiTextContentDtoCopyWith<$Res> {
  _$PiTextContentDtoCopyWithImpl(this._self, this._then);

  final PiTextContentDto _self;
  final $Res Function(PiTextContentDto) _then;

/// Create a copy of PiContentDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? text = null,}) {
  return _then(PiTextContentDto(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class PiImageContentDto implements PiContentDto {
  const PiImageContentDto({required this.data, required this.mimeType,  String? $type}): $type = $type ?? 'image';
  factory PiImageContentDto.fromJson(Map<String, dynamic> json) => _$PiImageContentDtoFromJson(json);

 final  String data;
 final  String mimeType;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of PiContentDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiImageContentDtoCopyWith<PiImageContentDto> get copyWith => _$PiImageContentDtoCopyWithImpl<PiImageContentDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiImageContentDto&&(identical(other.data, data) || other.data == data)&&(identical(other.mimeType, mimeType) || other.mimeType == mimeType));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data,mimeType);



}

/// @nodoc
abstract mixin class $PiImageContentDtoCopyWith<$Res> implements $PiContentDtoCopyWith<$Res> {
  factory $PiImageContentDtoCopyWith(PiImageContentDto value, $Res Function(PiImageContentDto) _then) = _$PiImageContentDtoCopyWithImpl;
@useResult
$Res call({
 String data, String mimeType
});




}
/// @nodoc
class _$PiImageContentDtoCopyWithImpl<$Res>
    implements $PiImageContentDtoCopyWith<$Res> {
  _$PiImageContentDtoCopyWithImpl(this._self, this._then);

  final PiImageContentDto _self;
  final $Res Function(PiImageContentDto) _then;

/// Create a copy of PiContentDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? data = null,Object? mimeType = null,}) {
  return _then(PiImageContentDto(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as String,mimeType: null == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class PiThinkingContentDto implements PiContentDto {
  const PiThinkingContentDto({required this.thinking, required this.redacted,  String? $type}): $type = $type ?? 'thinking';
  factory PiThinkingContentDto.fromJson(Map<String, dynamic> json) => _$PiThinkingContentDtoFromJson(json);

 final  String thinking;
 final  bool? redacted;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of PiContentDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiThinkingContentDtoCopyWith<PiThinkingContentDto> get copyWith => _$PiThinkingContentDtoCopyWithImpl<PiThinkingContentDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiThinkingContentDto&&(identical(other.thinking, thinking) || other.thinking == thinking)&&(identical(other.redacted, redacted) || other.redacted == redacted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,thinking,redacted);



}

/// @nodoc
abstract mixin class $PiThinkingContentDtoCopyWith<$Res> implements $PiContentDtoCopyWith<$Res> {
  factory $PiThinkingContentDtoCopyWith(PiThinkingContentDto value, $Res Function(PiThinkingContentDto) _then) = _$PiThinkingContentDtoCopyWithImpl;
@useResult
$Res call({
 String thinking, bool? redacted
});




}
/// @nodoc
class _$PiThinkingContentDtoCopyWithImpl<$Res>
    implements $PiThinkingContentDtoCopyWith<$Res> {
  _$PiThinkingContentDtoCopyWithImpl(this._self, this._then);

  final PiThinkingContentDto _self;
  final $Res Function(PiThinkingContentDto) _then;

/// Create a copy of PiContentDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? thinking = null,Object? redacted = freezed,}) {
  return _then(PiThinkingContentDto(
thinking: null == thinking ? _self.thinking : thinking // ignore: cast_nullable_to_non_nullable
as String,redacted: freezed == redacted ? _self.redacted : redacted // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class PiToolCallContentDto implements PiContentDto {
  const PiToolCallContentDto({required this.id, required this.name, required this.arguments,  String? $type}): $type = $type ?? 'toolCall';
  factory PiToolCallContentDto.fromJson(Map<String, dynamic> json) => _$PiToolCallContentDtoFromJson(json);

 final  String id;
 final  String name;
 final  Object? arguments;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of PiContentDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PiToolCallContentDtoCopyWith<PiToolCallContentDto> get copyWith => _$PiToolCallContentDtoCopyWithImpl<PiToolCallContentDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiToolCallContentDto&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other.arguments, arguments));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,const DeepCollectionEquality().hash(arguments));



}

/// @nodoc
abstract mixin class $PiToolCallContentDtoCopyWith<$Res> implements $PiContentDtoCopyWith<$Res> {
  factory $PiToolCallContentDtoCopyWith(PiToolCallContentDto value, $Res Function(PiToolCallContentDto) _then) = _$PiToolCallContentDtoCopyWithImpl;
@useResult
$Res call({
 String id, String name, Object? arguments
});




}
/// @nodoc
class _$PiToolCallContentDtoCopyWithImpl<$Res>
    implements $PiToolCallContentDtoCopyWith<$Res> {
  _$PiToolCallContentDtoCopyWithImpl(this._self, this._then);

  final PiToolCallContentDto _self;
  final $Res Function(PiToolCallContentDto) _then;

/// Create a copy of PiContentDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? arguments = freezed,}) {
  return _then(PiToolCallContentDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,arguments: freezed == arguments ? _self.arguments : arguments ,
  ));
}


}

/// @nodoc
@JsonSerializable(createToJson: false)

class PiUnknownContentDto implements PiContentDto {
  const PiUnknownContentDto({ String? $type}): $type = $type ?? 'unknown';
  factory PiUnknownContentDto.fromJson(Map<String, dynamic> json) => _$PiUnknownContentDtoFromJson(json);



@JsonKey(name: 'type')
final String $type;





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PiUnknownContentDto);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;



}




// dart format on
