// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bridge_settings_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BridgeSettingsResponse {

 PullRequestRefreshSettingsResponse get pullRequestRefresh; YoloSettingsResponse get yolo;
/// Create a copy of BridgeSettingsResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BridgeSettingsResponseCopyWith<BridgeSettingsResponse> get copyWith => _$BridgeSettingsResponseCopyWithImpl<BridgeSettingsResponse>(this as BridgeSettingsResponse, _$identity);

  /// Serializes this BridgeSettingsResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BridgeSettingsResponse&&(identical(other.pullRequestRefresh, pullRequestRefresh) || other.pullRequestRefresh == pullRequestRefresh)&&(identical(other.yolo, yolo) || other.yolo == yolo));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,pullRequestRefresh,yolo);

@override
String toString() {
  return 'BridgeSettingsResponse(pullRequestRefresh: $pullRequestRefresh, yolo: $yolo)';
}


}

/// @nodoc
abstract mixin class $BridgeSettingsResponseCopyWith<$Res>  {
  factory $BridgeSettingsResponseCopyWith(BridgeSettingsResponse value, $Res Function(BridgeSettingsResponse) _then) = _$BridgeSettingsResponseCopyWithImpl;
@useResult
$Res call({
 PullRequestRefreshSettingsResponse pullRequestRefresh, YoloSettingsResponse yolo
});


$PullRequestRefreshSettingsResponseCopyWith<$Res> get pullRequestRefresh;$YoloSettingsResponseCopyWith<$Res> get yolo;

}
/// @nodoc
class _$BridgeSettingsResponseCopyWithImpl<$Res>
    implements $BridgeSettingsResponseCopyWith<$Res> {
  _$BridgeSettingsResponseCopyWithImpl(this._self, this._then);

  final BridgeSettingsResponse _self;
  final $Res Function(BridgeSettingsResponse) _then;

/// Create a copy of BridgeSettingsResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? pullRequestRefresh = null,Object? yolo = null,}) {
  return _then(BridgeSettingsResponse(
pullRequestRefresh: null == pullRequestRefresh ? _self.pullRequestRefresh : pullRequestRefresh // ignore: cast_nullable_to_non_nullable
as PullRequestRefreshSettingsResponse,yolo: null == yolo ? _self.yolo : yolo // ignore: cast_nullable_to_non_nullable
as YoloSettingsResponse,
  ));
}
/// Create a copy of BridgeSettingsResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PullRequestRefreshSettingsResponseCopyWith<$Res> get pullRequestRefresh {
  
  return $PullRequestRefreshSettingsResponseCopyWith<$Res>(_self.pullRequestRefresh, (value) {
    return _then(_self.copyWith(pullRequestRefresh: value));
  });
}/// Create a copy of BridgeSettingsResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$YoloSettingsResponseCopyWith<$Res> get yolo {
  
  return $YoloSettingsResponseCopyWith<$Res>(_self.yolo, (value) {
    return _then(_self.copyWith(yolo: value));
  });
}
}



/// @nodoc
@JsonSerializable()

class _BridgeSettingsResponse implements BridgeSettingsResponse {
  const _BridgeSettingsResponse({required this.pullRequestRefresh, required this.yolo});
  factory _BridgeSettingsResponse.fromJson(Map<String, dynamic> json) => _$BridgeSettingsResponseFromJson(json);

@override final  PullRequestRefreshSettingsResponse pullRequestRefresh;
@override final  YoloSettingsResponse yolo;

/// Create a copy of BridgeSettingsResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BridgeSettingsResponseCopyWith<_BridgeSettingsResponse> get copyWith => __$BridgeSettingsResponseCopyWithImpl<_BridgeSettingsResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BridgeSettingsResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BridgeSettingsResponse&&(identical(other.pullRequestRefresh, pullRequestRefresh) || other.pullRequestRefresh == pullRequestRefresh)&&(identical(other.yolo, yolo) || other.yolo == yolo));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,pullRequestRefresh,yolo);

@override
String toString() {
  return 'BridgeSettingsResponse(pullRequestRefresh: $pullRequestRefresh, yolo: $yolo)';
}


}

/// @nodoc
abstract mixin class _$BridgeSettingsResponseCopyWith<$Res> implements $BridgeSettingsResponseCopyWith<$Res> {
  factory _$BridgeSettingsResponseCopyWith(_BridgeSettingsResponse value, $Res Function(_BridgeSettingsResponse) _then) = __$BridgeSettingsResponseCopyWithImpl;
@override @useResult
$Res call({
 PullRequestRefreshSettingsResponse pullRequestRefresh, YoloSettingsResponse yolo
});


@override $PullRequestRefreshSettingsResponseCopyWith<$Res> get pullRequestRefresh;@override $YoloSettingsResponseCopyWith<$Res> get yolo;

}
/// @nodoc
class __$BridgeSettingsResponseCopyWithImpl<$Res>
    implements _$BridgeSettingsResponseCopyWith<$Res> {
  __$BridgeSettingsResponseCopyWithImpl(this._self, this._then);

  final _BridgeSettingsResponse _self;
  final $Res Function(_BridgeSettingsResponse) _then;

/// Create a copy of BridgeSettingsResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? pullRequestRefresh = null,Object? yolo = null,}) {
  return _then(_BridgeSettingsResponse(
pullRequestRefresh: null == pullRequestRefresh ? _self.pullRequestRefresh : pullRequestRefresh // ignore: cast_nullable_to_non_nullable
as PullRequestRefreshSettingsResponse,yolo: null == yolo ? _self.yolo : yolo // ignore: cast_nullable_to_non_nullable
as YoloSettingsResponse,
  ));
}

/// Create a copy of BridgeSettingsResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PullRequestRefreshSettingsResponseCopyWith<$Res> get pullRequestRefresh {
  
  return $PullRequestRefreshSettingsResponseCopyWith<$Res>(_self.pullRequestRefresh, (value) {
    return _then(_self.copyWith(pullRequestRefresh: value));
  });
}/// Create a copy of BridgeSettingsResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$YoloSettingsResponseCopyWith<$Res> get yolo {
  
  return $YoloSettingsResponseCopyWith<$Res>(_self.yolo, (value) {
    return _then(_self.copyWith(yolo: value));
  });
}
}

// dart format on
