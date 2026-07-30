// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'product_analytics_preference_storage.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
StoredProductAnalyticsPreference _$StoredProductAnalyticsPreferenceFromJson(
  Map<String, dynamic> json
) {
        switch (json['kind']) {
                  case 'synced':
          return StoredProductAnalyticsSynced.fromJson(
            json
          );
                case 'pending_disable':
          return StoredProductAnalyticsPendingDisable.fromJson(
            json
          );
                case 'pending_enable':
          return StoredProductAnalyticsPendingEnable.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'kind',
  'StoredProductAnalyticsPreference',
  'Invalid union type "${json['kind']}"!'
);
        }
      
}

/// @nodoc
mixin _$StoredProductAnalyticsPreference {

 String get userId; int get revision; String get userKey;
/// Create a copy of StoredProductAnalyticsPreference
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StoredProductAnalyticsPreferenceCopyWith<StoredProductAnalyticsPreference> get copyWith => _$StoredProductAnalyticsPreferenceCopyWithImpl<StoredProductAnalyticsPreference>(this as StoredProductAnalyticsPreference, _$identity);

  /// Serializes this StoredProductAnalyticsPreference to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StoredProductAnalyticsPreference&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.revision, revision) || other.revision == revision)&&(identical(other.userKey, userKey) || other.userKey == userKey));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userId,revision,userKey);

@override
String toString() {
  return 'StoredProductAnalyticsPreference(userId: $userId, revision: $revision, userKey: $userKey)';
}


}

/// @nodoc
abstract mixin class $StoredProductAnalyticsPreferenceCopyWith<$Res>  {
  factory $StoredProductAnalyticsPreferenceCopyWith(StoredProductAnalyticsPreference value, $Res Function(StoredProductAnalyticsPreference) _then) = _$StoredProductAnalyticsPreferenceCopyWithImpl;
@useResult
$Res call({
 String userId, int revision, String userKey
});




}
/// @nodoc
class _$StoredProductAnalyticsPreferenceCopyWithImpl<$Res>
    implements $StoredProductAnalyticsPreferenceCopyWith<$Res> {
  _$StoredProductAnalyticsPreferenceCopyWithImpl(this._self, this._then);

  final StoredProductAnalyticsPreference _self;
  final $Res Function(StoredProductAnalyticsPreference) _then;

/// Create a copy of StoredProductAnalyticsPreference
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? userId = null,Object? revision = null,Object? userKey = null,}) {
  return _then(_self.copyWith(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,userKey: null == userKey ? _self.userKey : userKey // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable()

class StoredProductAnalyticsSynced implements StoredProductAnalyticsPreference {
  const StoredProductAnalyticsSynced({required this.userId, required this.revision, required this.userKey, required this.preference, final  String? $type}): $type = $type ?? 'synced';
  factory StoredProductAnalyticsSynced.fromJson(Map<String, dynamic> json) => _$StoredProductAnalyticsSyncedFromJson(json);

@override final  String userId;
@override final  int revision;
@override final  String userKey;
 final  ProductAnalyticsPreference preference;

@JsonKey(name: 'kind')
final String $type;


/// Create a copy of StoredProductAnalyticsPreference
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StoredProductAnalyticsSyncedCopyWith<StoredProductAnalyticsSynced> get copyWith => _$StoredProductAnalyticsSyncedCopyWithImpl<StoredProductAnalyticsSynced>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$StoredProductAnalyticsSyncedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StoredProductAnalyticsSynced&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.revision, revision) || other.revision == revision)&&(identical(other.userKey, userKey) || other.userKey == userKey)&&(identical(other.preference, preference) || other.preference == preference));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userId,revision,userKey,preference);

@override
String toString() {
  return 'StoredProductAnalyticsPreference.synced(userId: $userId, revision: $revision, userKey: $userKey, preference: $preference)';
}


}

/// @nodoc
abstract mixin class $StoredProductAnalyticsSyncedCopyWith<$Res> implements $StoredProductAnalyticsPreferenceCopyWith<$Res> {
  factory $StoredProductAnalyticsSyncedCopyWith(StoredProductAnalyticsSynced value, $Res Function(StoredProductAnalyticsSynced) _then) = _$StoredProductAnalyticsSyncedCopyWithImpl;
@override @useResult
$Res call({
 String userId, int revision, String userKey, ProductAnalyticsPreference preference
});




}
/// @nodoc
class _$StoredProductAnalyticsSyncedCopyWithImpl<$Res>
    implements $StoredProductAnalyticsSyncedCopyWith<$Res> {
  _$StoredProductAnalyticsSyncedCopyWithImpl(this._self, this._then);

  final StoredProductAnalyticsSynced _self;
  final $Res Function(StoredProductAnalyticsSynced) _then;

/// Create a copy of StoredProductAnalyticsPreference
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? userId = null,Object? revision = null,Object? userKey = null,Object? preference = null,}) {
  return _then(StoredProductAnalyticsSynced(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,userKey: null == userKey ? _self.userKey : userKey // ignore: cast_nullable_to_non_nullable
as String,preference: null == preference ? _self.preference : preference // ignore: cast_nullable_to_non_nullable
as ProductAnalyticsPreference,
  ));
}


}

/// @nodoc
@JsonSerializable()

