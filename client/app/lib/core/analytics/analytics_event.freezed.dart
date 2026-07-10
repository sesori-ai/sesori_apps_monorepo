// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'analytics_event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
AnalyticsEvent _$AnalyticsEventFromJson(
  Map<String, dynamic> json
) {
        switch (json['event_name']) {
                  case 'onboarding_need_help_opened':
          return NeedHelpMenuOpened.fromJson(
            json
          );
                case 'onboarding_support_link_opened':
          return SupportLinkOpened.fromJson(
            json
          );
                case 'onboarding_why_bridge_opened':
          return WhyBridgeOpened.fromJson(
            json
          );
                case 'bridge_install_command_copied':
          return InstallCommandCopied.fromJson(
            json
          );
                case 'bridge_install_command_shared':
          return InstallCommandShared.fromJson(
            json
          );
                case 'bridge_run_command_copied':
          return RunCommandCopied.fromJson(
            json
          );
                case 'bridge_run_command_shared':
          return RunCommandShared.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'event_name',
  'AnalyticsEvent',
  'Invalid union type "${json['event_name']}"!'
);
        }
      
}

/// @nodoc
mixin _$AnalyticsEvent {

 OnboardingSurface get surface;
/// Create a copy of AnalyticsEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AnalyticsEventCopyWith<AnalyticsEvent> get copyWith => _$AnalyticsEventCopyWithImpl<AnalyticsEvent>(this as AnalyticsEvent, _$identity);

  /// Serializes this AnalyticsEvent to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AnalyticsEvent&&(identical(other.surface, surface) || other.surface == surface));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,surface);

@override
String toString() {
  return 'AnalyticsEvent(surface: $surface)';
}


}

/// @nodoc
abstract mixin class $AnalyticsEventCopyWith<$Res>  {
  factory $AnalyticsEventCopyWith(AnalyticsEvent value, $Res Function(AnalyticsEvent) _then) = _$AnalyticsEventCopyWithImpl;
@useResult
$Res call({
 OnboardingSurface surface
});




}
/// @nodoc
class _$AnalyticsEventCopyWithImpl<$Res>
    implements $AnalyticsEventCopyWith<$Res> {
  _$AnalyticsEventCopyWithImpl(this._self, this._then);

  final AnalyticsEvent _self;
  final $Res Function(AnalyticsEvent) _then;

/// Create a copy of AnalyticsEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? surface = null,}) {
  return _then(_self.copyWith(
surface: null == surface ? _self.surface : surface // ignore: cast_nullable_to_non_nullable
as OnboardingSurface,
  ));
}

}



/// @nodoc
@JsonSerializable()

class NeedHelpMenuOpened implements AnalyticsEvent {
  const NeedHelpMenuOpened({required this.surface, final  String? $type}): $type = $type ?? 'onboarding_need_help_opened';
  factory NeedHelpMenuOpened.fromJson(Map<String, dynamic> json) => _$NeedHelpMenuOpenedFromJson(json);

@override final  OnboardingSurface surface;

@JsonKey(name: 'event_name')
final String $type;


/// Create a copy of AnalyticsEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NeedHelpMenuOpenedCopyWith<NeedHelpMenuOpened> get copyWith => _$NeedHelpMenuOpenedCopyWithImpl<NeedHelpMenuOpened>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NeedHelpMenuOpenedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NeedHelpMenuOpened&&(identical(other.surface, surface) || other.surface == surface));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,surface);

@override
String toString() {
  return 'AnalyticsEvent.needHelpMenuOpened(surface: $surface)';
}


}

