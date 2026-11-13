// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.7 (4ed4f749e644ffb5b279fb30b7b915e743d80142)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'permission_ruleset.g.dart';
import 'snapshot_file_diff.g.dart';

@immutable
class Session {
  const Session({
    required this.id,
    required this.slug,
    required this.projectID,
    required this.workspaceID,
    required this.directory,
    required this.path,
    required this.parentID,
    required this.summary,
    required this.cost,
    required this.tokens,
    required this.share,
    required this.title,
    required this.agent,
    required this.model,
    required this.version,
    required this.metadata,
    required this.time,
    required this.permission,
    required this.revert,
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
      summary: json["summary"] == null ? null : SessionSummary.fromJson(json["summary"] as Map<String, dynamic>),
      cost: (json["cost"] as num?)?.toDouble(),
      tokens: json["tokens"] == null ? null : SessionTokens.fromJson(json["tokens"] as Map<String, dynamic>),
      share: json["share"] == null ? null : SessionShare.fromJson(json["share"] as Map<String, dynamic>),
      title: json["title"] as String?,
      agent: json["agent"] as String?,
      model: json["model"] == null ? null : SessionModel.fromJson(json["model"] as Map<String, dynamic>),
      version: json["version"] as String?,
      metadata: json["metadata"] as Map<String, dynamic>?,
      time: SessionTime.fromJson(json["time"] as Map<String, dynamic>),
      permission: json["permission"] == null ? null : PermissionRuleset.fromJson(json["permission"] as List<dynamic>),
      revert: json["revert"] == null ? null : SessionRevert.fromJson(json["revert"] as Map<String, dynamic>),
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
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  Session copyWith({
    String? id,
    String? slug,
    String? projectID,
    String? workspaceID,
    String? directory,
    String? path,
    String? parentID,
    SessionSummary? summary,
    double? cost,
    SessionTokens? tokens,
    SessionShare? share,
    String? title,
    String? agent,
    SessionModel? model,
    String? version,
    Map<String, dynamic>? metadata,
    SessionTime? time,
    PermissionRuleset? permission,
    SessionRevert? revert,
  }) {
    return Session(
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
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Session &&
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
          other.revert == revert);

  @override
  int get hashCode => Object.hash(id, slug, projectID, workspaceID, directory, path, parentID, summary, cost, tokens, share, title, agent, model, version, const DeepCollectionEquality().hash(metadata), time, permission, revert);

  final String id;
  final String slug;
  final String projectID;
  final String? workspaceID;
  final String directory;
  final String? path;
  final String? parentID;
  final SessionSummary? summary;
  final double? cost;
  final SessionTokens? tokens;
  final SessionShare? share;
  final String? title;
  final String? agent;
  final SessionModel? model;
  final String? version;
  final Map<String, dynamic>? metadata;
  final SessionTime time;
  final PermissionRuleset? permission;
  final SessionRevert? revert;
}

@immutable
class SessionSummary {
  const SessionSummary({
    required this.additions,
    required this.deletions,
    required this.files,
    required this.diffs,
  });

  factory SessionSummary.fromJson(Map<String, dynamic> json) {
    return SessionSummary(
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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionSummary copyWith({
    double? additions,
    double? deletions,
    double? files,
    List<SnapshotFileDiff>? diffs,
  }) {
    return SessionSummary(
      additions: additions ?? this.additions,
      deletions: deletions ?? this.deletions,
      files: files ?? this.files,
      diffs: diffs ?? this.diffs,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionSummary &&
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
class SessionTokens {
  const SessionTokens({
    required this.input,
    required this.output,
    required this.reasoning,
    required this.cache,
  });

  factory SessionTokens.fromJson(Map<String, dynamic> json) {
    return SessionTokens(
      input: (json["input"] as num).toDouble(),
      output: (json["output"] as num).toDouble(),
      reasoning: (json["reasoning"] as num).toDouble(),
      cache: SessionTokensCache.fromJson(json["cache"] as Map<String, dynamic>),
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
  SessionTokens copyWith({
    double? input,
    double? output,
    double? reasoning,
    SessionTokensCache? cache,
  }) {
    return SessionTokens(
      input: input ?? this.input,
      output: output ?? this.output,
      reasoning: reasoning ?? this.reasoning,
      cache: cache ?? this.cache,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionTokens &&
          other.input == input &&
          other.output == output &&
          other.reasoning == reasoning &&
          other.cache == cache);

  @override
  int get hashCode => Object.hash(input, output, reasoning, cache);

  final double input;
  final double output;
  final double reasoning;
  final SessionTokensCache cache;
}

@immutable
class SessionShare {
  const SessionShare({
    required this.url,
  });

  factory SessionShare.fromJson(Map<String, dynamic> json) {
    return SessionShare(
      url: json["url"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "url": url,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionShare copyWith({
    String? url,
  }) {
    return SessionShare(
      url: url ?? this.url,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionShare &&
          other.url == url);

  @override
  int get hashCode => url.hashCode;

  final String url;
}

@immutable
class SessionModel {
  const SessionModel({
    required this.id,
    required this.providerID,
    required this.variant,
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionModel copyWith({
    String? id,
    String? providerID,
    String? variant,
  }) {
    return SessionModel(
      id: id ?? this.id,
      providerID: providerID ?? this.providerID,
      variant: variant ?? this.variant,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionModel &&
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
class SessionTime {
  const SessionTime({
    required this.created,
    required this.updated,
    required this.compacting,
    required this.archived,
  });

  factory SessionTime.fromJson(Map<String, dynamic> json) {
    return SessionTime(
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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionTime copyWith({
    int? created,
    int? updated,
    int? compacting,
    double? archived,
  }) {
    return SessionTime(
      created: created ?? this.created,
      updated: updated ?? this.updated,
      compacting: compacting ?? this.compacting,
      archived: archived ?? this.archived,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionTime &&
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
class SessionRevert {
  const SessionRevert({
    required this.messageID,
    required this.partID,
    required this.snapshot,
    required this.diff,
  });

  factory SessionRevert.fromJson(Map<String, dynamic> json) {
    return SessionRevert(
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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionRevert copyWith({
    String? messageID,
    String? partID,
    String? snapshot,
    String? diff,
  }) {
    return SessionRevert(
      messageID: messageID ?? this.messageID,
      partID: partID ?? this.partID,
      snapshot: snapshot ?? this.snapshot,
      diff: diff ?? this.diff,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionRevert &&
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
class SessionTokensCache {
  const SessionTokensCache({
    required this.read,
    required this.write,
  });

  factory SessionTokensCache.fromJson(Map<String, dynamic> json) {
    return SessionTokensCache(
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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionTokensCache copyWith({
    double? read,
    double? write,
  }) {
    return SessionTokensCache(
      read: read ?? this.read,
      write: write ?? this.write,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionTokensCache &&
          other.read == read &&
          other.write == write);

  @override
  int get hashCode => Object.hash(read, write);

  final double read;
  final double write;
}
