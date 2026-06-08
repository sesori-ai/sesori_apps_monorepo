// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:24:06.239792Z

import 'package:meta/meta.dart';
import 'prompt_source.dart';

@immutable
class PromptReferenceAttachment {
  const PromptReferenceAttachment({
    required this.name,
    required this.kind,
    this.uri,
    this.repository,
    this.branch,
    this.target,
    this.targetUri,
    this.problem,
    this.source,
  });

  factory PromptReferenceAttachment.fromJson(Map<String, dynamic> json) {
    return PromptReferenceAttachment(
      name: json["name"] as String,
      kind: json["kind"] as String,
      uri: json["uri"] as String?,
      repository: json["repository"] as String?,
      branch: json["branch"] as String?,
      target: json["target"] as String?,
      targetUri: json["targetUri"] as String?,
      problem: json["problem"] as String?,
      source: json["source"] == null ? null : PromptSource.fromJson(json["source"] as Map<String, dynamic>),
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "name": name,
      "kind": kind,
      "uri": ?uri,
      "repository": ?repository,
      "branch": ?branch,
      "target": ?target,
      "targetUri": ?targetUri,
      "problem": ?problem,
      "source": ?source?.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PromptReferenceAttachment &&
          other.name == name &&
          other.kind == kind &&
          other.uri == uri &&
          other.repository == repository &&
          other.branch == branch &&
          other.target == target &&
          other.targetUri == targetUri &&
          other.problem == problem &&
          other.source == source);

  @override
  int get hashCode => Object.hash(name, kind, uri, repository, branch, target, targetUri, problem, source);

  final String name;
  final String kind;
  final String? uri;
  final String? repository;
  final String? branch;
  final String? target;
  final String? targetUri;
  final String? problem;
  final PromptSource? source;
}
