// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'permission_ruleset.dart';
import 'project_summary.dart';
import 'snapshot_file_diff.dart';

@immutable
class GlobalSession {
  const GlobalSession({
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
    required this.project,
  });

  factory GlobalSession.fromJson(Map<String, dynamic> json) {
    return GlobalSession(
      id: json["id"] as String,
      slug: json["slug"] as String,
      projectID: json["projectID"] as String,
      workspaceID: json["workspaceID"] as String?,
      directory: json["directory"] as String,
      path: json["path"] as String?,
      parentID: json["parentID"] as String?,
      summary: json["summary"] == null ? null : GlobalSessionSummary.fromJson(json["summary"] as Map<String, dynamic>),
      cost: (json["cost"] as num?)?.toDouble(),
      tokens: json["tokens"] == null ? null : GlobalSessionTokens.fromJson(json["tokens"] as Map<String, dynamic>),
      share: json["share"] == null ? null : GlobalSessionShare.fromJson(json["share"] as Map<String, dynamic>),
      title: json["title"] as String,
      agent: json["agent"] as String?,
      model: json["model"] == null ? null : GlobalSessionModel.fromJson(json["model"] as Map<String, dynamic>),
      version: json["version"] as String,
      metadata: json["metadata"] as Map<String, dynamic>?,
      time: GlobalSessionTime.fromJson(json["time"] as Map<String, dynamic>),
      permission: json["permission"] == null ? null : PermissionRuleset.fromJson(json["permission"] as List<dynamic>),
      revert: json["revert"] == null ? null : GlobalSessionRevert.fromJson(json["revert"] as Map<String, dynamic>),
      project: json["project"] == null ? null : ProjectSummary.fromJson(json["project"] as Map<String, dynamic>),
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
      "summary": ?summary?.toJson(),
      "cost": ?cost,
      "tokens": ?tokens?.toJson(),
      "share": ?share?.toJson(),
      "title": title,
      "agent": ?agent,
      "model": ?model?.toJson(),
      "version": version,
      "metadata": ?metadata,
      "time": time.toJson(),
      "permission": ?permission?.toJson(),
      "revert": ?revert?.toJson(),
      "project": ?project?.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GlobalSession &&
          other.id == id &&
          other.slug == slug &&
          other.projectID == projectID &&
          other.workspaceID == workspaceID &&
          other.directory == directory &&
          other.path == path &&
          other.parentID == parentID &&
          other.summary == summary &&
          other.cost == cost &&
          other.tokens == tokens &&
          other.share == share &&
          other.title == title &&
          other.agent == agent &&
          other.model == model &&
          other.version == version &&
          const DeepCollectionEquality().equals(other.metadata, metadata) &&
          other.time == time &&
          other.permission == permission &&
          other.revert == revert &&
          other.project == project);

  @override
  int get hashCode => Object.hash(id, slug, projectID, workspaceID, directory, path, parentID, summary, cost, tokens, share, title, agent, model, version, const DeepCollectionEquality().hash(metadata), time, permission, revert, project);

  final String id;
  final String slug;
  final String projectID;
  final String? workspaceID;
  final String directory;
  final String? path;
  final String? parentID;
  final GlobalSessionSummary? summary;
  final double? cost;
  final GlobalSessionTokens? tokens;
  final GlobalSessionShare? share;
  final String title;
  final String? agent;
  final GlobalSessionModel? model;
  final String version;
  final Map<String, dynamic>? metadata;
  final GlobalSessionTime time;
  final PermissionRuleset? permission;
  final GlobalSessionRevert? revert;
  final ProjectSummary? project;
}

@immutable
class GlobalSessionSummary {
  const GlobalSessionSummary({
    required this.additions,
    required this.deletions,
    required this.files,
    this.diffs,
  });

