// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.18 (cd9a14a6b688d4021bee381dfd39d2cef9c0f862)

import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import 'location_public_ref.g.dart';
import 'model_ref.g.dart';
import 'permission_ruleset.g.dart';
import 'session_fork_boundary.g.dart';
import 'session_metadata.g.dart';
import 'session_revert.g.dart';
import 'token_usage_info.g.dart';

@immutable
class SessionInfo {
  const SessionInfo({
    required this.id,
    required this.parentID,
    required this.fork,
    required this.projectID,
    required this.agent,
    required this.model,
    required this.cost,
    required this.tokens,
    required this.outcome,
    required this.time,
    required this.title,
    required this.subpath,
    required this.metadata,
    required this.permissions,
    required this.revert,
    required this.location,
  });

  factory SessionInfo.fromJson(Map<String, dynamic> json) {
    return SessionInfo(
      id: json["id"] as String,
      parentID: json["parentID"] as String?,
      fork: json["fork"] == null ? null : SessionInfoFork.fromJson(json["fork"] as Map<String, dynamic>),
      projectID: json["projectID"] as String,
      agent: json["agent"] as String?,
      model: json["model"] == null ? null : ModelRef.fromJson(json["model"] as Map<String, dynamic>),
      cost: (json["cost"] as num).toDouble(),
      tokens: TokenUsageInfo.fromJson(json["tokens"] as Map<String, dynamic>),
      outcome: json["outcome"] == null ? null : SessionInfoOutcome.fromJson(json["outcome"] as String),
      time: SessionInfoTime.fromJson(json["time"] as Map<String, dynamic>),
      title: json["title"] as String?,
      subpath: json["subpath"] as String?,
      metadata: json["metadata"] == null ? null : SessionMetadata.fromJson(json["metadata"] as Map<String, dynamic>),
      permissions: json["permissions"] == null ? null : PermissionRuleset.fromJson(json["permissions"] as List<dynamic>),
      revert: json["revert"] == null ? null : SessionRevert.fromJson(json["revert"] as Map<String, dynamic>),
      location: LocationPublicRef.fromJson(json["location"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "parentID": ?parentID,
      "fork": ?fork?.toJson(),
      "projectID": projectID,
      "agent": ?agent,
      "model": ?model?.toJson(),
      "cost": cost,
      "tokens": tokens.toJson(),
      "outcome": ?outcome?.toJson(),
      "time": time.toJson(),
      "title": ?title,
      "subpath": ?subpath,
      "metadata": ?metadata?.toJson(),
      "permissions": ?permissions?.toJson(),
      "revert": ?revert?.toJson(),
      "location": location.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionInfo copyWith({
    String? id,
    String? parentID,
    SessionInfoFork? fork,
    String? projectID,
    String? agent,
    ModelRef? model,
    double? cost,
    TokenUsageInfo? tokens,
    SessionInfoOutcome? outcome,
    SessionInfoTime? time,
    String? title,
    String? subpath,
    SessionMetadata? metadata,
    PermissionRuleset? permissions,
    SessionRevert? revert,
    LocationPublicRef? location,
  }) {
    return SessionInfo(
      id: id ?? this.id,
      parentID: parentID ?? this.parentID,
      fork: fork ?? this.fork,
      projectID: projectID ?? this.projectID,
      agent: agent ?? this.agent,
      model: model ?? this.model,
      cost: cost ?? this.cost,
      tokens: tokens ?? this.tokens,
      outcome: outcome ?? this.outcome,
      time: time ?? this.time,
      title: title ?? this.title,
      subpath: subpath ?? this.subpath,
      metadata: metadata ?? this.metadata,
      permissions: permissions ?? this.permissions,
      revert: revert ?? this.revert,
      location: location ?? this.location,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionInfo &&
          other.id == id &&
          other.parentID == parentID &&
          other.fork == fork &&
          other.projectID == projectID &&
          other.agent == agent &&
          other.model == model &&
          other.cost == cost &&
          other.tokens == tokens &&
          other.outcome == outcome &&
          other.time == time &&
          other.title == title &&
          other.subpath == subpath &&
          other.metadata == metadata &&
          other.permissions == permissions &&
          other.revert == revert &&
          other.location == location);

  @override
  int get hashCode => Object.hash(id, parentID, fork, projectID, agent, model, cost, tokens, outcome, time, title, subpath, metadata, permissions, revert, location);

  final String id;
  final String? parentID;
  final SessionInfoFork? fork;
  final String projectID;
  final String? agent;
  final ModelRef? model;
  final double cost;
  final TokenUsageInfo tokens;
  final SessionInfoOutcome? outcome;
  final SessionInfoTime time;
  final String? title;
  final String? subpath;
  final SessionMetadata? metadata;
  final PermissionRuleset? permissions;
  final SessionRevert? revert;
  final LocationPublicRef location;
}

@immutable
class SessionInfoFork {
  const SessionInfoFork({
    required this.sessionID,
    required this.boundary,
  });

  factory SessionInfoFork.fromJson(Map<String, dynamic> json) {
    return SessionInfoFork(
      sessionID: json["sessionID"] as String,
      boundary: SessionForkBoundary.fromJson(json["boundary"] as Object),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "sessionID": sessionID,
      "boundary": boundary.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionInfoFork copyWith({
    String? sessionID,
    SessionForkBoundary? boundary,
  }) {
    return SessionInfoFork(
      sessionID: sessionID ?? this.sessionID,
      boundary: boundary ?? this.boundary,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionInfoFork &&
          other.sessionID == sessionID &&
          other.boundary == boundary);

  @override
  int get hashCode => Object.hash(sessionID, boundary);

  final String sessionID;
  final SessionForkBoundary boundary;
}

@immutable
class SessionInfoTime {
  const SessionInfoTime({
    required this.created,
    required this.updated,
    required this.idle,
    required this.viewed,
    required this.archived,
  });

  factory SessionInfoTime.fromJson(Map<String, dynamic> json) {
    return SessionInfoTime(
      created: (json["created"] as num).toDouble(),
      updated: (json["updated"] as num).toDouble(),
      idle: (json["idle"] as num?)?.toDouble(),
      viewed: (json["viewed"] as num?)?.toDouble(),
      archived: (json["archived"] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "created": created,
      "updated": updated,
      "idle": ?idle,
      "viewed": ?viewed,
      "archived": ?archived,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionInfoTime copyWith({
    double? created,
    double? updated,
    double? idle,
    double? viewed,
    double? archived,
  }) {
    return SessionInfoTime(
      created: created ?? this.created,
      updated: updated ?? this.updated,
      idle: idle ?? this.idle,
      viewed: viewed ?? this.viewed,
      archived: archived ?? this.archived,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionInfoTime &&
          other.created == created &&
          other.updated == updated &&
          other.idle == idle &&
          other.viewed == viewed &&
          other.archived == archived);

  @override
  int get hashCode => Object.hash(created, updated, idle, viewed, archived);

  final double created;
  final double updated;
  final double? idle;
  final double? viewed;
  final double? archived;
}

enum SessionInfoOutcome {
  @JsonValue("succeeded")
  succeeded,
  @JsonValue("failed")
  failed,
  @JsonValue("interrupted")
  interrupted,

  /// Fallback for values introduced by newer OpenCode servers.
  /// Encodes back to the literal string `unknown`.
  unknown,
  ;

  static SessionInfoOutcome fromJson(String value) {
    switch (value) {
      case "succeeded":
        return SessionInfoOutcome.succeeded;
      case "failed":
        return SessionInfoOutcome.failed;
      case "interrupted":
        return SessionInfoOutcome.interrupted;
      default:
        return SessionInfoOutcome.unknown;
    }
  }

  String toJson() {
    switch (this) {
      case SessionInfoOutcome.succeeded:
        return "succeeded";
      case SessionInfoOutcome.failed:
        return "failed";
      case SessionInfoOutcome.interrupted:
        return "interrupted";
      case SessionInfoOutcome.unknown:
        return 'unknown';
    }
  }
}
