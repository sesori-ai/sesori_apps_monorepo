// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'mcp_action.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
McpEntryAction _$McpEntryActionFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'server':
          return McpServerEntryAction.fromJson(
            json
          );
                case 'forgetAuthentication':
          return McpForgetAuthenticationEntryAction.fromJson(
            json
          );
                case 'connectorSetup':
          return McpConnectorSetupEntryAction.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'type',
  'McpEntryAction',
  'Invalid union type "${json['type']}"!'
);
        }
      
}

/// @nodoc
mixin _$McpEntryAction {



  /// Serializes this McpEntryAction to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is McpEntryAction);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'McpEntryAction()';
}


}





/// @nodoc
@JsonSerializable()

class McpServerEntryAction extends McpEntryAction {
  const McpServerEntryAction({@JsonKey(fromJson: McpEntryTarget.serverFromJson) required this.target, required this.action,  String? $type}): $type = $type ?? 'server',super._();
  factory McpServerEntryAction.fromJson(Map<String, dynamic> json) => _$McpServerEntryActionFromJson(json);

@JsonKey(fromJson: McpEntryTarget.serverFromJson) final  McpServerTarget target;
 final  McpServerAction action;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$McpServerEntryActionToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is McpServerEntryAction&&const DeepCollectionEquality().equals(other.target, target)&&(identical(other.action, action) || other.action == action));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(target),action);
}

@override
String toString() {
    return 'McpEntryAction.server(target: $target, action: $action)';
}


}




/// @nodoc
@JsonSerializable()

class McpForgetAuthenticationEntryAction extends McpEntryAction {
  const McpForgetAuthenticationEntryAction({@JsonKey(fromJson: McpEntryTarget.serverFromJson) required this.target,  String? $type}): $type = $type ?? 'forgetAuthentication',super._();
  factory McpForgetAuthenticationEntryAction.fromJson(Map<String, dynamic> json) => _$McpForgetAuthenticationEntryActionFromJson(json);

@JsonKey(fromJson: McpEntryTarget.serverFromJson) final  McpServerTarget target;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$McpForgetAuthenticationEntryActionToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is McpForgetAuthenticationEntryAction&&const DeepCollectionEquality().equals(other.target, target));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(target));
}

@override
String toString() {
    return 'McpEntryAction.forgetAuthentication(target: $target)';
}


}




/// @nodoc
@JsonSerializable()

class McpConnectorSetupEntryAction extends McpEntryAction {
  const McpConnectorSetupEntryAction({@JsonKey(name: "target", fromJson: McpEntryTarget.connectorOfferFromJson) required this.offerTarget,  String? $type}): $type = $type ?? 'connectorSetup',super._();
  factory McpConnectorSetupEntryAction.fromJson(Map<String, dynamic> json) => _$McpConnectorSetupEntryActionFromJson(json);

@JsonKey(name: "target", fromJson: McpEntryTarget.connectorOfferFromJson) final  McpConnectorOfferTarget offerTarget;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$McpConnectorSetupEntryActionToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is McpConnectorSetupEntryAction&&const DeepCollectionEquality().equals(other.offerTarget, offerTarget));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(offerTarget));
}

@override
String toString() {
    return 'McpEntryAction.connectorSetup(offerTarget: $offerTarget)';
}


}





/// @nodoc
mixin _$McpEntryActionRequest {

 String get pluginId; McpEntryAction get action;

  /// Serializes this McpEntryActionRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as McpEntryActionRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is McpEntryActionRequest&&(identical(other.pluginId, _this.pluginId) || other.pluginId == _this.pluginId)&&(identical(other.action, _this.action) || other.action == _this.action));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as McpEntryActionRequest;
  return Object.hash(runtimeType,_this.pluginId,_this.action);
}

@override
String toString() {
  final _this = this as McpEntryActionRequest;
  return 'McpEntryActionRequest(pluginId: ${_this.pluginId}, action: ${_this.action})';
}


}





/// @nodoc
@JsonSerializable()

class _McpEntryActionRequest implements McpEntryActionRequest {
  const _McpEntryActionRequest({required this.pluginId, required this.action});
  factory _McpEntryActionRequest.fromJson(Map<String, dynamic> json) => _$McpEntryActionRequestFromJson(json);

@override final  String pluginId;
@override final  McpEntryAction action;


@override
Map<String, dynamic> toJson() {
  return _$McpEntryActionRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _McpEntryActionRequest&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId)&&(identical(other.action, action) || other.action == action));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,pluginId,action);
}

@override
String toString() {
    return 'McpEntryActionRequest(pluginId: $pluginId, action: $action)';
}


}




McpEntryActionResult _$McpEntryActionResultFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'completed':
          return McpActionCompleted.fromJson(
            json
          );
                case 'externalSetup':
          return McpExternalSetup.fromJson(
            json
          );
                case 'unavailable':
          return McpActionUnavailable.fromJson(
            json
          );
                case 'failed':
          return McpActionFailed.fromJson(
            json
          );
        
          default:
            return McpActionUnknown.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$McpEntryActionResult {



  /// Serializes this McpEntryActionResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is McpEntryActionResult);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;



}





/// @nodoc
@JsonSerializable()

class McpActionUnknown implements McpEntryActionResult {
  const McpActionUnknown({ String? $type}): $type = $type ?? 'unknown';
  factory McpActionUnknown.fromJson(Map<String, dynamic> json) => _$McpActionUnknownFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$McpActionUnknownToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is McpActionUnknown);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;



}




/// @nodoc
@JsonSerializable()

class McpActionCompleted implements McpEntryActionResult {
  const McpActionCompleted({required this.inventory,  String? $type}): $type = $type ?? 'completed';
  factory McpActionCompleted.fromJson(Map<String, dynamic> json) => _$McpActionCompletedFromJson(json);

 final  McpInventoryResult inventory;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$McpActionCompletedToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is McpActionCompleted&&(identical(other.inventory, inventory) || other.inventory == inventory));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,inventory);
}



}




/// @nodoc
@JsonSerializable()

class McpExternalSetup implements McpEntryActionResult {
  const McpExternalSetup({required this.setupUrl,  String? $type}): $type = $type ?? 'externalSetup';
  factory McpExternalSetup.fromJson(Map<String, dynamic> json) => _$McpExternalSetupFromJson(json);

 final  String setupUrl;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$McpExternalSetupToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is McpExternalSetup&&(identical(other.setupUrl, setupUrl) || other.setupUrl == setupUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,setupUrl);
}



}




/// @nodoc
@JsonSerializable()

class McpActionUnavailable implements McpEntryActionResult {
  const McpActionUnavailable({@JsonKey(unknownEnumValue: McpActionUnavailableReason.unknown) required this.reason,  String? $type}): $type = $type ?? 'unavailable';
  factory McpActionUnavailable.fromJson(Map<String, dynamic> json) => _$McpActionUnavailableFromJson(json);

@JsonKey(unknownEnumValue: McpActionUnavailableReason.unknown) final  McpActionUnavailableReason reason;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$McpActionUnavailableToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is McpActionUnavailable&&(identical(other.reason, reason) || other.reason == reason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,reason);
}



}




/// @nodoc
@JsonSerializable()

class McpActionFailed implements McpEntryActionResult {
  const McpActionFailed({ String? $type}): $type = $type ?? 'failed';
  factory McpActionFailed.fromJson(Map<String, dynamic> json) => _$McpActionFailedFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$McpActionFailedToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is McpActionFailed);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;



}




// dart format on