  factory GlobalSessionSummary.fromJson(Map<String, dynamic> json) {
    return GlobalSessionSummary(
      additions: (json["additions"] as num).toDouble(),
      deletions: (json["deletions"] as num).toDouble(),
      files: (json["files"] as num).toDouble(),
      diffs: (json["diffs"] as List<dynamic>?)?.map((e) => SnapshotFileDiff.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "additions": additions,
      "deletions": deletions,
      "files": files,
      "diffs": ?diffs?.map((e) => e.toJson()).toList(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GlobalSessionSummary &&
          other.additions == additions &&
          other.deletions == deletions &&
          other.files == files &&
          const DeepCollectionEquality().equals(other.diffs, diffs));

  @override
  int get hashCode => Object.hash(additions, deletions, files, const DeepCollectionEquality().hash(diffs));

  final double additions;
  final double deletions;
  final double files;
  final List<SnapshotFileDiff>? diffs;
}

@immutable
class GlobalSessionTokens {
  const GlobalSessionTokens({
    required this.input,
    required this.output,
    required this.reasoning,
    required this.cache,
  });

  factory GlobalSessionTokens.fromJson(Map<String, dynamic> json) {
    return GlobalSessionTokens(
      input: (json["input"] as num).toDouble(),
      output: (json["output"] as num).toDouble(),
      reasoning: (json["reasoning"] as num).toDouble(),
      cache: GlobalSessionTokensCache.fromJson(json["cache"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "input": input,
      "output": output,
      "reasoning": reasoning,
      "cache": cache.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GlobalSessionTokens &&
          other.input == input &&
          other.output == output &&
          other.reasoning == reasoning &&
          other.cache == cache);

  @override
  int get hashCode => Object.hash(input, output, reasoning, cache);

  final double input;
  final double output;
  final double reasoning;
  final GlobalSessionTokensCache cache;
}

@immutable
class GlobalSessionShare {
  const GlobalSessionShare({
    required this.url,
  });

  factory GlobalSessionShare.fromJson(Map<String, dynamic> json) {
    return GlobalSessionShare(
      url: json["url"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "url": url,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GlobalSessionShare &&
          other.url == url);

  @override
  int get hashCode => url.hashCode;

  final String url;
}

@immutable
class GlobalSessionModel {
  const GlobalSessionModel({
    required this.id,
    required this.providerID,
    this.variant,
  });

  factory GlobalSessionModel.fromJson(Map<String, dynamic> json) {
    return GlobalSessionModel(
      id: json["id"] as String,
      providerID: json["providerID"] as String,
      variant: json["variant"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "providerID": providerID,
      "variant": ?variant,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GlobalSessionModel &&
          other.id == id &&
          other.providerID == providerID &&
          other.variant == variant);

  @override
  int get hashCode => Object.hash(id, providerID, variant);

  final String id;
  final String providerID;
  final String? variant;
}

@immutable
class GlobalSessionTime {
  const GlobalSessionTime({
    required this.created,
    required this.updated,
    this.compacting,
    this.archived,
  });

  factory GlobalSessionTime.fromJson(Map<String, dynamic> json) {
    return GlobalSessionTime(
      created: (json["created"] as num).toInt(),
      updated: (json["updated"] as num).toInt(),
      compacting: (json["compacting"] as num?)?.toInt(),
      archived: (json["archived"] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "created": created,
      "updated": updated,
      "compacting": ?compacting,
      "archived": ?archived,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GlobalSessionTime &&
          other.created == created &&
          other.updated == updated &&
          other.compacting == compacting &&
          other.archived == archived);

  @override
  int get hashCode => Object.hash(created, updated, compacting, archived);

  final int created;
  final int updated;
  final int? compacting;
  final double? archived;
}

@immutable
class GlobalSessionRevert {
  const GlobalSessionRevert({
    required this.messageID,
    this.partID,
    this.snapshot,
    this.diff,
  });

  factory GlobalSessionRevert.fromJson(Map<String, dynamic> json) {
    return GlobalSessionRevert(
      messageID: json["messageID"] as String,
      partID: json["partID"] as String?,
      snapshot: json["snapshot"] as String?,
      diff: json["diff"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "messageID": messageID,
      "partID": ?partID,
      "snapshot": ?snapshot,
      "diff": ?diff,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GlobalSessionRevert &&
          other.messageID == messageID &&
          other.partID == partID &&
          other.snapshot == snapshot &&
          other.diff == diff);

  @override
  int get hashCode => Object.hash(messageID, partID, snapshot, diff);

  final String messageID;
  final String? partID;
  final String? snapshot;
  final String? diff;
}

@immutable
class GlobalSessionTokensCache {
  const GlobalSessionTokensCache({
    required this.read,
    required this.write,
  });

  factory GlobalSessionTokensCache.fromJson(Map<String, dynamic> json) {
    return GlobalSessionTokensCache(
      read: (json["read"] as num).toDouble(),
      write: (json["write"] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "read": read,
      "write": write,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GlobalSessionTokensCache &&
          other.read == read &&
          other.write == write);

  @override
  int get hashCode => Object.hash(read, write);

  final double read;
  final double write;
}