/// @nodoc
abstract mixin class $NeedHelpMenuOpenedCopyWith<$Res> implements $AnalyticsEventCopyWith<$Res> {
  factory $NeedHelpMenuOpenedCopyWith(NeedHelpMenuOpened value, $Res Function(NeedHelpMenuOpened) _then) = _$NeedHelpMenuOpenedCopyWithImpl;
@override @useResult
$Res call({
 OnboardingSurface surface
});




}
/// @nodoc
class _$NeedHelpMenuOpenedCopyWithImpl<$Res>
    implements $NeedHelpMenuOpenedCopyWith<$Res> {
  _$NeedHelpMenuOpenedCopyWithImpl(this._self, this._then);

  final NeedHelpMenuOpened _self;
  final $Res Function(NeedHelpMenuOpened) _then;

/// Create a copy of AnalyticsEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? surface = null,}) {
  return _then(NeedHelpMenuOpened(
surface: null == surface ? _self.surface : surface // ignore: cast_nullable_to_non_nullable
as OnboardingSurface,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SupportLinkOpened implements AnalyticsEvent {
  const SupportLinkOpened({required this.channel, required this.surface, final  String? $type}): $type = $type ?? 'onboarding_support_link_opened';
  factory SupportLinkOpened.fromJson(Map<String, dynamic> json) => _$SupportLinkOpenedFromJson(json);

 final  SupportChannel channel;
@override final  OnboardingSurface surface;

@JsonKey(name: 'event_name')
final String $type;


/// Create a copy of AnalyticsEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SupportLinkOpenedCopyWith<SupportLinkOpened> get copyWith => _$SupportLinkOpenedCopyWithImpl<SupportLinkOpened>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SupportLinkOpenedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SupportLinkOpened&&(identical(other.channel, channel) || other.channel == channel)&&(identical(other.surface, surface) || other.surface == surface));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,channel,surface);

@override
String toString() {
  return 'AnalyticsEvent.supportLinkOpened(channel: $channel, surface: $surface)';
}


}

/// @nodoc
abstract mixin class $SupportLinkOpenedCopyWith<$Res> implements $AnalyticsEventCopyWith<$Res> {
  factory $SupportLinkOpenedCopyWith(SupportLinkOpened value, $Res Function(SupportLinkOpened) _then) = _$SupportLinkOpenedCopyWithImpl;
@override @useResult
$Res call({
 SupportChannel channel, OnboardingSurface surface
});




}
/// @nodoc
class _$SupportLinkOpenedCopyWithImpl<$Res>
    implements $SupportLinkOpenedCopyWith<$Res> {
  _$SupportLinkOpenedCopyWithImpl(this._self, this._then);

  final SupportLinkOpened _self;
  final $Res Function(SupportLinkOpened) _then;

/// Create a copy of AnalyticsEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? channel = null,Object? surface = null,}) {
  return _then(SupportLinkOpened(
channel: null == channel ? _self.channel : channel // ignore: cast_nullable_to_non_nullable
as SupportChannel,surface: null == surface ? _self.surface : surface // ignore: cast_nullable_to_non_nullable
as OnboardingSurface,
  ));
}


}

/// @nodoc
@JsonSerializable()

class WhyBridgeOpened implements AnalyticsEvent {
  const WhyBridgeOpened({required this.surface, final  String? $type}): $type = $type ?? 'onboarding_why_bridge_opened';
  factory WhyBridgeOpened.fromJson(Map<String, dynamic> json) => _$WhyBridgeOpenedFromJson(json);

@override final  OnboardingSurface surface;

@JsonKey(name: 'event_name')
final String $type;


/// Create a copy of AnalyticsEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WhyBridgeOpenedCopyWith<WhyBridgeOpened> get copyWith => _$WhyBridgeOpenedCopyWithImpl<WhyBridgeOpened>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WhyBridgeOpenedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WhyBridgeOpened&&(identical(other.surface, surface) || other.surface == surface));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,surface);

@override
String toString() {
  return 'AnalyticsEvent.whyBridgeOpened(surface: $surface)';
}


}

/// @nodoc
abstract mixin class $WhyBridgeOpenedCopyWith<$Res> implements $AnalyticsEventCopyWith<$Res> {
  factory $WhyBridgeOpenedCopyWith(WhyBridgeOpened value, $Res Function(WhyBridgeOpened) _then) = _$WhyBridgeOpenedCopyWithImpl;
@override @useResult
$Res call({
 OnboardingSurface surface
});




}
/// @nodoc
class _$WhyBridgeOpenedCopyWithImpl<$Res>
    implements $WhyBridgeOpenedCopyWith<$Res> {
  _$WhyBridgeOpenedCopyWithImpl(this._self, this._then);

  final WhyBridgeOpened _self;
  final $Res Function(WhyBridgeOpened) _then;

/// Create a copy of AnalyticsEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? surface = null,}) {
  return _then(WhyBridgeOpened(
surface: null == surface ? _self.surface : surface // ignore: cast_nullable_to_non_nullable
as OnboardingSurface,
  ));
}


}

/// @nodoc
@JsonSerializable()

class InstallCommandCopied implements AnalyticsEvent {
  const InstallCommandCopied({required this.method, required this.os, required this.surface, final  String? $type}): $type = $type ?? 'bridge_install_command_copied';
  factory InstallCommandCopied.fromJson(Map<String, dynamic> json) => _$InstallCommandCopiedFromJson(json);

 final  BridgeInstallMethod method;
 final  BridgeInstallOs os;
@override final  OnboardingSurface surface;

@JsonKey(name: 'event_name')
final String $type;


/// Create a copy of AnalyticsEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InstallCommandCopiedCopyWith<InstallCommandCopied> get copyWith => _$InstallCommandCopiedCopyWithImpl<InstallCommandCopied>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$InstallCommandCopiedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InstallCommandCopied&&(identical(other.method, method) || other.method == method)&&(identical(other.os, os) || other.os == os)&&(identical(other.surface, surface) || other.surface == surface));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,method,os,surface);

@override
String toString() {
  return 'AnalyticsEvent.installCommandCopied(method: $method, os: $os, surface: $surface)';
}


}

/// @nodoc
abstract mixin class $InstallCommandCopiedCopyWith<$Res> implements $AnalyticsEventCopyWith<$Res> {
  factory $InstallCommandCopiedCopyWith(InstallCommandCopied value, $Res Function(InstallCommandCopied) _then) = _$InstallCommandCopiedCopyWithImpl;
@override @useResult
$Res call({
 BridgeInstallMethod method, BridgeInstallOs os, OnboardingSurface surface
});




}
/// @nodoc
class _$InstallCommandCopiedCopyWithImpl<$Res>
    implements $InstallCommandCopiedCopyWith<$Res> {
  _$InstallCommandCopiedCopyWithImpl(this._self, this._then);

  final InstallCommandCopied _self;
  final $Res Function(InstallCommandCopied) _then;

/// Create a copy of AnalyticsEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? method = null,Object? os = null,Object? surface = null,}) {
  return _then(InstallCommandCopied(
method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as BridgeInstallMethod,os: null == os ? _self.os : os // ignore: cast_nullable_to_non_nullable
as BridgeInstallOs,surface: null == surface ? _self.surface : surface // ignore: cast_nullable_to_non_nullable
as OnboardingSurface,
  ));
}


}

