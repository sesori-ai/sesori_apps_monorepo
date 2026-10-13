// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'mcp.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
McpScope _$McpScopeFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'harness':
          return McpHarnessScope.fromJson(
            json
          );
                case 'project':
          return McpProjectScope.fromJson(
            json
          );
                case 'session':
          return McpSessionScope.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'type',
  'McpScope',
  'Invalid union type "${json['type']}"!'
);
        }
      
}

/// @nodoc
mixin _$McpScope {



  /// Serializes this McpScope to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is McpScope);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'McpScope()';
}


}





/// @nodoc
@JsonSerializable()

class McpHarnessScope implements McpScope {
  const McpHarnessScope({ String? $type}): $type = $type ?? 'harness';
  factory McpHarnessScope.fromJson(Map<String, dynamic> json) => _$McpHarnessScopeFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$McpHarnessScopeToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is McpHarnessScope);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'McpScope.harness()';
}


}




/// @nodoc
@JsonSerializable()

class McpProjectScope implements McpScope {
  const McpProjectScope({required this.projectId,  String? $type}): $type = $type ?? 'project';
  factory McpProjectScope.fromJson(Map<String, dynamic> json) => _$McpProjectScopeFromJson(json);

 final  String projectId;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$McpProjectScopeToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is McpProjectScope&&(identical(other.projectId, projectId) || other.projectId == projectId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,projectId);
}

@override
String toString() {
    return 'McpScope.project(projectId: $projectId)';
}


}




/// @nodoc
@JsonSerializable()

class McpSessionScope implements McpScope {
  const McpSessionScope({required this.sessionId,  String? $type}): $type = $type ?? 'session';
  factory McpSessionScope.fromJson(Map<String, dynamic> json) => _$McpSessionScopeFromJson(json);

 final  String sessionId;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$McpSessionScopeToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is McpSessionScope&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,sessionId);
}

@override
String toString() {
    return 'McpScope.session(sessionId: $sessionId)';
}


}




McpEntryTarget _$McpEntryTargetFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'server':
          return McpServerTarget.fromJson(
            json
          );
                case 'connectorOffer':
          return McpConnectorOfferTarget.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'type',
  'McpEntryTarget',
  'Invalid union type "${json['type']}"!'
);
        }
      
}

/// @nodoc
mixin _$McpEntryTarget {

 McpScope get scope;

  /// Serializes this McpEntryTarget to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as McpEntryTarget;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is McpEntryTarget&&(identical(other.scope, _this.scope) || other.scope == _this.scope));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as McpEntryTarget;
  return Object.hash(runtimeType,_this.scope);
}

@override
String toString() {
  final _this = this as McpEntryTarget;
  return 'McpEntryTarget(scope: ${_this.scope})';
}


}





/// @nodoc
@JsonSerializable()

class McpServerTarget implements McpEntryTarget {
  const McpServerTarget({required this.scope, required this.serverKey,  String? $type}): $type = $type ?? 'server';
  factory McpServerTarget.fromJson(Map<String, dynamic> json) => _$McpServerTargetFromJson(json);

@override final  McpScope scope;
 final  String serverKey;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$McpServerTargetToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is McpServerTarget&&(identical(other.scope, scope) || other.scope == scope)&&(identical(other.serverKey, serverKey) || other.serverKey == serverKey));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,scope,serverKey);
}

@override
String toString() {
    return 'McpEntryTarget.server(scope: $scope, serverKey: $serverKey)';
}


}




/// @nodoc
@JsonSerializable()

class McpConnectorOfferTarget implements McpEntryTarget {
  const McpConnectorOfferTarget({required this.scope, required this.offerKey,  String? $type}): $type = $type ?? 'connectorOffer';
  factory McpConnectorOfferTarget.fromJson(Map<String, dynamic> json) => _$McpConnectorOfferTargetFromJson(json);

@override final  McpScope scope;
 final  String offerKey;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$McpConnectorOfferTargetToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is McpConnectorOfferTarget&&(identical(other.scope, scope) || other.scope == scope)&&(identical(other.offerKey, offerKey) || other.offerKey == offerKey));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,scope,offerKey);
}

