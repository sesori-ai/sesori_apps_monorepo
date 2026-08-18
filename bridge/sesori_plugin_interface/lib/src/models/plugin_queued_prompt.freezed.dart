// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plugin_queued_prompt.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PluginQueuedPrompt {

/// The prompt id handed to `sendPrompt`/`sendCommand`.
 String get id;/// User-visible prompt text. Null for an attachment-only prompt — never
/// an empty string.
 String? get text;/// Bare slash-command name for a command send, without the leading `/`.
/// Null for a plain prompt.
 String? get command;/// Number of file attachments carried by the prompt.
 int get attachmentCount;/// Acceptance time in milliseconds since the Unix epoch.
 int get createdAt;
/// Create a copy of PluginQueuedPrompt
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginQueuedPromptCopyWith<PluginQueuedPrompt> get copyWith => _$PluginQueuedPromptCopyWithImpl<PluginQueuedPrompt>(this as PluginQueuedPrompt, _$identity);

  /// Serializes this PluginQueuedPrompt to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginQueuedPrompt&&(identical(other.id, id) || other.id == id)&&(identical(other.text, text) || other.text == text)&&(identical(other.command, command) || other.command == command)&&(identical(other.attachmentCount, attachmentCount) || other.attachmentCount == attachmentCount)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,text,command,attachmentCount,createdAt);

@override
String toString() {
  return 'PluginQueuedPrompt(id: $id, text: $text, command: $command, attachmentCount: $attachmentCount, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $PluginQueuedPromptCopyWith<$Res>  {
  factory $PluginQueuedPromptCopyWith(PluginQueuedPrompt value, $Res Function(PluginQueuedPrompt) _then) = _$PluginQueuedPromptCopyWithImpl;
@useResult
$Res call({
 String id, String? text, String? command, int attachmentCount, int createdAt
});




}
/// @nodoc
class _$PluginQueuedPromptCopyWithImpl<$Res>
    implements $PluginQueuedPromptCopyWith<$Res> {
  _$PluginQueuedPromptCopyWithImpl(this._self, this._then);

  final PluginQueuedPrompt _self;
  final $Res Function(PluginQueuedPrompt) _then;

/// Create a copy of PluginQueuedPrompt
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? text = freezed,Object? command = freezed,Object? attachmentCount = null,Object? createdAt = null,}) {
  return _then(PluginQueuedPrompt(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,text: freezed == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String?,command: freezed == command ? _self.command : command // ignore: cast_nullable_to_non_nullable
as String?,attachmentCount: null == attachmentCount ? _self.attachmentCount : attachmentCount // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}



/// @nodoc
@JsonSerializable(createFactory: false)

class _PluginQueuedPrompt implements PluginQueuedPrompt {
  const _PluginQueuedPrompt({required this.id, required this.text, required this.command, required this.attachmentCount, required this.createdAt});
  

/// The prompt id handed to `sendPrompt`/`sendCommand`.
@override final  String id;
/// User-visible prompt text. Null for an attachment-only prompt — never
/// an empty string.
@override final  String? text;
/// Bare slash-command name for a command send, without the leading `/`.
/// Null for a plain prompt.
@override final  String? command;
/// Number of file attachments carried by the prompt.
@override final  int attachmentCount;
/// Acceptance time in milliseconds since the Unix epoch.
@override final  int createdAt;

/// Create a copy of PluginQueuedPrompt
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginQueuedPromptCopyWith<_PluginQueuedPrompt> get copyWith => __$PluginQueuedPromptCopyWithImpl<_PluginQueuedPrompt>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginQueuedPromptToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginQueuedPrompt&&(identical(other.id, id) || other.id == id)&&(identical(other.text, text) || other.text == text)&&(identical(other.command, command) || other.command == command)&&(identical(other.attachmentCount, attachmentCount) || other.attachmentCount == attachmentCount)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,text,command,attachmentCount,createdAt);

@override
String toString() {
  return 'PluginQueuedPrompt(id: $id, text: $text, command: $command, attachmentCount: $attachmentCount, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$PluginQueuedPromptCopyWith<$Res> implements $PluginQueuedPromptCopyWith<$Res> {
  factory _$PluginQueuedPromptCopyWith(_PluginQueuedPrompt value, $Res Function(_PluginQueuedPrompt) _then) = __$PluginQueuedPromptCopyWithImpl;
@override @useResult
$Res call({
 String id, String? text, String? command, int attachmentCount, int createdAt
});




}
/// @nodoc
class __$PluginQueuedPromptCopyWithImpl<$Res>
    implements _$PluginQueuedPromptCopyWith<$Res> {
  __$PluginQueuedPromptCopyWithImpl(this._self, this._then);

  final _PluginQueuedPrompt _self;
  final $Res Function(_PluginQueuedPrompt) _then;

/// Create a copy of PluginQueuedPrompt
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? text = freezed,Object? command = freezed,Object? attachmentCount = null,Object? createdAt = null,}) {
  return _then(_PluginQueuedPrompt(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,text: freezed == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String?,command: freezed == command ? _self.command : command // ignore: cast_nullable_to_non_nullable
as String?,attachmentCount: null == attachmentCount ? _self.attachmentCount : attachmentCount // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
