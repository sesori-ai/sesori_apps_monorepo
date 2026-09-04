// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bridge_setting_update.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
BridgeSettingUpdate _$BridgeSettingUpdateFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'pullRequestRefreshInterval':
          return PullRequestRefreshIntervalSettingUpdate.fromJson(
            json
          );
                case 'yolo':
          return YoloSettingUpdate.fromJson(
            json
          );
                case 'warmUpPluginsOnSessionOpen':
          return WarmUpPluginsOnSessionOpenSettingUpdate.fromJson(
            json
          );
        
          default:
            return UnknownBridgeSettingUpdate.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$BridgeSettingUpdate {



  /// Serializes this BridgeSettingUpdate to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BridgeSettingUpdate);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'BridgeSettingUpdate()';
}


}





/// @nodoc
@JsonSerializable()

class PullRequestRefreshIntervalSettingUpdate implements BridgeSettingUpdate {
  const PullRequestRefreshIntervalSettingUpdate({@strictIntJsonConverter required this.intervalSeconds,  String? $type}): $type = $type ?? 'pullRequestRefreshInterval';
  factory PullRequestRefreshIntervalSettingUpdate.fromJson(Map<String, dynamic> json) => _$PullRequestRefreshIntervalSettingUpdateFromJson(json);

@strictIntJsonConverter final  int intervalSeconds;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$PullRequestRefreshIntervalSettingUpdateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PullRequestRefreshIntervalSettingUpdate&&(identical(other.intervalSeconds, intervalSeconds) || other.intervalSeconds == intervalSeconds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,intervalSeconds);

@override
String toString() {
  return 'BridgeSettingUpdate.pullRequestRefreshInterval(intervalSeconds: $intervalSeconds)';
}


}




/// @nodoc
@JsonSerializable()

class YoloSettingUpdate implements BridgeSettingUpdate {
  const YoloSettingUpdate({required this.enabled,  String? $type}): $type = $type ?? 'yolo';
  factory YoloSettingUpdate.fromJson(Map<String, dynamic> json) => _$YoloSettingUpdateFromJson(json);

 final  bool enabled;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$YoloSettingUpdateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is YoloSettingUpdate&&(identical(other.enabled, enabled) || other.enabled == enabled));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,enabled);

@override
String toString() {
  return 'BridgeSettingUpdate.yolo(enabled: $enabled)';
}


}




/// @nodoc
@JsonSerializable()

class WarmUpPluginsOnSessionOpenSettingUpdate implements BridgeSettingUpdate {
  const WarmUpPluginsOnSessionOpenSettingUpdate({required this.enabled,  String? $type}): $type = $type ?? 'warmUpPluginsOnSessionOpen';
  factory WarmUpPluginsOnSessionOpenSettingUpdate.fromJson(Map<String, dynamic> json) => _$WarmUpPluginsOnSessionOpenSettingUpdateFromJson(json);

 final  bool enabled;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$WarmUpPluginsOnSessionOpenSettingUpdateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WarmUpPluginsOnSessionOpenSettingUpdate&&(identical(other.enabled, enabled) || other.enabled == enabled));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,enabled);

@override
String toString() {
  return 'BridgeSettingUpdate.warmUpPluginsOnSessionOpen(enabled: $enabled)';
}


}




/// @nodoc
@JsonSerializable()

class UnknownBridgeSettingUpdate implements BridgeSettingUpdate {
  const UnknownBridgeSettingUpdate({ String? $type}): $type = $type ?? 'unknown';
  factory UnknownBridgeSettingUpdate.fromJson(Map<String, dynamic> json) => _$UnknownBridgeSettingUpdateFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$UnknownBridgeSettingUpdateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UnknownBridgeSettingUpdate);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'BridgeSettingUpdate.unknown()';
}


}




BridgeSettingUpdateRejection _$BridgeSettingUpdateRejectionFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'pullRequestRefreshIntervalOutOfRange':
          return PullRequestRefreshIntervalOutOfRangeSettingUpdateRejection.fromJson(
            json
          );
        
          default:
            return UnknownBridgeSettingUpdateRejection.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$BridgeSettingUpdateRejection {



  /// Serializes this BridgeSettingUpdateRejection to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BridgeSettingUpdateRejection);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'BridgeSettingUpdateRejection()';
}


}





/// @nodoc
@JsonSerializable()

class PullRequestRefreshIntervalOutOfRangeSettingUpdateRejection implements BridgeSettingUpdateRejection {
  const PullRequestRefreshIntervalOutOfRangeSettingUpdateRejection({@strictIntJsonConverter required this.minimumIntervalSeconds, @strictIntJsonConverter required this.maximumIntervalSeconds,  String? $type}): $type = $type ?? 'pullRequestRefreshIntervalOutOfRange';
  factory PullRequestRefreshIntervalOutOfRangeSettingUpdateRejection.fromJson(Map<String, dynamic> json) => _$PullRequestRefreshIntervalOutOfRangeSettingUpdateRejectionFromJson(json);

@strictIntJsonConverter final  int minimumIntervalSeconds;
@strictIntJsonConverter final  int maximumIntervalSeconds;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$PullRequestRefreshIntervalOutOfRangeSettingUpdateRejectionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PullRequestRefreshIntervalOutOfRangeSettingUpdateRejection&&(identical(other.minimumIntervalSeconds, minimumIntervalSeconds) || other.minimumIntervalSeconds == minimumIntervalSeconds)&&(identical(other.maximumIntervalSeconds, maximumIntervalSeconds) || other.maximumIntervalSeconds == maximumIntervalSeconds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,minimumIntervalSeconds,maximumIntervalSeconds);

@override
String toString() {
  return 'BridgeSettingUpdateRejection.pullRequestRefreshIntervalOutOfRange(minimumIntervalSeconds: $minimumIntervalSeconds, maximumIntervalSeconds: $maximumIntervalSeconds)';
}


}




/// @nodoc
@JsonSerializable()

class UnknownBridgeSettingUpdateRejection implements BridgeSettingUpdateRejection {
  const UnknownBridgeSettingUpdateRejection({ String? $type}): $type = $type ?? 'unknown';
  factory UnknownBridgeSettingUpdateRejection.fromJson(Map<String, dynamic> json) => _$UnknownBridgeSettingUpdateRejectionFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$UnknownBridgeSettingUpdateRejectionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UnknownBridgeSettingUpdateRejection);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'BridgeSettingUpdateRejection.unknown()';
}


}




// dart format on