@override
String toString() {
    return 'McpEntryTarget.connectorOffer(scope: $scope, offerKey: $offerKey)';
}


}




McpConnectionState _$McpConnectionStateFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'status':
          return McpConnectionStatus.fromJson(
            json
          );
                case 'failed':
          return McpConnectionFailed.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'type',
  'McpConnectionState',
  'Invalid union type "${json['type']}"!'
);
        }
      
}

/// @nodoc
mixin _$McpConnectionState {



  /// Serializes this McpConnectionState to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is McpConnectionState);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'McpConnectionState()';
}


}





/// @nodoc
@JsonSerializable()

class McpConnectionStatus implements McpConnectionState {
  const McpConnectionStatus({required this.phase,  String? $type}): $type = $type ?? 'status';
  factory McpConnectionStatus.fromJson(Map<String, dynamic> json) => _$McpConnectionStatusFromJson(json);

 final  McpConnectionPhase phase;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$McpConnectionStatusToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is McpConnectionStatus&&(identical(other.phase, phase) || other.phase == phase));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,phase);
}

@override
String toString() {
    return 'McpConnectionState.status(phase: $phase)';
}


}




/// @nodoc
@JsonSerializable()

class McpConnectionFailed implements McpConnectionState {
  const McpConnectionFailed({required this.message,  String? $type}): $type = $type ?? 'failed';
  factory McpConnectionFailed.fromJson(Map<String, dynamic> json) => _$McpConnectionFailedFromJson(json);

 final  String message;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$McpConnectionFailedToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is McpConnectionFailed&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,message);
}

@override
String toString() {
    return 'McpConnectionState.failed(message: $message)';
}


}





/// @nodoc
mixin _$McpConfigurationSource {

 McpConfigurationScope get scope; McpConfigurationMutability get mutability;

  /// Serializes this McpConfigurationSource to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as McpConfigurationSource;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is McpConfigurationSource&&(identical(other.scope, _this.scope) || other.scope == _this.scope)&&(identical(other.mutability, _this.mutability) || other.mutability == _this.mutability));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as McpConfigurationSource;
  return Object.hash(runtimeType,_this.scope,_this.mutability);
}

@override
String toString() {
  final _this = this as McpConfigurationSource;
  return 'McpConfigurationSource(scope: ${_this.scope}, mutability: ${_this.mutability})';
}


}





/// @nodoc
@JsonSerializable()

class _McpConfigurationSource implements McpConfigurationSource {
  const _McpConfigurationSource({required this.scope, required this.mutability});
  factory _McpConfigurationSource.fromJson(Map<String, dynamic> json) => _$McpConfigurationSourceFromJson(json);

@override final  McpConfigurationScope scope;
@override final  McpConfigurationMutability mutability;


@override
Map<String, dynamic> toJson() {
  return _$McpConfigurationSourceToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _McpConfigurationSource&&(identical(other.scope, scope) || other.scope == scope)&&(identical(other.mutability, mutability) || other.mutability == mutability));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,scope,mutability);
}

@override
String toString() {
    return 'McpConfigurationSource(scope: $scope, mutability: $mutability)';
}


}





/// @nodoc
mixin _$McpTool {

 String get name; String? get description;

  /// Serializes this McpTool to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as McpTool;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is McpTool&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.description, _this.description) || other.description == _this.description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as McpTool;
  return Object.hash(runtimeType,_this.name,_this.description);
}

@override
String toString() {
  final _this = this as McpTool;
  return 'McpTool(name: ${_this.name}, description: ${_this.description})';
}


}





/// @nodoc
@JsonSerializable()

class _McpTool implements McpTool {
  const _McpTool({required this.name, required this.description});
  factory _McpTool.fromJson(Map<String, dynamic> json) => _$McpToolFromJson(json);

@override final  String name;
@override final  String? description;


@override
Map<String, dynamic> toJson() {
  return _$McpToolToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _McpTool&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,name,description);
}