class StoredProductAnalyticsPendingDisable implements StoredProductAnalyticsPreference {
  const StoredProductAnalyticsPendingDisable({required this.userId, required this.revision, required this.userKey, required this.operationId, final  String? $type}): $type = $type ?? 'pending_disable';
  factory StoredProductAnalyticsPendingDisable.fromJson(Map<String, dynamic> json) => _$StoredProductAnalyticsPendingDisableFromJson(json);

@override final  String userId;
@override final  int revision;
@override final  String userKey;
 final  String operationId;

@JsonKey(name: 'kind')
final String $type;


/// Create a copy of StoredProductAnalyticsPreference
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StoredProductAnalyticsPendingDisableCopyWith<StoredProductAnalyticsPendingDisable> get copyWith => _$StoredProductAnalyticsPendingDisableCopyWithImpl<StoredProductAnalyticsPendingDisable>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$StoredProductAnalyticsPendingDisableToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StoredProductAnalyticsPendingDisable&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.revision, revision) || other.revision == revision)&&(identical(other.userKey, userKey) || other.userKey == userKey)&&(identical(other.operationId, operationId) || other.operationId == operationId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userId,revision,userKey,operationId);

@override
String toString() {
  return 'StoredProductAnalyticsPreference.pendingDisable(userId: $userId, revision: $revision, userKey: $userKey, operationId: $operationId)';
}


}

/// @nodoc
abstract mixin class $StoredProductAnalyticsPendingDisableCopyWith<$Res> implements $StoredProductAnalyticsPreferenceCopyWith<$Res> {
  factory $StoredProductAnalyticsPendingDisableCopyWith(StoredProductAnalyticsPendingDisable value, $Res Function(StoredProductAnalyticsPendingDisable) _then) = _$StoredProductAnalyticsPendingDisableCopyWithImpl;
@override @useResult
$Res call({
 String userId, int revision, String userKey, String operationId
});




}
/// @nodoc
class _$StoredProductAnalyticsPendingDisableCopyWithImpl<$Res>
    implements $StoredProductAnalyticsPendingDisableCopyWith<$Res> {
  _$StoredProductAnalyticsPendingDisableCopyWithImpl(this._self, this._then);

  final StoredProductAnalyticsPendingDisable _self;
  final $Res Function(StoredProductAnalyticsPendingDisable) _then;

/// Create a copy of StoredProductAnalyticsPreference
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? userId = null,Object? revision = null,Object? userKey = null,Object? operationId = null,}) {
  return _then(StoredProductAnalyticsPendingDisable(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,userKey: null == userKey ? _self.userKey : userKey // ignore: cast_nullable_to_non_nullable
as String,operationId: null == operationId ? _self.operationId : operationId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class StoredProductAnalyticsPendingEnable implements StoredProductAnalyticsPreference {
  const StoredProductAnalyticsPendingEnable({required this.userId, required this.revision, required this.userKey, required this.operationId, final  String? $type}): $type = $type ?? 'pending_enable';
  factory StoredProductAnalyticsPendingEnable.fromJson(Map<String, dynamic> json) => _$StoredProductAnalyticsPendingEnableFromJson(json);

@override final  String userId;
@override final  int revision;
@override final  String userKey;
 final  String operationId;

@JsonKey(name: 'kind')
final String $type;


/// Create a copy of StoredProductAnalyticsPreference
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StoredProductAnalyticsPendingEnableCopyWith<StoredProductAnalyticsPendingEnable> get copyWith => _$StoredProductAnalyticsPendingEnableCopyWithImpl<StoredProductAnalyticsPendingEnable>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$StoredProductAnalyticsPendingEnableToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StoredProductAnalyticsPendingEnable&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.revision, revision) || other.revision == revision)&&(identical(other.userKey, userKey) || other.userKey == userKey)&&(identical(other.operationId, operationId) || other.operationId == operationId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userId,revision,userKey,operationId);

@override
String toString() {
  return 'StoredProductAnalyticsPreference.pendingEnable(userId: $userId, revision: $revision, userKey: $userKey, operationId: $operationId)';
}


}

/// @nodoc
abstract mixin class $StoredProductAnalyticsPendingEnableCopyWith<$Res> implements $StoredProductAnalyticsPreferenceCopyWith<$Res> {
  factory $StoredProductAnalyticsPendingEnableCopyWith(StoredProductAnalyticsPendingEnable value, $Res Function(StoredProductAnalyticsPendingEnable) _then) = _$StoredProductAnalyticsPendingEnableCopyWithImpl;
@override @useResult
$Res call({
 String userId, int revision, String userKey, String operationId
});




}
/// @nodoc
class _$StoredProductAnalyticsPendingEnableCopyWithImpl<$Res>
    implements $StoredProductAnalyticsPendingEnableCopyWith<$Res> {
  _$StoredProductAnalyticsPendingEnableCopyWithImpl(this._self, this._then);

  final StoredProductAnalyticsPendingEnable _self;
  final $Res Function(StoredProductAnalyticsPendingEnable) _then;

/// Create a copy of StoredProductAnalyticsPreference
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? userId = null,Object? revision = null,Object? userKey = null,Object? operationId = null,}) {
  return _then(StoredProductAnalyticsPendingEnable(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,userKey: null == userKey ? _self.userKey : userKey // ignore: cast_nullable_to_non_nullable
as String,operationId: null == operationId ? _self.operationId : operationId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
