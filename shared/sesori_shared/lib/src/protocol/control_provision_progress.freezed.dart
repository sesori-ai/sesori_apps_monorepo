// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'control_provision_progress.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
ControlProvisionProgress _$ControlProvisionProgressFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'resolving':
          return ControlProvisionResolving.fromJson(
            json
          );
                case 'downloading':
          return ControlProvisionDownloading.fromJson(
            json
          );
                case 'extracting':
          return ControlProvisionExtracting.fromJson(
            json
          );
                case 'verifying':
          return ControlProvisionVerifying.fromJson(
            json
          );
                case 'notice':
          return ControlProvisionNotice.fromJson(
            json
          );
                case 'ready':
          return ControlProvisionReady.fromJson(
            json
          );
                case 'failed':
          return ControlProvisionFailed.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'type',
  'ControlProvisionProgress',
  'Invalid union type "${json['type']}"!'
);
        }
      
}

/// @nodoc
mixin _$ControlProvisionProgress {



  /// Serializes this ControlProvisionProgress to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ControlProvisionProgress);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ControlProvisionProgress()';
}


}

/// @nodoc
class $ControlProvisionProgressCopyWith<$Res>  {
$ControlProvisionProgressCopyWith(ControlProvisionProgress _, $Res Function(ControlProvisionProgress) __);
}



/// @nodoc
@JsonSerializable()

class ControlProvisionResolving implements ControlProvisionProgress {
  const ControlProvisionResolving({final  String? $type}): $type = $type ?? 'resolving';
  factory ControlProvisionResolving.fromJson(Map<String, dynamic> json) => _$ControlProvisionResolvingFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$ControlProvisionResolvingToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ControlProvisionResolving);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ControlProvisionProgress.resolving()';
}


}




/// @nodoc
@JsonSerializable()

class ControlProvisionDownloading implements ControlProvisionProgress {
  const ControlProvisionDownloading({required this.receivedBytes, required this.totalBytes, final  String? $type}): $type = $type ?? 'downloading';
  factory ControlProvisionDownloading.fromJson(Map<String, dynamic> json) => _$ControlProvisionDownloadingFromJson(json);

 final  int receivedBytes;
 final  int? totalBytes;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of ControlProvisionProgress
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ControlProvisionDownloadingCopyWith<ControlProvisionDownloading> get copyWith => _$ControlProvisionDownloadingCopyWithImpl<ControlProvisionDownloading>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ControlProvisionDownloadingToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ControlProvisionDownloading&&(identical(other.receivedBytes, receivedBytes) || other.receivedBytes == receivedBytes)&&(identical(other.totalBytes, totalBytes) || other.totalBytes == totalBytes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,receivedBytes,totalBytes);

@override
String toString() {
  return 'ControlProvisionProgress.downloading(receivedBytes: $receivedBytes, totalBytes: $totalBytes)';
}


}

/// @nodoc
abstract mixin class $ControlProvisionDownloadingCopyWith<$Res> implements $ControlProvisionProgressCopyWith<$Res> {
  factory $ControlProvisionDownloadingCopyWith(ControlProvisionDownloading value, $Res Function(ControlProvisionDownloading) _then) = _$ControlProvisionDownloadingCopyWithImpl;
@useResult
$Res call({
 int receivedBytes, int? totalBytes
});




}
/// @nodoc
class _$ControlProvisionDownloadingCopyWithImpl<$Res>
    implements $ControlProvisionDownloadingCopyWith<$Res> {
  _$ControlProvisionDownloadingCopyWithImpl(this._self, this._then);

  final ControlProvisionDownloading _self;
  final $Res Function(ControlProvisionDownloading) _then;

/// Create a copy of ControlProvisionProgress
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? receivedBytes = null,Object? totalBytes = freezed,}) {
  return _then(ControlProvisionDownloading(
receivedBytes: null == receivedBytes ? _self.receivedBytes : receivedBytes // ignore: cast_nullable_to_non_nullable
as int,totalBytes: freezed == totalBytes ? _self.totalBytes : totalBytes // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class ControlProvisionExtracting implements ControlProvisionProgress {
  const ControlProvisionExtracting({final  String? $type}): $type = $type ?? 'extracting';
  factory ControlProvisionExtracting.fromJson(Map<String, dynamic> json) => _$ControlProvisionExtractingFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$ControlProvisionExtractingToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ControlProvisionExtracting);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ControlProvisionProgress.extracting()';
}


}




/// @nodoc
@JsonSerializable()

