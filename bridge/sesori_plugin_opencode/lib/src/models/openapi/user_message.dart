// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'message.dart';
import 'output_format.dart';
import 'snapshot_file_diff.dart';

@immutable
class UserMessage implements Message {
  const UserMessage({
    required this.id,
    required this.sessionID,
    required this.time,
    this.format,
    this.summary,
    required this.agent,
    required this.model,
    this.system,
    this.tools,
  });

  factory UserMessage.fromJson(Map<String, dynamic> json) {
    return UserMessage(
      id: json["id"] as String,
      sessionID: json["sessionID"] as String,
      time: UserMessageTime.fromJson(json["time"] as Map<String, dynamic>),
      format: json["format"] == null ? null : OutputFormat.fromJson(json["format"] as Object),
      summary: json["summary"] == null ? null : UserMessageSummary.fromJson(json["summary"] as Map<String, dynamic>),
      agent: json["agent"] as String,
      model: UserMessageModel.fromJson(json["model"] as Map<String, dynamic>),
      system: json["system"] as String?,
      tools: (json["tools"] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as bool)),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "sessionID": sessionID,
      "role": "user",
      "time": time.toJson(),
      "format": ?format?.toJson(),
      "summary": ?summary?.toJson(),
      "agent": agent,
      "model": model.toJson(),
      "system": ?system,
      "tools": ?tools,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserMessage &&
          other.id == id &&
          other.sessionID == sessionID &&
          other.time == time &&
          other.format == format &&
          other.summary == summary &&
          other.agent == agent &&
          other.model == model &&
          other.system == system &&
          const DeepCollectionEquality().equals(other.tools, tools));

  @override
  int get hashCode => Object.hash(id, sessionID, time, format, summary, agent, model, system, const DeepCollectionEquality().hash(tools));

  final String id;
  final String sessionID;
  final UserMessageTime time;
  final OutputFormat? format;
  final UserMessageSummary? summary;
  final String agent;
  final UserMessageModel model;
  final String? system;
  final Map<String, bool>? tools;
}

@immutable
class UserMessageTime {
  const UserMessageTime({
    required this.created,
  });

  factory UserMessageTime.fromJson(Map<String, dynamic> json) {
    return UserMessageTime(
      created: (json["created"] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "created": created,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserMessageTime &&
          other.created == created);

  @override
  int get hashCode => created.hashCode;

  final double created;
}

@immutable
class UserMessageSummary {
  const UserMessageSummary({
    this.title,
    this.body,
    required this.diffs,
  });

  factory UserMessageSummary.fromJson(Map<String, dynamic> json) {
    return UserMessageSummary(
      title: json["title"] as String?,
      body: json["body"] as String?,
      diffs: (json["diffs"] as List<dynamic>).map((e) => SnapshotFileDiff.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "title": ?title,
      "body": ?body,
      "diffs": diffs.map((e) => e.toJson()).toList(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserMessageSummary &&
          other.title == title &&
          other.body == body &&
          const DeepCollectionEquality().equals(other.diffs, diffs));

  @override
  int get hashCode => Object.hash(title, body, const DeepCollectionEquality().hash(diffs));

  final String? title;
  final String? body;
  final List<SnapshotFileDiff> diffs;
}

@immutable
class UserMessageModel {
  const UserMessageModel({
    required this.providerID,
    required this.modelID,
    this.variant,
  });

  factory UserMessageModel.fromJson(Map<String, dynamic> json) {
    return UserMessageModel(
      providerID: json["providerID"] as String,
      modelID: json["modelID"] as String,
      variant: json["variant"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "providerID": providerID,
      "modelID": modelID,
      "variant": ?variant,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserMessageModel &&
          other.providerID == providerID &&
          other.modelID == modelID &&
          other.variant == variant);

  @override
  int get hashCode => Object.hash(providerID, modelID, variant);

  final String providerID;
  final String modelID;
  final String? variant;
}