/// @nodoc
@JsonSerializable()

class InstallCommandShared implements AnalyticsEvent {
  const InstallCommandShared({required this.method, required this.os, required this.surface, final  String? $type}): $type = $type ?? 'bridge_install_command_shared';
  factory InstallCommandShared.fromJson(Map<String, dynamic> json) => _$InstallCommandSharedFromJson(json);

 final  BridgeInstallMethod method;
 final  BridgeInstallOs os;
@override final  OnboardingSurface surface;

@JsonKey(name: 'event_name')
final String $type;


/// Create a copy of AnalyticsEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InstallCommandSharedCopyWith<InstallCommandShared> get copyWith => _$InstallCommandSharedCopyWithImpl<InstallCommandShared>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$InstallCommandSharedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InstallCommandShared&&(identical(other.method, method) || other.method == method)&&(identical(other.os, os) || other.os == os)&&(identical(other.surface, surface) || other.surface == surface));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,method,os,surface);

@override
String toString() {
  return 'AnalyticsEvent.installCommandShared(method: $method, os: $os, surface: $surface)';
}


}

/// @nodoc
abstract mixin class $InstallCommandSharedCopyWith<$Res> implements $AnalyticsEventCopyWith<$Res> {
  factory $InstallCommandSharedCopyWith(InstallCommandShared value, $Res Function(InstallCommandShared) _then) = _$InstallCommandSharedCopyWithImpl;
@override @useResult
$Res call({
 BridgeInstallMethod method, BridgeInstallOs os, OnboardingSurface surface
});




}
/// @nodoc
class _$InstallCommandSharedCopyWithImpl<$Res>
    implements $InstallCommandSharedCopyWith<$Res> {
  _$InstallCommandSharedCopyWithImpl(this._self, this._then);

  final InstallCommandShared _self;
  final $Res Function(InstallCommandShared) _then;

/// Create a copy of AnalyticsEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? method = null,Object? os = null,Object? surface = null,}) {
  return _then(InstallCommandShared(
method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as BridgeInstallMethod,os: null == os ? _self.os : os // ignore: cast_nullable_to_non_nullable
as BridgeInstallOs,surface: null == surface ? _self.surface : surface // ignore: cast_nullable_to_non_nullable
as OnboardingSurface,
  ));
}


}

