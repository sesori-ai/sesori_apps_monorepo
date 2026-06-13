// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

@immutable
class PermissionRequest {
  const PermissionRequest({
    this.id = '',
    this.sessionID = '',
    this.permission = '',
    this.patterns = const [],
    this.metadata = const {},
    this.always = const [],
    this.tool,
  });

  factory PermissionRequest.fromJson(Map<String, dynamic> json) {
    return PermissionRequest(
      id: (json["id"] ?? '') as String,
      sessionID: (json["sessionID"] ?? '') as String,
      permission: (json["permission"] ?? '') as String,
      patterns: ((json["patterns"] ?? const []) as List<dynamic>).cast<String>(),
      metadata: (json["metadata"] ?? const <String, dynamic>{}) as Map<String, dynamic>,
      always: ((json["always"] ?? const []) as List<dynamic>).cast<String>(),
      tool: json["tool"] == null ? null : PermissionRequestTool.fromJson(json["tool"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "sessionID": sessionID,
      "permission": permission,
      "patterns": patterns,
      "metadata": metadata,
      "always": always,
      "tool": ?tool?.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  PermissionRequest copyWith({
    String? id,
    String? sessionID,
    String? permission,
    List<String>? patterns,
    Map<String, dynamic>? metadata,
    List<String>? always,
    PermissionRequestTool? tool,
  }) {
    return PermissionRequest(
      id: id ?? this.id,
      sessionID: sessionID ?? this.sessionID,
      permission: permission ?? this.permission,
      patterns: patterns ?? this.patterns,
      metadata: metadata ?? this.metadata,
      always: always ?? this.always,
      tool: tool ?? this.tool,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PermissionRequest &&
          other.id == id &&
          other.sessionID == sessionID &&
          other.permission == permission &&
          const DeepCollectionEquality().equals(other.patterns, patterns) &&
          const DeepCollectionEquality().equals(other.metadata, metadata) &&
          const DeepCollectionEquality().equals(other.always, always) &&
          other.tool == tool);

  @override
  int get hashCode => Object.hash(id, sessionID, permission, const DeepCollectionEquality().hash(patterns), const DeepCollectionEquality().hash(metadata), const DeepCollectionEquality().hash(always), tool);

  final String id;
  final String sessionID;
  final String permission;
  final List<String> patterns;
  final Map<String, dynamic> metadata;
  final List<String> always;
  final PermissionRequestTool? tool;
}

@immutable
class PermissionRequestTool {
  const PermissionRequestTool({
    this.messageID = '',
    this.callID = '',
  });

  factory PermissionRequestTool.fromJson(Map<String, dynamic> json) {
    return PermissionRequestTool(
      messageID: (json["messageID"] ?? '') as String,
      callID: (json["callID"] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "messageID": messageID,
      "callID": callID,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  PermissionRequestTool copyWith({
    String? messageID,
    String? callID,
  }) {
    return PermissionRequestTool(
      messageID: messageID ?? this.messageID,
      callID: callID ?? this.callID,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PermissionRequestTool &&
          other.messageID == messageID &&
          other.callID == callID);

  @override
  int get hashCode => Object.hash(messageID, callID);

  final String messageID;
  final String callID;
}