@override
String toString() {
    return 'McpTool(name: $name, description: $description)';
}


}




McpToolInventory _$McpToolInventoryFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'available':
          return McpToolsAvailable.fromJson(
            json
          );
                case 'unavailable':
          return McpToolsUnavailable.fromJson(
            json
          );
                case 'failed':
          return McpToolsFailed.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'type',
  'McpToolInventory',
  'Invalid union type "${json['type']}"!'
);
        }
      
}

/// @nodoc
mixin _$McpToolInventory {



  /// Serializes this McpToolInventory to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is McpToolInventory);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'McpToolInventory()';
}


}





/// @nodoc
@JsonSerializable()

class McpToolsAvailable implements McpToolInventory {
  const McpToolsAvailable({required  List<McpTool> tools,  String? $type}): _tools = tools,$type = $type ?? 'available';
  factory McpToolsAvailable.fromJson(Map<String, dynamic> json) => _$McpToolsAvailableFromJson(json);

 final  List<McpTool> _tools;
 List<McpTool> get tools {
  if (_tools is EqualUnmodifiableListView) return _tools;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tools);
}


@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$McpToolsAvailableToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is McpToolsAvailable&&const DeepCollectionEquality().equals(other.tools, _tools));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_tools));
}

@override
String toString() {
    return 'McpToolInventory.available(tools: $tools)';
}


}




/// @nodoc
@JsonSerializable()

class McpToolsUnavailable implements McpToolInventory {
  const McpToolsUnavailable({ String? $type}): $type = $type ?? 'unavailable';
  factory McpToolsUnavailable.fromJson(Map<String, dynamic> json) => _$McpToolsUnavailableFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$McpToolsUnavailableToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is McpToolsUnavailable);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'McpToolInventory.unavailable()';
}


}




/// @nodoc
@JsonSerializable()

class McpToolsFailed implements McpToolInventory {
  const McpToolsFailed({required this.message,  String? $type}): $type = $type ?? 'failed';
  factory McpToolsFailed.fromJson(Map<String, dynamic> json) => _$McpToolsFailedFromJson(json);

 final  String message;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$McpToolsFailedToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is McpToolsFailed&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,message);
}

@override
String toString() {
    return 'McpToolInventory.failed(message: $message)';
}


}




McpInventoryEntry _$McpInventoryEntryFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'server':
          return McpServerSnapshot.fromJson(
            json
          );
                case 'connectorOffer':
          return McpConnectorOfferSnapshot.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'type',
  'McpInventoryEntry',
  'Invalid union type "${json['type']}"!'
);
        }
      
}

/// @nodoc
mixin _$McpInventoryEntry {

 String get name; String? get description;

  /// Serializes this McpInventoryEntry to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as McpInventoryEntry;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is McpInventoryEntry&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.description, _this.description) || other.description == _this.description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as McpInventoryEntry;
  return Object.hash(runtimeType,_this.name,_this.description);
}

@override
String toString() {
  final _this = this as McpInventoryEntry;
  return 'McpInventoryEntry(name: ${_this.name}, description: ${_this.description})';
}


}





/// @nodoc
@JsonSerializable()

class McpServerSnapshot implements McpInventoryEntry {
  const McpServerSnapshot({@JsonKey(name: "target") required this.serverTarget, required this.name, required this.description, required this.endpointOrigin, required this.connection, required this.authorization, required this.configuration, required this.tools,  String? $type}): $type = $type ?? 'server';
  factory McpServerSnapshot.fromJson(Map<String, dynamic> json) => _$McpServerSnapshotFromJson(json);

@JsonKey(name: "target") final  McpServerTarget serverTarget;
@override final  String name;
@override final  String? description;
 final  String? endpointOrigin;
 final  McpConnectionState connection;
 final  McpAuthorizationState authorization;
 final  McpConfigurationSource? configuration;
 final  McpToolInventory tools;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$McpServerSnapshotToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is McpServerSnapshot&&const DeepCollectionEquality().equals(other.serverTarget, serverTarget)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.endpointOrigin, endpointOrigin) || other.endpointOrigin == endpointOrigin)&&(identical(other.connection, connection) || other.connection == connection)&&(identical(other.authorization, authorization) || other.authorization == authorization)&&(identical(other.configuration, configuration) || other.configuration == configuration)&&(identical(other.tools, tools) || other.tools == tools));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(serverTarget),name,description,endpointOrigin,connection,authorization,configuration,tools);
}

