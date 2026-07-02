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



  /// Serializes this AnalyticsEvent to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AnalyticsEvent);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AnalyticsEvent()';
}


}

/// @nodoc
class $AnalyticsEventCopyWith<$Res>  {
$AnalyticsEventCopyWith(AnalyticsEvent _, $Res Function(AnalyticsEvent) __);
}



/// @nodoc
@JsonSerializable()

class NeedHelpMenuOpened implements AnalyticsEvent {
  const NeedHelpMenuOpened({final  String? $type}): $type = $type ?? 'onboarding_need_help_opened';
  factory NeedHelpMenuOpened.fromJson(Map<String, dynamic> json) => _$NeedHelpMenuOpenedFromJson(json);



@JsonKey(name: 'event_name')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$NeedHelpMenuOpenedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NeedHelpMenuOpened);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AnalyticsEvent.needHelpMenuOpened()';
}


}




/// @nodoc
@JsonSerializable()

class SupportLinkOpened implements AnalyticsEvent {
  const SupportLinkOpened({required this.channel, final  String? $type}): $type = $type ?? 'onboarding_support_link_opened';
  factory SupportLinkOpened.fromJson(Map<String, dynamic> json) => _$SupportLinkOpenedFromJson(json);

 final  SupportChannel channel;

@JsonKey(name: 'event_name')
final String $type;


/// Create a copy of AnalyticsEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SupportLinkOpenedCopyWith<SupportLinkOpened> get copyWith => _$SupportLinkOpenedCopyWithImpl<SupportLinkOpened>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SupportLinkOpenedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SupportLinkOpened&&(identical(other.channel, channel) || other.channel == channel));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,channel);

@override
String toString() {
  return 'AnalyticsEvent.supportLinkOpened(channel: $channel)';
}


}

/// @nodoc
abstract mixin class $SupportLinkOpenedCopyWith<$Res> implements $AnalyticsEventCopyWith<$Res> {
  factory $SupportLinkOpenedCopyWith(SupportLinkOpened value, $Res Function(SupportLinkOpened) _then) = _$SupportLinkOpenedCopyWithImpl;
@useResult
$Res call({
 SupportChannel channel
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
@pragma('vm:prefer-inline') $Res call({Object? channel = null,}) {
  return _then(SupportLinkOpened(
channel: null == channel ? _self.channel : channel // ignore: cast_nullable_to_non_nullable
as SupportChannel,
  ));
}


}

// dart format on
