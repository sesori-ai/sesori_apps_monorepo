// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'mcp_authentication.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$McpAuthenticationAttempt {

 String get attemptId; String get pluginId;@JsonKey(fromJson: McpEntryTarget.serverFromJson) McpServerTarget get target;@JsonKey(unknownEnumValue: McpAuthenticationCancellation.unknown) McpAuthenticationCancellation get cancellation;

  /// Serializes this McpAuthenticationAttempt to a JSON map.
  Map<String, dynamic> toJson();






}





/// @nodoc
@JsonSerializable()

class _McpAuthenticationAttempt implements McpAuthenticationAttempt {
  const _McpAuthenticationAttempt({required this.attemptId, required this.pluginId, @JsonKey(fromJson: McpEntryTarget.serverFromJson) required this.target, @JsonKey(unknownEnumValue: McpAuthenticationCancellation.unknown) required this.cancellation});
  factory _McpAuthenticationAttempt.fromJson(Map<String, dynamic> json) => _$McpAuthenticationAttemptFromJson(json);

@override final  String attemptId;
@override final  String pluginId;
@override@JsonKey(fromJson: McpEntryTarget.serverFromJson) final  McpServerTarget target;
@override@JsonKey(unknownEnumValue: McpAuthenticationCancellation.unknown) final  McpAuthenticationCancellation cancellation;


@override
Map<String, dynamic> toJson() {
  return _$McpAuthenticationAttemptToJson(this, );
}





}




McpAuthenticationState _$McpAuthenticationStateFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'idle':
          return McpAuthenticationIdle.fromJson(
            json
          );
                case 'starting':
          return McpAuthenticationStarting.fromJson(
            json
          );
                case 'callbackChallenge':
          return McpAuthenticationCallbackChallenge.fromJson(
            json
          );
                case 'settling':
          return McpAuthenticationSettling.fromJson(
            json
          );
                case 'completed':
          return McpAuthenticationCompleted.fromJson(
            json
          );
                case 'failed':
          return McpAuthenticationFailed.fromJson(
            json
          );
                case 'cancelled':
          return McpAuthenticationCancelled.fromJson(
            json
          );
        
          default:
            return McpAuthenticationUnknown.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$McpAuthenticationState {



  /// Serializes this McpAuthenticationState to a JSON map.
  Map<String, dynamic> toJson();






}





/// @nodoc
@JsonSerializable()

class McpAuthenticationUnknown implements McpAuthenticationState {
  const McpAuthenticationUnknown({ String? $type}): $type = $type ?? 'unknown';
  factory McpAuthenticationUnknown.fromJson(Map<String, dynamic> json) => _$McpAuthenticationUnknownFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$McpAuthenticationUnknownToJson(this, );
}





}




/// @nodoc
@JsonSerializable()

class McpAuthenticationIdle implements McpAuthenticationState {
  const McpAuthenticationIdle({ String? $type}): $type = $type ?? 'idle';
  factory McpAuthenticationIdle.fromJson(Map<String, dynamic> json) => _$McpAuthenticationIdleFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$McpAuthenticationIdleToJson(this, );
}





}




/// @nodoc
@JsonSerializable()

class McpAuthenticationStarting implements McpAuthenticationState {
  const McpAuthenticationStarting({required this.attempt,  String? $type}): $type = $type ?? 'starting';
  factory McpAuthenticationStarting.fromJson(Map<String, dynamic> json) => _$McpAuthenticationStartingFromJson(json);

 final  McpAuthenticationAttempt attempt;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$McpAuthenticationStartingToJson(this, );
}





}




/// @nodoc
@JsonSerializable()

class McpAuthenticationCallbackChallenge implements McpAuthenticationState {
  const McpAuthenticationCallbackChallenge({required this.attempt, required this.authorizationUrl, required this.expectedCallbackUrl,  String? $type}): $type = $type ?? 'callbackChallenge';
  factory McpAuthenticationCallbackChallenge.fromJson(Map<String, dynamic> json) => _$McpAuthenticationCallbackChallengeFromJson(json);

 final  McpAuthenticationAttempt attempt;
 final  String authorizationUrl;
 final  String expectedCallbackUrl;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$McpAuthenticationCallbackChallengeToJson(this, );
}





}




/// @nodoc
@JsonSerializable()

class McpAuthenticationSettling implements McpAuthenticationState {
  const McpAuthenticationSettling({required this.attempt,  String? $type}): $type = $type ?? 'settling';
  factory McpAuthenticationSettling.fromJson(Map<String, dynamic> json) => _$McpAuthenticationSettlingFromJson(json);

 final  McpAuthenticationAttempt attempt;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$McpAuthenticationSettlingToJson(this, );
}





}




/// @nodoc
@JsonSerializable()

class McpAuthenticationCompleted implements McpAuthenticationState {
  const McpAuthenticationCompleted({required this.attempt,  String? $type}): $type = $type ?? 'completed';
  factory McpAuthenticationCompleted.fromJson(Map<String, dynamic> json) => _$McpAuthenticationCompletedFromJson(json);

 final  McpAuthenticationAttempt attempt;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$McpAuthenticationCompletedToJson(this, );
}





}




/// @nodoc
@JsonSerializable()

class McpAuthenticationFailed implements McpAuthenticationState {
  const McpAuthenticationFailed({required this.attempt, @JsonKey(unknownEnumValue: McpAuthenticationFailureReason.unknown) required this.reason,  String? $type}): $type = $type ?? 'failed';
  factory McpAuthenticationFailed.fromJson(Map<String, dynamic> json) => _$McpAuthenticationFailedFromJson(json);