@override
String toString() {
    return 'McpInventoryEntry.server(serverTarget: $serverTarget, name: $name, description: $description, endpointOrigin: $endpointOrigin, connection: $connection, authorization: $authorization, configuration: $configuration, tools: $tools)';
}


}




/// @nodoc
@JsonSerializable()

class McpConnectorOfferSnapshot implements McpInventoryEntry {
  const McpConnectorOfferSnapshot({@JsonKey(name: "target") required this.offerTarget, required this.name, required this.description, required this.availability,  String? $type}): $type = $type ?? 'connectorOffer';
  factory McpConnectorOfferSnapshot.fromJson(Map<String, dynamic> json) => _$McpConnectorOfferSnapshotFromJson(json);

@JsonKey(name: "target") final  McpConnectorOfferTarget offerTarget;
@override final  String name;
@override final  String? description;
 final  McpConnectorOfferAvailability availability;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$McpConnectorOfferSnapshotToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is McpConnectorOfferSnapshot&&const DeepCollectionEquality().equals(other.offerTarget, offerTarget)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.availability, availability) || other.availability == availability));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(offerTarget),name,description,availability);
}

@override
String toString() {
    return 'McpInventoryEntry.connectorOffer(offerTarget: $offerTarget, name: $name, description: $description, availability: $availability)';
}


}




McpCatalogAvailability _$McpCatalogAvailabilityFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'available':
          return McpCatalogAvailable.fromJson(
            json
          );
                case 'notSupported':
          return McpCatalogNotSupported.fromJson(
            json
          );
                case 'unavailable':
          return McpCatalogUnavailable.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'type',
  'McpCatalogAvailability',
  'Invalid union type "${json['type']}"!'
);
        }
      
}

/// @nodoc
mixin _$McpCatalogAvailability {



  /// Serializes this McpCatalogAvailability to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is McpCatalogAvailability);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'McpCatalogAvailability()';
}


}





/// @nodoc
@JsonSerializable()

class McpCatalogAvailable implements McpCatalogAvailability {
  const McpCatalogAvailable({ String? $type}): $type = $type ?? 'available';
  factory McpCatalogAvailable.fromJson(Map<String, dynamic> json) => _$McpCatalogAvailableFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$McpCatalogAvailableToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is McpCatalogAvailable);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'McpCatalogAvailability.available()';
}


}




/// @nodoc
@JsonSerializable()

class McpCatalogNotSupported implements McpCatalogAvailability {
  const McpCatalogNotSupported({ String? $type}): $type = $type ?? 'notSupported';
  factory McpCatalogNotSupported.fromJson(Map<String, dynamic> json) => _$McpCatalogNotSupportedFromJson(json);



@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$McpCatalogNotSupportedToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is McpCatalogNotSupported);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'McpCatalogAvailability.notSupported()';
}


}




/// @nodoc
@JsonSerializable()

class McpCatalogUnavailable implements McpCatalogAvailability {
  const McpCatalogUnavailable({required this.message,  String? $type}): $type = $type ?? 'unavailable';
  factory McpCatalogUnavailable.fromJson(Map<String, dynamic> json) => _$McpCatalogUnavailableFromJson(json);

 final  String message;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$McpCatalogUnavailableToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is McpCatalogUnavailable&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,message);
}

@override
String toString() {
    return 'McpCatalogAvailability.unavailable(message: $message)';
}


}




