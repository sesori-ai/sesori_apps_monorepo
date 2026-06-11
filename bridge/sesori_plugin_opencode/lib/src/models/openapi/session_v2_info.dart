// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'location_ref.dart';

@immutable
class SessionV2Info {
  const SessionV2Info({
    required this.id,
    this.parentID,
    required this.projectID,
    this.agent,
    this.model,
    required this.cost,
    required this.tokens,
    required this.time,
    required this.title,
    required this.location,
    this.subpath,
  });

  factory SessionV2Info.fromJson(Map<String, dynamic> json) {
    return SessionV2Info(
      id: json["id"] as String,
      parentID: json["parentID"] as String?,
      projectID: json["projectID"] as String,
      agent: json["agent"] as String?,
      model: json["model"] == null ? null : SessionV2InfoModel.fromJson(json["model"] as Map<String, dynamic>),
      cost: (json["cost"] as num).toDouble(),
      tokens: SessionV2InfoTokens.fromJson(json["tokens"] as Map<String, dynamic>),
      time: SessionV2InfoTime.fromJson(json["time"] as Map<String, dynamic>),
      title: json["title"] as String,
      location: LocationRef.fromJson(json["location"] as Map<String, dynamic>),
      subpath: json["subpath"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "parentID": ?parentID,
      "projectID": projectID,
      "agent": ?agent,
      "model": ?model?.toJson(),
      "cost": cost,
      "tokens": tokens.toJson(),
      "time": time.toJson(),
      "title": title,
      "location": location.toJson(),
      "subpath": ?subpath,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionV2Info &&
          other.id == id &&
          other.parentID == parentID &&
          other.projectID == projectID &&
          other.agent == agent &&
          other.model == model &&
          other.cost == cost &&
          other.tokens == tokens &&
          other.time == time &&
          other.title == title &&
          other.location == location &&
          other.subpath == subpath);

  @override
  int get hashCode => Object.hash(id, parentID, projectID, agent, model, cost, tokens, time, title, location, subpath);

  final String id;
  final String? parentID;
  final String projectID;
  final String? agent;
  final SessionV2InfoModel? model;
  final double cost;
  final SessionV2InfoTokens tokens;
  final SessionV2InfoTime time;
  final String title;
  final LocationRef location;
  final String? subpath;
}

@immutable
class SessionV2InfoModel {
  const SessionV2InfoModel({
    required this.id,
    required this.providerID,
    this.variant,
  });

  factory SessionV2InfoModel.fromJson(Map<String, dynamic> json) {
    return SessionV2InfoModel(
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
      (other is SessionV2InfoModel &&
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
class SessionV2InfoTokens {
  const SessionV2InfoTokens({
    required this.input,
    required this.output,
    required this.reasoning,
    required this.cache,
  });

  factory SessionV2InfoTokens.fromJson(Map<String, dynamic> json) {
    return SessionV2InfoTokens(
      input: (json["input"] as num).toDouble(),
      output: (json["output"] as num).toDouble(),
      reasoning: (json["reasoning"] as num).toDouble(),
      cache: SessionV2InfoTokensCache.fromJson(json["cache"] as Map<String, dynamic>),
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
      (other is SessionV2InfoTokens &&
          other.input == input &&
          other.output == output &&
          other.reasoning == reasoning &&
          other.cache == cache);

  @override
  int get hashCode => Object.hash(input, output, reasoning, cache);

  final double input;
  final double output;
  final double reasoning;
  final SessionV2InfoTokensCache cache;
}

@immutable
class SessionV2InfoTime {
  const SessionV2InfoTime({
    required this.created,
    required this.updated,
    this.archived,
  });

  factory SessionV2InfoTime.fromJson(Map<String, dynamic> json) {
    return SessionV2InfoTime(
      created: (json["created"] as num).toDouble(),
      updated: (json["updated"] as num).toDouble(),
      archived: (json["archived"] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "created": created,
      "updated": updated,
      "archived": ?archived,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionV2InfoTime &&
          other.created == created &&
          other.updated == updated &&
          other.archived == archived);

  @override
  int get hashCode => Object.hash(created, updated, archived);

  final double created;
  final double updated;
  final double? archived;
}

@immutable
class SessionV2InfoTokensCache {
  const SessionV2InfoTokensCache({
    required this.read,
    required this.write,
  });

  factory SessionV2InfoTokensCache.fromJson(Map<String, dynamic> json) {
    return SessionV2InfoTokensCache(
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
      (other is SessionV2InfoTokensCache &&
          other.read == read &&
          other.write == write);

  @override
  int get hashCode => Object.hash(read, write);

  final double read;
  final double write;
}