/// @nodoc
@JsonSerializable()

class RunCommandCopied implements AnalyticsEvent {
  const RunCommandCopied({required this.surface, final  String? $type}): $type = $type ?? 'bridge_run_command_copied';
  factory RunCommandCopied.fromJson(Map<String, dynamic> json) => _$RunCommandCopiedFromJson(json);

@override final  OnboardingSurface surface;

@JsonKey(name: 'event_name')
final String $type;


/// Create a copy of AnalyticsEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RunCommandCopiedCopyWith<RunCommandCopied> get copyWith => _$RunCommandCopiedCopyWithImpl<RunCommandCopied>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RunCommandCopiedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RunCommandCopied&&(identical(other.surface, surface) || other.surface == surface));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,surface);

@override
String toString() {
  return 'AnalyticsEvent.runCommandCopied(surface: $surface)';
}


}

/// @nodoc
abstract mixin class $RunCommandCopiedCopyWith<$Res> implements $AnalyticsEventCopyWith<$Res> {
  factory $RunCommandCopiedCopyWith(RunCommandCopied value, $Res Function(RunCommandCopied) _then) = _$RunCommandCopiedCopyWithImpl;
@override @useResult
$Res call({
 OnboardingSurface surface
});




}
/// @nodoc
class _$RunCommandCopiedCopyWithImpl<$Res>
    implements $RunCommandCopiedCopyWith<$Res> {
  _$RunCommandCopiedCopyWithImpl(this._self, this._then);

  final RunCommandCopied _self;
  final $Res Function(RunCommandCopied) _then;

/// Create a copy of AnalyticsEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? surface = null,}) {
  return _then(RunCommandCopied(
surface: null == surface ? _self.surface : surface // ignore: cast_nullable_to_non_nullable
as OnboardingSurface,
  ));
}


}

/// @nodoc
@JsonSerializable()

class RunCommandShared implements AnalyticsEvent {
  const RunCommandShared({required this.surface, final  String? $type}): $type = $type ?? 'bridge_run_command_shared';
  factory RunCommandShared.fromJson(Map<String, dynamic> json) => _$RunCommandSharedFromJson(json);

@override final  OnboardingSurface surface;

@JsonKey(name: 'event_name')
final String $type;


/// Create a copy of AnalyticsEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RunCommandSharedCopyWith<RunCommandShared> get copyWith => _$RunCommandSharedCopyWithImpl<RunCommandShared>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RunCommandSharedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RunCommandShared&&(identical(other.surface, surface) || other.surface == surface));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,surface);

@override
String toString() {
  return 'AnalyticsEvent.runCommandShared(surface: $surface)';
}


}

/// @nodoc
abstract mixin class $RunCommandSharedCopyWith<$Res> implements $AnalyticsEventCopyWith<$Res> {
  factory $RunCommandSharedCopyWith(RunCommandShared value, $Res Function(RunCommandShared) _then) = _$RunCommandSharedCopyWithImpl;
@override @useResult
$Res call({
 OnboardingSurface surface
});




}
/// @nodoc
class _$RunCommandSharedCopyWithImpl<$Res>
    implements $RunCommandSharedCopyWith<$Res> {
  _$RunCommandSharedCopyWithImpl(this._self, this._then);

  final RunCommandShared _self;
  final $Res Function(RunCommandShared) _then;

/// Create a copy of AnalyticsEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? surface = null,}) {
  return _then(RunCommandShared(
surface: null == surface ? _self.surface : surface // ignore: cast_nullable_to_non_nullable
as OnboardingSurface,
  ));
}


}

// dart format on