McpInventoryResult _$McpInventoryResultFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'available':
          return McpInventorySnapshot.fromJson(
            json
          );
                case 'unavailable':
          return McpInventoryUnavailable.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'type',
  'McpInventoryResult',
  'Invalid union type "${json['type']}"!'
);
        }
      
}

/// @nodoc
mixin _$McpInventoryResult {

 McpScope get scope;

  /// Serializes this McpInventoryResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as McpInventoryResult;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is McpInventoryResult&&(identical(other.scope, _this.scope) || other.scope == _this.scope));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as McpInventoryResult;
  return Object.hash(runtimeType,_this.scope);
}

@override
String toString() {
  final _this = this as McpInventoryResult;
  return 'McpInventoryResult(scope: ${_this.scope})';
}


}





/// @nodoc
@JsonSerializable()

class McpInventorySnapshot implements McpInventoryResult {
  const McpInventorySnapshot({required this.scope, required  List<McpInventoryEntry> entries, required this.connectors,  String? $type}): _entries = entries,$type = $type ?? 'available';
  factory McpInventorySnapshot.fromJson(Map<String, dynamic> json) => _$McpInventorySnapshotFromJson(json);

@override final  McpScope scope;
 final  List<McpInventoryEntry> _entries;
 List<McpInventoryEntry> get entries {
  if (_entries is EqualUnmodifiableListView) return _entries;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_entries);
}

 final  McpCatalogAvailability connectors;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$McpInventorySnapshotToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is McpInventorySnapshot&&(identical(other.scope, scope) || other.scope == scope)&&const DeepCollectionEquality().equals(other.entries, _entries)&&(identical(other.connectors, connectors) || other.connectors == connectors));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,scope,const DeepCollectionEquality().hash(_entries),connectors);
}

@override
String toString() {
    return 'McpInventoryResult.available(scope: $scope, entries: $entries, connectors: $connectors)';
}


}




/// @nodoc
@JsonSerializable()

class McpInventoryUnavailable implements McpInventoryResult {
  const McpInventoryUnavailable({required this.scope, required this.reason, required this.message,  String? $type}): $type = $type ?? 'unavailable';
  factory McpInventoryUnavailable.fromJson(Map<String, dynamic> json) => _$McpInventoryUnavailableFromJson(json);

@override final  McpScope scope;
 final  McpInventoryUnavailableReason reason;
 final  String message;

@JsonKey(name: 'type')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$McpInventoryUnavailableToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is McpInventoryUnavailable&&(identical(other.scope, scope) || other.scope == scope)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,scope,reason,message);
}

@override
String toString() {
    return 'McpInventoryResult.unavailable(scope: $scope, reason: $reason, message: $message)';
}


}





/// @nodoc
mixin _$McpInventoryRequest {

 String get pluginId; McpScope get scope;

  /// Serializes this McpInventoryRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as McpInventoryRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is McpInventoryRequest&&(identical(other.pluginId, _this.pluginId) || other.pluginId == _this.pluginId)&&(identical(other.scope, _this.scope) || other.scope == _this.scope));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as McpInventoryRequest;
  return Object.hash(runtimeType,_this.pluginId,_this.scope);
}

@override
String toString() {
  final _this = this as McpInventoryRequest;
  return 'McpInventoryRequest(pluginId: ${_this.pluginId}, scope: ${_this.scope})';
}


}





/// @nodoc
@JsonSerializable()

class _McpInventoryRequest implements McpInventoryRequest {
  const _McpInventoryRequest({required this.pluginId, required this.scope});
  factory _McpInventoryRequest.fromJson(Map<String, dynamic> json) => _$McpInventoryRequestFromJson(json);

@override final  String pluginId;
@override final  McpScope scope;


@override
Map<String, dynamic> toJson() {
  return _$McpInventoryRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _McpInventoryRequest&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId)&&(identical(other.scope, scope) || other.scope == scope));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,pluginId,scope);
}

@override
String toString() {
    return 'McpInventoryRequest(pluginId: $pluginId, scope: $scope)';
}


}




// dart format on
