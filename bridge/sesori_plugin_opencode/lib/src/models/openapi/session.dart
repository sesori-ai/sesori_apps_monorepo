// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T13:43:24.187932Z

import 'permission_ruleset.dart';

class Session {
  const Session({
    required this.id,
    required this.slug,
    required this.projectID,
    this.workspaceID,
    required this.directory,
    this.path,
    this.parentID,
    this.summary,
    this.cost,
    this.tokens,
    this.share,
    required this.title,
    this.agent,
    this.model,
    required this.version,
    this.metadata,
    required this.time,
    this.permission,
    this.revert,
  });

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: json["id"] as String,
      slug: json["slug"] as String,
      projectID: json["projectID"] as String,
      workspaceID: json["workspaceID"] as String?,
      directory: json["directory"] as String,
      path: json["path"] as String?,
      parentID: json["parentID"] as String?,
      summary: json["summary"] as Map<String, dynamic>?,
      cost: (json["cost"] as num?)?.toDouble(),
      tokens: json["tokens"] as Map<String, dynamic>?,
      share: json["share"] as Map<String, dynamic>?,
      title: json["title"] as String,
      agent: json["agent"] as String?,
      model: json["model"] as Map<String, dynamic>?,
      version: json["version"] as String,
      metadata: json["metadata"] as Map<String, dynamic>?,
      time: json["time"] as Map<String, dynamic>,
      permission: json["permission"] == null ? null : PermissionRuleset.fromJson(json["permission"] as List<dynamic>),
      revert: json["revert"] as Map<String, dynamic>?,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "slug": slug,
      "projectID": projectID,
      "workspaceID": ?workspaceID,
      "directory": directory,
      "path": ?path,
      "parentID": ?parentID,
      "summary": ?summary,
      "cost": ?cost,
      "tokens": ?tokens,
      "share": ?share,
      "title": title,
      "agent": ?agent,
      "model": ?model,
      "version": version,
      "metadata": ?metadata,
      "time": time,
      "permission": ?permission?.toJson(),
      "revert": ?revert,
    };
  }

  final String id;
  final String slug;
  final String projectID;
  final String? workspaceID;
  final String directory;
  final String? path;
  final String? parentID;
  final Map<String, dynamic>? summary;
  final double? cost;
  final Map<String, dynamic>? tokens;
  final Map<String, dynamic>? share;
  final String title;
  final String? agent;
  final Map<String, dynamic>? model;
  final String version;
  final Map<String, dynamic>? metadata;
  final Map<String, dynamic> time;
  final PermissionRuleset? permission;
  final Map<String, dynamic>? revert;
}