class ControlProvisionVerifying implements ControlProvisionProgress {
  const ControlProvisionVerifying({final  String? $type}): $type = $type ?? 'verifying';
  factory ControlProvisionVerifying.fromJson(Map<String, dynamic> json) => _$ControlProvisionVerifyingFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$ControlProvisionVerifyingToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ControlProvisionVerifying);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ControlProvisionProgress.verifying()';
}


}




/// @nodoc
@JsonSerializable()

class ControlProvisionNotice implements ControlProvisionProgress {
  const ControlProvisionNotice({required this.message, final  String? $type}): $type = $type ?? 'notice';
  factory ControlProvisionNotice.fromJson(Map<String, dynamic> json) => _$ControlProvisionNoticeFromJson(json);

 final  String message;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of ControlProvisionProgress
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ControlProvisionNoticeCopyWith<ControlProvisionNotice> get copyWith => _$ControlProvisionNoticeCopyWithImpl<ControlProvisionNotice>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ControlProvisionNoticeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ControlProvisionNotice&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'ControlProvisionProgress.notice(message: $message)';
}


}

/// @nodoc
abstract mixin class $ControlProvisionNoticeCopyWith<$Res> implements $ControlProvisionProgressCopyWith<$Res> {
  factory $ControlProvisionNoticeCopyWith(ControlProvisionNotice value, $Res Function(ControlProvisionNotice) _then) = _$ControlProvisionNoticeCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$ControlProvisionNoticeCopyWithImpl<$Res>
    implements $ControlProvisionNoticeCopyWith<$Res> {
  _$ControlProvisionNoticeCopyWithImpl(this._self, this._then);

  final ControlProvisionNotice _self;
  final $Res Function(ControlProvisionNotice) _then;

/// Create a copy of ControlProvisionProgress
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(ControlProvisionNotice(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class ControlProvisionReady implements ControlProvisionProgress {
  const ControlProvisionReady({required this.binaryPath, final  String? $type}): $type = $type ?? 'ready';
  factory ControlProvisionReady.fromJson(Map<String, dynamic> json) => _$ControlProvisionReadyFromJson(json);

 final  String binaryPath;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of ControlProvisionProgress
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ControlProvisionReadyCopyWith<ControlProvisionReady> get copyWith => _$ControlProvisionReadyCopyWithImpl<ControlProvisionReady>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ControlProvisionReadyToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ControlProvisionReady&&(identical(other.binaryPath, binaryPath) || other.binaryPath == binaryPath));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,binaryPath);

@override
String toString() {
  return 'ControlProvisionProgress.ready(binaryPath: $binaryPath)';
}


}

/// @nodoc
abstract mixin class $ControlProvisionReadyCopyWith<$Res> implements $ControlProvisionProgressCopyWith<$Res> {
  factory $ControlProvisionReadyCopyWith(ControlProvisionReady value, $Res Function(ControlProvisionReady) _then) = _$ControlProvisionReadyCopyWithImpl;
@useResult
$Res call({
 String binaryPath
});




}
/// @nodoc
class _$ControlProvisionReadyCopyWithImpl<$Res>
    implements $ControlProvisionReadyCopyWith<$Res> {
  _$ControlProvisionReadyCopyWithImpl(this._self, this._then);

  final ControlProvisionReady _self;
  final $Res Function(ControlProvisionReady) _then;

/// Create a copy of ControlProvisionProgress
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? binaryPath = null,}) {
  return _then(ControlProvisionReady(
binaryPath: null == binaryPath ? _self.binaryPath : binaryPath // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class ControlProvisionFailed implements ControlProvisionProgress {
  const ControlProvisionFailed({required this.message, final  String? $type}): $type = $type ?? 'failed';
  factory ControlProvisionFailed.fromJson(Map<String, dynamic> json) => _$ControlProvisionFailedFromJson(json);

 final  String message;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of ControlProvisionProgress
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ControlProvisionFailedCopyWith<ControlProvisionFailed> get copyWith => _$ControlProvisionFailedCopyWithImpl<ControlProvisionFailed>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ControlProvisionFailedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ControlProvisionFailed&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'ControlProvisionProgress.failed(message: $message)';
}


}

/// @nodoc
abstract mixin class $ControlProvisionFailedCopyWith<$Res> implements $ControlProvisionProgressCopyWith<$Res> {
  factory $ControlProvisionFailedCopyWith(ControlProvisionFailed value, $Res Function(ControlProvisionFailed) _then) = _$ControlProvisionFailedCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$ControlProvisionFailedCopyWithImpl<$Res>
    implements $ControlProvisionFailedCopyWith<$Res> {
  _$ControlProvisionFailedCopyWithImpl(this._self, this._then);

  final ControlProvisionFailed _self;
  final $Res Function(ControlProvisionFailed) _then;

/// Create a copy of ControlProvisionProgress
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(ControlProvisionFailed(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
