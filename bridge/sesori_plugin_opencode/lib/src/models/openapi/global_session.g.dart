// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'permission_ruleset.g.dart';
import 'project_summary.g.dart';
import 'snapshot_file_diff.g.dart';

@immutable
class GlobalSession {
  const GlobalSession({
    this.id = '',
    this.slug = '',
    this.projectID = '',
    this.workspaceID,
    this.directory = '',
    this.path,
    this.parentID,
    this.summary,
    this.cost,
    this.tokens,
    this.share,
    this.title = '',
    this.agent,
    this.model,
    this.version = '',
    this.metadata,
    this.time = const GlobalSessionTime(created: 0, updated: 0),
    this.permission,
    this.revert,
    required this.project,
  });

  factory GlobalSession.fromJson(Map<String, dynamic> json) {
    return GlobalSession(
      id: (json["id"] ?? '') as String,
      slug: (json["slug"] ?? '') as String,
      projectID: (json["projectID"] ?? '') as String,
      workspaceID: json["workspaceID"] as String?,
      directory: (json["directory"] ?? '') as String,
      path: json["path"] as String?,
      parentID: json["parentID"] as String?,
      summary: json["summary"] == null ? null : GlobalSessionSummary.fromJson(json["summary"] as Map<String, dynamic>),
      cost: (json["cost"] as num?)?.toDouble(),
      tokens: json["tokens"] == null ? null : GlobalSessionTokens.fromJson(json["tokens"] as Map<String, dynamic>),
      share: json["share"] == null ? null : GlobalSessionShare.fromJson(json["share"] as Map<String, dynamic>),
      title: (json["title"] ?? '') as String,
      agent: json["agent"] as String?,
      model: json["model"] == null ? null : GlobalSessionModel.fromJson(json["model"] as Map<String, dynamic>),
      version: (json["version"] ?? '') as String,
      metadata: json["metadata"] as Map<String, dynamic>?,
      time: GlobalSessionTime.fromJson((json["time"] ?? const <String, dynamic>{}) as Map<String, dynamic>),
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
      "project": project?.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  GlobalSession copyWith({
    String? id,
    String? slug,
    String? projectID,
    String? workspaceID,
    String? directory,
    String? path,
    String? parentID,
    GlobalSessionSummary? summary,
    double? cost,
    GlobalSessionTokens? tokens,
    GlobalSessionShare? share,
    String? title,
    String? agent,
    GlobalSessionModel? model,
    String? version,
    Map<String, dynamic>? metadata,
    GlobalSessionTime? time,
    PermissionRuleset? permission,
    GlobalSessionRevert? revert,
    ProjectSummary? project,
  }) {
    return GlobalSession(
      id: id ?? this.id,
      slug: slug ?? this.slug,
      projectID: projectID ?? this.projectID,
      workspaceID: workspaceID ?? this.workspaceID,
      directory: directory ?? this.directory,
      path: path ?? this.path,
      parentID: parentID ?? this.parentID,
      summary: summary ?? this.summary,
      cost: cost ?? this.cost,
      tokens: tokens ?? this.tokens,
      share: share ?? this.share,
      title: title ?? this.title,
      agent: agent ?? this.agent,
      model: model ?? this.model,
      version: version ?? this.version,
      metadata: metadata ?? this.metadata,
      time: time ?? this.time,
      permission: permission ?? this.permission,
      revert: revert ?? this.revert,
      project: project ?? this.project,
    );
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
    this.additions = 0,
    this.deletions = 0,
    this.files = 0,
    this.diffs,
  });

  factory GlobalSessionSummary.fromJson(Map<String, dynamic> json) {
    return GlobalSessionSummary(
      additions: ((json["additions"] ?? 0) as num).toDouble(),
      deletions: ((json["deletions"] ?? 0) as num).toDouble(),
      files: ((json["files"] ?? 0) as num).toDouble(),
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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  GlobalSessionSummary copyWith({
    double? additions,
    double? deletions,
    double? files,
    List<SnapshotFileDiff>? diffs,
  }) {
    return GlobalSessionSummary(
      additions: additions ?? this.additions,
      deletions: deletions ?? this.deletions,
      files: files ?? this.files,
      diffs: diffs ?? this.diffs,
    );
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
    this.input = 0,
    this.output = 0,
    this.reasoning = 0,
    required this.cache,
  });

  factory GlobalSessionTokens.fromJson(Map<String, dynamic> json) {
    return GlobalSessionTokens(
      input: ((json["input"] ?? 0) as num).toDouble(),
      output: ((json["output"] ?? 0) as num).toDouble(),
      reasoning: ((json["reasoning"] ?? 0) as num).toDouble(),
      cache: GlobalSessionTokensCache.fromJson((json["cache"] ?? const <String, dynamic>{}) as Map<String, dynamic>),
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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  GlobalSessionTokens copyWith({
    double? input,
    double? output,
    double? reasoning,
    GlobalSessionTokensCache? cache,
  }) {
    return GlobalSessionTokens(
      input: input ?? this.input,
      output: output ?? this.output,
      reasoning: reasoning ?? this.reasoning,
      cache: cache ?? this.cache,
    );
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
    this.url = '',
  });

  factory GlobalSessionShare.fromJson(Map<String, dynamic> json) {
    return GlobalSessionShare(
      url: (json["url"] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "url": url,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  GlobalSessionShare copyWith({
    String? url,
  }) {
    return GlobalSessionShare(
      url: url ?? this.url,
    );
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
    this.id = '',
    this.providerID = '',
    this.variant,
  });

  factory GlobalSessionModel.fromJson(Map<String, dynamic> json) {
    return GlobalSessionModel(
      id: (json["id"] ?? '') as String,
      providerID: (json["providerID"] ?? '') as String,
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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  GlobalSessionModel copyWith({
    String? id,
    String? providerID,
    String? variant,
  }) {
    return GlobalSessionModel(
      id: id ?? this.id,
      providerID: providerID ?? this.providerID,
      variant: variant ?? this.variant,
    );
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
    this.created = 0,
    this.updated = 0,
    this.compacting,
    this.archived,
  });

  factory GlobalSessionTime.fromJson(Map<String, dynamic> json) {
    return GlobalSessionTime(
      created: ((json["created"] ?? 0) as num).toInt(),
      updated: ((json["updated"] ?? 0) as num).toInt(),
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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  GlobalSessionTime copyWith({
    int? created,
    int? updated,
    int? compacting,
    double? archived,
  }) {
    return GlobalSessionTime(
      created: created ?? this.created,
      updated: updated ?? this.updated,
      compacting: compacting ?? this.compacting,
      archived: archived ?? this.archived,
    );
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
    this.messageID = '',
    this.partID,
    this.snapshot,
    this.diff,
  });

  factory GlobalSessionRevert.fromJson(Map<String, dynamic> json) {
    return GlobalSessionRevert(
      messageID: (json["messageID"] ?? '') as String,
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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  GlobalSessionRevert copyWith({
    String? messageID,
    String? partID,
    String? snapshot,
    String? diff,
  }) {
    return GlobalSessionRevert(
      messageID: messageID ?? this.messageID,
      partID: partID ?? this.partID,
      snapshot: snapshot ?? this.snapshot,
      diff: diff ?? this.diff,
    );
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
    this.read = 0,
    this.write = 0,
  });

  factory GlobalSessionTokensCache.fromJson(Map<String, dynamic> json) {
    return GlobalSessionTokensCache(
      read: ((json["read"] ?? 0) as num).toDouble(),
      write: ((json["write"] ?? 0) as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "read": read,
      "write": write,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  GlobalSessionTokensCache copyWith({
    double? read,
    double? write,
  }) {
    return GlobalSessionTokensCache(
      read: read ?? this.read,
      write: write ?? this.write,
    );
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