 final  McpAuthenticationAttempt attempt;
@JsonKey(unknownEnumValue: McpAuthenticationFailureReason.unknown) final  McpAuthenticationFailureReason reason;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$McpAuthenticationFailedToJson(this, );
}





}




/// @nodoc
@JsonSerializable()

class McpAuthenticationCancelled implements McpAuthenticationState {
  const McpAuthenticationCancelled({required this.attempt,  String? $type}): $type = $type ?? 'cancelled';
  factory McpAuthenticationCancelled.fromJson(Map<String, dynamic> json) => _$McpAuthenticationCancelledFromJson(json);

 final  McpAuthenticationAttempt attempt;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$McpAuthenticationCancelledToJson(this, );
}





}





/// @nodoc
mixin _$McpAuthenticationStartRequest {

 String get pluginId;@JsonKey(fromJson: McpEntryTarget.serverFromJson) McpServerTarget get target;

  /// Serializes this McpAuthenticationStartRequest to a JSON map.
  Map<String, dynamic> toJson();






}





/// @nodoc
@JsonSerializable()

class _McpAuthenticationStartRequest implements McpAuthenticationStartRequest {
  const _McpAuthenticationStartRequest({required this.pluginId, @JsonKey(fromJson: McpEntryTarget.serverFromJson) required this.target});
  factory _McpAuthenticationStartRequest.fromJson(Map<String, dynamic> json) => _$McpAuthenticationStartRequestFromJson(json);

@override final  String pluginId;
@override@JsonKey(fromJson: McpEntryTarget.serverFromJson) final  McpServerTarget target;


@override
Map<String, dynamic> toJson() {
  return _$McpAuthenticationStartRequestToJson(this, );
}





}





/// @nodoc
mixin _$McpAuthenticationContinueRequest {

 String get attemptId; String get callbackUrl;

  /// Serializes this McpAuthenticationContinueRequest to a JSON map.
  Map<String, dynamic> toJson();






}





/// @nodoc
@JsonSerializable()

class _McpAuthenticationContinueRequest implements McpAuthenticationContinueRequest {
  const _McpAuthenticationContinueRequest({required this.attemptId, required this.callbackUrl});
  factory _McpAuthenticationContinueRequest.fromJson(Map<String, dynamic> json) => _$McpAuthenticationContinueRequestFromJson(json);

@override final  String attemptId;
@override final  String callbackUrl;


@override
Map<String, dynamic> toJson() {
  return _$McpAuthenticationContinueRequestToJson(this, );
}





}





/// @nodoc
mixin _$McpAuthenticationCancelRequest {

 String get attemptId;

  /// Serializes this McpAuthenticationCancelRequest to a JSON map.
  Map<String, dynamic> toJson();






}





/// @nodoc
@JsonSerializable()

class _McpAuthenticationCancelRequest implements McpAuthenticationCancelRequest {
  const _McpAuthenticationCancelRequest({required this.attemptId});
  factory _McpAuthenticationCancelRequest.fromJson(Map<String, dynamic> json) => _$McpAuthenticationCancelRequestFromJson(json);

@override final  String attemptId;


@override
Map<String, dynamic> toJson() {
  return _$McpAuthenticationCancelRequestToJson(this, );
}





}




McpAuthenticationResult _$McpAuthenticationResultFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'state':
          return McpAuthenticationStateResult.fromJson(
            json
          );
                case 'busy':
          return McpAuthenticationBusy.fromJson(
            json
          );
                case 'unavailable':
          return McpAuthenticationUnavailable.fromJson(
            json
          );
        
          default:
            return McpAuthenticationResultUnknown.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$McpAuthenticationResult {



  /// Serializes this McpAuthenticationResult to a JSON map.
  Map<String, dynamic> toJson();






}





/// @nodoc
@JsonSerializable()

class McpAuthenticationResultUnknown implements McpAuthenticationResult {
  const McpAuthenticationResultUnknown({ String? $type}): $type = $type ?? 'unknown';
  factory McpAuthenticationResultUnknown.fromJson(Map<String, dynamic> json) => _$McpAuthenticationResultUnknownFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$McpAuthenticationResultUnknownToJson(this, );
}





}




/// @nodoc
@JsonSerializable()

class McpAuthenticationStateResult implements McpAuthenticationResult {
  const McpAuthenticationStateResult({required this.state,  String? $type}): $type = $type ?? 'state';
  factory McpAuthenticationStateResult.fromJson(Map<String, dynamic> json) => _$McpAuthenticationStateResultFromJson(json);

 final  McpAuthenticationState state;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$McpAuthenticationStateResultToJson(this, );
}





}




/// @nodoc
@JsonSerializable()

class McpAuthenticationBusy implements McpAuthenticationResult {
  const McpAuthenticationBusy({ String? $type}): $type = $type ?? 'busy';
  factory McpAuthenticationBusy.fromJson(Map<String, dynamic> json) => _$McpAuthenticationBusyFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$McpAuthenticationBusyToJson(this, );
}





}




/// @nodoc
@JsonSerializable()

class McpAuthenticationUnavailable implements McpAuthenticationResult {
  const McpAuthenticationUnavailable({@JsonKey(unknownEnumValue: McpAuthenticationUnavailableReason.unknown) required this.reason,  String? $type}): $type = $type ?? 'unavailable';
  factory McpAuthenticationUnavailable.fromJson(Map<String, dynamic> json) => _$McpAuthenticationUnavailableFromJson(json);

@JsonKey(unknownEnumValue: McpAuthenticationUnavailableReason.unknown) final  McpAuthenticationUnavailableReason reason;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$McpAuthenticationUnavailableToJson(this, );
}





}




// dart format on
